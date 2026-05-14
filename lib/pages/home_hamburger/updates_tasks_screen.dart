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
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
  final _linksController = TextEditingController();
  DateTime? _deadline;
  bool _isSaving = false;
  final _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description);
    _deadline = widget.task.deadline;
    _linksController.text = widget.task.links
        .map((l) => l.url)
        .join('\n');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _linksController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final List<TaskLink> links = [];
      final linkText = _linksController.text.trim();
      if (linkText.isNotEmpty) {
        for (final line in linkText.split(RegExp(r'[\n,]'))) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            links.add(TaskLink(title: trimmed, url: trimmed));
          }
        }
      }

      await _taskService.updateTask(
        taskId: widget.task.id,
        title: _titleController.text,
        description: _descController.text,
        deadline: _deadline != null
            ? DateFormat('yyyy-MM-ddTHH:mm:ss').format(_deadline!)
            : null,
        clearDeadline: _deadline == null,
        links: links,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Edit Task'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _deadline == null
                      ? 'No deadline'
                      : 'Deadline: ${DateFormat('yyyy-MM-dd').format(_deadline!)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_deadline != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _deadline = null),
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: _selectDeadline,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _linksController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Links (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Task'),
                      content: const Text('Delete this task for everyone?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: AppColors.urgentRed),
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
                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.urgentRed),
                label: const Text('Delete this task', style: TextStyle(color: AppColors.urgentRed)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
