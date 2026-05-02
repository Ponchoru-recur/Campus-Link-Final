# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luminescence** (app name: "Campus Link") is a Flutter application for campus communication at Caraga State University (CarSU). It provides role-based access (Student/Faculty) with chat functionality, including group chats and instructor direct messages.

## Development Commands

```bash
# Install dependencies
flutter pub get

# Run the app (configure platform as needed)
flutter run

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze code
flutter analyze

# Build for Android
flutter build apk

# Build for iOS
flutter build ios
```

## Architecture

### Auth Flow
`AuthWrapper` (`lib/main.dart`) is the home widget. It uses `StreamBuilder` with `FirebaseAuth.instance.authStateChanges()` to react to auth state changes in real-time.

**Flow:**
1. No Firebase user → `RoleSelectionScreen`
2. User exists → `_resolveUser()` reloads user and checks `emailVerified`:
   - Verified → `ChatsScreen`
   - Unverified → `VerifyEmailScreen` (role loaded from SharedPreferences `pending_role`)

**Navigation:**
- `RoleSelectionScreen` → `LoginScreen` (role via route args) → `SignUpScreen` (role via constructor) → `VerifyEmailScreen` → `ChatsScreen`
- `SignUpScreen` uses `MaterialPageRoute` (not named route) for navigation to `VerifyEmailScreen`
- After auth, screens use `pushNamedAndRemoveUntil(route, (route) => false)` to clear the navigation stack

Routes in `lib/main.dart`:
- `/roleSelection` - RoleSelectionScreen
- `/login` - LoginScreen (receives role as route arguments)
- `/chatScreen` - ChatsScreen

**Note:** `themeMode` is hardcoded to `ThemeMode.light` in `main.dart` - dark mode themes exist but are not user-selectable.

### Key Directories

- **`lib/main.dart`** - Entry point; `AuthWrapper` handles auth state routing
- **`lib/themes/`** - Material 3 theme system with light/dark mode support
  - `app_colors.dart` - Shared color palette (primary: teal-green #2DC58C)
  - `light_mode.dart` / `dark_mode.dart` - Complete ThemeData definitions
  - `app_theme.dart` - Barrel export file
- **`lib/pages/`** - Screen widgets organized by feature
  - `role_selection/` - Role selection with staggered animations (3 AnimationControllers)
  - `login/` - Login with CarSU email validation + Firebase auth
  - `signup/` - SignUpScreen with Firebase auth + email verification trigger
  - `verify_email/` - Email verification screen with 10-min timer, polling, cancel/retry
  - `home_hamburger/channel_screen/` - Main chat interface
    - `chats_screen.dart` - Channel list with drawer (logout now functional via `FirebaseAuth.instance.signOut()`)
    - `group_chat_screen.dart` - Group chat conversation view
    - `instructor_chat_screen.dart` - Instructor DM conversation view
    - `chat_item.dart` - ChatItem model with ChatType enum
    - `message.dart` - Message model for chat conversations
    - `announcement_button/` - Announcement dialog (create announcements, select groups, set priority)

### Data Models

- **`ChatItem`** (`lib/pages/home_hamburger/channel_screen/chat_item.dart`) - Chat entry with `ChatType` enum (groupChat, instructor)
- **`Message`** (`lib/pages/home_hamburger/channel_screen/message.dart`) - Single chat message with sender info, text, timestamp, isMe flag

### State Management

Uses `setState` for local widget state. `AuthWrapper` uses `StreamBuilder` for reactive auth state. SharedPreferences persists pending verification data (`pending_email`, `pending_role`).

## Key Dependencies

- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore` - Auth and data storage
- **Network**: `http` - HTTP requests
- **Local Storage**: `shared_preferences` - Persists pending verification state; `hive_ce`, `hive_ce_flutter` (not yet initialized)
- **UI**: `flutter_spinkit` (loading indicators), `app_links` (deep linking), `url_launcher`
- **Platform**: `android_intent_plus` for Android-specific intents
- **Utilities**: `intl` (date formatting), `logging` (logging framework)

## Assets

- Images stored in `assets/images/` (declared in `pubspec.yaml`)
- Currently contains: `joker.png`, `dragon.jpg`

## Firebase Configuration

- Android config present at `android/app/google-services.json`
- iOS config not yet present (may need `ios/Runner/GoogleService-Info.plist`)

## Email Verification System

New accounts require email verification via Firebase (`VerifyEmailScreen`):
- 10-minute countdown timer with polling every 3 seconds
- Persists state via SharedPreferences (survives app restart)
- "Cancel & Try Different Email" option if user entered wrong email
- Auto-deletes unverified accounts after timeout
- On verification: saves user data to Firestore `users` collection

## Conventions

- Email validation enforces CarSU format: `FirstName.LastName@carsu.edu.ph` (regex: `^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$`)
- Theme colors centralized in `AppColors` class - use these instead of hardcoded colors
- Role is passed as String ('student'/'faculty') - check `widget.role == 'faculty'` for conditional UI
- `withValues(alpha: ...)` preferred over deprecated `withOpacity()` (some files still use `withOpacity` - see analyzer warnings)

## Known Issues

- **No tests exist** - test directory is empty, no `test/` files created yet
- **Hardcoded colors** - Several screens (`login_screen.dart`, `sign_up_screen.dart`, `verify_email_screen.dart`) use `Colors.grey[100]`, `Colors.green`, `Colors.blue` instead of `AppColors`
- **Dark mode not functional** - Themes defined in `themes/` but `ThemeMode.light` is hardcoded in `main.dart`
- **TODO comments** mark Firebase integration points in ChatsScreen, GroupChatScreen, InstructorChatScreen, and drawer navigation items
