import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/components/my_text_field.dart';
import 'package:luminescence/pages/auth/auth_service.dart';
import 'package:luminescence/services/chat_service.dart';

class Chatpage extends StatelessWidget {
  final String receiverEmail;
  final String receiverID;

  Chatpage({super.key, required this.receiverEmail, required this.receiverID});

  // text controller
  final TextEditingController _messageController = TextEditingController();

  // chat and auth services
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  // send message
  void sendMessage() async {
    // If there's a message, send it
    if (_messageController.text.isNotEmpty) {
      // This sends the message to the chat service
      await _chatService.sendMessage(receiverID, _messageController.text);
      // Clear the message controller
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(receiverEmail)),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildUserInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    String senderID = _authService.getCurrentUser()!.uid;
    return StreamBuilder(
      stream: _chatService.getMessages(receiverID, senderID),
      builder: (context, snapshot) {
        // Errors
        if (snapshot.hasError) {
          return Text("Error: ${snapshot.error}");
        }
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        // return the list of messages
        return ListView(
          children: snapshot.data!.docs
              .map((doc) => _buildMessageItem(doc))
              .toList(),
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Text(data["message"]);
  }

  // build message inpiut

  Widget _buildUserInput() {
    return Row(
      children: [
        Expanded(
          child: MyTextField(
            controller: _messageController,
            label: "Type a message",
          ),
        ),
        ElevatedButton(
          onPressed: sendMessage,
          child: const Icon(Icons.arrow_upward),
        ),
      ],
    );
  }
}
