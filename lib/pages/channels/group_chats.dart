import 'package:flutter/material.dart';
import 'package:luminescence/components/user_tile.dart';
import 'package:luminescence/pages/auth/auth_service.dart';
import 'package:luminescence/pages/channels/models/chatpage.dart';
import 'package:luminescence/services/chat_service.dart';

class ChanncelScreen extends StatefulWidget {
  const ChanncelScreen({super.key});

  @override
  State<ChanncelScreen> createState() => _ChanncelScreenState();
}

class _ChanncelScreenState extends State<ChanncelScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chats")),
      // drawer: const MyDrawer(),
      body: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder(
      stream: _chatService.getUsersStream(),

      builder: (context, snapshot) {
        print(" SNAPSHOTTT : ${snapshot.data} ");
        if (snapshot.hasError) {
          return const Text("Error");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading...");
        }

        return ListView(
          children: snapshot.data!
              .map<Widget>((userData) => _buildUserListItem(userData, context))
              .toList(),
        );
      },
    );
  }

  Widget _buildUserListItem(
    Map<String, dynamic> userData,
    BuildContext context,
  ) {
    return UserTile(
      text: userData["email"],
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Chatpage(receiverEmail: userData['email']),
          ),
        );
      },
    );
  }
}
