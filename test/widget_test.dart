import 'package:flutter_test/flutter_test.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message.dart';

void main() {
  group('Message model — Phase 7 fields', () {
    test('Message can be created without mentions', () {
      final msg = Message(
        id: '1',
        senderId: 'user1',
        senderName: 'Test User',
        text: 'Hello',
        timestamp: DateTime.now(),
        isMe: false,
      );
      expect(msg.mentionedUids, isEmpty);
      expect(msg.pinnedUntil, isNull);
    });

    test('Message can be created with mentionedUids', () {
      final msg = Message(
        id: '2',
        senderId: 'user1',
        senderName: 'Test User',
        text: 'Hello @Other User',
        timestamp: DateTime.now(),
        isMe: false,
        mentionedUids: ['otherUser'],
      );
      expect(msg.mentionedUids.length, 1);
      expect(msg.mentionedUids.first, 'otherUser');
    });

    test('Message can be created with pinnedUntil', () {
      final pinnedUntil = DateTime.now().add(const Duration(hours: 24));
      final msg = Message(
        id: '3',
        senderId: 'user1',
        senderName: 'Test User',
        text: '@everyone announcement',
        timestamp: DateTime.now(),
        isMe: false,
        mentionedUids: [],
        pinnedUntil: pinnedUntil,
      );
      expect(msg.pinnedUntil, isNotNull);
      expect(msg.pinnedUntil!.difference(DateTime.now()).inHours, greaterThanOrEqualTo(23));
    });
  });
}