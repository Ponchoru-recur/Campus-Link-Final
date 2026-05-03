import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_item.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_avatars.dart';

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
  bool _isAdmin = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedMemberUids = {};
  final Set<String> _markedAsRead = {};
  List<Map<String, dynamic>> _firestoreMembers = [];
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _groupDocSubscription;

  // Sample messages — replace with real data source later
  final List<Message> _messages = [
    Message(
      id: '1',
      senderId: 'user2',
      senderName: 'Maria',
      text: 'Hey everyone, did you finish the assignment?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      isMe: false,
    ),
    Message(
      id: '2',
      senderId: 'user3',
      senderName: 'Juan',
      text: 'Almost done, just need to fix one bug.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      isMe: false,
    ),
    Message(
      id: '3',
      senderId: 'me',
      senderName: 'Me',
      text: 'I submitted mine already! 🎉',
      timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
      isMe: true,
    ),
    Message(
      id: '4',
      senderId: 'user2',
      senderName: 'Maria',
      text: 'Nice! What time is the deadline again?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      isMe: false,
    ),
  ];

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'me',
        senderName: 'Me',
        text: text,
        timestamp: DateTime.now(),
        isMe: true,
      ));
    });
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  // Sample members — replace with real data later
  final List<Map<String, String>> _members = const [
    {'name': 'You', 'role': 'Admin'},
    {'name': 'Maria Santos', 'role': 'Member'},
    {'name': 'Juan Dela Cruz', 'role': 'Member'},
    {'name': 'Ana Reyes', 'role': 'Member'},
  ];

  @override
  void initState() {
    super.initState();
    _groupName = widget.chat.name;
    _checkAdminStatus();
    _setupGroupStream();
    _setupMessagesStream();
    _loadMembers();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(widget.chat.id)
          .get();
      if (!mounted) return;
      setState(() {
        _isAdmin = doc.data()?['createdBy'] == user.uid;
      });
    } catch (e) {
      debugPrint('Error checking admin status: $e');
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

  void _setupMessagesStream() {
    _messagesSubscription = FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.chat.id)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _messages.clear();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final senderId = data['senderId'] ?? '';
          final isMe = senderId == FirebaseAuth.instance.currentUser?.uid;
          _messages.add(Message(
            id: doc.id,
            senderId: senderId,
            senderName: data['senderName'] ?? 'Unknown',
            text: data['text'] ?? '',
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isMe: isMe,
            type: data['type'],
            readBy: List<String>.from(data['readBy'] ?? []),
          ));
        }
      });
      _markMessagesAsRead();
    }, onError: (e) {
      debugPrint('Error in messages stream: $e');
    });
  }

  Future<void> _loadMembers() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(widget.chat.id)
          .get();
      if (!mounted) return;
      final data = doc.data();
      if (data == null) return;
      final members = List<String>.from(data['members'] ?? []);
      final userDocs = await Future.wait(
        members.map((uid) => FirebaseFirestore.instance.collection('users').doc(uid).get()),
      );
      if (!mounted) return;
      setState(() {
        _firestoreMembers = userDocs.map((doc) {
          final data = doc.data();
          return {
            'uid': doc.id,
            'name': data?['email']?.split('@').first.replaceAll('.', ' ').split(' ').map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join(' ') ?? 'Unknown',
            'email': data?['email'] ?? '',
            'role': doc.id == data?['createdBy'] ? 'Admin' : 'Member',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading members: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final unreadMessages = _messages.where((m) => !m.isMe && !m.readBy.contains(user.uid)).toList();
    if (unreadMessages.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < unreadMessages.length; i++) {
      final msg = unreadMessages[i];
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
              const SizedBox(height: 20),
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
                  separatorBuilder: (_, __) => const Divider(height: 1),
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
                );
              },
            ),
          ),
          // ── Input Bar ──
          _MessageInputBar(
            controller: _controller,
            onSend: _sendMessage,
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

  const _MessageBubble({required this.message, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: Text(
                message.senderName[0],
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Message Input Bar
// ─────────────────────────────────────────────
class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInputBar({required this.controller, required this.onSend});

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
            Expanded(
              child: TextField(
                controller: controller,
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
                onSubmitted: (_) => onSend(),
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
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
