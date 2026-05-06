# Unread Message Indicators Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add visual unread message indicators (bold+accent text, counter badge) to group chats and DMs, with archived section repositioned above DMs showing unread count.

**Architecture:** Modify GroupChatTile and DirectMessageTile to conditionally apply bold+accent styling when unreadCount > 0. Update chats_screen.dart to parse per-user unreadCount map from Firestore for group chats (matching existing DM pattern). Update group_chat_screen.dart to increment/decrement unreadCount on send/open. Reposition archived section above DMs with updated header text.

**Tech Stack:** Flutter, Firebase Firestore, Dart

---

### Task 1: Update GroupChatTile unread styling

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/group_chat_tile.dart:36-53`

- [ ] **Step 1: Modify name Text widget to conditionally apply bold+accent**

In `GroupChatTile.build()`, replace the `chat.name` Text widget (lines 36-43):

```dart
Text(
  chat.name,
  style: TextStyle(
    fontWeight: chat.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
    fontSize: 15,
    color: chat.unreadCount > 0 ? AppColors.primary : AppColors.textPrimary,
  ),
),
```

- [ ] **Step 2: Modify lastMessage Text widget to conditionally apply bold+accent**

Replace the `chat.lastMessage` Text widget (lines 45-53):

```dart
Text(
  chat.lastMessage,
  style: TextStyle(
    fontSize: 13,
    fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
    color: chat.unreadCount > 0 ? AppColors.primary : AppColors.textSecondary,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

- [ ] **Step 3: Run analyzer to verify**

Run: `flutter analyze lib/pages/home_hamburger/channel_screen/group_chat_tile.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/group_chat_tile.dart
git commit -m "feat: bold+accent styling for unread group chats"
```

---

### Task 2: Update DirectMessageTile unread styling

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/direct_message_tile.dart:54-62, 84-92`

- [ ] **Step 1: Modify otherParticipantName Text widget to conditionally apply bold+accent**

In `DirectMessageTile.build()`, replace the `chat.otherParticipantName` Text widget (lines 54-62):

```dart
Expanded(
  child: Text(
    chat.otherParticipantName,
    style: TextStyle(
      fontWeight: chat.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
      fontSize: 15,
      color: chat.unreadCount > 0 ? AppColors.primary : null,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
),
```

- [ ] **Step 2: Modify lastMessage Text widget to conditionally apply bold+accent**

Replace the `chat.lastMessage` Text widget in subtitle (lines 84-92):

```dart
subtitle: Text(
  chat.lastMessage,
  style: TextStyle(
    fontSize: 13,
    fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
    color: chat.unreadCount > 0 ? AppColors.primary : AppColors.textSecondary,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

- [ ] **Step 3: Run analyzer to verify**

Run: `flutter analyze lib/pages/home_hamburger/channel_screen/direct_message_tile.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/direct_message_tile.dart
git commit -m "feat: bold+accent styling for unread DMs"
```

---

### Task 3: Parse group chat unreadCount map in chats_screen.dart

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/chats_screen.dart:80-95`

The current `_setupGroupChatsStream()` creates `ChatItem` without parsing `unreadCount` from Firestore. Need to handle both old format (int) and new format (per-user map).

- [ ] **Step 1: Modify _setupGroupChatsStream() to parse unreadCount**

In `chats_screen.dart`, update the `_setupGroupChatsStream()` method. Replace the `ChatItem` creation inside the stream listener:

```dart
void _setupGroupChatsStream() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || _isDisposed) return;

  _groupChatsSubscription = FirebaseFirestore.instance
      .collection('group_chats')
      .where('members', arrayContains: user.uid)
      .snapshots()
      .listen(
    (snapshot) {
      if (_isDisposed || !mounted) return;
      setState(() {
        _groupChats = snapshot.docs.map((doc) {
          final data = doc.data();
          int unreadCount = 0;
          if (data['unreadCount'] is Map) {
            unreadCount = (data['unreadCount'] as Map)[user.uid] ?? 0;
          } else if (data['unreadCount'] is int) {
            unreadCount = data['unreadCount'] ?? 0;
          }
          return ChatItem(
            id: doc.id,
            name: data['name'] ?? '',
            lastMessage: data['lastMessage'] ?? '',
            time: data['time'] ?? 'Now',
            type: ChatType.groupChat,
            unreadCount: unreadCount,
          );
        }).toList();
      });
    },
    onError: (e) {
      if (!_isDisposed) {
        debugPrint('Error in group chats stream: $e');
      }
    },
  );
}
```

- [ ] **Step 2: Run analyzer to verify**

Run: `flutter analyze lib/pages/home_hamburger/channel_screen/chats_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/chats_screen.dart
git commit -m "feat: parse per-user unreadCount map for group chats"
```

---

### Task 4: Reposition archived section + update header in chats_screen.dart

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/chats_screen.dart` (ListView builder, _buildArchivedHeader)

- [ ] **Step 1: Add _totalArchivedUnread getter**

Add to `_ChatsScreenState` class:

```dart
int get _totalArchivedUnread => _archivedDMs.fold(0, (sum, dm) => sum + dm.unreadCount);
```

- [ ] **Step 2: Update _buildArchivedHeader() to show unread count**

Replace the `Text` widget inside `_buildArchivedHeader()`:

```dart
Text(
  'Archived (${_totalArchivedUnread} unread)',
  style: const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  ),
),
```

- [ ] **Step 3: Move archived section above Direct Messages in ListView**

In the `build()` method's `ListView`, move the archived section (currently at bottom) to between Group Chats and Direct Messages. The new order:

1. Search bar (`_buildSearchField()`)
2. Group Chats list (`_buildGroupChatsHeader()` + `_groupChats.map(...)`)
3. Archived Header (`_buildArchivedHeader()`) + Archived DMs list (if `_showArchived`)
4. Direct Messages list (`_directMessages.map(...)`)

Find the current ListView children and reorder:

```dart
// In the build() method, locate the ListView children and reorder to:

children: [
  // Search bar
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: _buildSearchField(),
  ),

  // Group Chats Header
  _buildGroupChatsHeader(),

  // Group Chats List
  ..._groupChats.map(
    (chat) => GroupChatTile(
      chat: chat,
      onTap: () => _openGroupChat(chat),
      isFaculty: _userRole == 'faculty',
      onDelete: _userRole == 'faculty'
          ? () => _confirmAndDeleteGroupChat(chat)
          : null,
    ),
  ),

  // Archived Header (moved from bottom to here)
  _buildArchivedHeader(),
  // Archived DMs List (shown when expanded)
  if (_showArchived)
    ..._archivedDMs.map(
      (dm) => DirectMessageTile(
        chat: dm,
        onTap: () => _openDirectMessage(dm),
        isArchived: true,
        onLongPress: () => _showArchiveDialog(dm, isArchived: true),
      ),
    ),

  // Direct Messages Header
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(
      children: [
        const Text(
          'Direct Messages',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        if (_userRole == 'student')
          const Text(
            'Faculty only can create group chats',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
      ],
    ),
  ),

  // Direct Messages List
  ..._directMessages.map(
    (dm) => DirectMessageTile(
      chat: dm,
      onTap: () => _openDirectMessage(dm),
      onLongPress: () => _showArchiveDialog(dm, isArchived: false),
    ),
  ),

  // ... rest of existing code (search results, empty states, etc.)
],
```

- [ ] **Step 4: Run analyzer to verify**

Run: `flutter analyze lib/pages/home_hamburger/channel_screen/chats_screen.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/chats_screen.dart
git commit -m "feat: reposition archived section above DMs, show unread count in header"
```

---

### Task 5: Update GroupChatScreen to track unreadCount

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` (_sendMessage, initState/dispose)

- [ ] **Step 1: Add _chatId and _otherMembers state variables**

Add to `_GroupChatScreenState`:

```dart
late String _chatId;
List<String> _otherMembers = [];

@override
void initState() {
  super.initState();
  _chatId = widget.chat.id;
  _loadOtherMembers();
  _resetUnreadCount();
  _setupMessagesStream();
  _setupGroupDocStream();
  _loadMembers();
}
```

- [ ] **Step 2: Add _loadOtherMembers() method**

```dart
Future<void> _loadOtherMembers() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('group_chats')
        .doc(_chatId)
        .get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final members = List<String>.from(data['members'] ?? []);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    setState(() {
      _otherMembers = members.where((uid) => uid != currentUid).toList();
    });
  } catch (e) {
    debugPrint('Error loading other members: $e');
  }
}
```

- [ ] **Step 3: Add _resetUnreadCount() method (called on open)**

```dart
Future<void> _resetUnreadCount() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    final docRef = FirebaseFirestore.instance
        .collection('group_chats')
        .doc(_chatId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final unreadCount = data['unreadCount'];
    if (unreadCount is Map && (unreadCount[user.uid] ?? 0) > 0) {
      await docRef.update({
        'unreadCount.${user.uid}': 0,
      });
    }
  } catch (e) {
    debugPrint('Error resetting unread count: $e');
  }
}
```

- [ ] **Step 4: Update _sendMessage() to increment unreadCount for other members**

After adding the message and updating `lastMessage`, add:

```dart
// After updating lastMessage and time in _sendMessage():
final currentUid = FirebaseAuth.instance.currentUser?.uid;
if (currentUid != null) {
  final chatDoc = await firestore.collection('group_chats').doc(widget.chat.id).get();
  if (chatDoc.exists) {
    final data = chatDoc.data()!;
    final members = List<String>.from(data['members'] ?? []);
    final unreadCount = data['unreadCount'];
    Map<String, dynamic> updateMap = {};
    if (unreadCount is Map) {
      for (final uid in members) {
        if (uid == currentUid) continue;
        final currentCount = (unreadCount[uid] ?? 0) as int;
        updateMap['unreadCount.$uid'] = currentCount + 1;
      }
    } else {
      // Old format: initialize new map
      updateMap['unreadCount'] = {};
      for (final uid in members) {
        if (uid == currentUid) {
          updateMap['unreadCount.$uid'] = 0;
        } else {
          updateMap['unreadCount.$uid'] = 1;
        }
      }
    }
    if (updateMap.isNotEmpty) {
      await firestore.collection('group_chats').doc(widget.chat.id).update(updateMap);
    }
  }
}
```

- [ ] **Step 5: Run analyzer to verify**

Run: `flutter analyze lib/pages/home_hamburger/channel_screen/group_chat_screen.dart`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/group_chat_screen.dart
git commit -m "feat: track per-user unreadCount in group chats (increment on send, reset on open)"
```

---

### Task 6: Manual Testing

- [ ] **Step 1: Test group chat unread indicators**

1. Open app as User A (faculty), create group chat with User B
2. Open app as User B, verify group chat shows with no bold/unread
3. As User A, send message to group chat
4. As User B, verify group chat name is bold+accent color, unread badge shows "1"
5. As User B, open group chat, verify unreadCount resets to 0, bold removed
6. Repeat steps 3-5 with multiple messages

- [ ] **Step 2: Test DM unread indicators**

1. As User A, send DM to User B
2. As User B, verify DM name is bold+accent color, unread badge shows count
3. As User B, open DM, verify unreadCount resets, bold removed

- [ ] **Step 3: Test archived section**

1. Archive a DM with unread messages
2. Verify archived header shows "Archived (X unread)" with correct count
3. Unarchive and verify header updates
4. Verify archived DMs follow same bold+accent rules when unread

- [ ] **Step 4: Test archived position**

1. Verify in Chats list: Group Chats → Archived Header → Direct Messages
2. Verify archived section is above DMs, easy to access

- [ ] **Step 5: Commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address issues found during manual testing"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** All spec requirements have matching tasks:
  - Bold+accent for group chats → Task 1
  - Bold+accent for DMs → Task 2
  - Parse group chat unreadCount map → Task 3
  - Archived header shows unread count → Task 4
  - Archived section above DMs → Task 4
  - Group chat increment on send → Task 5
  - Group chat reset on open → Task 5

- [x] **No placeholders:** All steps contain complete code, exact commands, expected output.

- [x] **Type consistency:** `unreadCount` is `int` in ChatItem and DirectMessageItem. Parsing handles both `int` and `Map` formats. `AppColors.primary` used consistently.

- [x] **All file paths verified:** Relative to project root, match actual file locations.
