import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:luminescence/services/task_service.dart';
import 'package:luminescence/themes/app_colors.dart';

class SubmissionsListScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const SubmissionsListScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<SubmissionsListScreen> createState() => _SubmissionsListScreenState();
}

class _SubmissionsListScreenState extends State<SubmissionsListScreen> {
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  String? _error;

  final _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);
    try {
      final submissions = await _taskService.getSubmissions(widget.taskId);
      setState(() {
        _submissions = submissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load submissions: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadFile(String downloadUrl, String fileName) async {
    try {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Submissions: ${widget.taskTitle}'),
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
    if (_submissions.isEmpty) {
      return const Center(child: Text('No submissions yet'));
    }
    return ListView.builder(
      itemCount: _submissions.length,
      itemBuilder: (context, index) {
        final sub = _submissions[index];
        final studentName = sub['studentName'] ?? 'Unknown';
        final submittedAt = sub['submittedAt'] ?? '';
        final attachments = sub['attachments'] as List<dynamic>? ?? [];

        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(studentName),
          subtitle: Text('Submitted: $submittedAt'),
          trailing: attachments.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () {
                    final file = attachments.first;
                    _downloadFile(
                      file['downloadUrl'],
                      file['fileName'],
                    );
                  },
                )
              : null,
        );
      },
    );
  }
}
