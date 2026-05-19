import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/direct_message_item.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message_actions.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message_edit_delete.dart';
import 'package:luminescence/pages/tasks/create_task_screen.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:luminescence/widgets/task_bubble.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:luminescence/services/notification_service.dart';
import 'package:luminescence/services/pinned_notice_service.dart';
import 'package:luminescence/models/pinned_notice.dart';
import 'package:luminescence/pages/home_hamburger/profile/faculty_profile_view_screen.dart';

final _urlRegex = RegExp(
  r'(https?://[^\s<]+)',
  caseSensitive: false,
);

/// The full conversation screen for a 1-on-1 DIRECT MESSAGE.
/// Firestore-backed with real-time sync, replaces old instructor chat placeholder.
class IndividualChatScreen extends StatefulWidget {
  final DirectMessageItem? chat;
  final String? otherUid;
  final String? otherName;
  final String? otherEmail;
  final String? otherRole;
  final String? chatId;

  const IndividualChatScreen({
    super.key,
    this.chat,
    this.otherUid,
    this.otherName,
    this.otherEmail,
    this.otherRole,
    this.chatId,
  }) : assert(chat != null || (otherUid != null && chatId != null),
        'Either chat or otherUid+chatId must be provided');

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  final List<Message> _messages = [];
  Map<String, String> _uidToName = {};
  bool _isMarkingRead = false;
  final Set<String> _markedAsRead = {};
  late final String _otherParticipantUid;
  late final String _otherParticipantName;
  late final String? _otherParticipantRole;
  late final String _chatId;
  bool _isFaculty = false;

  // Pinned notices
  StreamSubscription<QuerySnapshot>? _pinnedNoticeSubscription;
  List<PinnedNotice> _activePinnedNotices = [];
  final _pinnedNoticeService = PinnedNoticeService.instance;

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  DateTime _parseEditedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Future<void> _checkFacultyRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _isFaculty = doc.exists && (doc.data()?['role'] == 'faculty');
        });
      }
    } catch (e) {
      debugPrint('Error checking faculty role: $e');
    }
  }

  void _showTaskCreation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTaskScreen(
          prefilledChatId: _chatId,
          prefilledChatType: 'dm',
          prefilledRecipientName: _otherParticipantName,
          prefilledOtherParticipantUid: _otherParticipantUid,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkFacultyRole();
    if (widget.chat != null) {
      _otherParticipantUid = widget.chat!.otherParticipantUid;
      _otherParticipantName = widget.chat!.otherParticipantName;
      _otherParticipantRole = widget.chat!.otherParticipantRole;
      _chatId = widget.chat!.id;
      _uidToName = {
        _otherParticipantUid: _otherParticipantName,
      };
    } else {
      _otherParticipantUid = widget.otherUid!;
      _otherParticipantName = widget.otherName ?? '';
      _otherParticipantRole = widget.otherRole;
      _chatId = widget.chatId!;
      _uidToName = {
        _otherParticipantUid: _otherParticipantName,
      };
    }
    NotificationService.activeChatId = _chatId;
    _setupMessagesStream();
    _setupPinnedNoticesStream();
  }

  void _setupMessagesStream() {
    _messagesSubscription = FirebaseFirestore.instance
        .collection('direct_messages')
        .doc(_chatId)
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
            ));
          }
        });
        _markMessagesAsRead();
      } catch (e, stack) {
        debugPrint('Error processing DM messages stream: $e');
        debugPrint('$stack');
      }
    }, onError: (e) {
      debugPrint('Error in DM messages stream: $e');
    });
  }

  Future<void> _markMessagesAsRead() async {
    if (_isMarkingRead) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final unreadMessages =
        _messages.where((m) => !m.isMe && !m.readBy.contains(user.uid)).toList();
    if (unreadMessages.isEmpty) return;
    _isMarkingRead = true;
    final batch = FirebaseFirestore.instance.batch();
    for (final msg in unreadMessages) {
      if (_markedAsRead.contains(msg.id)) continue;
      _markedAsRead.add(msg.id);
      final ref = FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(_chatId)
          .collection('messages')
          .doc(msg.id);
      batch.update(ref, {
        'readBy': FieldValue.arrayUnion([user.uid]),
      });
    }
    try {
      await batch.commit();
      // Reset unreadCount for current user after marking messages as read
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('direct_messages')
            .doc(_chatId)
            .update({'unreadCount.${user.uid}': 0});
      }
    } catch (e) {
      debugPrint('Error marking DM messages as read: $e');
    } finally {
      _isMarkingRead = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
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
      final dmRef = firestore.collection('direct_messages').doc(_chatId);

      // Auto-unarchive: remove sender from archivedBy if present
      await dmRef.update({
        'archivedBy': FieldValue.arrayRemove([user.uid]),
      });

      final messagesRef = dmRef.collection('messages');

      await messagesRef.add({
        'senderId': user.uid,
        'senderName': senderName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'readBy': [user.uid],
      });

      await dmRef.update({
        'lastMessage': text,
        'time': 'Now',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount.$_otherParticipantUid': FieldValue.increment(1),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _setupPinnedNoticesStream() {
    _pinnedNoticeSubscription = _pinnedNoticeService
        .getActivePinsStream('dm', _chatId)
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _activePinnedNotices = snapshot.docs
            .map((doc) => PinnedNotice.fromFirestore(doc))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });
    }, onError: (e) {
      debugPrint('Error in DM pinned notices stream: $e');
    });
  }

  Future<void> _handleMessageAction(BuildContext context, Message msg) async {
    final canEdit = msg.isMe && isWithinEditWindow(msg.timestamp);
    final canDelete = msg.isMe && isWithinEditWindow(msg.timestamp);
    final action = await showMessageActions(
      context: context,
      canEdit: canEdit,
      canDelete: canDelete,
    );
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: msg.text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message copied')),
          );
        }
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Message'),
            content: const Text('Are you sure you want to delete this message?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) await _deleteMessage(msg);
      case 'edit':
        await _editMessage(msg);
    }
  }

  Future<void> _editMessage(Message msg) async {
    final controller = TextEditingController(text: msg.text);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Edit your message...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final newText = controller.text.trim();
    if (newText.isEmpty || newText == msg.text) return;
    try {
      final ok = await editMessageWithHistory(
        chatId: _chatId,
        msg: msg,
        newText: newText,
        collection: 'direct_messages',
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messages can only be edited within 60 minutes')),
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
      await softDeleteMessage(
        chatId: _chatId,
        messageId: msg.id,
        collection: 'direct_messages',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  void _showEditHistory(BuildContext context, Message msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Edit History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...msg.editHistory.reversed.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.text,
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        _formatTime(entry.editedAt),
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      const Divider(),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    NotificationService.activeChatId = null;
    _messagesSubscription?.cancel();
    _pinnedNoticeSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showPinnedNoticesSheet({int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 3,
          initialIndex: initialTab,
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
                        const Icon(Icons.push_pin, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Pinned Notices',
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
                        Tab(text: 'Pinned'),
                        Tab(text: '@you'),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildDMPinnedTab(scrollController),
                          Center(
                            child: Text(
                              'No one mentioned you recently',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
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

  Widget _buildDMPinnedTab(ScrollController scrollController) {
    final hasReachedMax = _activePinnedNotices.length >= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // FAB row — faculty only, hidden at max
        if (_isFaculty && !hasReachedMax)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
              child: FloatingActionButton.small(
                heroTag: 'dm_pinned_fab',
                onPressed: () => _showCreateEditDMPinnedNotice(notice: null),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),

        // Limit message — faculty only, shown at max
        if (_isFaculty && hasReachedMax)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Maximum of 5 pinned notices reached. Unpin one to add more.',
                style: TextStyle(fontSize: 12, color: Colors.amber[800]),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // Cards list or empty state
        Expanded(
          child: _activePinnedNotices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'No pinned notices yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                      if (_isFaculty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tap + to add one',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _activePinnedNotices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final notice = _activePinnedNotices[index];
                    return _DMPinnedNoticeCard(
                      notice: notice,
                      isFaculty: _isFaculty,
                      isFirst: index == 0,
                      isLast: index == _activePinnedNotices.length - 1,
                      chatId: _chatId,
                      collectionType: 'dm',
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreateEditDMPinnedNotice({PinnedNotice? notice}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CreateEditDMPinnedNoticeSheet(
        notice: notice,
        chatId: _chatId,
        chatName: _otherParticipantName,
        collectionType: 'dm',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFaculty = _otherParticipantRole == 'faculty';
    final appBarColor = isFaculty ? AppColors.instructorPurple : AppColors.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                _otherParticipantName.isNotEmpty
                    ? _otherParticipantName[0]
                    : '?',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherParticipantName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    isFaculty ? 'Instructor' : 'Student',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: isFaculty
            ? [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FacultyProfileViewScreen(
                          facultyUid: _otherParticipantUid,
                          facultyName: _otherParticipantName,
                        ),
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // ── Pinned Notice & @everyone Slim Bar ──
          _DMPinnedNoticeBar(
            activePins: _activePinnedNotices,
            onShowSheet: _showPinnedNoticesSheet,
          ),
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
                  onTapEdited: msg.isEdited && !msg.isDeleted
                      ? () => _showEditHistory(context, msg)
                      : null,
                  onLongPress: msg.isMe && !msg.isDeleted
                      ? () => _handleMessageAction(context, msg)
                      : null,
                );
              },
            ),
          ),
          _MessageInputBar(
            controller: _controller,
            onSend: _sendMessage,
            isFaculty: _isFaculty,
            onTaskCreate: _showTaskCreation,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────
// Message Bubble (adapted from GroupChatScreen)
// ─────────────────────────────────────
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

  Widget _buildLinkifiedText(String text, bool isMe, BuildContext context) {
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
    if (isTask) {
      return TaskBubble(message: message, formatTime: formatTime);
    }
    final isMe = message.isMe;

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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primary : const Color(0xFFF0F0F0),
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
                        : _buildLinkifiedText(message.text, isMe, context),
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

// ─────────────────────────────────────
// Message Input Bar
// ─────────────────────────────────────
// ─────────────────────────────
// Task Bubble (rendered for type=='task' messages)
// ─────────────────────────────

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isFaculty;
  final VoidCallback? onTaskCreate;

  const _MessageInputBar({
    required this.controller,
    required this.onSend,
    this.isFaculty = false,
    this.onTaskCreate,
  });

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
            if (isFaculty && onTaskCreate != null)
              GestureDetector(
                onTap: onTaskCreate,
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

// ─────────────────────────────────────
// DM Pinned Notice Slim Bar
// ─────────────────────────────────────
class _DMPinnedNoticeBar extends StatelessWidget {
  final List<PinnedNotice> activePins;
  final void Function({int initialTab}) onShowSheet;

  const _DMPinnedNoticeBar({required this.activePins, required this.onShowSheet});

  @override
  Widget build(BuildContext context) {
    if (activePins.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: InkWell(
        onTap: () => onShowSheet(initialTab: 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.push_pin, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                'Pinned',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${activePins.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
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

// ─────────────────────────────────────
// DM Pinned Notice Card
// ─────────────────────────────────────
class _DMPinnedNoticeCard extends StatelessWidget {
  final PinnedNotice notice;
  final bool isFaculty;
  final bool isFirst;
  final bool isLast;
  final String chatId;
  final String collectionType;

  const _DMPinnedNoticeCard({
    required this.notice,
    required this.isFaculty,
    required this.isFirst,
    required this.isLast,
    required this.chatId,
    required this.collectionType,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.push_pin, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notice.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isFaculty)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        _showEditSheet(context);
                      case 'unpin':
                        await PinnedNoticeService.instance.archive(
                          collectionType: collectionType,
                          chatId: chatId,
                          noticeId: notice.id,
                        );
                      case 'up':
                        await PinnedNoticeService.instance.moveUp(
                          collectionType: collectionType,
                          chatId: chatId,
                          noticeId: notice.id,
                          currentOrder: notice.order,
                        );
                      case 'down':
                        await PinnedNoticeService.instance.moveDown(
                          collectionType: collectionType,
                          chatId: chatId,
                          noticeId: notice.id,
                          currentOrder: notice.order,
                        );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'unpin', child: Text('Unpin')),
                    PopupMenuItem(
                      value: 'up',
                      enabled: !isFirst,
                      child: const Text('Move up'),
                    ),
                    PopupMenuItem(
                      value: 'down',
                      enabled: !isLast,
                      child: const Text('Move down'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            notice.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (notice.link != null && notice.link!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(notice.link!);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      notice.link!.replaceAll(RegExp(r'^https?://'), ''),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Posted by ${notice.createdByName} · ${_timeAgo(notice.createdAt)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              if (notice.editedAt != null) ...[
                const SizedBox(width: 6),
                Text(
                  '· edited',
                  style: TextStyle(fontSize: 10, color: Colors.grey[400], fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CreateEditDMPinnedNoticeSheet(
        notice: notice,
        chatId: chatId,
        chatName: '',
        collectionType: collectionType,
      ),
    );
  }
}

// ─────────────────────────────────────
// DM Create / Edit Pinned Notice Form
// ─────────────────────────────────────
class _CreateEditDMPinnedNoticeSheet extends StatefulWidget {
  final PinnedNotice? notice;
  final String chatId;
  final String chatName;
  final String collectionType;

  const _CreateEditDMPinnedNoticeSheet({
    this.notice,
    required this.chatId,
    required this.chatName,
    required this.collectionType,
  });

  @override
  State<_CreateEditDMPinnedNoticeSheet> createState() => _CreateEditDMPinnedNoticeSheetState();
}

class _CreateEditDMPinnedNoticeSheetState extends State<_CreateEditDMPinnedNoticeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _linkController;
  bool _isSubmitting = false;
  final _service = PinnedNoticeService.instance;

  bool get _isEditing => widget.notice != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notice?.title ?? '');
    _descriptionController = TextEditingController(text: widget.notice?.description ?? '');
    _linkController = TextEditingController(text: widget.notice?.link ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return 'Enter a valid URL (http:// or https://)';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      if (_isEditing) {
        await _service.update(
          collectionType: widget.collectionType,
          chatId: widget.chatId,
          noticeId: widget.notice!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          link: _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
        );
      } else {
        await _service.create(
          collectionType: widget.collectionType,
          chatId: widget.chatId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          link: _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
          chatName: widget.chatName,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_isEditing ? 'Update' : 'Create'} failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEditing ? 'Edit Pinned Notice' : 'New Pinned Notice',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Title *', border: OutlineInputBorder(), counterText: '',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLength: 500, maxLines: 3, minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description *', border: OutlineInputBorder(), alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Link (optional)', hintText: 'https://', border: OutlineInputBorder(),
              ),
              validator: _validateUrl,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEditing ? 'Save' : 'Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
