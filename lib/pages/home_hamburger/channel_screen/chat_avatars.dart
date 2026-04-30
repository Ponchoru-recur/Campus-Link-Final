import 'package:flutter/material.dart';
import 'package:luminescence/themes/app_colors.dart';

/// Reusable avatar for group chats — teal circle with a group icon.
class GroupChatAvatar extends StatelessWidget {
  final double radius;

  const GroupChatAvatar({super.key, this.radius = 26});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: Icon(Icons.group, color: Colors.white, size: radius * 0.9),
    );
  }
}

/// Reusable avatar for instructor chats — purple circle with a school icon.
class InstructorAvatar extends StatelessWidget {
  final double radius;

  const InstructorAvatar({super.key, this.radius = 26});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.instructorPurple,
      child: Icon(Icons.school, color: Colors.white, size: radius * 0.9),
    );
  }
}
