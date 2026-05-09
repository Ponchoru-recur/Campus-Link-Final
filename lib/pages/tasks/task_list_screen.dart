import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/services/task_service.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'create_task_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String? _role;
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _error;

  final _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _loadRoleAndTasks();
  }

  Future<void> _loadRoleAndTasks() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _role = doc.data()?['role'] ?? 'student';

      final tasks = await _taskService.getTasks();
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tasks: $e';
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
        title: const Text('Tasks'),
      ),
      body: _buildBody(),
      floatingActionButton: _role == 'faculty'
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateTaskScreen(),
                  ),
                );
                _loadRoleAndTasks();
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
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
    if (_tasks.isEmpty) {
      return const Center(child: Text('No tasks yet'));
    }
    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return ListTile(
          title: Text(task['title'] ?? 'Untitled'),
          subtitle: Text(task['description'] ?? ''),
          trailing: Text(
            task['deadline'] != null
                ? DateTime.parse(task['deadline']).toString().split(' ')[0]
                : 'No deadline',
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TaskDetailScreen(taskId: task['id']),
              ),
            );
          },
        );
      },
    );
  }
}
