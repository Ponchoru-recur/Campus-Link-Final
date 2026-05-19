import 'package:flutter/material.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:luminescence/services/task_service.dart';

/// Compact task card used in Today dashboard sections.
class CompactTaskCard extends StatelessWidget {
  final Task task;
  final String groupName;
  final String deadlineLabel;
  final Color deadlineColor;
  final VoidCallback onTap;
  final Widget? trailing; // e.g. "Overdue" badge, "Unacknowledged" badge

  const CompactTaskCard({
    super.key,
    required this.task,
    required this.groupName,
    required this.deadlineLabel,
    required this.deadlineColor,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: deadlineColor == AppColors.urgentRed
                        ? deadlineColor.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment,
                    size: 18,
                    color: deadlineColor == AppColors.urgentRed
                        ? deadlineColor
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        groupName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 11, color: deadlineColor),
                          const SizedBox(width: 4),
                          Text(
                            deadlineLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: deadlineColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Static helper to format deadline label for compact cards.
  static String daysLeftText(Task task) {
    if (task.deadline == null) return 'No deadline';
    if (!task.isActive) return '';
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final deadlineDay = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
    final daysLeft = deadlineDay.difference(today).inDays;
    if (daysLeft < 0) return 'Overdue';
    if (daysLeft == 0) return 'Due today';
    if (daysLeft == 1) return '1 day left';
    return '$daysLeft days left';
  }

  /// Static helper to compute deadline color matching updates_tasks_screen.
  static Color computeDeadlineColor(Task task) {
    if (task.deadline == null) return Colors.grey[600]!;
    if (!task.isActive) return Colors.grey[500]!;

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final deadlineDay = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
    final daysLeft = deadlineDay.difference(today).inDays;

    final green = task.greenThresholdDays ?? TaskService.defaultGreenDays;
    final yellow = task.yellowThresholdDays ?? TaskService.defaultYellowDays;
    final red = task.redThresholdDays ?? TaskService.defaultRedDays;

    if (daysLeft >= green) return AppColors.doneGreen;
    if (daysLeft >= yellow) return AppColors.pendingYellow;
    if (daysLeft >= red) return AppColors.urgentRed;
    return AppColors.urgentRed;
  }
}