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
  final List<TaskLink> links;
  final bool isActive; // false if faculty deleted/ignored it
  final bool reminderSent3h; // true after 3h deadline reminder sent
  final bool reminderSent1h; // true after 1h deadline reminder sent
  final List<String> targetUids; // UIDs of users who should see this task
  final List<String> ignoredBy; // Faculty who tapped out
  final List<String> doneByUids; // students who marked as done
  final int? greenThresholdDays; // per-task override for green deadline color
  final int? yellowThresholdDays; // per-task override for yellow deadline color
  final int? redThresholdDays; // per-task override for red deadline color
  final Map<String, StudentTaskResponse> studentResponses;

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
    this.links = const [],
    this.isActive = true,
    this.reminderSent3h = false,
    this.reminderSent1h = false,
    this.targetUids = const [],
    this.ignoredBy = const [],
    this.doneByUids = const [],
    this.greenThresholdDays,
    this.yellowThresholdDays,
    this.redThresholdDays,
    this.studentResponses = const {},
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
      deadline: (data['deadline'] is Timestamp
                ? (data['deadline'] as Timestamp).toDate()
                : data['deadline'] is String
                    ? DateTime.tryParse(data['deadline'] as String)
                    : null),
      links: (data['links'] as List<dynamic>? ?? [])
          .map((e) => TaskLink.fromMap(e as Map<String, dynamic>))
          .toList(),
      isActive: data['isActive'] ?? true,
      reminderSent3h: data['reminderSent3h'] ?? false,
      reminderSent1h: data['reminderSent1h'] ?? false,
      targetUids: List<String>.from(data['targetUids'] ?? []),
      ignoredBy: List<String>.from(data['ignoredBy'] ?? []),
      doneByUids: List<String>.from(data['doneByUids'] ?? []),
      greenThresholdDays: data['greenThresholdDays'] as int?,
      yellowThresholdDays: data['yellowThresholdDays'] as int?,
      redThresholdDays: data['redThresholdDays'] as int?,
      studentResponses: (data['studentResponses'] as Map<String, dynamic>?)
              ?.map((k, v) =>
                  MapEntry(k, StudentTaskResponse.fromMap(v as Map<String, dynamic>))) ??
          {},
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
        'links': links.map((l) => l.toMap()).toList(),
        'isActive': isActive,
        'reminderSent3h': reminderSent3h,
        'reminderSent1h': reminderSent1h,
        'targetUids': targetUids,
        'ignoredBy': ignoredBy,
        'doneByUids': doneByUids,
        'greenThresholdDays': greenThresholdDays,
        'yellowThresholdDays': yellowThresholdDays,
        'redThresholdDays': redThresholdDays,
        'studentResponses':
            studentResponses.map((k, v) => MapEntry(k, v.toMap())),
      };
}

/// Per-student response tracking for a task.
class StudentTaskResponse {
  final bool seen;
  final DateTime? seenAt;
  final bool acknowledged;
  final DateTime? acknowledgedAt;

  const StudentTaskResponse({
    this.seen = false,
    this.seenAt,
    this.acknowledged = false,
    this.acknowledgedAt,
  });

  factory StudentTaskResponse.fromMap(Map<String, dynamic> m) {
    return StudentTaskResponse(
      seen: m['seen'] ?? false,
      seenAt: (m['seenAt'] as Timestamp?)?.toDate(),
      acknowledged: m['acknowledged'] ?? false,
      acknowledgedAt: (m['acknowledgedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'seen': seen,
        if (seenAt != null) 'seenAt': Timestamp.fromDate(seenAt!),
        'acknowledged': acknowledged,
        if (acknowledgedAt != null) 'acknowledgedAt': Timestamp.fromDate(acknowledgedAt!),
      };
}

class TaskLink {
  final String title;
  final String url;

  const TaskLink({required this.title, required this.url});

  factory TaskLink.fromMap(Map<String, dynamic> m) => TaskLink(
        title: m['title'] ?? '',
        url: m['url'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'url': url,
      };
}
