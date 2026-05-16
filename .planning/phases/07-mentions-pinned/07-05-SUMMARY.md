---
phase: 07-mentions-pinned
plan: 05
wave: 3
tags: [push-notifications, cloudflare-worker, fcm, tiered-dispatch]
depends_on:
  - 07-01
  - 07-02
provides:
  - sendTieredNotification() method on NotificationService (raw message POST to Worker)
  - Worker integration call from _sendMessage() after successful message send
  - Updated Cloudflare Worker Firestore REST API query logic
affects:
  - lib/services/notification_service.dart
  - lib/pages/home_hamburger/channel_screen/group_chat_screen.dart
  - temp/cloudflare-worker.js
tech-stack:
  added: []
  patterns:
    - Fire-and-forget HTTP POST with raw message data (no await in calling code)
    - Worker queries Firestore REST API for member strategies + FCM tokens server-side
    - Worker applies D-16 tier logic server-side (strategies never leave Firestore)
    - Worker handles both raw-message and legacy-targets shapes
key-files:
  modified:
    - lib/services/notification_service.dart
    - lib/pages/home_hamburger/channel_screen/group_chat_screen.dart
    - temp/cloudflare-worker.js
decisions:
  - "Flutter sends raw message data only — no FCM tokens or strategies in client code per D-20"
  - "Worker updated to handle raw shape (chatId, mentionedUids, etc.) — queries Firestore REST API server-side"
  - "Worker supports both raw-message and legacy-targets shapes for backward compat"
  - "sendTieredNotification() is fire-and-forget — failures never block message delivery"
  - "Task messages (isTask: true) trigger full push via Worker tier logic"
  - "Worker extracts FCM tokens from users/{uid} document, not member subcollection"
metrics:
  duration: ~10 min
  completed_date: 2026-05-17
  total_commits: 0 (part of ongoing branch)
---

# Phase 7 Plan 5: Cloudflare Worker Tiered FCM Dispatch

**One-liner:** Added `sendTieredNotification()` to NotificationService that POSTs raw message data to Cloudflare Worker. Worker queries Firestore REST API for member strategies + FCM tokens, applies D-16 tier logic, and fans out FCM v1 calls.

## Context

Plan 07-02 established FCM client infrastructure (token registration, local notifications, navigation). Plan 05 completes the push pipeline by adding server-side dispatch via Cloudflare Worker. This avoids Firebase Functions (which require Blaze plan / credit card).

## Tasks Completed

### Task 1: Add sendTieredNotification() method to NotificationService

**Modified:** `lib/services/notification_service.dart`

Added public method `sendTieredNotification()` that sends ONE HTTP POST to the Worker URL (`https://dawn-rice-bc73.sam-varela.workers.dev`) with raw message data:

```dart
Future<void> sendTieredNotification({
  required String chatId,
  required String messageId,
  required String senderId,
  required String senderName,
  required String chatName,
  required String text,
  required List<String> mentionedUids,
  required bool isEveryone,
  required bool isTask,
}) async { ... }
```

Key properties:
- Fire-and-forget (no await) — notification failure never breaks message delivery
- Sends raw data only — no FCM tokens, no notification strategies (Worker handles server-side per D-20)
- Wraps in try/catch with debugPrint — silent failure
- Uses `http` package (already in pubspec.yaml)

**Files modified:** `lib/services/notification_service.dart` (+32 lines)

### Task 2: Update group_chat_screen.dart _sendMessage to call notification service

**Modified:** `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart`

Changes:
- Added `import 'package:luminescence/services/notification_service.dart'`
- Changed `messagesRef.add(...)` to capture `final docRef = await messagesRef.add(...)` for messageId
- Added fire-and-forget call to `NotificationService.instance.sendTieredNotification(...)` after successful Firestore write
- Sends: chatId, messageId, senderId, senderName, chatName, text, mentionedUids, isEveryone, isTask

### Task 3: Update Cloudflare Worker with Firestore REST API query logic

**Modified:** `temp/cloudflare-worker.js`

Worker updated to handle raw message shape (`{ chatId, messageId, ..., mentionedUids, isEveryone, isTask }`):
- Queries `group_chats/{chatId}` doc for member UIDs via Firestore REST API
- Queries `group_chats/{chatId}/members/{uid}` for notificationStrategy per member
- Queries `users/{uid}` for `fcmTokens` array
- Applies D-16 tier logic server-side:
  - `muted` → skip entirely
  - `mentionsOnly` + @mentioned → full push; `mentionsOnly` + normal → silent push
  - `normal` → full push for everything
- Excludes sender from notification targets
- Legacy `{ title, body, data, targets }` shape still supported for backward compatibility

## Verification

- `flutter analyze` on both modified files — **0 errors, 0 warnings**
  - 10 pre-existing info-level lints (`deprecated_member_use`, `use_build_context_synchronously`) unrelated to this plan
- Worker URL constant set: `https://dawn-rice-bc73.sam-varela.workers.dev`
- Notification call is fire-and-forget (no `await` before it)
- Worker handles both raw and legacy payload shapes

## Deviations from Plan

### Worker shape mismatch

The deployed Worker originally expected `{ title, body, data, targets }` shape. Plan 05 specified raw message shape per D-20. Updated Worker to accept both — raw messages for new behavior, legacy for backward compat.

## Threat Flags

None — no new client-side auth paths or schema changes. Worker uses Firestore REST API with scoped OAuth2 token.

## Next Phase Readiness

Phase 7 is now fully implemented:
- 07-01: Data layer ✓
- 07-02: FCM infrastructure ✓
- 07-03: Test stubs ✓
- 07-04: UI (autocomplete, pinned bar, highlight, toggle) ✓
- 07-05: Tiered notification dispatch ✓