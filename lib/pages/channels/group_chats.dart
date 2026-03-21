import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:luminescence/pages/channels/models/chat_database.dart';
import 'package:hive_ce/hive.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  List<Map<String, dynamic>> messages = [];
  final TextEditingController _messageController =
      TextEditingController(); // Control messages

  // Open information about the current user
  // Get groupchat names
  // Get messages from different group chats
  late Box _currentUser;
  late Box _groupChatBox;
  late Box _messsageBox;

  String? user;

  @override
  void initState() {
    super.initState();
    _currentUser = Hive.box("CURRENT_USER");
    _groupChatBox = Hive.box("GROUP_CHATS");
    _messsageBox = Hive.box("MESSAGES");

    user = _currentUser.get("email");
  }

  void sendMessage() async {
    // Does not send message if it's empty
    if (_messageController.text.isNotEmpty) {
      // Send a message

      // clear message after send
      _messageController.clear();
    }
  }

  void createGroup(String GroupName) {
    // Who created the group and name of group
    _groupChatBox.put(GroupName, {
      "name": GroupName,
      "members": ["Sam Varela", "Kyle Bravo", "Micheal Jackson"],
    });

    //
  }

  @override
  Widget build(BuildContext context) {
    // final currentUserEmail = db.getCurrentUserEmail();
    return Scaffold(
      appBar: AppBar(title: Text("Group Chat"), actions: [],),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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

  // Widget _buildMessageWidget() {
  //   String senderID;
  //   return StreamBuilder()
  // }
}
