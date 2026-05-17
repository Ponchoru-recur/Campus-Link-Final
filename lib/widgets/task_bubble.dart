import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message.dart';
import 'package:luminescence/pages/home_hamburger/updates_tasks_screen.dart';
import 'package:luminescence/services/task_service.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:luminescence/widgets/acknowledge_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

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

    final brandGreen = AppColors.primary;

    Color deadlineColor = Colors.grey[600]!;
    int? daysLeft;
    if (deadline != null && !deleted) {
      daysLeft = deadline.difference(DateTime.now()).inDays;
      if (daysLeft >= TaskService.defaultGreenDays) {
        deadlineColor = AppColors.doneGreen;
      } else if (daysLeft >= TaskService.defaultYellowDays) {
        deadlineColor = AppColors.pendingYellow;
      } else {
        deadlineColor = AppColors.urgentRed;
      }
    }

    final cardBg = deleted
        ? Colors.grey[200]
        : const Color(0xFFF0FBF5);

    final cardBorder = deleted
        ? Colors.grey[400]!
        : brandGreen.withValues(alpha: 0.35);

    // Check student response for acknowledge button
    final studentResponses = (data?['studentResponses'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final myResponse = studentResponses[_currentUid] as Map<String, dynamic>?;
    final isAcknowledged = myResponse?['acknowledged'] == true;
    final showAckBtn = !deleted && !isMe && !isAcknowledged && _currentUid.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (_currentUid.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UpdatesTasksScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: brandGreen.withValues(alpha: 0.2),
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0] : '?',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(color: cardBorder, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header row: TASK badge + title (inline) ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // "TASK" badge — solid filled green
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: deleted ? Colors.grey[400] : brandGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          deleted ? 'DELETED' : 'TASK',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Title
                      Expanded(
                        child: Text(
                          message.text.split('\n\n').first,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: deleted ? Colors.grey[500]! : AppColors.textPrimary,
                            decoration: deleted ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (deleted)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.block, size: 14, color: Colors.grey[400]),
                        ),
                      if (_loadingTask)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Colors.grey[400]),
                          ),
                        ),
                    ],
                  ),

                  // Sender name (not me)
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 11,
                          color: deleted ? Colors.grey[500]! : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Description (second part after \n\n)
                  if (message.text.contains('\n\n'))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        message.text.split('\n\n').skip(1).join('\n\n'),
                        style: TextStyle(
                          fontSize: 13,
                          color: deleted
                              ? Colors.grey[400]!
                              : AppColors.textSecondary,
                          decoration: deleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),

                  // Deadline
                  if (deadline != null && !deleted) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: deadlineColor),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, y').format(deadline),
                          style: TextStyle(
                            fontSize: 11,
                            color: deadlineColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (daysLeft != null && daysLeft >= 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            daysLeft == 0
                                ? 'Due today'
                                : daysLeft == 1
                                    ? '1 day left'
                                    : '$daysLeft days left',
                            style: TextStyle(
                              fontSize: 10,
                              color: deadlineColor.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  // Deleted deadline fallback
                  if (deadline != null && deleted)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            'Due: ${deadline.month}/${deadline.day}/${deadline.year}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),

                  // Link chips
                  if (!_loadingTask && links.isNotEmpty && !deleted) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: links.map((link) => InkWell(
                        onTap: () async {
                          final uri = Uri.tryParse(link.url);
                          if (uri == null ||
                              !(uri.isScheme('http') || uri.isScheme('https'))) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Not a valid link: ${link.url}'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            return;
                          }
                          try {
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Broken link — no app available to open it'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not open link: $e'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: brandGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: brandGreen.withValues(alpha: 0.25),
                                width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link,
                                  size: 13, color: brandGreen),
                              const SizedBox(width: 4),
                              Text(
                                link.title,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: brandGreen,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ],

                  // Timestamp — right-aligned
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: 12,
                            color: deleted ? Colors.grey[400] : Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text(
                          widget.formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: deleted ? Colors.grey[400] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Acknowledge button for students
                  if (showAckBtn) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AcknowledgeButton(
                        taskId: widget.message.taskId ?? '',
                        uid: _currentUid,
                        isAcknowledged: false,
                        compact: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),   // closes Row
      ),   // closes Padding
    );     // closes GestureDetector
  }
}