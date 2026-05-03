# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luminescence** (app name: "Campus Link") is a Flutter app for campus communication at Caraga State University. Role-based access (Student/Faculty) with group chats and instructor DMs.

## Development Commands

```bash
flutter pub get
flutter run
flutter test
flutter test test/widget_test.dart
flutter analyze
flutter build apk
```

## Architecture

### Auth Flow
`AuthWrapper` (`lib/main.dart`) uses `StreamBuilder` + `FirebaseAuth.instance.authStateChanges()`.

**Flow:** No user → `RoleSelectionScreen` → `LoginScreen` (role via route args) → `SignUpScreen` → `VerifyEmailScreen` → `ChatsScreen`

Routes (`lib/main.dart`):
- `/roleSelection` → `RoleSelectionScreen`
- `/login` → `LoginScreen` (receives role via `ModalRoute.settings.arguments`)
- `/chatScreen` → `ChatsScreen`

Note: `themeMode` is hardcoded to `ThemeMode.light` in `main.dart:25`.

### Firebase Integration

**Firestore Structure:**
```
users/{uid}: email, role, createdAt, emailVerified
group_chats/{chatId}: name, members[], createdBy, lastMessage, time, unreadCount, createdAt
group_chats/{chatId}/messages/{messageId}: senderId, senderName, text, timestamp, type(optional)
```

**Key:** Group chats queried with `where('members', arrayContains: user.uid)` in `chats_screen.dart:51-54`.

### Data Models

**ChatItem** (`lib/pages/home_hamburger/channel_screen/chat_item.dart`):
```dart
class ChatItem {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final ChatType type;
  final int unreadCount;
  final bool isOnline;
}

enum ChatType { groupChat, instructor }
```

### Key Files

- **`lib/main.dart`** - Entry point, AuthWrapper, routes, theme setup
- **`lib/themes/`** - Material 3 themes
  - `app_theme.dart` - Barrel file exporting all theme files
  - `app_colors.dart` - Shared color palette
  - `light_mode.dart` / `dark_mode.dart` - Theme definitions
- **`lib/pages/home_hamburger/channel_screen/`** - Main chat feature
  - `chats_screen.dart` - Channel list with drawer (logout functional, other drawer items are TODO placeholders)
  - `group_chat_screen.dart` - Group chat conversation (Firestore messages stream)
  - `instructor_chat_screen.dart` - Instructor DM (placeholder, not Firestore-backed)
  - `message.dart` / `chat_item.dart` - Data models
  - `chat_avatars.dart` - Chat avatar utilities
  - `group_chat_tile.dart` - Group chat list tile widget
  - `instructor_chat_tile.dart` - Instructor chat list tile widget
  - `announcement_button/` - Announcement dialog (faculty only)
  - `create_group_chat_button.dart` - Create group chat UI
- **`lib/pages/home_hamburger/settings_screen/settings_screen.dart`** - Settings screen

### State Management

`setState` for local widget state. `StreamBuilder` for auth state. `SharedPreferences` for pending verification state (`pending_email`, `pending_role`).

### Assets

Assets located in `assets/images/` (per `pubspec.yaml`). App uses `assets/images/avatar.png` for user avatars.

## Conventions

- Email validation: `^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$` (enforced in login, signup, add member)
- Use `AppColors` (in `lib/themes/app_colors.dart`) instead of hardcoded colors
- Role checks: `widget.role == 'faculty'` for conditional UI
- **`withValues(alpha:)`** preferred over deprecated `withOpacity()` (some files still use `withOpacity` - see analyzer warnings)

## Key Dependencies

`firebase_core`, `firebase_auth`, `cloud_firestore`, `shared_preferences`, `flutter_spinkit`, `app_links`, `url_launcher`, `intl`, `hive_ce`, `hive_ce_flutter` (not yet initialized), `android_intent_plus`, `http`, `logging`, `cupertino_icons`

## Known Issues

- **No tests** - test directory is empty
- **Hardcoded colors** - `login_screen.dart`, `sign_up_screen.dart`, `verify_email_screen.dart`, `reset_password_screen.dart` use `Colors.grey[100]`, `Colors.green`, `Colors.blue` instead of `AppColors`
- **Deprecated `withOpacity()` usage** - `chats_screen.dart` (lines 216, 229, 435), also other screens mentioned above
- **Dark mode not functional** - Themes defined but `ThemeMode.light` hardcoded in main.dart
- **Drawer placeholders** - Most drawer items in ChatsScreen navigate to nothing (TODO comments)
- **Instructor DMs hardcoded** - `_instructorChats` list in `chats_screen.dart:82-98` is static placeholder data, not from Firestore
- **iOS config missing** - No `ios/Runner/GoogleService-Info.plist`
- **Analyzer warnings** - Unused variables in `group_chat_screen.dart`
- **Hive CE not initialized** - Both `hive_ce` and `hive_ce_flutter` dependencies included but not yet initialized

## Email Verification

`VerifyEmailScreen` (`lib/pages/verify_email/`): 10-min countdown, polls every 3s, persists to SharedPreferences, auto-deletes unverified accounts on timeout. On verification: saves user to Firestore `users` collection.
