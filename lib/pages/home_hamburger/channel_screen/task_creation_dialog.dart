import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:file_picker/file_picker.dart';

/// Modal dialog for faculty to create a task inside a chat.
/// Sends a task-type message into the chat upon creation.
class TaskCreationDialog extends StatefulWidget {
  final String chatId;
  final String chatType; // 'group' or 'dm'
  final String chatName;
  final String? otherParticipantUid; // for DM tasks

  const TaskCreationDialog({
    super.key,
    required this.chatId,
    required this.chatType,
    required this.chatName,
    this.otherParticipantUid,
  });

  @override
  State<TaskCreationDialog> createState() => _TaskCreationDialogState();
}

class _TaskCreationDialogState extends State<TaskCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  DateTime? _deadline;
  bool _allowSubmissions = false;
  final List<TaskAttachment> _attachments = [];
  bool _isSaving = false;

  String _getCurrentUserName() {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) return 'Unknown';
    return email
        .split('@')
        .first
        .replaceAll('.', ' ')
        .split(' ')
        .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
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
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _deadline = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  Future<void> _addAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      setState(() {
        _attachments.add(TaskAttachment(
          fileName: file.name,
          fileUrl: file.path ?? '', // Will be replaced with actual URL after upload
          mimeType: file.extension != null ? 'application/${file.extension}' : null,
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userName = _getCurrentUserName();
      final taskId = FirebaseFirestore.instance.collection('tasks').doc().id;

      // Fetch target UIDs
      List<String> targetUids = [user.uid];
      if (widget.chatType == 'group') {
        final chatDoc = await FirebaseFirestore.instance
            .collection('group_chats')
            .doc(widget.chatId)
            .get();
        if (chatDoc.exists) {
          final members = List<String>.from(chatDoc.data()?['members'] ?? []);
          targetUids = members;
        }
      } else {
        // DM: add both participants
        if (widget.otherParticipantUid != null) {
          targetUids.add(widget.otherParticipantUid!);
        }
      }

      final task = Task(
        id: taskId,
        title: _descController.text.trim(),
        description: _descController.text.trim(),
        createdBy: user.uid,
        creatorName: userName,
        chatId: widget.chatId,
        chatType: widget.chatType,
        createdAt: DateTime.now(),
        deadline: _deadline,
        allowSubmissions: _allowSubmissions,
        attachments: _attachments,
        targetUids: targetUids,
      );

      final firestore = FirebaseFirestore.instance;

      // Save task document
      await firestore.collection('tasks').doc(taskId).set(task.toFirestore());

      // Send a task-type message into the chat
      final messagesRef = widget.chatType == 'group'
          ? firestore.collection('group_chats').doc(widget.chatId).collection('messages')
          : firestore.collection('direct_messages').doc(widget.chatId).collection('messages');

      final chatRef = widget.chatType == 'group'
          ? firestore.collection('group_chats').doc(widget.chatId)
          : firestore.collection('direct_messages').doc(widget.chatId);

      await messagesRef.add({
        'senderId': user.uid,
        'senderName': userName,
        'text': _descController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'task',
        'taskId': taskId,
        'readBy': [user.uid],
      });

      // Update last message
      final deadlineStr = _deadline != null
          ? ' (Due: ${_deadline!.month}/${_deadline!.day}/${_deadline!.year})'
          : '';
      await chatRef.update({
        'lastMessage': '📋 Task: ${_descController.text.trim().substring(0, _descController.text.trim().length > 50 ? 50 : _descController.text.trim().length)}${_descController.text.trim().length > 50 ? '...' : ''}$deadlineStr',
        'time': 'Now',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      // Increment unread count for other members
      if (widget.chatType == 'group') {
        final chatDoc = await chatRef.get();
        if (chatDoc.exists) {
          final data = chatDoc.data()!;
          final members = List<String>.from(data['members'] ?? []);
          final unreadCount = data['unreadCount'];
          Map<String, dynamic> updateMap = {};
          if (unreadCount is Map) {
            for (final uid in members) {
              if (uid == user.uid) continue;
              final currentCount = (unreadCount[uid] ?? 0) as int;
              updateMap['unreadCount.$uid'] = currentCount + 1;
            }
          } else {
            updateMap['unreadCount'] = {};
            for (final uid in members) {
              updateMap['unreadCount.$uid'] = uid == user.uid ? 0 : 1;
            }
          }
          if (updateMap.isNotEmpty) {
            await chatRef.update(updateMap);
          }
        }
      } else {
        // DM: increment unread for other participant
        await chatRef.update({
          'unreadCount.${widget.chatId.split('_').firstWhere((e) => e != user.uid)}': FieldValue.increment(1),
        });
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.assignment_add, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Create Task',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(widget.chatName,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Description / Title
                const Text('Task Description',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  minLines: 2,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Describe the task...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Task description is required';
                    if (v.trim().length < 3) return 'Must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Deadline
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _pickDeadline,
                      child: Text(
                        _deadline == null
                            ? 'Set deadline (optional)'
                            : 'Due: ${_deadline!.month}/${_deadline!.day}/${_deadline!.year} '
                                '${_deadline!.hour.toString().padLeft(2, '0')}:${_deadline!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 14, color: AppColors.primary),
                      ),
                    ),
                    if (_deadline != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => _deadline = null),
                        splashRadius: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Allow submissions checkbox
                CheckboxListTile(
                  value: _allowSubmissions,
                  onChanged: (v) => setState(() => _allowSubmissions = v ?? false),
                  title: const Text('Allow student submissions',
                      style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Students can submit files or text in response',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppColors.primary,
                ),
                const SizedBox(height: 8),

                // Attachments section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Attachments (${_attachments.length})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    TextButton.icon(
                      onPressed: _addAttachment,
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text('Add File', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                if (_attachments.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _attachments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final a = _attachments[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 20),
                          title: Text(a.fileName, style: const TextStyle(fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => _removeAttachment(i),
                            splashRadius: 16,
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _createTask,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.task_alt, size: 18),
                      label: Text(_isSaving ? 'Creating...' : 'Create Task'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
