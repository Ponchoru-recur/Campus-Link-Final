import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/services/notification_service.dart';

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
    DateTime? deadlineDate,
    String? chatId,
    String? chatType,
    String? otherParticipantUid,
  }) async {
    final user = _user;

    final taskRef = _firestore.collection('tasks').doc();
    final taskId = taskRef.id;

    final linkData = links.map((link) => link.toMap()).toList();

    final email = user.email ?? '';
    final creatorName = email.isEmpty
        ? 'Unknown'
        : email
            .split('@')
            .first
            .replaceAll('.', ' ')
            .split(' ')
            .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
            .join(' ');

    List<String>? targetUids;
    if (chatId != null && chatType != null) {
      if (chatType == 'group') {
        final chatDoc = await _firestore.collection('group_chats').doc(chatId).get();
        if (chatDoc.exists) {
          targetUids = List<String>.from(chatDoc.data()?['members'] ?? []);
        }
      } else if (chatType == 'dm') {
        targetUids = [user.uid];
        if (otherParticipantUid != null) {
          targetUids.add(otherParticipantUid);
        }
      }
    }

    final deadlineField = deadlineDate ?? deadline;

    final taskData = {
      'title': title,
      'description': description,
      'deadline': deadlineField,
      'createdBy': user.uid,
      'creatorName': creatorName,
      'createdAt': FieldValue.serverTimestamp(),
      'links': linkData,
      'isActive': true,
      'doneByUids': <String>[],
      if (greenThresholdDays != null) 'greenThresholdDays': int.tryParse(greenThresholdDays),
      if (yellowThresholdDays != null) 'yellowThresholdDays': int.tryParse(yellowThresholdDays),
      if (redThresholdDays != null) 'redThresholdDays': int.tryParse(redThresholdDays),
      'chatId': ?chatId,
      'chatType': ?chatType,
      'targetUids': ?targetUids,
    };

    await taskRef.set(taskData);

    if (chatId != null && chatType != null) {
      final messagesRef = chatType == 'group'
          ? _firestore.collection('group_chats').doc(chatId).collection('messages')
          : _firestore.collection('direct_messages').doc(chatId).collection('messages');

      final chatRef = chatType == 'group'
          ? _firestore.collection('group_chats').doc(chatId)
          : _firestore.collection('direct_messages').doc(chatId);

      await messagesRef.add({
        'senderId': user.uid,
        'senderName': creatorName,
        'text': '\u{1F4CB} $title\n\n$description',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'task',
        'taskId': taskId,
        'readBy': [user.uid],
      });

      final deadlineStr = deadlineDate != null
          ? ' (Due: ${deadlineDate.month}/${deadlineDate.day}/${deadlineDate.year})'
          : deadline.isNotEmpty
              ? ' (Due: $deadline)'
              : '';

      final truncatedTitle = title.length > 50 ? '${title.substring(0, 50)}...' : title;
      await chatRef.update({
        'lastMessage': '\u{1F4CB} Task: $truncatedTitle$deadlineStr',
        'time': 'Now',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      // Fire notification (bypasses muted strategy for tasks)
      String chatName = 'Task';
      if (chatType == 'group') {
        final groupDoc = await _firestore.collection('group_chats').doc(chatId).get();
        if (groupDoc.exists) {
          chatName = groupDoc.data()?['name'] as String? ?? 'Group Chat';
        }
      } else if (chatType == 'dm') {
        final dmDoc = await _firestore.collection('direct_messages').doc(chatId).get();
        if (dmDoc.exists) {
          final participants = dmDoc.data()?['participants'] as List<dynamic>?;
          if (participants != null) {
            final otherUid = participants.cast<String>().firstWhere((e) => e != user.uid, orElse: () => '');
            if (otherUid.isNotEmpty) {
              final otherDoc = await _firestore.collection('users').doc(otherUid).get();
              chatName = otherDoc.data()?['name'] as String? ?? otherDoc.data()?['email'] as String? ?? 'DM';
            }
          }
        }
      }
      NotificationService.instance.sendTieredNotification(
        chatId: chatId,
        messageId: taskId,
        senderId: user.uid,
        senderName: creatorName,
        chatName: chatName,
        text: '\u{1F4CB} $title\n\n$description',
        mentionedUids: [],
        isEveryone: false,
        isTask: true,
      );

      if (chatType == 'group' && targetUids != null) {
        final chatDoc = await chatRef.get();
        if (chatDoc.exists) {
          final data = chatDoc.data()!;
          final members = List<String>.from(data['members'] ?? []);
          final unreadCount = data['unreadCount'];
          final Map<String, dynamic> updateMap = {};
          if (unreadCount is Map) {
            for (final uid in members) {
              if (uid == user.uid) continue;
              final currentCount = (unreadCount[uid] ?? 0) as int;
              updateMap['unreadCount.$uid'] = currentCount + 1;
            }
          } else {
            for (final uid in members) {
              updateMap['unreadCount.$uid'] = uid == user.uid ? 0 : 1;
            }
          }
          if (updateMap.isNotEmpty) {
            await chatRef.update(updateMap);
          }
        }
      } else if (chatType == 'dm') {
        await chatRef.update({
          'unreadCount.${chatId.split('_').firstWhere((e) => e != user.uid)}': FieldValue.increment(1),
        });
      }
    }

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
    if (deadline != null) {
      // Store as Timestamp, not String — prevents stream crash in fromFirestore
      final parsed = DateTime.tryParse(deadline);
      updates['deadline'] = parsed != null ? Timestamp.fromDate(parsed) : deadline;
    }
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
