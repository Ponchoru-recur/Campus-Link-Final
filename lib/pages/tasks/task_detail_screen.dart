import 'package:flutter/material.dart';
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

  final _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _loadTask();
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
    final links = (task['links'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
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
          if (links.isNotEmpty) ...[
            const Text(
              'Links:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...links.map((link) {
              final title = link['title'] ?? 'Unknown';
              final url = link['url'] ?? '';
              return ListTile(
                leading: const Icon(Icons.link, color: AppColors.primary),
                title: Text(title),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              );
            }),
          ] else
            const Text('No links'),
        ],
      ),
    );
  }
}
