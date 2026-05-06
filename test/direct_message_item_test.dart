import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/direct_message_item.dart';

void main() {
  test('fromFirestore sets isArchivedByMe true when current user in archivedBy', () {
    final data = {
      'members': ['user1', 'user2'],
      'archivedBy': ['user1'],
      'otherParticipantName': 'Alice',
      'lastMessage': 'Hello',
      'time': 'Now',
      'unreadCount': {'user1': 0, 'user2': 0},
    };

    final doc = _FakeDocSnapshot('dm1', data);
    final item = DirectMessageItem.fromFirestore(doc, 'user1');

    expect(item.isArchivedByMe, true);
  });

  test('fromFirestore sets isArchivedByMe false when current user not in archivedBy', () {
    final data = {
      'members': ['user1', 'user2'],
      'archivedBy': <String>[],
      'otherParticipantName': 'Alice',
      'lastMessage': 'Hello',
      'time': 'Now',
      'unreadCount': {'user1': 0, 'user2': 0},
    };

    final doc = _FakeDocSnapshot('dm1', data);
    final item = DirectMessageItem.fromFirestore(doc, 'user1');

    expect(item.isArchivedByMe, false);
  });

  test('fromFirestore sets isArchivedByMe false when archivedBy missing', () {
    final data = {
      'members': ['user1', 'user2'],
      'otherParticipantName': 'Alice',
      'lastMessage': 'Hello',
      'time': 'Now',
      'unreadCount': {'user1': 0, 'user2': 0},
    };

    final doc = _FakeDocSnapshot('dm1', data);
    final item = DirectMessageItem.fromFirestore(doc, 'user1');

    expect(item.isArchivedByMe, false);
  });
}

class _FakeDocSnapshot implements DocumentSnapshot {
  final String _id;
  final Map<String, dynamic> _data;

  _FakeDocSnapshot(this._id, this._data);

  @override
  Map<String, dynamic> data() => _data;

  @override
  String get id => _id;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
