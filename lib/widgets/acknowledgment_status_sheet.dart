import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/themes/app_colors.dart';

/// Faculty-only bottom sheet showing per-student seen & acknowledged status.
class AcknowledgmentStatusSheet extends StatefulWidget {
  final Task task;
  final String chatId;

  const AcknowledgmentStatusSheet({
    super.key,
    required this.task,
    required this.chatId,
  });

  @override
  State<AcknowledgmentStatusSheet> createState() =>
      _AcknowledgmentStatusSheetState();
}

class _AcknowledgmentStatusSheetState
    extends State<AcknowledgmentStatusSheet> {
  List<_StudentInfo> _students = [];
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(widget.chatId)
          .get();

      if (!chatDoc.exists) {
        if (mounted) setState(() => _loadingMembers = false);
        return;
      }

      final members = List<String>.from(chatDoc.data()?['members'] ?? []);
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final futures = members
          .where((uid) => uid != currentUid)
          .map((uid) => FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get());
      final snapshots = await Future.wait(futures);

      if (!mounted) return;
      final students = <_StudentInfo>[];
      for (final doc in snapshots) {
        final role = doc.data()?['role'] ?? 'student';
        if (role == 'faculty') continue;

        final email = doc.data()?['email'] ?? '';
        final name = email
            .split('@')
            .first
            .replaceAll('.', ' ')
            .split(' ')
            .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
            .join(' ');
        students.add(_StudentInfo(uid: doc.id, name: name));
      }

      setState(() {
        _students = students;
        _loadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error loading members: $e');
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
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
              const SizedBox(height: 20),

              // Task title
              Text(
                widget.task.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

              // Live summary from task stream
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tasks')
                    .doc(widget.task.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data =
                      snapshot.data?.data() as Map<String, dynamic>?;
                  final responses =
                      (data?['studentResponses'] as Map<String, dynamic>?) ??
                          {};
                  final total = _students.length;
                  int ackCount = 0;
                  int seenCount = 0;
                  for (final entry in responses.entries) {
                    final resp = entry.value as Map<String, dynamic>;
                    if (resp['acknowledged'] == true) ackCount++;
                    if (resp['seen'] == true) seenCount++;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '$ackCount of $total acknowledged · $seenCount seen',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // Member list with live status
              Expanded(
                child: _loadingMembers
                    ? const Center(child: CircularProgressIndicator())
                    : _students.isEmpty
                        ? Center(
                            child: Text('No students in this group',
                                style: TextStyle(color: Colors.grey[500])),
                          )
                        : StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('tasks')
                                .doc(widget.task.id)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final data = snapshot.data?.data()
                                  as Map<String, dynamic>?;
                              final responses = (data?['studentResponses']
                                      as Map<String, dynamic>?) ??
                                  {};

                              return ListView.separated(
                                controller: scrollController,
                                itemCount: _students.length,
                                separatorBuilder: (_, _) =>
                                    Divider(height: 1, color: Colors.grey[200]),
                                itemBuilder: (context, index) {
                                  final s = _students[index];
                                  final resp = responses[s.uid]
                                      as Map<String, dynamic>?;
                                  final seen =
                                      resp?['seen'] == true;
                                  final acknowledged =
                                      resp?['acknowledged'] == true;

                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              AppColors.primary
                                                  .withValues(alpha: 0.15),
                                          child: Text(
                                            s.name.isNotEmpty
                                                ? s.name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            s.name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          seen
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: seen
                                              ? AppColors.doneGreen
                                              : Colors.grey[400],
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          acknowledged
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: acknowledged
                                              ? AppColors.doneGreen
                                              : Colors.grey[400],
                                          size: 22,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudentInfo {
  final String uid;
  final String name;
  const _StudentInfo({required this.uid, required this.name});
}