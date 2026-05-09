import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/services/task_service.dart';
import 'package:luminescence/themes/app_colors.dart';

class SubmitTaskScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const SubmitTaskScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<SubmitTaskScreen> createState() => _SubmitTaskScreenState();
}

class _SubmitTaskScreenState extends State<SubmitTaskScreen> {
  final _attachments = <PlatformFile>[];
  bool _isSubmitting = false;

  final _taskService = TaskService();

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null) {
      setState(() {
        _attachments.addAll(result.files);
      });
    }
  }

  Future<void> _submit() async {
    if (_attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach at least one file')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _taskService.submitTask(
        taskId: widget.taskId,
        studentName: '',
        attachments: _attachments,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission successful')),
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
        title: Text('Submit: ${widget.taskTitle}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task: ${widget.taskTitle}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _pickFiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add Files'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_attachments.isNotEmpty)
              Expanded(
                child: ListView(
                  children: _attachments.map((file) {
                    return ListTile(
                      leading: const Icon(Icons.attach_file),
                      title: Text(file.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _attachments.remove(file);
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
