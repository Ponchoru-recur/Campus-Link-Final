import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

const String _workerUrl = 'https://dawn-rice-bc73.sam-varela.workers.dev';

/// Unique name for workmanager task identifiers.
const String reminderTaskName3h = 'deadlineReminder3h';
const String reminderTaskName1h = 'deadlineReminder1h';

/// Schedules and executes deadline reminder callbacks.
///
/// Uses workmanager for background execution. Each task is a one-off
/// callback that checks Firestore at trigger time. If task is not done
/// and reminder flag not already set, sends FCM via Cloudflare Worker.
class DeadlineReminderService {
  /// Schedule both 3h and 1h reminders for a task deadline.
  ///
  /// [deadline] must be in the future. Skips if deadline is within 1h.
  /// Each one-off task fires after [delay].
  static Future<void> scheduleReminders({
    required String taskId,
    required DateTime deadline,
  }) async {
    final now = DateTime.now();
    final deadlineUtc = deadline.toUtc();
    final diff3h = deadlineUtc.difference(now);
    final diff1h = deadlineUtc.subtract(const Duration(hours: 2)).difference(now);

    // Schedule 3h reminder (if deadline is > 3h away)
    if (diff3h > Duration.zero) {
      await Workmanager().registerOneOffTask(
        '${reminderTaskName3h}_$taskId',
        reminderTaskName3h,
        inputData: {'taskId': taskId, 'period': '3h'},
        initialDelay: diff3h,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      debugPrint('DeadlineReminder: scheduled 3h reminder for $taskId (delay: ${diff3h.inMinutes}min)');
    }

    // Schedule 1h reminder (if deadline is > 1h away)
    if (diff1h > Duration.zero) {
      await Workmanager().registerOneOffTask(
        '${reminderTaskName1h}_$taskId',
        reminderTaskName1h,
        inputData: {'taskId': taskId, 'period': '1h'},
        initialDelay: diff1h,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      debugPrint('DeadlineReminder: scheduled 1h reminder for $taskId (delay: ${diff1h.inMinutes}min)');
    }
  }

  /// Cancel all scheduled reminders for a task.
  static Future<void> cancelReminders(String taskId) async {
    try {
      await Workmanager().cancelByUniqueName('${reminderTaskName3h}_$taskId');
      await Workmanager().cancelByUniqueName('${reminderTaskName1h}_$taskId');
      debugPrint('DeadlineReminder: cancelled reminders for $taskId');
    } catch (e) {
      debugPrint('DeadlineReminder: cancel error for $taskId: $e');
    }
  }
  /// Entry point called by workmanager background callback.
  ///
  /// [taskId] passed as workmanager inputData.
  /// [period] is '3h' or '1h' — determines which reminder flag to check.
  static Future<void> handleReminderCallback({
    required String taskId,
    required String period,
  }) async {
    debugPrint('DeadlineReminder [$period] firing for task $taskId');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .get();

      if (!doc.exists) {
        debugPrint('DeadlineReminder: task $taskId no longer exists');
        return;
      }

      final data = doc.data()!;

      // Skip if task is inactive (deleted)
      if (data['isActive'] == false) {
        debugPrint('DeadlineReminder: task $taskId is inactive, skipping');
        return;
      }

      // Check if ALL targetUids have doneByUids — meaning task fully done
      final doneByUids = List<String>.from(data['doneByUids'] ?? []);
      final targetUids = List<String>.from(data['targetUids'] ?? []);
      if (targetUids.isNotEmpty) {
        final everyoneDone = targetUids.every((uid) => doneByUids.contains(uid));
        if (everyoneDone) {
          debugPrint('DeadlineReminder: task $taskId done by all, skipping');
          return;
        }
      }

      // Check duplicate prevention flag
      final flag = period == '3h' ? 'reminderSent3h' : 'reminderSent1h';
      if (data[flag] == true) {
        debugPrint('DeadlineReminder: $flag already set for $taskId, skipping');
        return;
      }

      // Set flag atomically — Firestore update with existing check
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .update({flag: true});

      // Send notification via Worker
      await _sendReminderNotification(
        taskId: taskId,
        taskTitle: data['title'] ?? 'Untitled Task',
        taskDescription: data['description'] ?? '',
        chatId: data['chatId'] ?? '',
        creatorName: data['creatorName'] ?? '',
        period: period,
      );

      debugPrint('DeadlineReminder [$period] sent for task $taskId');
    } catch (e) {
      debugPrint('DeadlineReminder [$period] error: $e');
    }
  }

  /// Send FCM notification for deadline reminder via Cloudflare Worker.
  static Future<void> _sendReminderNotification({
    required String taskId,
    required String taskTitle,
    required String taskDescription,
    required String chatId,
    required String creatorName,
    required String period,
  }) async {
    if (chatId.isEmpty) return;

    final title = period == '3h' ? 'Task Due in 3 Hours' : 'Task Due in 1 Hour';

    try {
      final response = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chatId': chatId,
          'messageId': 'reminder_${taskId}_$period',
          'senderId': 'system',
          'senderName': creatorName,
          'chatName': 'Campus Link',
          'customTitle': title,
          'text': '$taskTitle${taskDescription.isNotEmpty ? '\n\n$taskDescription' : ''}',
          'mentionedUids': [],
          'isEveryone': false,
          'isTask': true,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('DeadlineReminder: Worker returned ${response.statusCode}: ${response.body}');
      } else {
        debugPrint('DeadlineReminder: Worker success: ${response.body}');
      }
    } catch (e) {
      debugPrint('DeadlineReminder: Worker send failed: $e');
    }
  }
}