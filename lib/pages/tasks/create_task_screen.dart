import 'package:flutter/material.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/services/task_service.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:intl/intl.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linksController = TextEditingController();
  DateTime? _deadline;
  bool _isSubmitting = false;

  final _taskService = TaskService();

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
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

    setState(() => _isSubmitting = true);
    try {
      final deadlineStr = DateFormat('yyyy-MM-ddTHH:mm:ss').format(_deadline!);

      // Parse links from input (one per line or comma-separated)
      final List<TaskLink> links = [];
      final linkText = _linksController.text.trim();
      if (linkText.isNotEmpty) {
        // Split by newline or comma
        final linkLines = linkText.split(RegExp(r'[\n,]'));
        for (final line in linkLines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            // If it looks like a URL, use it as both title and URL
            final Uri? uri = Uri.tryParse(trimmed);
            if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
              links.add(TaskLink(title: trimmed, url: trimmed));
            } else {
              // If not a valid URL, still add it but show warning or handle appropriately
              links.add(TaskLink(title: trimmed, url: trimmed));
            }
          }
        }
      }

      await _taskService.createTask(
        title: _titleController.text,
        description: _descriptionController.text,
        deadline: deadlineStr,
        links: links,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Create Task'),
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
                validator: (value) =>
                    value == null || value.isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
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
                      ? 'Select deadline'
                      : 'Deadline: ${DateFormat('yyyy-MM-dd').format(_deadline!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDeadline,
              ),
              const SizedBox(height: 16),
              // Links section
              TextFormField(
                controller: _linksController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Links (one per line or comma-separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
