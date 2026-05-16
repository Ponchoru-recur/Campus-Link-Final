/// Represents a single edit entry in a message's history.
class EditEntry {
  final String text;
  final DateTime editedAt;

  const EditEntry({required this.text, required this.editedAt});
}

/// Represents a single message inside a chat conversation.
/// Reused for both group_chats and direct_messages subcollections (DB-02).
class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final String? type; // 'system' for system messages, 'task' for task messages
  final List<String> readBy; // UIDs of users who read this
  final List<EditEntry> editHistory; // Previous versions of this message
  final bool isDeleted; // true if message was soft-deleted
  final String? taskId; // links to tasks/{taskId} document for type=='task'
  final List<String> mentionedUids; // UIDs of users mentioned via @mention (D-04)
  final DateTime? pinnedUntil; // If set, message is pinned until this time (D-11)

  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.type,
    this.readBy = const [],
    this.editHistory = const [],
    this.isDeleted = false,
    this.taskId,
    this.mentionedUids = const [],
    this.pinnedUntil,
  });

  bool get isEdited => editHistory.isNotEmpty;

  /// Whether the current message is pinned (pinnedUntil is set and hasn't expired).
  bool get isPinned => pinnedUntil != null && pinnedUntil!.isAfter(DateTime.now());

  /// Whether the given uid was mentioned in this message.
  bool isMentioned(String uid) => mentionedUids.contains(uid);

  /// Whether this message contains @everyone.
  bool get isEveryone => text.contains('@everyone');
}
