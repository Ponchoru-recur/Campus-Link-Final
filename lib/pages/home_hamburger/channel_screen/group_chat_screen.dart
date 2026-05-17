import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_item.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_avatars.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message_actions.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message_edit_delete.dart';
import 'package:luminescence/pages/tasks/create_task_screen.dart';
import 'package:luminescence/widgets/task_bubble.dart';
import 'package:luminescence/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

final _urlRegex = RegExp(
  r'(https?://[^\s<]+)',
  caseSensitive: false,
);

/// The full conversation screen for a GROUP CHAT.
/// Edit this file to change how group chat conversations look and behave.
class GroupChatScreen extends StatefulWidget {
  final ChatItem chat;

  const GroupChatScreen({super.key, required this.chat});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _groupName;
  late String _chatId;
  bool _isAdmin = false;
  bool _isFaculty = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedMemberUids = {};
  final Set<String> _markedAsRead = {};
  List<Map<String, dynamic>> _firestoreMembers = [];
  Map<String, String> _uidToName = {};
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _groupDocSubscription;
  bool _isMarkingRead = false;
  final LayerLink _mentionLayerLink = LayerLink();

  // Pinned messages
  StreamSubscription<QuerySnapshot>? _pinnedSubscription;
  List<Message> _pinnedMessages = [];
  bool _pinnedBarExpanded = true;

  // Notification strategy
  String _notificationStrategy = 'mentionsOnly';

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Messages loaded from Firestore stream
  final List<Message> _messages = [];

  void _sendMessage() async {
    String text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email ?? '';
    final senderName = email.isEmpty
        ? 'Me'
        : email
            .split('@')
            .first
            .replaceAll('.', ' ')
            .split(' ')
            .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
            .join(' ');

    _controller.clear();

    try {
      final firestore = FirebaseFirestore.instance;
      final messagesRef = firestore
          .collection('group_chats')
          .doc(_chatId)
          .collection('messages');

      // Parse @mentions from message text (D-02, D-04)
      final mentionRegex = RegExp(r'@(\w+(?: \w+)*)');
      final mentionMatches = mentionRegex.allMatches(text);
      final mentionedUids = <String>[];
      for (final match in mentionMatches) {
        final displayName = match.group(1)!;
        final uid = _uidToName.entries
            .firstWhere(
              (e) => e.value.toLowerCase() == displayName.toLowerCase(),
              orElse: () => const MapEntry('', ''),
            )
            .key;
        if (uid.isNotEmpty && uid != user.uid) mentionedUids.add(uid);
      }

      // @everyone: pinned message for all roles (D-05, D-06)
      final hasEveryone = text.contains('@everyone');
      DateTime? pinnedUntil;
      if (hasEveryone) {
        pinnedUntil = DateTime.now().add(const Duration(hours: 24));
      }

      final docRef = await messagesRef.add({
        'senderId': user.uid,
        'senderName': senderName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'readBy': [user.uid],
        'mentionedUids': mentionedUids, // NEW per D-04
        if (pinnedUntil != null)
          'pinnedUntil': Timestamp.fromDate(pinnedUntil), // NEW per D-11
      });

      // Audit log: record @everyone usage
      if (hasEveryone) {
        final everyoneCallsRef = firestore
            .collection('group_chats').doc(_chatId)
            .collection('everyone_calls');
        everyoneCallsRef.add({
          'senderId': user.uid,
          'senderName': senderName,
          'messageId': docRef.id,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'expireAt': Timestamp.fromMillisecondsSinceEpoch(
            DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
          ),
        });
      }

      // Audit log: record @mentions for each mentioned user
      if (mentionedUids.isNotEmpty) {
        final mentionsRef = firestore
            .collection('group_chats').doc(_chatId)
            .collection('mentions');
        final writeBatch = firestore.batch();
        for (final uid in mentionedUids) {
          final mentionDoc = mentionsRef.doc();
          writeBatch.set(mentionDoc, {
            'senderId': user.uid,
            'senderName': senderName,
            'messageId': docRef.id,
            'text': text,
            'mentionedUid': uid,
            'timestamp': FieldValue.serverTimestamp(),
            'expireAt': Timestamp.fromMillisecondsSinceEpoch(
              DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
            ),
          });
        }
        writeBatch.commit();
      }

      // Fire-and-forget notification dispatch to Worker
      NotificationService.instance.sendTieredNotification(
        chatId: _chatId,
        messageId: docRef.id,
        senderId: user.uid,
        senderName: senderName,
        chatName: widget.chat.name,
        text: text,
        mentionedUids: mentionedUids,
        isEveryone: hasEveryone,
        isTask: false,
      );

      await firestore.collection('group_chats').doc(_chatId).update({
        'lastMessage': text,
        'time': 'Now',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      // Increment unreadCount for other members
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        final chatDoc = await firestore.collection('group_chats').doc(_chatId).get();
        if (chatDoc.exists) {
          final data = chatDoc.data()!;
          final members = List<String>.from(data['members'] ?? []);
          final unreadCount = data['unreadCount'];
          Map<String, dynamic> updateMap = {};
          if (unreadCount is Map) {
            for (final uid in members) {
              if (uid == currentUid) continue;
              final currentCount = (unreadCount[uid] ?? 0) as int;
              updateMap['unreadCount.$uid'] = currentCount + 1;
            }
          } else {
            // Old format: initialize new map
            updateMap['unreadCount'] = {};
            for (final uid in members) {
              if (uid == currentUid) {
                updateMap['unreadCount.$uid'] = 0;
              } else {
                updateMap['unreadCount.$uid'] = 1;
              }
            }
          }
          if (updateMap.isNotEmpty) {
            await firestore.collection('group_chats').doc(_chatId).update(updateMap);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _showTaskCreation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTaskScreen(
          prefilledChatId: _chatId,
          prefilledChatType: 'group',
          prefilledRecipientName: _groupName,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  void initState() {
    super.initState();
    _chatId = widget.chat.id;
    NotificationService.activeChatId = _chatId;
    _groupName = widget.chat.name;
    _checkAdminStatus();
    _resetUnreadCount();
    _setupGroupStream();
    _setupMessagesStream();
    _loadMembers();
    _setupPinnedStream();
    _loadNotificationStrategy();
  }

  Future<void> _checkAdminStatus() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(widget.chat.id)
          .get()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final isCreator = groupDoc.data()?['createdBy'] == user.uid;
      final isFaculty = userDoc.data()?['role'] == 'faculty';
      setState(() {
        _isAdmin = isCreator || isFaculty;
        _isFaculty = isFaculty;
      });
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  Future<void> _resetUnreadCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('group_chats')
          .doc(_chatId);
      final doc = await docRef.get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final unreadCount = data['unreadCount'];
      if (unreadCount is Map && (unreadCount[user.uid] ?? 0) > 0) {
        await docRef.update({
          'unreadCount.${user.uid}': 0,
        });
      }
    } catch (e) {
      debugPrint('Error resetting unread count: $e');
    }
  }

  void _setupGroupStream() {
    _groupDocSubscription = FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.chat.id)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final data = snapshot.data();
      if (data != null) {
        setState(() {
          _groupName = data['name'] ?? widget.chat.name;
        });
      }
    }, onError: (e) {
      debugPrint('Error in group stream: $e');
    });
  }

  DateTime _parseEditedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  void _setupMessagesStream() {
    _messagesSubscription = FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.chat.id)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      try {
        setState(() {
        _messages.clear();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final senderId = data['senderId'] ?? '';
          final isMe = senderId == FirebaseAuth.instance.currentUser?.uid;
          final editHistoryRaw = data['editHistory'] as List<dynamic>? ?? [];
          final editHistory = editHistoryRaw.map((e) {
            final map = e as Map<String, dynamic>;
            return EditEntry(
              text: map['text'] ?? '',
              editedAt: _parseEditedAt(map['editedAt']),
            );
          }).toList();
          _messages.add(Message(
            id: doc.id,
            senderId: senderId,
            senderName: (data['senderName'] as String?)?.isNotEmpty == true
                ? data['senderName']
                : 'Unknown',
            text: data['text'] ?? '',
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isMe: isMe,
            type: data['type'],
            readBy: List<String>.from(data['readBy'] ?? []),
            editHistory: editHistory,
            isDeleted: data['isDeleted'] ?? false,
            taskId: data['taskId'],
            mentionedUids: List<String>.from(data['mentionedUids'] ?? []),
            pinnedUntil: (data['pinnedUntil'] as Timestamp?)?.toDate(),
          ));
        }
      });
      _markMessagesAsRead();
      } catch (e, stack) {
        debugPrint('Error processing messages stream: $e');
        debugPrint('$stack');
      }
    }, onError: (e) {
      debugPrint('Error in messages stream: $e');
    });
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(widget.chat.id)
          .get()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final groupData = groupDoc.data();
      if (groupData == null) return;
      final members = List<String>.from(groupData['members'] ?? []);
      final userDocs = await Future.wait(
        members.map((uid) => FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 10))),
      );
      if (!mounted) return;
      setState(() {
        _firestoreMembers = userDocs.map((doc) {
          final data = doc.data();
          final isCreator = doc.id == groupData['createdBy'];
          final isFaculty = data?['role'] == 'faculty';
          return {
            'uid': doc.id,
            'name': data?['email']?.split('@').first.replaceAll('.', ' ').split(' ').map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join(' ') ?? 'Unknown',
            'email': data?['email'] ?? '',
            'role': (isCreator || isFaculty) ? 'Admin' : 'Member',
          };
        }).toList();
        _uidToName = {
          for (final m in _firestoreMembers) m['uid'] as String: m['name'] as String,
        };
      });
      _ensureMemberNotificationStrategies();
    } catch (e) {
      debugPrint('Error loading members: $e');
    }
  }

  Future<void> _ensureMemberNotificationStrategies() async {
    /// Initialize default notificationStrategy for each group chat member doc.
    /// Per D-17: students get 'mentionsOnly' for group chats, faculty get 'normal'.
    /// Uses merge:true so existing user-set strategies are NOT overwritten.
    /// TODO: When DMs are migrated to Firestore-backed storage, their member docs at
    /// instructor_chats/{chatId}/members/{uid} should also receive 'normal' defaults
    /// (D-17: students get 'normal' for DMs, faculty get 'normal' for everything).
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final member in _firestoreMembers) {
        final uid = member['uid'] as String;
        final role = member['role'] as String;
        final memberRef = FirebaseFirestore.instance
            .collection('group_chats')
            .doc(_chatId)
            .collection('members')
            .doc(uid);
        // Default: Admin (faculty) -> 'normal', Member (student) -> 'mentionsOnly'
        final defaultStrategy = (role == 'Admin') ? 'normal' : 'mentionsOnly';
        batch.set(memberRef, {
          'notificationStrategy': defaultStrategy,
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error ensuring notification strategies: $e');
    }
  }

  void _setupPinnedStream() {
    _pinnedSubscription = FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.chat.id)
        .collection('messages')
        .where('pinnedUntil', isGreaterThan: Timestamp.now())
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _pinnedMessages = snapshot.docs.map((doc) {
          final data = doc.data();
          final senderId = data['senderId'] ?? '';
          final isMe = senderId == FirebaseAuth.instance.currentUser?.uid;
          return Message(
            id: doc.id,
            senderId: senderId,
            senderName: data['senderName'] ?? 'Unknown',
            text: data['text'] ?? '',
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isMe: isMe,
            mentionedUids: List<String>.from(data['mentionedUids'] ?? []),
            pinnedUntil: (data['pinnedUntil'] as Timestamp?)?.toDate(),
          );
        }).toList();
      });
    }, onError: (e) {
      debugPrint('Error in pinned stream: $e');
    });
  }

  Future<void> _unpinMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(widget.chat.id)
          .collection('messages')
          .doc(messageId)
          .update({'pinnedUntil': null});
    } catch (e) {
      debugPrint('Error unpinning message: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_isMarkingRead) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final unreadMessages = _messages.where((m) => !m.isMe && !m.readBy.contains(user.uid)).toList();
    if (unreadMessages.isEmpty) return;
    _isMarkingRead = true;
    final batch = FirebaseFirestore.instance.batch();
    for (final msg in unreadMessages) {
      if (_markedAsRead.contains(msg.id)) continue;
      _markedAsRead.add(msg.id);
      final ref = FirebaseFirestore.instance
          .collection('group_chats')
          .doc(widget.chat.id)
          .collection('messages')
          .doc(msg.id);
      batch.update(ref, {
        'readBy': FieldValue.arrayUnion([user.uid]),
      });
    }
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    } finally {
      _isMarkingRead = false;
    }
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Group name (clickable for admin)
              GestureDetector(
                onTap: _isAdmin
                    ? () => _showRenameDialog(context, setSheetState)
                    : null,
                child: Tooltip(
                  message: _isAdmin ? 'Tap to rename group' : 'Only admins can rename',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _groupName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          decoration: _isAdmin ? TextDecoration.underline : null,
                          decorationColor: _isAdmin ? AppColors.primary : null,
                        ),
                      ),
                      if (_isAdmin) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.edit, size: 18, color: AppColors.primary),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Group Chat',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              // Notifications section
              const Text(
                'Notifications',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...['normal', 'mentionsOnly', 'muted'].map((strategy) {
                final labels = {
                  'normal': 'All notifications',
                  'mentionsOnly': 'Mentions only',
                  'muted': 'Muted',
                };
                return RadioListTile<String>(
                  title: Text(
                    labels[strategy] ?? strategy,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    strategy == 'normal'
                        ? 'Full notifications for all messages'
                        : strategy == 'mentionsOnly'
                            ? 'Only @mentions and @everyone'
                            : 'No notifications from this group',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  value: strategy,
                  groupValue: _notificationStrategy,
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() {
                        _notificationStrategy = value;
                      });
                      _updateNotificationStrategy(value);
                    }
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                );
              }),
              const Divider(height: 1),
              const SizedBox(height: 16),
              // Search bar
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setSheetState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setSheetState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              const SizedBox(height: 16),
              if (_searchQuery.isEmpty) ...[
                // Members header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Members (${_firestoreMembers.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_isSelectionMode) ...[
                      TextButton(
                        onPressed: _selectedMemberUids.isEmpty
                            ? null
                            : () {
                                _removeMembers(setSheetState);
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: Text('Remove (${_selectedMemberUids.length})'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _isSelectionMode = false;
                            _selectedMemberUids.clear();
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                    ] else ...[
                      if (_isAdmin)
                        TextButton.icon(
                          onPressed: () {
                            setSheetState(() {
                              _isSelectionMode = true;
                              _selectedMemberUids.clear();
                            });
                          },
                          icon: const Icon(Icons.check_box, size: 18),
                          label: const Text('Select'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      TextButton.icon(
                        onPressed: _isAdmin
                            ? () {
                                _addMember(context, setSheetState);
                              }
                            : null,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                const Divider(height: 1),
                // Members list
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _firestoreMembers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = _firestoreMembers[index];
                      final uid = member['uid'] as String;
                      final isSelected = _selectedMemberUids.contains(uid);
                      final isCurrentUser = uid == FirebaseAuth.instance.currentUser?.uid;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: GestureDetector(
                          onTap: _isSelectionMode && !isCurrentUser
                              ? () {
                                  setSheetState(() {
                                    if (isSelected) {
                                      _selectedMemberUids.remove(uid);
                                    } else {
                                      _selectedMemberUids.add(uid);
                                    }
                                  });
                                }
                              : null,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                child: Text(
                                  (member['name'] as String)[0],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (_isSelectionMode && !isCurrentUser)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.red : Colors.grey[300],
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        title: Text(
                          member['name'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          member['role'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                // Search results header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Search Results',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_messages.where((m) => !m.isDeleted && m.type != 'system' && (m.text.toLowerCase().contains(_searchQuery) || m.senderName.toLowerCase().contains(_searchQuery))).length} found',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Search results list
                Flexible(
                  child: _buildSearchResults(setSheetState),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, StateSetter setSheetState) async {
    final controller = TextEditingController(text: _groupName);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rename Group'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 30,
              decoration: const InputDecoration(
                hintText: 'Group name',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Group name cannot be empty';
                }
                if (value.trim().length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final newName = controller.text.trim();
                        await FirebaseFirestore.instance
                            .collection('group_chats')
                            .doc(widget.chat.id)
                            .update({'name': newName});
                        if (!mounted) return;
                        setState(() {
                          _groupName = newName;
                        });
                        setSheetState(() {});
                        if (mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Group renamed')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Unknown';
    final email = user.email ?? '';
    if (email.isEmpty) return 'Unknown';
    return email
        .split('@')
        .first
        .replaceAll('.', ' ')
        .split(' ')
        .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  Future<void> _sendSystemMessage(String text) async {
    try {
      await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(widget.chat.id)
          .collection('messages')
          .add({
        'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'senderName': await _getCurrentUserName(),
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
        'readBy': [FirebaseAuth.instance.currentUser?.uid ?? ''],
      });
    } catch (e) {
      debugPrint('Error sending system message: $e');
    }
  }

  Future<void> _removeMembers(StateSetter setSheetState) async {
    if (_selectedMemberUids.isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Members'),
            content: Text('Remove ${_selectedMemberUids.length} member(s) from this group?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ?? false;
    if (!confirmed) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final groupRef = FirebaseFirestore.instance.collection('group_chats').doc(widget.chat.id);
      batch.update(groupRef, {
        'members': FieldValue.arrayRemove(_selectedMemberUids.toList()),
      });
      await batch.commit();

      final removedNames = _selectedMemberUids
          .map((uid) => _uidToName[uid] ?? 'Unknown')
          .join(', ');
      await _sendSystemMessage('removed $removedNames');

      if (!mounted) return;
      setSheetState(() {
        _isSelectionMode = false;
        _selectedMemberUids.clear();
      });
      _loadMembers();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Members removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }

  Future<void> _addMember(BuildContext context, StateSetter setSheetState) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Member'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter CarSU email',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              final regex = RegExp(r'^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$');
              if (!regex.hasMatch(value.trim())) {
                return 'Use format: FirstName.LastName@carsu.edu.ph';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final email = controller.text.trim();
              try {
                final query = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .limit(1)
                    .get();
                if (query.docs.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User not found')),
                    );
                  }
                  return;
                }
                final newUid = query.docs.first.id;
                final groupDoc = await FirebaseFirestore.instance
                    .collection('group_chats')
                    .doc(widget.chat.id)
                    .get();
                final members = List<String>.from(groupDoc.data()?['members'] ?? []);
                if (members.contains(newUid)) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Already a member')),
                    );
                  }
                  return;
                }
                await FirebaseFirestore.instance
                    .collection('group_chats')
                    .doc(widget.chat.id)
                    .update({
                  'members': FieldValue.arrayUnion([newUid]),
                });
                await _sendSystemMessage('added $email');
                if (!mounted) return;
                Navigator.pop(dialogContext);
                _loadMembers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Member added')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNotificationStrategy() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(_chatId)
          .collection('members')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()?['notificationStrategy'] != null) {
        setState(() {
          _notificationStrategy = doc.data()!['notificationStrategy'] as String;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification strategy: $e');
    }
  }

  Future<void> _updateNotificationStrategy(String strategy) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(_chatId)
          .collection('members')
          .doc(user.uid)
          .set({'notificationStrategy': strategy}, SetOptions(merge: true));
      setState(() {
        _notificationStrategy = strategy;
      });
    } catch (e) {
      debugPrint('Error updating notification strategy: $e');
    }
  }

  Future<void> _handleMessageAction(Message msg, String action) async {
    if (!msg.isMe) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: msg.text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        }
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Message'),
                content: const Text('Delete this message for everyone?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ?? false;
        if (confirmed) await _deleteMessage(msg);
        break;
      case 'edit':
        await _editMessage(msg);
        break;
    }
  }

  Future<void> _editMessage(Message msg) async {
    if (!isWithinEditWindow(msg.timestamp)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messages can only be edited within 60 minutes'),
          ),
        );
      }
      return;
    }
    final controller = TextEditingController(text: msg.text);
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Message'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            minLines: 1,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Message cannot be empty';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final newText = controller.text.trim();
    if (newText == msg.text) return;
    try {
      final ok = await editMessageWithHistory(
        chatId: widget.chat.id,
        msg: msg,
        newText: newText,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messages can only be edited within 60 minutes'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to edit: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(Message msg) async {
    try {
      await softDeleteMessage(chatId: widget.chat.id, messageId: msg.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    NotificationService.activeChatId = null;
    _messagesSubscription?.cancel();
    _groupDocSubscription?.cancel();
    _pinnedSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Build search results list
  Widget _buildSearchResults(StateSetter setSheetState) {
    final query = _searchQuery.toLowerCase();
    final results = _messages
        .asMap()
        .entries
        .where((entry) {
          final msg = entry.value;
          if (msg.isDeleted || msg.type == 'system') return false;
          return msg.text.toLowerCase().contains(query) ||
              msg.senderName.toLowerCase().contains(query);
        })
        .toList()
        .reversed
        .toList(); // Show newest first

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No messages found',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = results[index];
        final msg = entry.value;
        final originalIndex = entry.key;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Text(
              msg.senderName.isNotEmpty ? msg.senderName[0] : '?',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            msg.senderName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTime(msg.timestamp),
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
          onTap: () {
            Navigator.pop(context);
            _scrollToMessage(originalIndex);
          },
        );
      },
    );
  }

  Widget _buildAuditList(Stream<QuerySnapshot> stream, ScrollController scrollController, {
    String emptyMessage = 'Nothing yet',
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.separated(
          controller: scrollController,
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final senderName = data['senderName'] ?? 'Unknown';
            final messageText = data['text'] ?? '';
            final messageId = data['messageId'] ?? '';
            final ts = data['timestamp'] as Timestamp?;
            final timeStr = ts != null ? _formatTime(ts.toDate()) : '';
            final msgIndex = _messages.indexWhere((m) => m.id == messageId);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  senderName.isNotEmpty ? senderName[0] : '?',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              title: Text(
                senderName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                messageText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (msgIndex >= 0) _scrollToMessage(msgIndex);
              },
            );
          },
        );
      },
    );
  }

  void _showAuditSheet() {
    final db = FirebaseFirestore.instance;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Mentions & @everyone',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const TabBar(
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      tabs: [
                        Tab(text: '@everyone'),
                        Tab(text: '@you'),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // @everyone tab
                          _buildAuditList(
                            db
                                .collection('group_chats').doc(_chatId)
                                .collection('everyone_calls')
                                .orderBy('timestamp', descending: true)
                                .limit(50)
                                .snapshots(),
                            scrollController,
                            emptyMessage: 'No @everyone calls in the last 24 hours',
                          ),
                          // @you tab
                          _buildAuditList(
                            db
                                .collection('group_chats').doc(_chatId)
                                .collection('mentions')
                                .where('mentionedUid', isEqualTo: currentUid)
                                .orderBy('timestamp', descending: true)
                                .limit(50)
                                .snapshots(),
                            scrollController,
                            emptyMessage: 'No one mentioned you recently',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _scrollToMessage(int index) {
    if (index < 0 || index >= _messages.length) return;
    final position = index * 60.0;
    _scrollController.animateTo(
      position,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            const GroupChatAvatar(radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _groupName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Group Chat',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showGroupInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Pinned Bar ──
          if (_pinnedMessages.isNotEmpty)
            _PinnedBar(
              pinnedMessages: _pinnedMessages,
              isExpanded: _pinnedBarExpanded,
              onToggle: () {
                setState(() {
                  _pinnedBarExpanded = !_pinnedBarExpanded;
                });
              },
              onUnpin: _unpinMessage,
              formatTime: _formatTime,
              onShowHistory: _showAuditSheet,
            )
          else
            _EveryoneHistoryButton(onShowHistory: _showAuditSheet),
          // ── Messages List ──
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _MessageBubble(
                  message: msg,
                  formatTime: _formatTime,
                  uidToName: _uidToName,
                  onLongPress: msg.isMe && !msg.isDeleted
                      ? () async {
                          final action = await showMessageActions(
                            context: context,
                            canEdit: isWithinEditWindow(msg.timestamp),
                            canDelete: isWithinEditWindow(msg.timestamp),
                          );
                          if (action != null) {
                            await _handleMessageAction(msg, action);
                          }
                        }
                      : null,
                  onTapEdited: msg.isEdited
                      ? () => showEditHistory(
                            context: context,
                            history: msg.editHistory,
                            formatTime: _formatTime,
                          )
                      : null,
                );
              },
            ),
          ),
          // ── Input Bar ──
          _MessageInputBar(
            controller: _controller,
            onSend: _sendMessage,
            isFaculty: _isFaculty,
            onTaskCreate: _showTaskCreation,
            uidToName: _uidToName,
            layerLink: _mentionLayerLink,
            currentUserUid: FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Message Bubble
// ─────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Message message;
  final String Function(DateTime) formatTime;
  final Map<String, String> uidToName;
  final VoidCallback? onTapEdited;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.message,
    required this.formatTime,
    this.uidToName = const {},
    this.onTapEdited,
    this.onLongPress,
  });

  Widget _buildReadReceipt() {
    if (!message.isMe) return const SizedBox.shrink();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final otherReaders = message.readBy
        .where((uid) => uid != currentUid)
        .toList();
    if (otherReaders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 2, left: 4),
        child: Icon(Icons.check, size: 12, color: Colors.grey[400]),
      );
    }
    const int maxDisplayNames = 2;
    final readerNames = otherReaders
        .take(maxDisplayNames)
        .map((uid) => uidToName[uid] ?? 'Unknown')
        .toList();
    String receiptText;
    if (otherReaders.length <= maxDisplayNames) {
      receiptText = 'Seen by ${readerNames.join(', ')}';
    } else {
      final remaining = otherReaders.length - maxDisplayNames;
      receiptText =
          'Seen by ${readerNames.join(', ')} and $remaining other${remaining > 1 ? 's' : ''}';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 4),
      child: Text(
        receiptText,
        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildLinkifiedText(String text, bool isMe) {
    final matches = _urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isMe ? Colors.white : AppColors.textPrimary,
          fontSize: 14,
        ),
      );
    }
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    final linkColor = isMe ? Colors.white.withValues(alpha: 0.85) : AppColors.primary;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 14),
        ));
      }
      final url = match.group(1)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () async {
            final uri = Uri.tryParse(url);
            if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: linkColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              url,
              style: TextStyle(
                color: linkColor,
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 14),
      ));
    }
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTask = message.type == 'task';
    final isMe = message.isMe;
    final isSystem = message.type == 'system';
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMentioned = message.mentionedUids.contains(currentUid);

    if (isTask) {
      return TaskBubble(message: message, formatTime: formatTime);
    }

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${message.senderName} ${message.text}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatTime(message.timestamp),
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: message.isDeleted ? null : onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  message.senderName.isNotEmpty ? message.senderName[0] : '?',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (!isMe) const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.senderName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!isMentioned && message.mentionedUids.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.alternate_email, size: 10, color: Colors.amber),
                                    SizedBox(width: 2),
                                    Text(
                                      'mentions',
                                      style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppColors.primary
                          : isMentioned
                              ? const Color(0xFFFFF3E0)
                              : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: message.isDeleted
                        ? Text(
                            'This message was deleted',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : _buildLinkifiedText(message.text, isMe),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                    child: Text(
                      formatTime(message.timestamp),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (isMe && !message.isDeleted) _buildReadReceipt(),
                  if (message.isEdited && !message.isDeleted)
                    GestureDetector(
                      onTap: onTapEdited,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2, left: 4),
                        child: Text(
                          'edited',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Pinned Bar
// ─────────────────────────────────────────────
class _PinnedBar extends StatelessWidget {
  final List<Message> pinnedMessages;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Future<void> Function(String) onUnpin;
  final String Function(DateTime) formatTime;
  final VoidCallback onShowHistory;

  const _PinnedBar({
    required this.pinnedMessages,
    required this.isExpanded,
    required this.onToggle,
    required this.onUnpin,
    required this.formatTime,
    required this.onShowHistory,
  });

  String _formatAge(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return 'yesterday';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (pinnedMessages.isEmpty) return const SizedBox.shrink();

    final mostRecent = pinnedMessages.last; // last = most recent in ascending order
    final age = DateTime.now().difference(mostRecent.timestamp);
    Color bgColor;
    if (age.inHours < 1) {
      bgColor = Colors.amber.withValues(alpha: 0.2);
    } else if (age.inHours < 24) {
      bgColor = Colors.amber.withValues(alpha: 0.1);
    } else {
      bgColor = Colors.grey[100]!;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: InkWell(
        onTap: onShowHistory,
        onLongPress: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.push_pin,
                size: 16,
                color: age.inHours < 1 ? Colors.amber[700] : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          mostRecent.senderName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatAge(mostRecent.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mostRecent.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: age.inHours < 1 ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history, size: 18, color: AppColors.primary),
                tooltip: '@everyone history',
                onPressed: onShowHistory,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                onPressed: () => onUnpin(mostRecent.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// @everyone History Button (when no pinned message)
// ─────────────────────────────────────────────
class _EveryoneHistoryButton extends StatelessWidget {
  final VoidCallback onShowHistory;
  const _EveryoneHistoryButton({required this.onShowHistory});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: InkWell(
        onTap: onShowHistory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.history, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                '@everyone history',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Message Input Bar
// ─────────────────────────────────────────────
class _MessageInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isFaculty;
  final VoidCallback? onTaskCreate;
  final Map<String, String> uidToName;
  final LayerLink layerLink;
  final String currentUserUid;

  const _MessageInputBar({
    required this.controller,
    required this.onSend,
    this.isFaculty = false,
    this.onTaskCreate,
    required this.uidToName,
    required this.layerLink,
    required this.currentUserUid,
  });

  @override
  State<_MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<_MessageInputBar> {
  OverlayEntry? _mentionOverlay;

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0 || cursorPos > text.length) {
      _removeMentionOverlay();
      return;
    }

    // Find the last @ before cursor
    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex == -1 || (atIndex > 0 && textBeforeCursor[atIndex - 1] != ' ' && atIndex != 0)) {
      _removeMentionOverlay();
      return;
    }

    final query = textBeforeCursor.substring(atIndex + 1);
    final filtered = widget.uidToName.entries
        .where((e) => e.key != widget.currentUserUid) // Don't mention self
        .where((e) => e.value.toLowerCase().contains(query.toLowerCase()))
        .take(10)
        .toList();

    if (filtered.isEmpty) {
      _removeMentionOverlay();
      return;
    }

    _showOrUpdateMentionOverlay(filtered);
  }

  void _showOrUpdateMentionOverlay(List<MapEntry<String, String>> members) {
    _removeMentionOverlay();
    _mentionOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 200,
        child: CompositedTransformFollower(
          link: widget.layerLink,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: members.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = members[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(
                        entry.value[0],
                        style: const TextStyle(fontSize: 10, color: AppColors.primaryDark),
                      ),
                    ),
                    title: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 13),
                    ),
                    onTap: () => _selectMention(entry),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_mentionOverlay!);
  }

  void _removeMentionOverlay() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
  }

  void _selectMention(MapEntry<String, String> entry) {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    final beforeAt = text.substring(0, atIndex);
    final afterCursor = text.substring(cursorPos);
    widget.controller.value = TextEditingValue(
      text: '$beforeAt@${entry.value} $afterCursor',
      selection: TextSelection.collapsed(offset: beforeAt.length + entry.value.length + 2),
    );
    _removeMentionOverlay();
  }

  @override
  void dispose() {
    _removeMentionOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (widget.isFaculty && widget.onTaskCreate != null)
              GestureDetector(
                onTap: widget.onTaskCreate,
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.add, color: AppColors.primary, size: 20),
                ),
              ),
            Expanded(
              child: CompositedTransformTarget(
                link: widget.layerLink,
                child: TextField(
                  controller: widget.controller,
                  onChanged: (_) => _onTextChanged(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) {
                    _removeMentionOverlay();
                    widget.onSend();
                  },
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
