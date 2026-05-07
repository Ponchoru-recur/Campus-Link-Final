import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:luminescence/services/storage_service.dart';
import 'package:file_picker/file_picker.dart';

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
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: const Text(
                'Delete this task for everyone? It will appear crossed out in chat.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.urgentRed),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update({'isActive': false});

      // Send deletion message to chat
      final messagesRef = task.chatType == 'group'
          ? FirebaseFirestore.instance
              .collection('group_chats')
              .doc(task.chatId)
              .collection('messages')
          : FirebaseFirestore.instance
              .collection('direct_messages')
              .doc(task.chatId)
              .collection('messages');

      final chatRef = task.chatType == 'group'
          ? FirebaseFirestore.instance.collection('group_chats').doc(task.chatId)
          : FirebaseFirestore.instance.collection('direct_messages').doc(task.chatId);

      await messagesRef.add({
        'senderId': _userId ?? '',
        'senderName': task.creatorName,
        'text': 'Task deleted: ${task.title}',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'task_deleted',
        'taskId': task.id,
        'readBy': [_userId ?? ''],
      });

      await chatRef.update({
        'lastMessage': 'Task deleted: ${task.title.substring(0, task.title.length > 50 ? 50 : task.title.length)}${task.title.length > 50 ? '...' : ''}',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

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
    String? attachedFilePath;
    String? attachedFileName;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Submit to Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.description,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  if (task.deadline != null) ...[
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: _isOverdue(task) ? AppColors.urgentRed : Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          _isOverdue(task) ? 'Deadline has passed' : 'Due: ${_formatDate(task.deadline)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isOverdue(task) ? AppColors.urgentRed : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            final pickResult = await FilePicker.platform.pickFiles(
                              allowMultiple: false,
                              withData: false,
                            );
                            if (pickResult != null && pickResult.files.isNotEmpty) {
                              setState(() {
                                attachedFilePath = pickResult.files.first.path;
                                attachedFileName = pickResult.files.first.name;
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to pick file: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          attachedFileName ?? 'Attach File',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (attachedFileName != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            attachedFileName!,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () => setState(() {
                            attachedFilePath = null;
                            attachedFileName = null;
                          }),
                          splashRadius: 14,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, {
                  'textReply': controller.text.trim(),
                  'filePath': attachedFilePath,
                  'fileName': attachedFileName,
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
      },
    );

    if (result == null) return;

    try {
      // Server-side deadline check
      if (task.deadline != null && task.deadline!.isBefore(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deadline has passed. Submissions are closed.')),
          );
        }
        return;
      }

      String? fileUrl;
      if (result['filePath'] != null) {
        final storageService = StorageService();
        fileUrl = await storageService.uploadSubmissionFile(
          taskId: task.id,
          studentUid: user.uid,
          filePath: result['filePath'],
          fileName: result['fileName'] ?? 'submission',
        );
      }

      final submission = TaskSubmission(
        studentUid: user.uid,
        studentName: name,
        textReply: result['textReply']?.isNotEmpty == true ? result['textReply'] : null,
        fileUrl: fileUrl,
        fileName: fileUrl != null ? result['fileName'] : null,
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

  Future<void> _downloadAttachment(String fileUrl, String fileName) async {
    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open file')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
        );
      }
    }
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
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                                if (task.attachments.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Attachments (${task.attachments.length})',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 6),
                                  ...task.attachments.map((a) => InkWell(
                                        onTap: () =>
                                            _downloadAttachment(a.fileUrl, a.fileName),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6, horizontal: 10),
                                          margin: const EdgeInsets.only(bottom: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.insert_drive_file,
                                                  size: 16,
                                                  color: AppColors.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(a.fileName,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.primary)),
                                              ),
                                              const Icon(Icons.download,
                                                  size: 14,
                                                  color: AppColors.primary),
                                            ],
                                          ),
                                        ),
                                      )),
                                ],
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
                                    task.allowSubmissions) ...[
                                  Expanded(
                                    child: _isOverdue(task)
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.lock_clock,
                                                    size: 14, color: AppColors.urgentRed),
                                                const SizedBox(width: 6),
                                                const Text('Deadline Passed',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: AppColors.urgentRed,
                                                        fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            onPressed: () => _submitToTask(task),
                                            icon: const Icon(Icons.send, size: 16),
                                            label: const Text('Submit'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                            ),
                                          ),
                                  ),
                                ],
                                if (isFaculty && isCreator) ...[
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _editTask(task),
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      label: const Text('Edit'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
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
                                ],
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


  Future<void> _editTask(Task task) async {
    if (_userRole != 'faculty' || task.createdBy != _userId) return;

    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description);
    DateTime? deadline = task.deadline;
    bool allowSubmissions = task.allowSubmissions;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  maxLength: 100,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 4,
                  minLines: 2,
                  maxLength: 500,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: deadline ?? DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() => deadline = DateTime(
                                picked.year, picked.month, picked.day, time.hour, time.minute));
                          }
                        }
                      },
                      child: Text(
                        deadline == null
                            ? 'Set deadline'
                            : 'Due: ${deadline!.month}/${deadline!.day}/${deadline!.year}',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                    if (deadline != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => deadline = null),
                      ),
                  ],
                ),
                CheckboxListTile(
                  value: allowSubmissions,
                  onChanged: (v) => setState(() => allowSubmissions = v ?? false),
                  title: const Text('Allow submissions', style: TextStyle(fontSize: 14)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final update = TaskUpdate(
        updatedBy: user.uid,
        updatedAt: DateTime.now(),
        oldTitle: task.title,
        newTitle: titleController.text.trim() != task.title ? titleController.text.trim() : null,
        oldDescription: task.description,
        newDescription: descController.text.trim() != task.description
            ? descController.text.trim()
            : null,
        oldDeadline: task.deadline,
        newDeadline: deadline != task.deadline ? deadline : null,
        oldAllowSubmissions: task.allowSubmissions,
        newAllowSubmissions: allowSubmissions != task.allowSubmissions
            ? allowSubmissions
            : null,
      );

      final updateMap = <String, dynamic>{
        'title': titleController.text.trim(),
        'description': descController.text.trim(),
        'updatedAt': DateTime.now(),
        'updatedBy': user.uid,
        'updateHistory': FieldValue.arrayUnion([update.toMap()]),
      };
      if (deadline != task.deadline) updateMap['deadline'] = deadline;
      if (allowSubmissions != task.allowSubmissions) {
        updateMap['allowSubmissions'] = allowSubmissions;
      }

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update(updateMap);

      // Send edit notification to chat
      final chatRef = task.chatType == 'group'
          ? FirebaseFirestore.instance.collection('group_chats').doc(task.chatId)
          : FirebaseFirestore.instance.collection('direct_messages').doc(task.chatId);

      final messagesRef = task.chatType == 'group'
          ? chatRef.collection('messages')
          : FirebaseFirestore.instance
              .collection('direct_messages')
              .doc(task.chatId)
              .collection('messages');

      await messagesRef.add({
        'senderId': user.uid,
        'senderName': task.creatorName,
        'text': 'Task updated: ${titleController.text.trim()}',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'task_updated',
        'taskId': task.id,
        'readBy': [user.uid],
      });

      // Update last message
      final titleTrimmed = titleController.text.trim();
      await chatRef.update({
        'lastMessage': 'Task updated: ${titleTrimmed.substring(0, titleTrimmed.length > 50 ? 50 : titleTrimmed.length)}${titleTrimmed.length > 50 ? '...' : ''}',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated!')),
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
                  separatorBuilder: (_, _) => const Divider(height: 1),
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
                            InkWell(
                              onTap: () => _downloadAttachment(
                                  sub.fileUrl!, sub.fileName ?? 'attachment'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 8),
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.attach_file,
                                        size: 12,
                                        color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      sub.fileName ?? 'Download file',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.download,
                                        size: 12,
                                        color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
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
