import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/direct_message_item.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/direct_message_tile.dart';

void main() {
  testWidgets('DirectMessageTile shows grey background when isArchived is true', (WidgetTester tester) async {
    final chat = DirectMessageItem(
      id: 'dm1',
      otherParticipantName: 'Alice',
      otherParticipantUid: 'uid2',
      lastMessage: 'Hello',
      time: 'Now',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DirectMessageTile(
          chat: chat,
          onTap: () {},
          isArchived: true,
        ),
      ),
    ));

    final container = tester.widget<Container>(find.ancestor(
      of: find.byType(ListTile),
      matching: find.byType(Container),
    ));
    expect(container.decoration, isA<BoxDecoration>());
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, isNotNull);
  });

  testWidgets('DirectMessageTile uses default background when isArchived is false', (WidgetTester tester) async {
    final chat = DirectMessageItem(
      id: 'dm1',
      otherParticipantName: 'Alice',
      otherParticipantUid: 'uid2',
      lastMessage: 'Hello',
      time: 'Now',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DirectMessageTile(
          chat: chat,
          onTap: () {},
          isArchived: false,
        ),
      ),
    ));

    final container = tester.widget<Container>(find.ancestor(
      of: find.byType(ListTile),
      matching: find.byType(Container),
    ));
    final decoration = container.decoration as BoxDecoration?;
    expect(decoration?.color, isNull);
  });
}
