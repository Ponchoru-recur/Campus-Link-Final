import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/services/task_service.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class CreateTaskScreen extends StatefulWidget {
  final String? prefilledChatId;
  final String? prefilledChatType;
  final String? prefilledRecipientName;
  final String? prefilledOtherParticipantUid;

  const CreateTaskScreen({
    super.key,
    this.prefilledChatId,
    this.prefilledChatType,
    this.prefilledRecipientName,
    this.prefilledOtherParticipantUid,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<TaskLink> _links = [];
  DateTime? _deadline;
  bool _isSubmitting = false;

  final _taskService = TaskService();
  String _userRole = 'student';
  String? _userId;
  List<Map<String, dynamic>> _availableGroups = [];
  final Set<String> _selectedGroupIds = {};

  @override
  void initState() {
    super.initState();
    _fetchUserAndGroups();
  }

  Future<void> _fetchUserAndGroups() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userId = user.uid;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        _userRole = userDoc.data()?['role'] ?? 'student';
      }
      if (widget.prefilledChatId == null && _userRole == 'faculty') {
        final snapshot = await FirebaseFirestore.instance
            .collection('group_chats')
            .where('members', arrayContains: user.uid)
            .get();
        if (mounted) {
          setState(() {
            _availableGroups = snapshot.docs
                .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
                .toList();
          });
        }
      }
    } catch (_) {}
  }

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a deadline')),
      );
      return;
    }

    List<Map<String, String?>> targets = [];
    if (widget.prefilledChatId != null) {
      targets.add({
        'chatId': widget.prefilledChatId,
        'chatType': widget.prefilledChatType,
        'otherParticipantUid': widget.prefilledOtherParticipantUid,
      });
    } else {
      if (_selectedGroupIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one group')),
        );
        return;
      }
      for (final gid in _selectedGroupIds) {
        targets.add({'chatId': gid, 'chatType': 'group', 'otherParticipantUid': null});
      }
    }

    setState(() => _isSubmitting = true);
    try {
      for (final target in targets) {
        await _taskService.createTask(
          title: _titleController.text,
          description: _descriptionController.text,
          deadline: '',
          deadlineDate: _deadline,
          links: _links,
          chatId: target['chatId'],
          chatType: target['chatType'],
          otherParticipantUid: target['otherParticipantUid'],
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task created in ${targets.length} group${targets.length > 1 ? 's' : ''}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Create Task',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Title Section
              _SectionCard(
                icon: Icons.assignment,
                title: 'Task Information',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      maxLength: 100,
                      decoration: _inputDecoration(
                        label: 'Task Title',
                        hint: 'Enter a clear task title...',
                        icon: Icons.title,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Title is required';
                        if (v.trim().length < 3) return 'Must be at least 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      minLines: 3,
                      maxLength: 500,
                      decoration: _inputDecoration(
                        label: 'Description',
                        hint: 'Describe what needs to be done...',
                        icon: Icons.description_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Task description is required';
                        if (v.trim().length < 3) return 'Must be at least 3 characters';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Deadline Section
              _SectionCard(
                icon: Icons.calendar_month,
                title: 'Deadline',
                child: Column(
                  children: [
                    InkWell(
                      onTap: _selectDeadline,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                        ? 'Tap to set deadline'
                                        : DateFormat('EEEE, MMMM d, y').format(_deadline!),
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
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
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
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Links Section
              _SectionCard(
                icon: Icons.link,
                title: 'Attached Links',
                trailing: TextButton.icon(
                  onPressed: _addLink,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Link'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                child: _links.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.link_off, size: 16, color: Colors.grey[400]),
                            const SizedBox(width: 8),
                            Text('No links added yet',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(link.title,
                                      style: const TextStyle(
                                          fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => setState(() => _links.remove(link)),
                                    child: Icon(Icons.close, size: 14, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              // Group selector (global mode) or target chat label (prefilled mode)
              if (widget.prefilledChatId == null && _userRole == 'faculty') ...[
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.group,
                  title: 'Assign to Groups',
                  child: _availableGroups.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('No groups available',
                              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        )
                      : Column(
                          children: _availableGroups.map((group) {
                            final isSelected = _selectedGroupIds.contains(group['id']);
                            return CheckboxListTile(
                              title: Text(group['name'], style: const TextStyle(fontSize: 14)),
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedGroupIds.add(group['id']);
                                  } else {
                                    _selectedGroupIds.remove(group['id']);
                                  }
                                });
                              },
                              activeColor: AppColors.primary,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          }).toList(),
                        ),
                ),
              ],
              if (widget.prefilledChatId != null) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.group,
                  title: 'Target Chat',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.chat, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.prefilledRecipientName ?? 'Chat',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt, size: 22),
                            SizedBox(width: 10),
                            Text('Create Task',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.urgentRed),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      counterText: '',
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
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
