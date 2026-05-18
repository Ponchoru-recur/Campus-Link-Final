import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Service managing pinned notices in group chats and DMs.
///
/// Uses subcollection `pinnedNotices` under:
///   group_chats/{chatId}/pinnedNotices/{noticeId}
///   direct_messages/{conversationId}/pinnedNotices/{noticeId}
class PinnedNoticeService {
  static final PinnedNoticeService instance = PinnedNoticeService._();
  PinnedNoticeService._();

  static const String _workerUrl = 'https://dawn-rice-bc73.sam-varela.workers.dev';

  CollectionReference _ref(String collectionType, String chatId) {
    if (collectionType == 'group') {
      return FirebaseFirestore.instance
          .collection('group_chats')
          .doc(chatId)
          .collection('pinnedNotices');
    } else {
      return FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(chatId)
          .collection('pinnedNotices');
    }
  }

  Stream<QuerySnapshot> getActivePinsStream(
      String collectionType, String chatId) {
    return _ref(collectionType, chatId)
        .where('isArchived', isEqualTo: false)
        .snapshots();
  }

  /// Count current active pins for limit checking.
  Future<int> _countActivePins(
      String collectionType, String chatId) async {
    final snapshot = await _ref(collectionType, chatId)
        .where('isArchived', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Create a new pinned notice. Throws if 5 already active.
  Future<void> create({
    required String collectionType,
    required String chatId,
    required String title,
    required String description,
    String? link,
    required String chatName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final currentCount = await _countActivePins(collectionType, chatId);
    if (currentCount >= 5) {
      throw Exception('Maximum of 5 pinned notices reached');
    }

    final email = user.email ?? '';
    final userName = email.isEmpty
        ? 'Unknown'
        : email
            .split('@')
            .first
            .replaceAll('.', ' ')
            .split(' ')
            .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
            .join(' ');

    await _ref(collectionType, chatId).add({
      'title': title,
      'description': description,
      'link': link,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'createdByName': userName,
      'isArchived': false,
      'order': currentCount, // append at end
      'editedAt': null,
    });

    // Send push notification (fire-and-forget)
    _sendCreateNotification(chatName: chatName, title: title);
  }

  Future<void> update({
    required String collectionType,
    required String chatId,
    required String noticeId,
    required String title,
    required String description,
    String? link,
  }) async {
    await _ref(collectionType, chatId).doc(noticeId).update({
      'title': title,
      'description': description,
      'link': link,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Archive a pinned notice (soft delete).
  Future<void> archive({
    required String collectionType,
    required String chatId,
    required String noticeId,
  }) async {
    await _ref(collectionType, chatId).doc(noticeId).update({
      'isArchived': true,
    });
  }

  /// Move a notice up (lower order value). Swaps order with the one above.
  Future<void> moveUp({
    required String collectionType,
    required String chatId,
    required String noticeId,
    required int currentOrder,
  }) async {
    if (currentOrder <= 0) return;
    final snapshot = await _ref(collectionType, chatId)
        .where('isArchived', isEqualTo: false)
        .where('order', isEqualTo: currentOrder - 1)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;
    final aboveDoc = snapshot.docs.first;

    final batch = FirebaseFirestore.instance.batch();
    batch.update(_ref(collectionType, chatId).doc(noticeId), {
      'order': currentOrder - 1,
    });
    batch.update(_ref(collectionType, chatId).doc(aboveDoc.id), {
      'order': currentOrder,
    });
    await batch.commit();
  }

  /// Move a notice down (higher order value). Swaps order with the one below.
  Future<void> moveDown({
    required String collectionType,
    required String chatId,
    required String noticeId,
    required int currentOrder,
  }) async {
    final snapshot = await _ref(collectionType, chatId)
        .where('isArchived', isEqualTo: false)
        .where('order', isEqualTo: currentOrder + 1)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;
    final belowDoc = snapshot.docs.first;

    final batch = FirebaseFirestore.instance.batch();
    batch.update(_ref(collectionType, chatId).doc(noticeId), {
      'order': currentOrder + 1,
    });
    batch.update(_ref(collectionType, chatId).doc(belowDoc.id), {
      'order': currentOrder,
    });
    await batch.commit();
  }

  Future<void> _sendCreateNotification({
    required String chatName,
    required String title,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      await http.post(
        Uri.parse('$_workerUrl/send-notification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': '📌 New Pinned Notice in $chatName',
          'body': title,
        }),
      );
    } catch (e) {
      debugPrint('Failed to send pinned notice notification: $e');
    }
  }
}