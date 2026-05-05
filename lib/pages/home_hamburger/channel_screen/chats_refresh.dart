import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/direct_message_item.dart';

/// Selective refresh logic for ChatsScreen.
///
/// Pull-to-refresh should NOT tear down and re-setup Firestore streams
/// (they already provide real-time sync). Instead, this refreshes:
///   1. User role from Firestore
///   2. Cached users list (for search)
///   3. Fixes any DM docs still showing 'Unknown' names by patching them
///
/// Called by RefreshIndicator.onRefresh — keeps raw data out of widget code.
class ChatsRefresher {
  final FirebaseFirestore firestore;
  final Function(String) onRoleFetched;
  final Function(List<Map<String, dynamic>>) onUsersFetched;
  final List<DirectMessageItem> directMessages;
  final String? currentUserId;

  ChatsRefresher({
    required this.firestore,
    required this.onRoleFetched,
    required this.onUsersFetched,
    required this.directMessages,
    required this.currentUserId,
  });

  /// Selective refresh — only fetches what might be stale.
  Future<void> refresh() async {
    final uid = currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 1 & 2: Role + user cache in parallel (lightweight reads)
    final results = await Future.wait([
      firestore.collection('users').doc(uid).get(),
      firestore.collection('users').get(),
    ]);

    final userDoc = results[0] as DocumentSnapshot;
    final usersSnap = results[1] as QuerySnapshot;

    // Update role
    final role = userDoc.exists
        ? (userDoc['role'] ?? 'student')
        : 'student';
    onRoleFetched(role);

    // Update cached users
    final cached = usersSnap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final email = data['email'] ?? '';
      final namePart = email.split('@').first;
      final displayName = namePart
          .split('.')
          .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
          .join(' ');
      return {
        'uid': doc.id,
        'email': email,
        'role': data['role'] ?? 'student',
        'displayName': displayName,
      };
    }).toList();
    onUsersFetched(cached);

    // 3: Patch DMs still showing 'Unknown' names
    await _fixUnknownNames(uid);
  }

  Future<void> _fixUnknownNames(String uid) async {
    final unknowns = directMessages.where(
      (dm) => dm.otherParticipantName == 'Unknown' || dm.otherParticipantRole == null,
    );

    for (final dm in unknowns) {
      try {
        final otherUid = dm.otherParticipantUid;
        if (otherUid.isEmpty) continue;

        final userDoc = await firestore.collection('users').doc(otherUid).get();
        if (!userDoc.exists) continue;

        final data = userDoc.data() as Map<String, dynamic>;
        final email = data['email'] ?? '';
        final namePart = email.split('@').first;
        final displayName = namePart
            .split('.')
            .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
            .join(' ');
        final role = data['role'] ?? 'student';

        final dmRef = firestore.collection('direct_messages').doc(dm.id);
        final updates = <String, dynamic>{
          'participantNames.$otherUid': displayName,
          'participantRoles.$otherUid': role,
        };
        await dmRef.update(updates);
      } catch (e) {
        debugPrint('Error patching DM ${dm.id}: $e');
      }
    }
  }
}
