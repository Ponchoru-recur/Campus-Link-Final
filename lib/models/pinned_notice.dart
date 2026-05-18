import 'package:cloud_firestore/cloud_firestore.dart';

class PinnedNotice {
  final String id;
  final String title;
  final String description;
  final String? link;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final bool isArchived;
  final int order;
  final DateTime? editedAt;

  PinnedNotice({
    required this.id,
    required this.title,
    required this.description,
    this.link,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.isArchived = false,
    required this.order,
    this.editedAt,
  });

  factory PinnedNotice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PinnedNotice(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      link: data['link'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      isArchived: data['isArchived'] ?? false,
      order: data['order'] ?? 0,
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'link': link,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'isArchived': isArchived,
      'order': order,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
    };
  }
}