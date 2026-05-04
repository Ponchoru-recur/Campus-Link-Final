# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luminescence** (app name: "Campus Link") is a Flutter app for campus communication at Caraga State University. Role-based access (Student/Faculty) with group chats and instructor DMs.

- **Dart SDK**: `^3.11.1`
- **Dart package**: `luminescence` (all imports use `package:luminescence/...`)
- **Android application ID**: `com.example.luminescence` (from `android/app/google-services.json` — not yet updated from default)
- **Firebase project ID**: `campus-link-aac60`
- **No `firestore.rules` file** — security rules must be created before production deployment

## Development Commands

```bash
flutter pub get
flutter run
flutter test
flutter test test/widget_test.dart
flutter analyze
flutter build apk
```

- To run a specific test file: `flutter test test/path/to/test.dart`

## Architecture

### Auth Flow

`AuthWrapper` (`lib/main.dart`) uses `StreamBuilder` + `FirebaseAuth.instance.authStateChanges()`.

**Flow:** No user → `RoleSelectionScreen` → `LoginScreen` (role via route args) → `SignUpScreen` → `VerifyEmailScreen` → `ChatsScreen`

**User resolution** (`_resolveUser` in `main.dart`): After auth state change, checks `user.emailVerified`. If verified → `ChatsScreen`. If not → reads `pending_role` from SharedPreferences and shows `VerifyEmailScreen`.

Routes (`lib/main.dart`):

- `/` (home) → `AuthWrapper` (set via `home:` property, not in `routes`)
- `/roleSelection` → `RoleSelectionScreen`
- `/login` → `LoginScreen` (receives role via `ModalRoute.settings.arguments`)
- `/chatScreen` → `ChatsScreen`

Note: `themeMode` is hardcoded to `ThemeMode.light` in `main.dart`. `SignUpScreen` and `VerifyEmailScreen` are navigated to directly via constructors (not named routes).

### Firebase Integration

**Firestore Structure:**

```
users/{uid}: email, role, createdAt, emailVerified
group_chats/{chatId}: name, members[], createdBy, lastMessage, time, unreadCount, createdAt
group_chats/{chatId}/messages/{messageId}: senderId, senderName, text, timestamp, type(optional)
```

**Queries:** Group chats queried with `where('members', arrayContains: user.uid)` in `chats_screen.dart`. Messages are subcollections under each group chat document. Group chat deletion in `chats_screen.dart` batches message deletion in groups of 500.

### Data Models

**ChatItem** (`lib/pages/home_hamburger/channel_screen/chat_item.dart`): `id`, `name`, `lastMessage`, `time`, `type` (ChatType enum: `groupChat`/`instructor`), `unreadCount`, `isOnline`.

**Message** (`lib/pages/home_hamburger/channel_screen/message.dart`): `senderId`, `senderName`, `text`, `timestamp`, `type`.

### Key Files

- **`lib/main.dart`** - Entry point, `AuthWrapper` with `StreamBuilder` auth state, routes, theme setup
- **`lib/themes/`** - Material 3 themes (`app_theme.dart` barrel, `app_colors.dart` palette, `light_mode.dart`/`dark_mode.dart`)
- **`lib/pages/role_selection/role_selection_screen.dart`** - Role selection on app start
- **`lib/pages/login/login_screen.dart`** - Login with email validation, navigation to signup/reset password
- **`lib/pages/signup/sign_up_screen.dart`** - Registration with email/role persistence
- **`lib/pages/verify_email/verify_email_screen.dart`** - 10-min countdown, polls every 3s, auto-deletes unverified accounts
- **`lib/pages/reset_password/reset_password_screen.dart`** - Password reset flow
- **`lib/pages/home_hamburger/channel_screen/`** - Main chat feature
  - `chats_screen.dart` - Channel list with drawer, group chat stream, create/delete group chat, instructor DM list (static placeholder data)
  - `group_chat_screen.dart` - Group chat conversation (Firestore messages stream, faculty admin controls)
  - `instructor_chat_screen.dart` - Instructor DM (placeholder, not Firestore-backed)
  - `message.dart` / `chat_item.dart` - Data models
  - `group_chat_tile.dart` / `instructor_chat_tile.dart` - List tile widgets
  - `announcement_button/` - Announcement dialog (faculty only)
  - `create_group_chat_button.dart` - Create group chat UI
  - `message_edit_delete.dart` - Edit/delete message functionality (within 60 min)
  - `message_actions.dart` - Message action handlers
- **`lib/pages/home_hamburger/settings_screen/settings_screen.dart`** - Settings with debug role-switching feature

### State Management

`setState` for local widget state. `StreamBuilder` for auth state. `StreamSubscription` for Firestore streams (remember to cancel in `dispose`). `SharedPreferences` for pending verification state (`pending_email`, `pending_role`).

### Assets

Assets in `assets/images/` (per `pubspec.yaml`). App uses `assets/images/avatar.png` for user avatars.

### Planned/Unimplemented Features
All planned features are detailed in `docs/REQUIREMENTS.md`. Key unimplemented items:
- Message editing/deletion (within 60 minutes)
- Keyword message search, read receipts, priority messaging (Urgent/Standard)
- Do Not Disturb (DND) scheduling with priority override
- Full FCM push notification integration (dependency added, not yet implemented)
- Offline caching of recent messages (Hive CE added, not yet initialized)
- Channel search/filter in home screen
- Instructor DMs (currently static placeholder data, not Firestore-backed)

### Analysis Configuration
`analysis_options.yaml` includes only `package:flutter_lints/flutter.yaml` with no custom rules. Run `flutter analyze` to check.

## Conventions

- Email validation: `^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$` (enforced in login, signup, add member dialog)
- Use `AppColors` (in `lib/themes/app_colors.dart`) instead of hardcoded colors
- Role checks: `widget.role == 'faculty'` or `_userRole == 'faculty'` for conditional UI
- **`withValues(alpha:)`** preferred over deprecated `withOpacity()`
- Navigation: `pushNamedAndRemoveUntil` used to clear stack on logout and post-login
- All imports use `package:luminescence/...` prefix

## Role-Based Access Control

**Faculty Privileges:**

- Only faculty can create group chats - checked via `_userRole == 'faculty'` in `chats_screen.dart`
- Faculty are automatically admins in all group chats they're members of - checked via `isFaculty` flag in `group_chat_screen.dart`
- Only admins (faculty or group creator) can add/remove members and rename groups

**Role Badge UI:**

- Drawer header shows user role as a soft, rounded tag in `chats_screen.dart`
- Badge uses `withValues(alpha: 0.25)` with subtle border
- Displays capitalized role: "Student" or "Faculty"

## Key Dependencies

`firebase_core`, `firebase_auth`, `cloud_firestore`, `shared_preferences`, `flutter_spinkit`, `app_links`, `url_launcher`, `intl`, `hive_ce`, `hive_ce_flutter` (not yet initialized), `android_intent_plus`, `http`, `logging`, `cupertino_icons`

## Known Issues

- **No tests** - test directory is empty
- **Hardcoded colors** - `login_screen.dart`, `sign_up_screen.dart`, `verify_email_screen.dart`, `reset_password_screen.dart` use `Colors.grey[100]`, `Colors.green`, `Colors.blue` instead of `AppColors`
- **Deprecated `withOpacity()` usage** - `chats_screen.dart`, `login_screen.dart`, `sign_up_screen.dart`, `verify_email_screen.dart`, `reset_password_screen.dart`
- **Dark mode not functional** - Themes defined but `ThemeMode.light` hardcoded in main.dart
- **Drawer placeholders** - Most drawer items in ChatsScreen navigate to nothing (TODO comments)
- **Instructor DMs hardcoded** - `_instructorChats` list in `chats_screen.dart` is static placeholder data, not from Firestore
- **iOS config missing** - No `ios/Runner/GoogleService-Info.plist`
- **Analyzer warnings** - Unused variables in `group_chat_screen.dart`
- **Hive CE not initialized** - Both `hive_ce` and `hive_ce_flutter` dependencies included but not yet initialized
- **temp/ directory** - Contains `priorities.txt`, already gitignored

# Campus Link – Project Rules

## ⚠️ Implementation Integrity

The full feature requirements are in `docs/REQUIREMENTS.md`.

- **Never remove or replace** any implemented feature listed there without explicit instruction.
- Before modifying any feature, check if it's in REQUIREMENTS.md first.
- If asked to refactor, preserve all existing functionality unless told otherwise.
- When asked "is X implemented?", check the codebase and answer honestly.

## Tech Stack

- Flutter (mobile)
- Firebase Auth, Firestore, FCM
- Domain restriction: @carsu.edu.ph only

## Key Rules

- Auth must always enforce @carsu.edu.ph domain
- Firestore security rules must never be weakened
- Real-time sync must remain intact when editing messaging code
