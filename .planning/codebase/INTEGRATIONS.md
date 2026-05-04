---
date: 2026-05-04
focus: tech
---

# Integrations — Campus Link (Luminescence)

## Firebase Authentication

- **Provider**: Email/Password only
- **Domain restriction**: `@carsu.edu.ph` enforced in `login_screen.dart`, `sign_up_screen.dart`, and add-member dialog
- **Email verification flow**: `VerifyEmailScreen` — 10-min countdown, polls every 3s, auto-deletes unverified accounts
- **Singleton access**: `FirebaseAuth.instance` used throughout codebase
- **Auth state**: `FirebaseAuth.instance.authStateChanges()` → `StreamBuilder` in `AuthWrapper` (`lib/main.dart:41`)

## Cloud Firestore

### Collections

| Collection | Document Fields | Subcollections |
|------------|------------------|----------------|
| `users/{uid}` | `email`, `role`, `createdAt`, `emailVerified` | — |
| `group_chats/{chatId}` | `name`, `members[]`, `createdBy`, `lastMessage`, `time`, `unreadCount`, `createdAt`, `type` | `messages/{messageId}` |

### Message Document Fields
- `senderId`, `senderName`, `text`, `timestamp`, `type` (optional: 'system'), `readBy[]`, `editHistory[]`, `isDeleted`

### Queries
- Group chats: `where('members', arrayContains: user.uid)` in `chats_screen.dart:80-83`
- Messages: subcollection stream under each group chat document
- Message deletion: batched in groups of 500 in `chats_screen.dart:211-221`

## Firebase Cloud Messaging (FCM)

- **Package added**: `firebase_messaging` NOT in pubspec.yaml — listed in planned features but not yet integrated
- **Status**: Not implemented — dependency missing, no notification handling code

## SharedPreferences

- **Package**: `shared_preferences ^2.2.2`
- **Keys used**:
  - `pending_email` — temp storage during email verification
  - `pending_role` — temp storage during email verification (`AuthWrapper._resolveUser`, `main.dart:78`)
- **Access pattern**: `SharedPreferences.getInstance()` → async read/write

## Hive CE (Offline Caching — Planned)

- **Packages added**: `hive_ce ^2.19.3`, `hive_ce_flutter ^2.3.4`
- **Status**: NOT initialized — no `Hive.init()` or `Hive.openBox()` calls found
- **Planned use**: Cache recent messages for offline access

## Deep Linking

- **Package**: `app_links ^7.0.0`
- **Status**: Configured but no link handling logic found in codebase

## External URLs

- **url_launcher**: Available for launching external links
- **android_intent_plus**: Android platform intent support
- **No webhook endpoints** configured

## Google Services

- **Android**: `android/app/google-services.json` — project `campus-link-aac60`, API key `AIzaSyDLuRXOmQjvMi24fuB1yW01sSmvRJHiixQ`
- **iOS**: Not configured (`GoogleService-Info.plist` missing)
