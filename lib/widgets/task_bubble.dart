import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message.dart';
import 'package:luminescence/services/task_service.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskBubble extends StatefulWidget {
  final Message message;
  final String Function(DateTime) formatTime;

  const TaskBubble({super.key, required this.message, required this.formatTime});

  @override
  State<TaskBubble> createState() => _TaskBubbleState();
}

class _TaskBubbleState extends State<TaskBubble> {
  DocumentSnapshot? _taskDoc;
  bool _loadingTask = false;

  @override
  void initState() {
    super.initState();
    _fetchTask();
  }

  Future<void> _fetchTask() {
    final taskId = widget.message.taskId;
    if (taskId == null) return Future.value();
    setState(() => _loadingTask = true);
    return FirebaseFirestore.instance
        .collection('tasks')
        .doc(taskId)
        .get()
        .then((doc) {
      if (mounted) {
        setState(() {
          _taskDoc = doc;
          _loadingTask = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _loadingTask = false);
    });
  }

  bool get _isDeleted {
    if (_taskDoc == null || !_taskDoc!.exists) return false;
    final data = _taskDoc!.data() as Map<String, dynamic>?;
    return data?['isActive'] == false;
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = message.isMe;
    final deleted = _isDeleted;

    final data = _taskDoc?.data() as Map<String, dynamic>?;
    final links = (data?['links'] as List<dynamic>?)
            ?.map((e) => TaskLink.fromMap(e as Map<String, dynamic>))
            .toList() ??
        <TaskLink>[];
    final deadline = data?['deadline'] != null
        ? (data!['deadline'] is Timestamp
            ? (data['deadline'] as Timestamp).toDate()
            : DateTime.tryParse(data['deadline']))
        : null;

    Color deadlineColor = Colors.grey[600]!;
    if (deadline != null && !deleted) {
      final daysLeft = deadline.difference(DateTime.now()).inDays;
      if (daysLeft >= TaskService.defaultGreenDays) {
        deadlineColor = AppColors.doneGreen;
      } else if (daysLeft >= TaskService.defaultYellowDays) {
        deadlineColor = AppColors.pendingYellow;
      } else {
        deadlineColor = AppColors.urgentRed;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0] : '?',
                style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: deleted
                    ? Colors.grey[200]
                    : isMe
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(
                  color: deleted
                      ? Colors.grey[400]!
                      : AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: deleted
                              ? Colors.grey[400]
                              : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          deleted ? Icons.delete_outline : Icons.assignment,
                          color: deleted ? Colors.white : AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        deleted ? 'DELETED' : 'TASK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: deleted ? Colors.grey[500]! : AppColors.primary,
                          letterSpacing: 1,
                        ),
                      ),
                      if (deleted) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.block, size: 12, color: Colors.grey[400]),
                      ],
                      if (_loadingTask) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey[400]),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 11,
                          color: deleted ? Colors.grey[500]! : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    message.text.split('\n\n').first,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: deleted ? Colors.grey[500]! : AppColors.textPrimary,
                      decoration: deleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (message.text.contains('\n\n'))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        message.text.split('\n\n').skip(1).join('\n\n'),
                        style: TextStyle(
                          fontSize: 13,
                          color: deleted ? Colors.grey[400]! : AppColors.textSecondary,
                          decoration: deleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  if (deadline != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: deadlineColor),
                        const SizedBox(width: 4),
                        Text(
                          'Due: ${deadline.month}/${deadline.day}/${deadline.year}',
                          style: TextStyle(fontSize: 11, color: deadlineColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                  if (!_loadingTask && links.isNotEmpty && !deleted) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: links.map((link) => InkWell(
                        onTap: () async {
                          final uri = Uri.tryParse(link.url);
                          if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No app available to open this link'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, size: 12, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(link.title, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: deleted ? Colors.grey[400] : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        widget.formatTime(message.timestamp),
                        style: TextStyle(fontSize: 11, color: deleted ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}