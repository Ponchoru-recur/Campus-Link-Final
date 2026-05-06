import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/direct_message_item.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message_actions.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message_edit_delete.dart';
import 'package:luminescence/themes/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
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
    _setupMessagesStream();
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
    _messagesSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
      ),
      body: Column(
        children: [
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

  @override
  Widget build(BuildContext context) {
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
                        : Text(
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
