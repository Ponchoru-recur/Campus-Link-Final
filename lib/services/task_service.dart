import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/models/task.dart';

class TaskService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    return user;
  }

  // Default deadline thresholds (can be overridden per-task or globally)
  static const int defaultGreenDays = 7;
  static const int defaultYellowDays = 4;
  static const int defaultRedDays = 2;

  Future<Map<String, dynamic>> createTask({
    required String title,
    required String description,
    required String deadline,
    required List<TaskLink> links,
    String? greenThresholdDays,
    String? yellowThresholdDays,
    String? redThresholdDays,
  }) async {
    final user = _user;

    final taskRef = _firestore.collection('tasks').doc();
    final taskId = taskRef.id;

    final linkData = links.map((link) => link.toMap()).toList();

    final taskData = {
      'title': title,
      'description': description,
      'deadline': deadline,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'links': linkData,
      'isActive': true,
      'doneByUids': <String>[],
      if (greenThresholdDays != null) 'greenThresholdDays': int.tryParse(greenThresholdDays),
      if (yellowThresholdDays != null) 'yellowThresholdDays': int.tryParse(yellowThresholdDays),
      if (redThresholdDays != null) 'redThresholdDays': int.tryParse(redThresholdDays),
    };

    await taskRef.set(taskData);

    return {...taskData, 'id': taskId};
  }

  Future<void> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? deadline,
    List<TaskLink>? links,
    int? greenThresholdDays,
    int? yellowThresholdDays,
    int? redThresholdDays,
    bool clearDeadline = false,
    bool clearThresholds = false,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (deadline != null) updates['deadline'] = deadline;
    if (clearDeadline) updates['deadline'] = null;
    if (links != null) updates['links'] = links.map((l) => l.toMap()).toList();

    if (clearThresholds) {
      updates['greenThresholdDays'] = null;
      updates['yellowThresholdDays'] = null;
      updates['redThresholdDays'] = null;
    } else {
      if (greenThresholdDays != null) updates['greenThresholdDays'] = greenThresholdDays;
      if (yellowThresholdDays != null) updates['yellowThresholdDays'] = yellowThresholdDays;
      if (redThresholdDays != null) updates['redThresholdDays'] = redThresholdDays;
    }

    if (updates.isNotEmpty) {
      await _firestore.collection('tasks').doc(taskId).update(updates);
    }
  }

  Future<void> deleteTask(String taskId) async {
    // Soft delete - just mark as inactive
    await _firestore.collection('tasks').doc(taskId).update({'isActive': false});
  }

  Future<void> restoreTask(String taskId) async {
    await _firestore.collection('tasks').doc(taskId).update({'isActive': true});
  }

  Future<void> markTaskDone(String taskId, String uid) async {
    await _firestore.collection('tasks').doc(taskId).update({
      'doneByUids': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> unmarkTaskDone(String taskId, String uid) async {
    await _firestore.collection('tasks').doc(taskId).update({
      'doneByUids': FieldValue.arrayRemove([uid]),
    });
  }

  Future<Map<String, dynamic>> getGlobalDeadlineSettings() async {
    final doc = await _firestore.collection('app_settings').doc('deadline_thresholds').get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!;
    }
    // Return defaults if no settings exist
    return {
      'greenDays': defaultGreenDays,
      'yellowDays': defaultYellowDays,
      'redDays': defaultRedDays,
    };
  }

  Future<void> setGlobalDeadlineSettings({
    required int greenDays,
    required int yellowDays,
    required int redDays,
  }) async {
    await _firestore.collection('app_settings').doc('deadline_thresholds').set({
      'greenDays': greenDays,
      'yellowDays': yellowDays,
      'redDays': redDays,
    });
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    final snapshot = await _firestore
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {...data, 'id': doc.id};
    }).toList();
  }

  Future<Map<String, dynamic>> getTask(String taskId) async {
    final doc = await _firestore.collection('tasks').doc(taskId).get();
    if (!doc.exists) throw Exception('Task not found');
    final data = doc.data()!;
    return {...data, 'id': doc.id};
  }
}