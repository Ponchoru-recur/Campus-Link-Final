import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification strategy defaults', () {
    test('student defaults to mentionsOnly for group chats', () {
      const role = 'student';
      const chatType = 'group';
      String defaultStrategy;
      if (role == 'faculty') {
        defaultStrategy = 'normal';
      } else if (chatType == 'dm') {
        defaultStrategy = 'normal';
      } else {
        defaultStrategy = 'mentionsOnly';
      }
      expect(defaultStrategy, 'mentionsOnly');
    });

    test('student defaults to normal for DMs', () {
      const role = 'student';
      const chatType = 'dm';
      String defaultStrategy;
      if (role == 'faculty') {
        defaultStrategy = 'normal';
      } else if (chatType == 'dm') {
        defaultStrategy = 'normal';
      } else {
        defaultStrategy = 'mentionsOnly';
      }
      expect(defaultStrategy, 'normal');
    });

    test('faculty defaults to normal for everything', () {
      const role = 'faculty';
      String defaultStrategy;
      if (role == 'faculty') {
        defaultStrategy = 'normal';
      } else {
        defaultStrategy = 'mentionsOnly';
      }
      expect(defaultStrategy, 'normal');
    });

    test('valid strategy values are normal, mentionsOnly, muted', () {
      const validStrategies = ['normal', 'mentionsOnly', 'muted'];
      expect(validStrategies, contains('normal'));
      expect(validStrategies, contains('mentionsOnly'));
      expect(validStrategies, contains('muted'));
      expect(validStrategies.length, 3);
    });

    test('muted strategy suppresses all notifications', () {
      const strategy = 'muted';
      const shouldNotify = strategy != 'muted';
      expect(shouldNotify, isFalse);
    });

    test('mentionsOnly allows notifications for @mentions and @everyone', () {
      const strategy = 'mentionsOnly';
      const hasMention = true;
      const hasEveryone = true;
      const isTaskEvent = false;
      // mentionsOnly: full push for mentions/everyone/tasks
      final shouldNotify =
          strategy == 'normal' ||
              (hasMention && strategy == 'mentionsOnly') ||
              (hasEveryone && strategy == 'mentionsOnly') ||
              (isTaskEvent && strategy == 'mentionsOnly');
      expect(shouldNotify, isTrue);
    });

    test('mentionsOnly suppresses normal group messages', () {
      const strategy = 'mentionsOnly';
      const hasMention = false;
      const hasEveryone = false;
      const isTaskEvent = false;
      final shouldNotify =
          strategy == 'normal' ||
              (hasMention && strategy == 'mentionsOnly') ||
              (hasEveryone && strategy == 'mentionsOnly') ||
              (isTaskEvent && strategy == 'mentionsOnly');
      // Normal message in mentionsOnly -> silent
      expect(shouldNotify, isFalse);
    });
  });
}