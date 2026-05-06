# DM Archive Feature - Design Spec

Date: 2026-05-06

## Overview

Add the ability to archive direct messages so the DM list doesn't get too long. Archived DMs are hidden in a collapsible section and can be unarchived. New messages in archived DMs auto-unarchive them.

## Architecture & Data Model

### Firestore Changes

`direct_messages` collection docs gain a new `archivedBy` array field (default: `[]`).

- When user archives: `FieldValue.arrayUnion([userId])`
- When user unarchives: `FieldValue.arrayRemove([userId])`
- Auto-unarchive on new message: remove sender UID from `archivedBy`

### DirectMessageItem Changes

`lib/pages/home_hamburger/channel_screen/direct_message_item.dart`:

- Add `final bool isArchivedByMe;` field
- In `fromFirestore()`: read `archivedBy` array, check if `currentUserId` is in it
- Set `isArchivedByMe = (data['archivedBy'] as List?)?.contains(currentUserId) ?? false`

### ChatsScreen Changes

`lib/pages/home_hamburger/channel_screen/chats_screen.dart`:

- Single Firestore query unchanged: `where('members', arrayContains: user.uid)`
- Client-side split into `_activeDMs` and `_archivedDMs` based on `isArchivedByMe`
- Add `_showArchived` boolean state (default: `false`)

## UI Changes

### ChatsScreen Body (ListView order)

1. Group Chats
2. Create Group Chat Button (Faculty only)
3. Divider
4. Direct Messages Header
5. Active DMs list
6. Archived Header (collapsed by default, shows count)
7. Archived DMs list (shown when expanded)
8. Search Results (when searching)

### Archived Section Header

- Text: "Archived (X)" where X = archived count
- Trailing chevron icon (up/down based on `_showArchived`)
- Tappable to toggle `_showArchived`
- Only shown when there are archived DMs

### Archived DM Tiles

- Use `DirectMessageTile` with `isArchived: true` flag
- Light grey background (`Colors.grey[100]`) to visually distinguish
- Small archive icon overlay on leading avatar

### Long-Press Actions

- Active DM long-press → context menu with "Archive" option
- Archived DM long-press → context menu with "Unarchive" option

## Auto-Unarchive Logic

In `lib/pages/home_hamburger/channel_screen/individual_chat_screen.dart` message send handler:

- When a message is sent, check if `archivedBy` contains the sender's UID
- If yes, call `update({ 'archivedBy': FieldValue.arrayRemove([senderUid]) })` before sending
- Real-time stream updates move it back to active list automatically

## Edge Cases

- Archive a DM → disappears from active list, appears in archived section
- Unarchive → moves back to active list
- New message in archived DM → auto-unarchives, user sees it in active list with unread count
- Reinstall app → `archivedBy` preserved in Firestore, archives persist
- Search mode → archived DMs not shown in search results (only active DMs + new contact search)

## Files to Modify

1. `lib/pages/home_hamburger/channel_screen/direct_message_item.dart` — add `isArchivedByMe`, update `fromFirestore()`
2. `lib/pages/home_hamburger/channel_screen/direct_message_tile.dart` — add `isArchived` flag, grey background
3. `lib/pages/home_hamburger/channel_screen/chats_screen.dart` — split DMs, archived section, long-press menu, archive/unarchive handlers
4. `lib/pages/home_hamburger/channel_screen/individual_chat_screen.dart` — auto-unarchive on message send

## Out of Scope

- Archive for group chats (DMs only for now)
- Bulk archive/unarchive
- Archive notifications or reminders
