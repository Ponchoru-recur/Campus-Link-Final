import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/themes/app_colors.dart';

/// Updates & Tasks screen showing all tasks for the current user.
/// Students can view and submit. Faculty can delete their own or ignore others'.
class UpdatesTasksScreen extends StatefulWidget {
  const UpdatesTasksScreen({super.key});

  @override
  State<UpdatesTasksScreen> createState() => _UpdatesTasksScreenState();
}

class _UpdatesTasksScreenState extends State<UpdatesTasksScreen> {
  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  final List<Task> _tasks = [];
  bool _isLoading = true;
  String _userRole = 'student';
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _fetchUserRole();
    _setupTasksStream();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _userRole = doc.exists ? (doc['role'] ?? 'student') : 'student';
        });
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
    }
  }

  void _setupTasksStream() {
    final uid = _userId;
    if (uid == null) return;
    _tasksSubscription = FirebaseFirestore.instance
        .collection('tasks')
        .where('targetUids', arrayContains: uid)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _tasks.clear();
        for (final doc in snapshot.docs) {
          final task = Task.fromFirestore(doc);
          // For faculty, filter out ignored tasks
          if (_userRole == 'faculty' && task.ignoredBy.contains(uid)) {
            continue;
          }
          _tasks.add(task);
        }
        _isLoading = false;
      });
    }, onError: (e) {
      debugPrint('Error in tasks stream: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update({'isActive': false});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _ignoreTask(Task task) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update({
        'ignoredBy': FieldValue.arrayUnion([uid]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task ignored')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _submitToTask(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = await _getUserName(user);
    final controller = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit to Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(task.description,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Your reply (optional)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'textReply': controller.text.trim(),
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result == null) return;
    try {
      final submission = TaskSubmission(
        studentUid: user.uid,
        studentName: name,
        textReply: result['textReply']?.isNotEmpty == true ? result['textReply'] : null,
        submittedAt: DateTime.now(),
      );
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update({
        'submissions': FieldValue.arrayUnion([submission.toMap()]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<String> _getUserName(User user) async {
    final email = user.email ?? '';
    if (email.isEmpty) return 'Unknown';
    return email
        .split('@')
        .first
        .replaceAll('.', ' ')
        .split(' ')
        .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'No deadline';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  bool _isOverdue(Task task) {
    if (task.deadline == null) return false;
    return task.deadline!.isBefore(DateTime.now());
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Updates & Tasks',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No tasks yet',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Tasks will appear here when faculty create them',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    final isCreator = task.createdBy == _userId;
                    final isFaculty = _userRole == 'faculty';
                    final overdue = _isOverdue(task);
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: overdue
                              ? AppColors.urgentRed.withValues(alpha: 0.3)
                              : AppColors.divider,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: overdue
                                  ? AppColors.urgentRed.withValues(alpha: 0.05)
                                  : AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: overdue
                                        ? AppColors.urgentRed
                                            .withValues(alpha: 0.1)
                                        : AppColors.primary
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.assignment,
                                    color: overdue
                                        ? AppColors.urgentRed
                                        : AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'By ${task.creatorName}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                if (overdue)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.urgentRed,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('OVERDUE',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.5)),
                                  ),
                              ],
                            ),
                          ),
                          // Body
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(task.description,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Due: ${_formatDate(task.deadline)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: overdue
                                              ? AppColors.urgentRed
                                              : Colors.grey[600]),
                                    ),
                                    const Spacer(),
                                    if (task.allowSubmissions)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.successGreen
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text('Submissions open',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    AppColors.successGreen,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                  ],
                                ),
                                if (task.submissions.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '${task.submissions.length} submission(s)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Actions
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Row(
                              children: [
                                if (!isFaculty &&
                                    task.allowSubmissions)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _submitToTask(task),
                                      icon: const Icon(Icons.send, size: 16),
                                      label: const Text('Submit'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                if (isFaculty && isCreator)
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _confirmDelete(task),
                                      icon: const Icon(Icons.delete_outline,
                                          size: 16),
                                      label: const Text('Delete'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.urgentRed,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                if (isFaculty && !isCreator) ...[
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _ignoreTask(task),
                                      icon: const Icon(Icons.visibility_off,
                                          size: 16),
                                      label: const Text('Ignore'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey[600],
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                                if (isFaculty &&
                                    task.submissions.isNotEmpty)
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _showSubmissions(task),
                                      icon: const Icon(Icons.list_alt,
                                          size: 16),
                                      label: const Text('View Submissions'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: const Text(
                'Delete this task for everyone? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.urgentRed),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await _deleteTask(task);
  }

  void _showSubmissions(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Submissions (${task.submissions.length})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (task.submissions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No submissions yet',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[600])),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: task.submissions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final sub = task.submissions[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.2),
                        child: Text(
                          sub.studentName.isNotEmpty
                              ? sub.studentName[0]
                              : '?',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(sub.studentName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (sub.textReply != null)
                            Text(sub.textReply!,
                                style: const TextStyle(fontSize: 13)),
                          if (sub.fileUrl != null)
                            Text('File: ${sub.fileName ?? "attachment"}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary)),
                          Text(
                            '${sub.submittedAt.month}/${sub.submittedAt.day} '
                            '${sub.submittedAt.hour.toString().padLeft(2, '0')}:'
                            '${sub.submittedAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
