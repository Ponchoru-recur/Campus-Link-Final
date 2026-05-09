import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/pages/tasks/submit_task_screen.dart';
import 'package:luminescence/pages/tasks/submissions_list_screen.dart';
import 'package:luminescence/services/task_service.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map<String, dynamic>? _task;
  bool _isLoading = true;
  String? _error;
  String _userRole = 'student';

  final _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadTask();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        _userRole = doc.data()?['role'] ?? 'student';
      });
    } catch (e) {
      debugPrint('Failed to load user role: $e');
    }
  }

  Future<void> _loadTask() async {
    setState(() => _isLoading = true);
    try {
      final task = await _taskService.getTask(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = task;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load task: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(_task?['title'] ?? 'Task Detail'),
      ),
      body: _buildBody(),
      floatingActionButton: _task != null && _userRole == 'student'
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubmitTaskScreen(
                      taskId: widget.taskId,
                      taskTitle: _task!['title'] ?? '',
                    ),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload),
              label: const Text('Submit'),
            )
          : _task != null && _userRole == 'faculty'
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubmissionsListScreen(
                          taskId: widget.taskId,
                          taskTitle: _task!['title'] ?? '',
                        ),
                      ),
                    );
                  },
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.list),
                  label: const Text('Submissions'),
                )
              : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_task == null) {
      return const Center(child: Text('Task not found'));
    }

    final task = _task!;
    final attachments = task['attachments'] as List<dynamic>? ?? [];
    final deadline = task['deadline'] != null
        ? DateTime.parse(task['deadline'])
        : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            task['title'] ?? 'Untitled',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (task['description'] != null && task['description'].isNotEmpty) ...[
            Text(
              task['description'],
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
          ],
          if (deadline != null)
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Deadline: ${deadline.toLocal().toString().split(' ')[0]}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          const SizedBox(height: 24),
          if (attachments.isNotEmpty) ...[
            const Text(
              'Attachments:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...attachments.map((att) {
              return ListTile(
                leading: const Icon(Icons.attach_file),
                title: Text(att['fileName'] ?? 'Unknown'),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () async {
                    final url = att['viewLink'];
                    if (url != null) {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                ),
              );
            }),
          ] else
            const Text('No attachments'),
        ],
      ),
    );
  }
}
