/// Represents a single message inside a chat conversation.
class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final String? type; // 'system' for system messages
  final List<String> readBy; // UIDs of users who read this

  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.type,
    this.readBy = const [],
  });
}
