# DM Archive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ability to archive direct messages with `archivedBy` Firestore field, expandable archived section in ChatsScreen, and auto-unarchive on new messages.

**Architecture:** Add `archivedBy` array to `direct_messages` docs. Client-side splits DMs into active/archived lists. Long-press to archive/unarchive. Auto-unarchive when new message sent to archived DM.

**Tech Stack:** Flutter, Firestore, Dart

---

### Task 1: Add `isArchivedByMe` to DirectMessageItem

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/direct_message_item.dart`
- Test: `test/direct_message_item_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// In test/direct_message_item_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/direct_message_item_test.dart`
Expected: FAIL — `isArchivedByMe` does not exist on `DirectMessageItem`

- [ ] **Step 3: Add field and update fromFirestore**

```dart
// In lib/pages/home_hamburger/channel_screen/direct_message_item.dart
// Add field to class (after line 21):
final bool isArchivedByMe;

// Update constructor (add to constructor and initializer):
const DirectMessageItem({
  required this.id,
  required this.otherParticipantName,
  required this.otherParticipantUid,
  this.otherParticipantRole,
  required this.lastMessage,
  required this.time,
  this.unreadCount = 0,
  this.isArchivedByMe = false,
});

// In fromFirestore factory, after reading otherRole (around line 52), add:
final archivedBy = List<String>.from(data['archivedBy'] ?? []);
final isArchived = archivedBy.contains(currentUserId);

// Update the return statement to include:
return DirectMessageItem(
  id: doc.id,
  otherParticipantName: otherName,
  otherParticipantUid: otherUid,
  otherParticipantRole: otherRole,
  lastMessage: data['lastMessage'] ?? '',
  time: data['time'] ?? 'Now',
  unreadCount: (data['unreadCount'] is Map)
      ? (data['unreadCount'][currentUserId] ?? 0)
      : 0,
  isArchivedByMe: isArchived,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/direct_message_item_test.dart`
Expected: PASS — all 3 tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/direct_message_item.dart test/direct_message_item_test.dart
git commit -m "feat: add isArchivedByMe to DirectMessageItem with tests"
```

---

### Task 2: Modify DirectMessageTile for archived state

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/direct_message_tile.dart`
- Test: `test/direct_message_tile_test.dart` (new file)

- [ ] **Step 1: Write the failing test**

```dart
// In test/direct_message_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/direct_message_item.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/direct_message_tile.dart';
import 'package:luminescence/themes/app_colors.dart';

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/direct_message_tile_test.dart`
Expected: FAIL — `isArchived` parameter does not exist on `DirectMessageTile`

- [ ] **Step 3: Add isArchived parameter with grey background**

```dart
// In lib/pages/home_hamburger/channel_screen/direct_message_tile.dart

// Update constructor (around line 10):
const DirectMessageTile({
  super.key,
  required this.chat,
  required this.onTap,
  this.isArchived = false,
});

final bool isArchived;

// In build(), update the Container decoration (around line 25):
Container(
  decoration: BoxDecoration(
    color: isArchived ? Colors.grey[100] : null,
    border: isFaculty
        ? const Border(
            left: BorderSide(
              color: AppColors.instructorPurple,
              width: 3,
            ),
          )
        : null,
  ),
  // ... rest of the widget
)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/direct_message_tile_test.dart`
Expected: PASS — both tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/direct_message_tile.dart test/direct_message_tile_test.dart
git commit -m "feat: add isArchived flag to DirectMessageTile with grey background"
```

---

### Task 3: Add archivedBy split logic to ChatsScreen state

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/chats_screen.dart`

- [ ] **Step 1: Add _archivedDMs list and _showArchived boolean to state**

In `chats_screen.dart`, add to `_ChatsScreenState` class (after line 37):
```dart
List<DirectMessageItem> _archivedDMs = [];
bool _showArchived = false;
```

- [ ] **Step 2: Update _setupDirectMessagesStream to split active/archived**

Replace the `_setupDirectMessagesStream` method body (lines 200-223) with:
```dart
void _setupDirectMessagesStream() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || _isDisposed) return;

  _directMessagesSubscription = FirebaseFirestore.instance
      .collection('direct_messages')
      .where('members', arrayContains: user.uid)
      .snapshots()
      .listen(
    (snapshot) {
      if (_isDisposed || !mounted) return;
      final allDMs = snapshot.docs.map((doc) {
        return DirectMessageItem.fromFirestore(doc, user.uid);
      }).toList();

      setState(() {
        _directMessages = allDMs.where((dm) => !dm.isArchivedByMe).toList();
        _archivedDMs = allDMs.where((dm) => dm.isArchivedByMe).toList();
      });
    },
    onError: (e) {
      if (!_isDisposed) {
        debugPrint('Error in DM stream: $e');
      }
    },
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/chats_screen.dart
git commit -m "feat: split DMs into active and archived lists in ChatsScreen"
```

---

### Task 4: Add archived section UI to ChatsScreen

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/chats_screen.dart`

- [ ] **Step 1: Add archived section header widget method**

Add to `_ChatsScreenState` class (before the build method):
```dart
Widget _buildArchivedHeader() {
  if (_archivedDMs.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: InkWell(
      onTap: () {
        setState(() {
          _showArchived = !_showArchived;
        });
      },
      child: Row(
        children: [
          Text(
            'Archived (${_archivedDMs.length})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            _showArchived ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: Add archived DMs list rendering in build method**

In the `build()` method's `ListView` children, add after the active DMs section and before search results (after line 730 area):
```dart
// ── Archived Header ──
_buildArchivedHeader(),
// ── Archived DMs List ──
if (_showArchived)
  ..._archivedDMs.map(
    (dm) => DirectMessageTile(
      chat: dm,
      onTap: () => _openDirectMessage(dm),
      isArchived: true,
    ),
  ),
```

- [ ] **Step 3: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/chats_screen.dart
git commit -m "feat: add expandable archived section to ChatsScreen"
```

---

### Task 5: Add long-press archive/unarchive to DM tiles

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/direct_message_tile.dart`
- Modify: `lib/pages/home_hamburger/channel_screen/chats_screen.dart`

- [ ] **Step 1: Add onLongPress callback to DirectMessageTile**

In `direct_message_tile.dart`:
```dart
// Add to constructor:
final VoidCallback? onLongPress;

const DirectMessageTile({
  super.key,
  required this.chat,
  required this.onTap,
  this.isArchived = false,
  this.onLongPress,
});

// In the ListTile widget inside build(), add:
onLongPress: onLongPress,
```

- [ ] **Step 2: Add archive/unarchive methods to ChatsScreen**

Add to `_ChatsScreenState` class:
```dart
Future<void> _archiveDM(DirectMessageItem dm) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('direct_messages')
        .doc(dm.id)
        .update({
      'archivedBy': FieldValue.arrayUnion([user.uid]),
    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to archive: $e')),
      );
    }
  }
}

Future<void> _unarchiveDM(DirectMessageItem dm) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('direct_messages')
        .doc(dm.id)
        .update({
      'archivedBy': FieldValue.arrayRemove([user.uid]),
    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unarchive: $e')),
      );
    }
  }
}
```

- [ ] **Step 3: Wire long-press in build method for active DMs**

In the active DMs `map` (around line 714):
```dart
..._directMessages.map(
  (dm) => DirectMessageTile(
    chat: dm,
    onTap: () => _openDirectMessage(dm),
    onLongPress: () => _showArchiveDialog(dm, isArchived: false),
  ),
),
```

- [ ] **Step 4: Wire long-press in archived section for archived DMs**

In the archived DMs `map` (from Task 4):
```dart
..._archivedDMs.map(
  (dm) => DirectMessageTile(
    chat: dm,
    onTap: () => _openDirectMessage(dm),
    isArchived: true,
    onLongPress: () => _showArchiveDialog(dm, isArchived: true),
  ),
),
```

- [ ] **Step 5: Add _showArchiveDialog method**

```dart
Future<void> _showArchiveDialog(DirectMessageItem dm, {required bool isArchived}) async {
  final action = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(isArchived ? 'Unarchive Chat' : 'Archive Chat'),
      content: Text(
        isArchived
            ? 'Move this conversation back to your active messages?'
            : 'Archive this conversation? It will be moved to the Archived section.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, isArchived ? 'unarchive' : 'archive'),
          child: Text(
            isArchived ? 'Unarchive' : 'Archive',
            style: TextStyle(
              color: isArchived ? AppColors.primary : AppColors.urgentRed,
            ),
          ),
        ),
      ],
    ),
  );

  if (action == 'archive') {
    await _archiveDM(dm);
  } else if (action == 'unarchive') {
    await _unarchiveDM(dm);
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/direct_message_tile.dart lib/pages/home_hamburger/channel_screen/chats_screen.dart
git commit -m "feat: add long-press archive/unarchive for DMs"
```

---

### Task 6: Add auto-unarchive on new message in IndividualChatScreen

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/individual_chat_screen.dart`

- [ ] **Step 1: Update _sendMessage to auto-unarchive**

In `individual_chat_screen.dart`, replace the `_sendMessage` method (lines 166-213) with:
```dart
Future<void> _sendMessage() async {
  final text = _controller.text.trim();
  if (text.isEmpty) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final email = user.email ?? '';
  final senderName = email.isEmpty
      ? 'Me'
      : email
          .split('@')
          .first
          .replaceAll('.', ' ')
          .split(' ')
          .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
          .join(' ');

  _controller.clear();

  try {
    final firestore = FirebaseFirestore.instance;
    final dmRef = firestore.collection('direct_messages').doc(_chatId);

    // Auto-unarchive: remove sender from archivedBy if present
    await dmRef.update({
      'archivedBy': FieldValue.arrayRemove([user.uid]),
    });

    final messagesRef = dmRef.collection('messages');

    await messagesRef.add({
      'senderId': user.uid,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'readBy': [user.uid],
    });

    await dmRef.update({
      'lastMessage': text,
      'time': 'Now',
    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/individual_chat_screen.dart
git commit -m "feat: auto-unarchive DM on new message send"
```

---

### Task 7: Run all tests and verify nothing is broken

**Files:**
- Test: `test/chats_screen_test.dart`
- Test: `test/individual_chat_screen_test.dart`
- Test: `test/direct_message_item_test.dart`
- Test: `test/direct_message_tile_test.dart`

- [ ] **Step 1: Run all tests**

Run: `flutter test`
Expected: All tests pass (new + existing)

- [ ] **Step 2: Commit if any test files were updated**

```bash
git add test/
git commit -m "test: verify all tests pass after DM archive implementation"
```

---

### Task 8: Run flutter analyze and fix any issues

- [ ] **Step 1: Run analyzer**

Run: `flutter analyze`
Expected: No errors (warnings acceptable)

- [ ] **Step 2: Fix any errors if found**

Edit files as needed.

- [ ] **Step 3: Commit fixes if any**

```bash
git add -A
git commit -m "fix: address analyzer warnings after DM archive implementation"
```
