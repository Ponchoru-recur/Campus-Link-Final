import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/services/task_service.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

/// Updates & Tasks screen showing all tasks for the current user.
/// Tasks are informational only - no submissions allowed.
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
  final _taskService = TaskService();

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

  Future<void> _toggleTaskDone(Task task) async {
    final uid = _userId;
    if (uid == null) return;
    final isDone = task.doneByUids.contains(uid);
    try {
      if (isDone) {
        await _taskService.unmarkTaskDone(task.id, uid);
      } else {
        await _taskService.markTaskDone(task.id, uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _launchLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return;
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No app available to open this link'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'No deadline';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  bool _isOverdue(Task task) {
    if (task.deadline == null) return false;
    return task.deadline!.isBefore(DateTime.now());
  }

  Color _getDeadlineColor(Task task) {
    if (task.deadline == null) return Colors.grey[600]!;

    final now = DateTime.now();
    final deadline = task.deadline!;
    final daysLeft = deadline.difference(now).inDays;

    // Check per-task thresholds first
    final green = task.greenThresholdDays ?? TaskService.defaultGreenDays;
    final yellow = task.yellowThresholdDays ?? TaskService.defaultYellowDays;
    final red = task.redThresholdDays ?? TaskService.defaultRedDays;

    if (daysLeft >= green) return AppColors.doneGreen;
    if (daysLeft >= yellow) return AppColors.pendingYellow;
    if (daysLeft >= red) return AppColors.urgentRed;
    return AppColors.urgentRed;
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
              : Builder(builder: (context) {
                  final uid = _userId;
                  final activeTasks = _tasks.where((t) {
                    return t.isActive && (uid == null || !t.doneByUids.contains(uid));
                  }).toList();
                  final doneTasks = _tasks.where((t) {
                    return t.isActive && uid != null && t.doneByUids.contains(uid);
                  }).toList();
                  final deletedTasks = _tasks.where((t) => !t.isActive).toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (activeTasks.isNotEmpty) ...[
                        ...activeTasks.map((task) => _buildTaskCard(task)),
                        const SizedBox(height: 16),
                      ],
                      if (doneTasks.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: AppColors.doneGreen),
                              SizedBox(width: 6),
                              Text('Completed',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.doneGreen)),
                            ],
                          ),
                        ),
                        ...doneTasks.map((task) => _buildTaskCard(task, isDone: true)),
                        const SizedBox(height: 16),
                      ],
                      if (deletedTasks.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                              SizedBox(width: 6),
                              Text('Deleted',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                            ],
                          ),
                        ),
                        ...deletedTasks.map((task) => _buildTaskCard(task, isDeleted: true)),
                      ],
                    ],
                  );
                }),
    );
  }

  Widget _buildTaskCard(Task task, {bool isDone = false, bool isDeleted = false}) {
    final isCreator = task.createdBy == _userId;
    final isFaculty = _userRole == 'faculty';
    final overdue = _isOverdue(task);
    final deadlineColor = isDeleted ? Colors.grey[500]! : _getDeadlineColor(task);
    final uid = _userId;

    return GestureDetector(
      onLongPress: isDone || isDeleted
          ? null
          : () {
              if (uid != null) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Mark as done?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _toggleTaskDone(task);
                        },
                        child: const Text('Mark done'),
                      ),
                    ],
                  ),
                );
              }
            },
      child: Container(
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDeleted
              ? Colors.grey[300]!
              : isDone
                  ? AppColors.doneGreen.withValues(alpha: 0.3)
                  : overdue
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
              color: isDeleted
                  ? Colors.grey[100]!
                  : isDone
                      ? AppColors.doneGreen.withValues(alpha: 0.05)
                      : overdue
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
                    color: isDeleted
                        ? Colors.grey[300]
                        : isDone
                            ? AppColors.doneGreen.withValues(alpha: 0.1)
                            : overdue
                                ? AppColors.urgentRed.withValues(alpha: 0.1)
                                : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDeleted ? Icons.delete_outline : isDone ? Icons.check_circle : Icons.assignment,
                    color: isDeleted
                        ? Colors.grey[500]
                        : isDone
                            ? AppColors.doneGreen
                            : overdue
                                ? AppColors.urgentRed
                                : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: isDone || isDeleted
                                ? TextDecoration.lineThrough
                                : null),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'By ${task.creatorName}',
                        style: TextStyle(
                            fontSize: 12, color: isDeleted ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                isDeleted
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[400]!,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('DELETED',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5)),
                      )
                    : overdue && !isDone
                        ? Container(
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
                          )
                        : const SizedBox.shrink(),
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
                    style: TextStyle(
                        fontSize: 14,
                        color: isDeleted ? Colors.grey[500]! : AppColors.textPrimary,
                        decoration: isDeleted ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: deadlineColor),
                    const SizedBox(width: 6),
                    Text(
                      'Due: ${_formatDate(task.deadline)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: deadlineColor),
                    ),
                    const SizedBox(width: 8),
                    if (!isDone && !isDeleted && !overdue)
                      Text(
                        _daysLeftText(task),
                        style: TextStyle(
                            fontSize: 11, color: deadlineColor, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
                if (!isDeleted && task.links.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: task.links.map((link) => InkWell(
                      onTap: () => _launchLink(link.url),
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
                            Text(
                              link.title,
                              style: const TextStyle(fontSize: 11, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          // Actions
          if (!isDone && !isDeleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  if (isFaculty && isCreator) ...[
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _editTask(task),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _confirmDelete(task),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.urgentRed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                  if (isFaculty && !isCreator) ...[
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _ignoreTask(task),
                        icon: const Icon(Icons.visibility_off, size: 16),
                        label: const Text('Ignore'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    ),
    );
  }

  String _daysLeftText(Task task) {
    if (task.deadline == null) return '';
    final daysLeft = task.deadline!.difference(DateTime.now()).inDays;
    if (daysLeft <= 0) return 'Due today';
    if (daysLeft == 1) return '1 day left';
    return '$daysLeft days left';
  }

  void _editTask(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditTaskScreen(task: task),
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
}

/// Inline edit task screen for faculty to update task fields.
class _EditTaskScreen extends StatefulWidget {
  final Task task;

  const _EditTaskScreen({required this.task});

  @override
  State<_EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<_EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  DateTime? _deadline;
  bool _isSaving = false;
  final List<TaskLink> _links = [];
  final _taskService = TaskService();

  Future<void> _openLink(TaskLink link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null || !uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid URL: ${link.url}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No app available to open this link'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open link'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description);
    _deadline = widget.task.deadline;
    _links.addAll(widget.task.links);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _deadline = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  Future<void> _addLink() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final result = await showDialog<TaskLink>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Link Name',
                hintText: 'e.g., Course Materials',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final url = urlController.text.trim();
              if (name.isEmpty || url.isEmpty) return;
              Navigator.pop(ctx, TaskLink(title: name, url: url));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _links.add(result));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _taskService.updateTask(
        taskId: widget.task.id,
        title: _titleController.text,
        description: _descController.text,
        deadline: _deadline != null
            ? DateFormat('yyyy-MM-ddTHH:mm:ss').format(_deadline!)
            : null,
        clearDeadline: _deadline == null,
        links: _links,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Task updated'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Edit Task',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Task Information
              _EditSectionCard(
                icon: Icons.assignment,
                title: 'Task Information',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      maxLength: 100,
                      decoration: _editInputDecoration(
                        label: 'Task Title',
                        hint: 'Enter task title...',
                        icon: Icons.title,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Title required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      maxLines: 5,
                      minLines: 3,
                      maxLength: 500,
                      decoration: _editInputDecoration(
                        label: 'Description',
                        hint: 'Describe the task...',
                        icon: Icons.description_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Deadline
              _EditSectionCard(
                icon: Icons.calendar_month,
                title: 'Deadline',
                child: InkWell(
                  onTap: _selectDeadline,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.calendar_today,
                              size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _deadline == null
                                    ? 'No deadline set'
                                    : DateFormat('EEEE, MMMM d, y')
                                        .format(_deadline!),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: _deadline == null
                                      ? Colors.grey[500]
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (_deadline != null)
                                Text(
                                  '${_deadline!.hour.toString().padLeft(2, '0')}:${_deadline!.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500]),
                                ),
                            ],
                          ),
                        ),
                        if (_deadline != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _deadline = null),
                            splashRadius: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Links
              _EditSectionCard(
                icon: Icons.link,
                title: 'Attached Links',
                trailing: TextButton.icon(
                  onPressed: _addLink,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Link'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                child: _links.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.link_off,
                                size: 16, color: Colors.grey[400]),
                            const SizedBox(width: 8),
                            Text('No links attached',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 13)),
                          ],
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _links.map((link) {
                          return InkWell(
                            onTap: () => _openLink(link),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                        AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link,
                                      size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(link.title,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _links.remove(link)),
                                    child: Icon(Icons.close,
                                        size: 14, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 24),

              // Delete button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Delete Task'),
                        content: const Text(
                            'Delete this task for everyone? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.urgentRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _taskService.deleteTask(widget.task.id);
                      if (!mounted) return;
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete this task'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.urgentRed,
                    side: BorderSide(color: AppColors.urgentRed.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _editInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      counterText: '',
    );
  }
}

class _EditSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  const _EditSectionCard({
    required this.icon,
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1, indent: 18, endIndent: 18),
          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }
}
