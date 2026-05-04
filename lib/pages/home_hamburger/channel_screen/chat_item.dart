/// Represents a single chat item in the Chats list.
class ChatItem {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final ChatType type;
  final int unreadCount;
  final bool isOnline;

  const ChatItem({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.type,
    this.unreadCount = 0,
    this.isOnline = false,
  });
}

enum ChatType { groupChat, directMessage }
