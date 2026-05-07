import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single edit entry in a message's history.
class EditEntry {
  final String text;
  final DateTime editedAt;

  const EditEntry({required this.text, required this.editedAt});

  factory EditEntry.fromMap(Map<String, dynamic> m) => EditEntry(
        text: m['text'] ?? '',
        editedAt: (m['editedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
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
  final String? type; // 'system' for system messages, 'task', 'task_updated', 'task_deleted'
  final List<String> readBy; // UIDs of users who read this
  final List<EditEntry> editHistory; // Previous versions of this message
  final String? taskId; // for task-type messages
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
    this.taskId,
    this.isDeleted = false,
  });

  bool get isEdited => editHistory.isNotEmpty;

  factory Message.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, String currentUid) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMe: data['senderId'] == currentUid,
      type: data['type'],
      readBy: List<String>.from(data['readBy'] ?? []),
      editHistory: (data['editHistory'] as List<dynamic>? ?? [])
          .map((e) => EditEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      taskId: data['taskId'],
      isDeleted: data['isDeleted'] ?? false,
    );
  }
}
