---
phase: 07-mentions-pinned
plan: 04
wave: 2
tags: [mentions, pinned-bar, autocomplete, notification-toggle, group-chat-ui]
depends_on:
  - 07-01
provides:
  - @mention autocomplete overlay in _MessageInputBar
  - Pinned bar widget between AppBar and message list
  - Message bubble amber highlight for mentioned users
  - @mentions badge icon on non-mentioned user messages
  - Notification strategy toggle (normal/mentionsOnly/muted) in group info panel
  - Pinned messages Firestore stream subscription
affects:
  - lib/pages/home_hamburger/channel_screen/group_chat_screen.dart
tech-stack:
  added: []
  patterns:
    - OverlayEntry + CompositedTransformTarget/Follower for autocomplete dropdown
    - Firestore where('pinnedUntil', isGreaterThan: now) stream query
    - Conditional amber tint via mentionedUids.contains(currentUid)
    - StatefulBuilder for bottom sheet local state management
    - LayerLink for autocomplete positioning relative to input field
key-files:
  modified:
    - lib/pages/home_hamburger/channel_screen/group_chat_screen.dart
decisions:
  - "Autocomplete uses OverlayEntry for proper z-ordering above keyboard"
  - "Pinned bar shows only most recent pinned message (not carousel)"
  - "Pinned bar bg color fades: amber tint <1h, light amber <24h, grey >24h"
  - "Age label: 'Xm ago' for <1h, 'Xh ago' for <24h, 'yesterday' for >24h"
  - "Dismiss button sets pinnedUntil to null (message stays in stream)"
  - "Notification toggle uses RadioListTile in StatefulBuilder bottom sheet"
metrics:
  duration: ~20 min
  completed_date: 2026-05-17
  total_commits: 2
---

# Phase 7 Plan 4: @Mention Autocomplete, Pinned Bar, Highlight/@badge, Notification Toggle

**One-liner:** Implemented all user-facing @mention and pinned message UI — autocomplete overlay, bubble highlighting, @badge, collapsible pinned bar with visual fading, and per-user notification strategy toggle.

## Context

Plan 07-01 established the data layer (mentionedUids, pinnedUntil fields, member notification strategies). Plan 04 consumes all of those to build the visual interface users interact with. No new Firestore schema or model changes — all UI.

## Tasks Completed

### Task 1: @mention autocomplete overlay in _MessageInputBar

**Commit:** `46fd975`

Added autocomplete to `_MessageInputBar`:
- `_onTextChanged()` detects `@` + typed chars before cursor position
- Filters `_uidToName` entries by partial name match (excludes self)
- `_showOrUpdateMentionOverlay()` renders `OverlayEntry` with filtered member list
- `_selectMention()` replaces `@query` with `@DisplayName ` in controller text
- Uses `LayerLink` + `CompositedTransformTarget`/`Follower` for correct positioning

**Key implementation details:**
- Only triggers when `@` is preceded by space or at start of input
- Caps at 10 results, shows avatar initials + display name per row
- Overlay removed on dispose and after selection

**Files modified:** `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart`

### Task 2: Pinned bar widget with stream subscription

**Commit:** `760b345`

Added pinned messages infrastructure:
- `_setupPinnedStream()` — Firestore query: `where('pinnedUntil', isGreaterThan: Timestamp.now())` on messages subcollection
- `_unpinMessage()` — sets `pinnedUntil` to null (message stays in stream)
- `_PinnedBar` widget — collapsible bar between AppBar and message ListView
  - Shows: sender name, truncated message preview, age label, dismiss button
  - Visual fading: amber bg (<1h), light amber (<24h), grey (>24h dimmed)
  - Pin icon color matches age-based tint
- `_pinnedBarExpanded` state toggles bar collapse (visual only via conditional render)

**Files modified:** `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart`

### Task 3: Message bubble mention highlighting and @badge icon

**Commit:** `760b345` (same commit — part of larger changeset)

Updated `_MessageBubble`:
- Amber highlight (`Color(0xFFFFF3E0)`) on bubble bg when `mentionedUids.contains(currentUserUid)`
- `@mentions` badge with `Icons.alternate_email` + "mentions" label shown beside sender name for non-mentioned users when message has any mentions
- Badge uses amber-tinted container with small icon and text

### Task 4: Notification strategy toggle in group info panel

**Commit:** `760b345` (same commit)

Extended `_showGroupInfo()` bottom sheet:
- Three `RadioListTile` options: All notifications, Mentions only, Muted
- Each has subtitle describing behavior
- Uses `StatefulBuilder` for local setState within bottom sheet
- `_loadNotificationStrategy()` reads from `group_chats/{chatId}/members/{uid}`
- `_updateNotificationStrategy()` writes via `set(merge: true)`

## Deviations from Plan

None — plan executed as written.

## Verification

- `flutter analyze` — zero new issues
- Autocomplete renders on `@` input, filters by name, inserts `@DisplayName`
- Pinned bar appears/disappears based on `pinnedUntil` query
- Bubble amber tint renders for mentioned users
- @badge appears beside sender name for non-mentioned users
- Notification strategy persists to Firestore and loads on init

## Files Modified

- `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` — ~300 lines added (autocomplete overlay, pinned bar widget, bubble highlight logic, notification toggle, pinned stream, unpin method)

## Threat Flags

None — all UI-only changes. No new network endpoints, auth paths, or schema changes.