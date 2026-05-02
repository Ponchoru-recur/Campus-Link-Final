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

### Navigation Flow
`RoleSelectionScreen` → `LoginScreen` (role passed via args) → `SignUpScreen` (role passed via constructor) → `ChatsScreen`

Routes are defined in `lib/main.dart`:
- `/` - RoleSelectionScreen (entry point)
- `/login` - LoginScreen (receives role as String argument)
- `/chatScreen` - ChatsScreen (main app screen after login)

Role propagation: RoleSelectionScreen passes role via `Navigator.pushNamed(arguments: 'student'/'faculty')` → LoginScreen extracts via `ModalRoute.of(context)?.settings.arguments` → SignUpScreen receives role via constructor parameter.

After authentication, both LoginScreen and SignUpScreen use `pushNamedAndRemoveUntil('/chatScreen', (route) => false)` to clear the navigation stack.

Note: ChatsScreen uses `MaterialPageRoute` directly for navigation to GroupChatScreen and InstructorChatScreen (not named routes).

### Key Directories

- **`lib/main.dart`** - Entry point; initializes Firebase and sets up MaterialApp with routes; currently uses `ThemeMode.light` (hardcoded)
- **`lib/themes/`** - Material 3 theme system with light/dark mode support
  - `app_colors.dart` - Shared color palette (primary: teal-green #2DC58C)
  - `light_mode.dart` / `dark_mode.dart` - Complete ThemeData definitions
  - `app_theme.dart` - Barrel export file
- **`lib/pages/`** - Screen widgets organized by feature
  - `role_selection/` - Role selection (Student/Faculty) with staggered animations using 3 AnimationControllers
  - `login/` - Login with CarSU email validation; extracts role from route arguments
  - `signup/` - SignUpScreen with role-based UI (button text: "Create Account" vs "Create Faculty Account")
  - `home_hamburger/channel_screen/` - Main chat interface
    - `chats_screen.dart` - Channel list with drawer navigation (Profile, Updates & Tasks, Announcements, Settings, Policies, Share, Log out)
    - `group_chat_screen.dart` - Group chat conversation view with sample messages
    - `instructor_chat_screen.dart` - Instructor DM conversation view
    - `chat_item.dart` - ChatItem model with ChatType enum
    - `message.dart` - Message model for chat conversations
    - `group_chat_tile.dart` / `instructor_chat_tile.dart` - List tile widgets

### Data Models

- **`ChatItem`** (`lib/pages/home_hamburger/channel_screen/chat_item.dart`) - Represents a chat entry with `ChatType` enum (groupChat, instructor)
- **`Message`** (`lib/pages/home_hamburger/channel_screen/message.dart`) - Represents a single chat message with sender info, text, timestamp, and isMe flag

### State Management

Currently uses `setState` for local widget state. RoleSelectionScreen uses 3 AnimationControllers (header, cards, floating) with staggered timing. LoginScreen uses `didChangeDependencies()` to extract route arguments.

## Key Dependencies

- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore` - Auth and data storage
- **Local Storage**: `hive_ce`, `hive_ce_flutter`, `shared_preferences` - Offline data persistence (Hive not yet initialized)
- **Network**: `http` - HTTP client for API calls (not yet used in codebase)
- **UI**: `flutter_spinkit` (loading indicators), `app_links` (deep linking), `url_launcher`
- **Platform**: `android_intent_plus` for Android-specific intents
- **Utilities**: `intl` (date formatting), `logging` (logging framework)

## Firebase Configuration

- Android config present at `android/app/google-services.json`
- iOS config not yet present (may need `ios/Runner/GoogleService-Info.plist`)
- App tests Firebase connection on startup via anonymous sign-in (`testFirebaseConnection()` in main.dart) - this is a temporary diagnostic, not a feature

## Conventions

- Email validation enforces CarSU format: `FirstName.LastName@carsu.edu.ph` (regex: `^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$`)
- Theme colors are centralized in `AppColors` class - use these instead of hardcoded colors
- Role is passed as a String ('student'/'faculty') - check `widget.role == 'faculty'` for conditional UI
- `withValues(alpha: ...)` is preferred over deprecated `withOpacity()` for color transparency (some files still use `withOpacity` - see analyzer warnings)
- Sample/dummy data is used in ChatsScreen, GroupChatScreen, and InstructorChatScreen - look for TODO comments where Firebase integration is needed:
  - `login_screen.dart:66` - TODO: connect to Firebase
  - `sign_up_screen.dart:72` - TODO: connect to Firebase with role information
  - `chats_screen.dart` - sample `_groupChats` and `_instructorChats` lists
  - `group_chat_screen.dart` - sample `_messages` list
  - Drawer navigation items in `chats_screen.dart` - multiple TODOs for Profile, Updates & Tasks, Announcements, Settings, Policies, Share, Log out
