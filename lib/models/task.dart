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
  final List<String> targetUids; // UIDs of users who should see this task
  final List<String> ignoredBy; // Faculty who tapped out
  final List<String> doneByUids; // students who marked as done
  final int? greenThresholdDays; // per-task override for green deadline color
  final int? yellowThresholdDays; // per-task override for yellow deadline color
  final int? redThresholdDays; // per-task override for red deadline color

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
    this.targetUids = const [],
    this.ignoredBy = const [],
    this.doneByUids = const [],
    this.greenThresholdDays,
    this.yellowThresholdDays,
    this.redThresholdDays,
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
      targetUids: List<String>.from(data['targetUids'] ?? []),
      ignoredBy: List<String>.from(data['ignoredBy'] ?? []),
      doneByUids: List<String>.from(data['doneByUids'] ?? []),
      greenThresholdDays: data['greenThresholdDays'] as int?,
      yellowThresholdDays: data['yellowThresholdDays'] as int?,
      redThresholdDays: data['redThresholdDays'] as int?,
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
        'targetUids': targetUids,
        'ignoredBy': ignoredBy,
        'doneByUids': doneByUids,
        'greenThresholdDays': greenThresholdDays,
        'yellowThresholdDays': yellowThresholdDays,
        'redThresholdDays': redThresholdDays,
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
