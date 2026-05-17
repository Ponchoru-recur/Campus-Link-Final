import 'package:flutter/material.dart';
import 'package:luminescence/services/task_service.dart';
import 'package:luminescence/themes/app_colors.dart';

/// Reusable acknowledge button for task cards.
/// Hides itself when [isAcknowledged] is true.
class AcknowledgeButton extends StatelessWidget {
  final String taskId;
  final String uid;
  final bool isAcknowledged;
  final bool compact;

  const AcknowledgeButton({
    super.key,
    required this.taskId,
    required this.uid,
    required this.isAcknowledged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isAcknowledged) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: () {
        TaskService().setAcknowledged(taskId, uid);
      },
      icon: Icon(
        Icons.visibility,
        size: compact ? 16 : 18,
        color: AppColors.primary,
      ),
      label: Text(
        'Acknowledge',
        style: TextStyle(
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 4 : 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}