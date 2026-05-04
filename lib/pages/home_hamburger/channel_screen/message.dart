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
  final String? type; // 'system' for system messages
  final List<String> readBy; // UIDs of users who read this
  final List<EditEntry> editHistory; // Previous versions of this message
  final bool isDeleted; // true if message was soft-deleted

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
  });

  bool get isEdited => editHistory.isNotEmpty;
}
