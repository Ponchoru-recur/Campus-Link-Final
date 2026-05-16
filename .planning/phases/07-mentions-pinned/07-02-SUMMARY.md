---
phase: 07-mentions-pinned
plan: 02
type: execute
wave: 1
depends_on: [07-01]
subsystem: push_notifications
tags: ["FCM", "push-notifications", "firebase_messaging", "notification-service"]
requires: []
provides: ["FCM token registration", "local notification display", "notification-tap navigation"]
affects:
  - pubspec.yaml
  - lib/services/notification_service.dart
  - lib/main.dart
  - android/app/src/main/AndroidManifest.xml
tech-stack:
  added:
    - firebase_messaging: ^16.2.2
    - flutter_local_notifications: ^21.0.0
  patterns:
    - Singleton service class for notification lifecycle
    - Top-level background handler function with @pragma vm:entry-point
    - Global navigator key for cold-start notification navigation
key-files:
  created:
    - lib/services/notification_service.dart
  modified:
    - pubspec.yaml
    - lib/main.dart
    - android/app/src/main/AndroidManifest.xml
decisions:
  - "FlutterLocalNotificationsPlugin is now a singleton factory in v21 — no need for 'new' keyword"
  - "initialize() and show() in flutter_local_notifications v21 use named parameters exclusively"
  - "Android notification channels created programmatically (high_importance_channel for full pushes, silent_channel for badge-only updates)"
metrics:
  duration: ~15 minutes
  completed: "2026-05-16"
  errors: 0
---

# Phase 7 Plan 2: FCM Push Notification Infrastructure Summary

**One-liner:** Added FCM push notification client pipeline with firebase_messaging and flutter_local_notifications — token registration, foreground/background/terminated message handling, local notification display, Android manifest configuration, and notification-tap navigation.

## Context

This plan establishes the client-side FCM pipeline required for the tiered notification dispatch model (Phase 7 Plan 5). The NotificationService handles token lifecycle, message routing, and notification display. The server-side dispatch logic (Cloud Functions or equivalent) is deferred to Plan 5.

## Tasks Completed

### Task 1: Add FCM dependencies to pubspec.yaml

**Commit:** `84af0a0`

Added `firebase_messaging: ^16.2.2` and `flutter_local_notifications: ^21.0.0` to dependencies. Resolved via `flutter pub get` with no version conflicts. Eleven new transitive dependencies installed.

### Task 2: Create notification_service.dart

**Commit:** `d5e3552`

Created `lib/services/notification_service.dart` (166 lines) — a singleton service class following the existing codebase pattern (see `task_service.dart`). Implements:

- **`initialize()`**: Idempotent initialization creating Android notification channels (`high_importance_channel` with `Importance.max`, `silent_channel` with `Importance.min`), requesting permissions, registering token handlers, and setting up message listeners
- **`_saveToken()`**: Stores FCM tokens in Firestore `users/{uid}/fcmTokens` using `FieldValue.arrayUnion` for multi-device support
- **`_handleForegroundMessage()`**: Displays local notifications via `flutter_local_notifications` on the `high_importance_channel`
- **`_handleNotificationTap()`**: Parses `chatId` from FCM data payload, navigates to `GroupChatScreen` with `pushNamedAndRemoveUntil` clear-stack pattern
- **`navigatorKey`**: Static `GlobalKey<NavigatorState>` for context-free navigation from background/terminated state

**Deviation noted:** `flutter_local_notifications` v21 uses a factory singleton pattern (`FlutterLocalNotificationsPlugin()` returns the same instance) and all methods use named parameters. The plan's example code used positional parameters. API calls were corrected to match the actual v21 API.

### Task 3: Register FCM handlers in main.dart and update Android manifest

**Commit:** `eb7b130`

**main.dart changes:**
- Added `import 'package:firebase_messaging/firebase_messaging.dart'` and `import 'package:luminescence/services/notification_service.dart'`
- Added top-level `_firebaseMessagingBackgroundHandler()` function with `@pragma('vm:entry-point')` annotation — receives `RemoteMessage` in a separate isolate, re-initializes Firebase, logs receipt
- In `main()`: registered `FirebaseMessaging.onBackgroundMessage()` and called `NotificationService.instance.initialize()` after Firebase initialization
- Added `navigatorKey: NotificationService.navigatorKey` to MaterialApp

**AndroidManifest.xml changes:**
- Added `com.google.firebase.messaging.default_notification_channel_id` metadata pointing to `high_importance_channel`
- Added `com.google.firebase.messaging.default_notification_icon` metadata pointing to `@mipmap/ic_launcher`

## Verification

- `flutter pub get` — succeeded
- `flutter analyze` on all modified files (`lib/main.dart`, `lib/services/notification_service.dart`, `android/app/src/main/AndroidManifest.xml`) — **0 issues found**
- Full `flutter analyze` — 110 pre-existing issues (all in `lib/pages/channels/group_chats.dart`, `lib/pages/channels/models/chatpage.dart`, and `test/services/storage_service_test.dart` — unrelated to this plan)

## Deviations from Plan

### Auto-fixed: flutter_local_notifications v21 API differences

**Rule 1 - Bug:** The plan's example code showed positional parameters for `initialize()` and `show()` calls on `FlutterLocalNotificationsPlugin`. In v21, both methods use exclusively named parameters (`settings:` and `id:`/`title:`/`body:`/etc.). Additionally, the class is now a factory singleton — `FlutterLocalNotificationsPlugin()` always returns the same instance.

**Fix:** Converted to named parameter calls matching the actual v21 API. Confirmed with `flutter analyze`.

**Files modified:** `lib/services/notification_service.dart`

**Commit:** `d5e3552`

## Known Stubs

None — all wired functionality is complete. NotificationService is fully initialized at app start. The server-side dispatch (Cloud Functions) is not part of this plan.

## Threat Flags

None — the FCM -> Client boundary (T-07-04) was accepted per the threat model. Notification-tap navigation (T-07-05) uses `pushNamedAndRemoveUntil` clear-stack, and only parses `chatId` from the data payload. Token storage (T-07-06) was accepted.

## Self-Check: PASSED

- `pubspec.yaml` contains both new dependencies — FOUND
- `lib/services/notification_service.dart` exists (166 lines, meets 120-line minimum) — FOUND. Exports `NotificationService` — FOUND.
- `lib/main.dart` contains `_firebaseMessagingBackgroundHandler` — FOUND. Contains `FirebaseMessaging.onBackgroundMessage` — FOUND. Contains `NotificationService.instance.initialize()` — FOUND. Contains `navigatorKey: NotificationService.navigatorKey` — FOUND.
- `AndroidManifest.xml` contains `firebase_messaging_default_channel` — FOUND. Min lines of main.dart > 85 — FOUND (currently > 100 lines after additions).
- Commit `84af0a0` — FOUND
- Commit `d5e3552` — FOUND
- Commit `eb7b130` — FOUND