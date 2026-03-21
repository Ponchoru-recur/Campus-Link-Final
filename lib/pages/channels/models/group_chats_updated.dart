import 'package:flutter/material.dart';
import 'package:luminescence/pages/channels/models/chat_storage_helper.dart';

/// ============================================
/// UPDATED GROUP CHAT SCREEN
/// ============================================
///
/// This screen shows messages for ONE group chat.
/// Pass the groupId when navigating to this screen.

class GroupChatScreen extends StatefulWidget {
  final String groupId; // Pass this when navigating

  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatStorageHelper storage = ChatStorageHelper();

  List<Map<String, dynamic>> messages = [];
  String? currentUserEmail;
  String? groupName;

  @override
  void initState() {
    super.initState();
    currentUserEmail = storage.getCurrentUserEmail();
    _loadGroupInfo();
    _loadMessages();
  }

  void _loadGroupInfo() {
    final group = storage.getGroup(widget.groupId);
    if (group != null) {
      setState(() {
        groupName = group["name"];
      });
    }
  }

  void _loadMessages() {
    setState(() {
      messages = storage.getMessagesForGroup(widget.groupId);
    });
  }

  void sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      // Save message to Hive
      storage.sendMessage(
        groupId: widget.groupId,
        content: _messageController.text.trim(),
      );

      // Clear input and reload messages
      _messageController.clear();
      _loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(groupName ?? "Group Chat")),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            // MESSAGE LIST
            Expanded(
              child: messages.isEmpty
                  ? Center(child: Text("No messages yet. Say hello!"))
                  : ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(messages[index]);
                      },
                    ),
            ),

            // INPUT FIELD
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  onPressed: sendMessage,
                  icon: Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    bool isMe = message["senderEmail"] == currentUserEmail;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Sender name (only show for others)
            if (!isMe)
              Text(
                message["senderName"] ?? "Unknown",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            // Message content
            Text(message["content"] ?? ""),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

/// ============================================
/// SIMPLE VERSION (Without groupId parameter)
/// ============================================
///
/// If you want to keep using routes without parameters,
/// use this simpler version with a hardcoded group.

class SimpleGroupChatScreen extends StatefulWidget {
  const SimpleGroupChatScreen({super.key});

  @override
  State<SimpleGroupChatScreen> createState() => _SimpleGroupChatScreenState();
}

class _SimpleGroupChatScreenState extends State<SimpleGroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatStorageHelper storage = ChatStorageHelper();

  // Use a default group ID
  final String groupId = "default_group";
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _createDefaultGroupIfNeeded();
    _loadMessages();
  }

  void _createDefaultGroupIfNeeded() {
    // Create the default group if it doesn't exist
    if (storage.getGroup(groupId) == null) {
      storage.createGroup(
        groupId: groupId,
        groupName: "General Chat",
        members: [],
      );
    }
  }

  void _loadMessages() {
    setState(() {
      messages = storage.getMessagesForGroup(groupId);
    });
  }

  void sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      storage.sendMessage(
        groupId: groupId,
        content: _messageController.text.trim(),
      );
      _messageController.clear();
      _loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Group Chat")),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            // MESSAGE LIST
            Expanded(
              child: messages.isEmpty
                  ? Center(child: Text("No messages yet!"))
                  : ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return ListTile(
                          title: Text(msg["content"] ?? ""),
                          subtitle: Text(msg["senderName"] ?? "Unknown"),
                        );
                      },
                    ),
            ),

            // INPUT ROW
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(hintText: "Type a message"),
                  ),
                ),
                IconButton(
                  onPressed: sendMessage,
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
