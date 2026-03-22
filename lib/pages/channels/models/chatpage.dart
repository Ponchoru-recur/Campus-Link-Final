import 'package:flutter/material.dart';

class Chatpage extends StatelessWidget {
  final String receiverEmail;

  const Chatpage({super.key, required this.receiverEmail});

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(receiverEmail));
  }
}
