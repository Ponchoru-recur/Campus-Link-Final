import 'package:flutter_test/flutter_test.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message.dart';

void main() {
  group('Mention highlighting', () {
    const currentUid = 'currentUser';
    final baseMessage = Message(
      id: 'msg1',
      senderId: 'otherUser',
      senderName: 'John Doe',
      text: 'Hello @Current User',
      timestamp: DateTime.now(),
      isMe: false,
      mentionedUids: ['currentUser'],
    );

    test('isMentioned returns true when currentUid is in mentionedUids', () {
      final isMentioned = baseMessage.isMentioned(currentUid);
      expect(isMentioned, isTrue);
    });

    test('isMentioned returns false for non-mentioned user', () {
      const nonMentioned = 'otherUser';
      final isMentioned = baseMessage.isMentioned(nonMentioned);
      expect(isMentioned, isFalse);
    });

    test('empty mentionedUids means no highlight', () {
      final emptyMessage = Message(
        id: 'msg2',
        senderId: 'otherUser',
        senderName: 'Jane Smith',
        text: 'Just a normal message',
        timestamp: DateTime.now(),
        isMe: false,
      );
      expect(emptyMessage.mentionedUids, isEmpty);
    });

    test('messages with mentions show @badge for non-mentioned users', () {
      final hasMentions = baseMessage.mentionedUids.isNotEmpty;
      final isMentioned = baseMessage.isMentioned('unrelatedUser');
      // Non-mentioned user sees message with mentions -> show badge
      expect(hasMentions, isTrue);
      expect(isMentioned, isFalse); // this user is not the mentioned one
      // Contract: badge shown when hasMentions && !isMentioned
    });

    test('pinnedUntil field is null by default on regular messages', () {
      expect(baseMessage.pinnedUntil, isNull);
    });

    test('isEveryone returns true when text contains @everyone', () {
      final everyoneMsg = Message(
        id: 'msg3',
        senderId: 'facultyUser',
        senderName: 'Prof. Smith',
        text: '@everyone please check the announcement',
        timestamp: DateTime.now(),
        isMe: false,
        mentionedUids: [],
      );
      expect(everyoneMsg.isEveryone, isTrue);
    });

    test('isEveryone returns false when text has no @everyone', () {
      expect(baseMessage.isEveryone, isFalse);
    });
  });
}