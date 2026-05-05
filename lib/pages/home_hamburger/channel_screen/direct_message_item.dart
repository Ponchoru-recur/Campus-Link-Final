import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_item.dart';

/// Represents a single direct message item in the Chats list.
/// Mirrors ChatItem but with other participant details instead of group name.
///
/// Firestore query pattern (per DB-03):
///   FirebaseFirestore.instance
///       .collection('direct_messages')
///       .where('members', arrayContains: user.uid)
///       .snapshots()
/// Same pattern as group_chats query in chats_screen.dart line 80.
class DirectMessageItem {
  final String id;
  final String otherParticipantName;
  final String otherParticipantUid;
  final String? otherParticipantRole; // 'faculty' or 'student'
  final String lastMessage;
  final String time;
  final int unreadCount;
  final ChatType type = ChatType.directMessage;

  const DirectMessageItem({
    required this.id,
    required this.otherParticipantName,
    required this.otherParticipantUid,
    this.otherParticipantRole,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
  });

  /// Factory to create from Firestore doc + current user UID.
  /// Parses 'members' array to find other participant,
  /// and 'unreadCount' Map for per-user tracking (D-03).
  factory DirectMessageItem.fromFirestore(
    DocumentSnapshot doc,
    String currentUserId,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final members = List<String>.from(data['members'] ?? []);
    final otherUid = members.firstWhere(
      (uid) => uid != currentUserId,
      orElse: () => '',
    );

    // Try participantRoles map first, then fall back to otherParticipantRole
    String? otherRole;
    if (data['participantRoles'] is Map) {
      otherRole = (data['participantRoles'] as Map)[otherUid] as String?;
    }
    otherRole ??= data['otherParticipantRole'] as String?;

    return DirectMessageItem(
      id: doc.id,
      otherParticipantName: data['otherParticipantName'] ?? 'Unknown',
      otherParticipantUid: otherUid,
      otherParticipantRole: otherRole,
      lastMessage: data['lastMessage'] ?? '',
      time: data['time'] ?? 'Now',
      unreadCount: (data['unreadCount'] is Map)
          ? (data['unreadCount'][currentUserId] ?? 0)
          : 0,
    );
  }
}
