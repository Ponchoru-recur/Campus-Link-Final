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

### Key Directories

- **`lib/main.dart`** - Entry point; initializes Firebase and sets up MaterialApp with routes
- **`lib/themes/`** - Material 3 theme system with light/dark mode support
  - `app_colors.dart` - Shared color palette for both themes
  - `light_mode.dart` / `dark_mode.dart` - Complete ThemeData definitions
  - `app_theme.dart` - Barrel export file
- **`lib/pages/`** - Screen widgets organized by feature
  - `role_selection/` - Role selection (Student/Faculty) with animations; passes role to login route
  - `login/` - Login with CarSU email validation; extracts role from route arguments and passes to SignUpScreen
  - `signup/` - SignUpScreen with role-based UI (button text: "Create Account" vs "Create Faculty Account")
  - `home_hamburger/channel_screen/` - Main chat interface with drawer navigation

### Data Models

- **`ChatItem`** (`lib/pages/home_hamburger/channel_screen/chat_item.dart`) - Represents a chat entry with `ChatType` enum (groupChat, instructor)

### State Management

Currently uses `setState` for local widget state. Animation controllers are used in RoleSelectionScreen for staggered entrance animations. LoginScreen uses `didChangeDependencies()` to extract route arguments.

## Key Dependencies

- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore` - Auth and data storage
- **Local Storage**: `hive_ce`, `hive_ce_flutter`, `shared_preferences` - Offline data persistence
- **UI**: `flutter_spinkit` (loading indicators), `app_links`, `url_launcher`
- **Platform**: `android_intent_plus` for Android-specific intents

## Firebase Configuration

- Android config present at `android/app/google-services.json`
- iOS config not yet present (may need `ios/Runner/GoogleService-Info.plist`)

## Conventions

- Email validation enforces CarSU format: `FirstName.LastName@carsu.edu.ph`
- Theme colors are centralized in `AppColors` class - use these instead of hardcoded colors
- Currently uses sample/dummy data in ChatsScreen - TODO comments indicate where Firebase integration is needed
- `withValues(alpha: ...)` is used instead of deprecated `withOpacity()` for color transparency (though some files still use `withOpacity` - see analyzer warnings)
- Role-based UI: pass role as String argument via `Navigator.pushNamed(arguments: 'student'/'faculty')` or constructor parameter; check `widget.role == 'faculty'` for conditional UI
