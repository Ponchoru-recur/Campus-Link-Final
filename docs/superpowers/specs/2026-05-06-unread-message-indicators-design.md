# Unread Message Indicators Design Spec

**Date:** 2026-05-06
**Status:** Approved

## Overview

Add visual unread message indicators (bold text + accent color + counter badge) to group chats and direct messages in the Chats list. Archived DMs should follow the same rules, with the archived header showing total unread count.

## Selected Design Choices

| Decision | Choice |
|----------|--------|
| Visual style | C — Accent Color + Bold (WhatsApp style: `AppColors.primary` + `FontWeight.w700/w600`) |
| Archived header | Unread count only — `Archived (X unread)` |
| Group chat tracking | Add per-user `unreadCount` map (mirrors DM structure) |
| Archived section position | Above Direct Messages (between Group Chats and DMs for easy access) |

## Firestore Schema Changes

### group_chats/{chatId}

Change `unreadCount` from integer to per-user map:

```
// Before:
unreadCount: 0

// After:
unreadCount: { uid1: 0, uid2: 3, uid3: 0 }
```

### direct_messages/{chatId}

No schema change needed — already uses per-user map.

## Data Flow

### Write Path (increment unread)

**Group chats** — when a message is sent in `GroupChatScreen._sendMessage()`:
1. After adding message to `group_chats/{chatId}/messages`
2. Read current `unreadCount` map from `group_chats/{chatId}`
3. For each member in `members` array except sender: increment `unreadCount[memberUid]`
4. Update `group_chats/{chatId}` with updated `unreadCount` map

**DMs** — already handled by existing code.

### Read Path (reset unread)

**Group chats** — when user opens chat in `GroupChatScreen`:
1. On `initState` or when screen opens: set `unreadCount[uid] = 0`
2. Update `group_chats/{chatId}` document

**DMs** — already handled by `IndividualChatScreen._markMessagesAsRead()`.

## Stream Updates in chats_screen.dart

### _setupGroupChatsStream()

Parse `unreadCount` map from Firestore, extract current user's count:

```dart
unreadCount: (data['unreadCount'] is Map)
    ? (data['unreadCount'][user.uid] ?? 0)
    : 0,
```

### _setupDirectMessagesStream()

No change needed — already correctly parses per-user `unreadCount`.

## UI Changes

### GroupChatTile (lib/pages/home_hamburger/channel_screen/group_chat_tile.dart)

When `chat.unreadCount > 0`:
- `chat.name` → `FontWeight.w700` + `color: AppColors.primary`
- `chat.lastMessage` → `FontWeight.w600` + `color: AppColors.primary`
- Unread badge (already exists at `chat.unreadCount > 0`) — no change

When `chat.unreadCount == 0`: current styling unchanged.

### DirectMessageTile (lib/pages/home_hamburger/channel_screen/direct_message_tile.dart)

When `chat.unreadCount > 0`:
- `chat.otherParticipantName` → `FontWeight.w700` + `color: AppColors.primary`
- `chat.lastMessage` → `FontWeight.w600` + `color: AppColors.primary`
- Unread badge (already exists) — no change

When `chat.unreadCount == 0`: current styling unchanged.

**Archived DMs**: Same `DirectMessageTile` widget is used — same bold/accent rules apply automatically.

### Archived Section Position (chats_screen.dart)

Move the archived section from bottom (after DMs) to **above Direct Messages** for better accessibility:

**New order in the ListView:**
1. Search bar
2. Group Chats list
3. Archived Header + Archived DMs list (collapsible, `showArchived` toggle)
4. Direct Messages list

**Implementation:** In the `ListView` builder, move `_buildArchivedHeader()` and archived DMs mapping to before the `_directMessages.map()` section.

### Archived Header (_buildArchivedHeader() in chats_screen.dart)

Change from:
```dart
'Archived (${_archivedDMs.length})'
```

To:
```dart
'Archived (${_totalArchivedUnread} unread)'
```

Calculate `_totalArchivedUnread`:
```dart
int get _totalArchivedUnread => _archivedDMs.fold(0, (sum, dm) => sum + dm.unreadCount);
```

## Files to Modify

1. `lib/pages/home_hamburger/channel_screen/group_chat_tile.dart` — bold + accent color for unread
2. `lib/pages/home_hamburger/channel_screen/direct_message_tile.dart` — bold + accent color for unread
3. `lib/pages/home_hamburger/channel_screen/chats_screen.dart` — parse group chat unreadCount, update archived header, reset unread on open
4. `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` — increment unreadCount on send, reset on open
5. Firestore data migration — existing group chats need `unreadCount` converted from int to per-user map

## Testing

- Send message to group chat as User A → User B sees bold name + badge count
- Open group chat as User B → unreadCount resets to 0, bold removed
- Send DM as User A → User B sees bold name + badge count
- Open archived DM with unread → bold appears, archived header shows correct total
- Archived header shows `Archived (X unread)` with correct sum
