import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _TaskCreationDialogState extends State<TaskCreationDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _deadline;
  bool _isSaving = false;
  final List<TaskLink> _links = [];
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
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
        if (widget.otherParticipantUid != null) {
          targetUids.add(widget.otherParticipantUid!);
        }
      }

      final task = Task(
        id: taskId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        createdBy: user.uid,
        creatorName: userName,
        chatId: widget.chatId,
        chatType: widget.chatType,
        createdAt: DateTime.now(),
        deadline: _deadline,
        links: _links,
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
        'text': '📋 ${_titleController.text.trim()}\n\n${_descController.text.trim()}',
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
        'lastMessage': '📋 Task: ${_titleController.text.trim().substring(0, _titleController.text.trim().length > 50 ? 50 : _titleController.text.trim().length)}${_titleController.text.trim().length > 50 ? '...' : ''}$deadlineStr',
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
        await chatRef.update({
          'unreadCount.${widget.chatId.split('_').firstWhere((e) => e != user.uid)}': FieldValue.increment(1),
        });
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: $e'),
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.assignment_add,
                            color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Create Task',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(widget.chatName,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.pop(context),
                          splashRadius: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Scrollable form content
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          _fieldLabel('Task Title'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _titleController,
                            maxLength: 100,
                            decoration: _inputDecoration(
                              hint: 'Enter task title...',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Title is required';
                              if (v.trim().length < 3) return 'Must be at least 3 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Description
                          _fieldLabel('Task Description'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descController,
                            maxLines: 4,
                            minLines: 2,
                            maxLength: 500,
                            decoration: _inputDecoration(
                              hint: 'Describe the task...',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Task description is required';
                              if (v.trim().length < 3) return 'Must be at least 3 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Deadline
                          _fieldLabel('Deadline'),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickDeadline,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 18, color: AppColors.textSecondary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _deadline == null
                                          ? 'Set deadline (optional)'
                                          : '${_deadline!.month}/${_deadline!.day}/${_deadline!.year} '
                                              '${_deadline!.hour.toString().padLeft(2, '0')}:${_deadline!.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _deadline == null
                                            ? Colors.grey[500]
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (_deadline != null)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: () =>
                                          setState(() => _deadline = null),
                                      splashRadius: 16,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Links
                          _fieldLabel('Attached Links'),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _addLink,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Link'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                  color: AppColors.primary.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                          if (_links.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
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
                                          color: AppColors.primary.withValues(alpha: 0.2)),
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
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _isSaving ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _createTask,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.task_alt, size: 20),
                        label: Text(_isSaving ? 'Creating...' : 'Create Task'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: AppColors.primary.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary));
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.urgentRed),
      ),
      contentPadding: const EdgeInsets.all(14),
      counterText: '',
    );
  }
}