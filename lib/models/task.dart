import 'package:cloud_firestore/cloud_firestore.dart';

/// Task model for faculty-created tasks.
/// Stored in Firestore: tasks/{taskId}
class Task {
  final String id;
  final String title;
  final String description;
  final String createdBy; // faculty UID
  final String creatorName;
  final String chatId; // which group/DM it was created in
  final String chatType; // 'group' or 'dm'
  final DateTime createdAt;
  final DateTime? deadline;
  final bool allowSubmissions;
  final List<TaskAttachment> attachments;
  final List<TaskSubmission> submissions;
  final bool isActive; // false if faculty deleted/ignored it
  final List<String> targetUids; // UIDs of users who should see this task
  final List<String> ignoredBy; // Faculty who tapped out

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.creatorName,
    required this.chatId,
    required this.chatType,
    required this.createdAt,
    this.deadline,
    this.allowSubmissions = false,
    this.attachments = const [],
    this.submissions = const [],
    this.isActive = true,
    this.targetUids = const [],
    this.ignoredBy = const [],
  });

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      creatorName: data['creatorName'] ?? '',
      chatId: data['chatId'] ?? '',
      chatType: data['chatType'] ?? 'group',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
      allowSubmissions: data['allowSubmissions'] ?? false,
      attachments: (data['attachments'] as List<dynamic>? ?? [])
          .map((e) => TaskAttachment.fromMap(e as Map<String, dynamic>))
          .toList(),
      submissions: (data['submissions'] as List<dynamic>? ?? [])
          .map((e) => TaskSubmission.fromMap(e as Map<String, dynamic>))
          .toList(),
      isActive: data['isActive'] ?? true,
      targetUids: List<String>.from(data['targetUids'] ?? []),
      ignoredBy: List<String>.from(data['ignoredBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'createdBy': createdBy,
        'creatorName': creatorName,
        'chatId': chatId,
        'chatType': chatType,
        'createdAt': createdAt,
        'deadline': deadline,
        'allowSubmissions': allowSubmissions,
        'attachments': attachments.map((a) => a.toMap()).toList(),
        'submissions': submissions.map((s) => s.toMap()).toList(),
        'isActive': isActive,
        'targetUids': targetUids,
        'ignoredBy': ignoredBy,
      };
}

class TaskAttachment {
  final String fileName;
  final String fileUrl;
  final String? mimeType;

  const TaskAttachment({required this.fileName, required this.fileUrl, this.mimeType});

  factory TaskAttachment.fromMap(Map<String, dynamic> m) => TaskAttachment(
        fileName: m['fileName'] ?? '',
        fileUrl: m['fileUrl'] ?? '',
        mimeType: m['mimeType'],
      );

  Map<String, dynamic> toMap() => {
        'fileName': fileName,
        'fileUrl': fileUrl,
        if (mimeType != null) 'mimeType': mimeType,
      };
}

class TaskSubmission {
  final String studentUid;
  final String studentName;
  final String? textReply;
  final String? fileUrl;
  final String? fileName;
  final DateTime submittedAt;

  const TaskSubmission({
    required this.studentUid,
    required this.studentName,
    this.textReply,
    this.fileUrl,
    this.fileName,
    required this.submittedAt,
  });

  factory TaskSubmission.fromMap(Map<String, dynamic> m) => TaskSubmission(
        studentUid: m['studentUid'] ?? '',
        studentName: m['studentName'] ?? '',
        textReply: m['textReply'],
        fileUrl: m['fileUrl'],
        fileName: m['fileName'],
        submittedAt: (m['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'studentUid': studentUid,
        'studentName': studentName,
        if (textReply != null) 'textReply': textReply,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
        'submittedAt': submittedAt,
      };
}
