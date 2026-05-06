import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single chat item in the Chats list.
class ChatItem {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final ChatType type;
  final int unreadCount;
  final bool isOnline;
  final Timestamp? createdAt;

  const ChatItem({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.type,
    this.unreadCount = 0,
    this.isOnline = false,
    this.createdAt,
  });
}

enum ChatType { groupChat, directMessage }
