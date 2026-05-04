---
date: 2026-05-04
focus: concerns
---

# Concerns — Campus Link (Luminescence)

## Critical Issues

### 1. No Firestore Security Rules
- **Severity**: HIGH
- **File**: No `firestore.rules` file exists
- **Impact**: Any authenticated user can read/write ANY data — no per-user access control
- **Required**: Create `firestore.rules` before production deployment
- **Rules needed**:
  - `@carsu.edu.ph` domain validation in `users` collection
  - Channel access: users can only read group_chats where they are in `members[]`
  - Message read/write: only members can read messages, only sender can edit/delete
  - Notification settings: users can only read/write their own settings

### 2. No Tests
- **Severity**: HIGH
- **File**: `test/` directory is empty
- **Impact**: No regression safety, bugs can ship silently
- **Recommendation**: Start with critical path tests (auth, messaging, role access)

### 3. Hardcoded Colors Instead of AppColors
- **Severity**: MEDIUM
- **Files**: `login_screen.dart`, `sign_up_screen.dart`, `verify_email_screen.dart`, `reset_password_screen.dart`
- **Issue**: Uses `Colors.grey[100]`, `Colors.green`, `Colors.blue` instead of `AppColors.*`
- **Impact**: Theme inconsistency, dark mode won't work properly for these screens
- **Fix**: Replace all hardcoded colors with `AppColors.*` constants

### 4. Deprecated `withOpacity()` Usage
- **Severity**: MEDIUM
- **Files**: `chats_screen.dart`, `login_screen.dart`, `sign_up_screen.dart`, `verify_email_screen.dart`, `reset_password_screen.dart`
- **Issue**: `withOpacity()` is deprecated in Flutter 3.x
- **Fix**: Replace with `withValues(alpha:)`
- **Note**: Some files already use `withValues(alpha:)` correctly — inconsistent

## Architecture Concerns

### 5. Dark Mode Not Functional
- **Severity**: MEDIUM
- **File**: `lib/main.dart:25`
- **Issue**: `ThemeMode.light` hardcoded — dark mode themes exist but never used
- **Fix**: Add theme toggle in SettingsScreen, persist preference

### 6. No State Management Library
- **Severity**: LOW-MEDIUM
- **Issue**: Mixed `setState()`, `StreamBuilder`, `StreamSubscription` — works for small app but harder to scale
- **Impact**: Data flow is scattered across widgets, no single source of truth
- **Note**: Not urgent to change, but consider Provider/Riverpod if app grows

### 7. Hive CE Not Initialized
- **Severity**: MEDIUM
- **Files**: `pubspec.yaml` has `hive_ce` and `hive_ce_flutter` but no init code
- **Issue**: Offline caching feature can't work — Hive never initialized
- **Needed**: `Hive.init()` / `HiveFlutter.init()` in `main()`, `Hive.openBox()` for message cache

## Security Concerns

### 8. Firebase API Key Exposed
- **Severity**: LOW (acceptable for Firebase)
- **File**: `android/app/google-services.json:18`
- **Note**: Firebase API keys are designed to be public — security is enforced via Firebase Security Rules (which don't exist yet — see #1)
- **Action**: Create `firestore.rules` — that's the real security layer

### 9. Android App ID Still Default
- **Severity**: LOW
- **File**: `android/app/google-services.json:12` — `com.example.luminescence`
- **Issue**: Not updated from Flutter template default
- **Impact**: Play Store release will need proper package name

## Incomplete Features

### 10. Instructor DMs Are Static Placeholder Data
- **Severity**: MEDIUM
- **File**: `chats_screen.dart:114-130` — `_instructorChats` list
- **Issue**: Hardcoded list of 2 instructors, not Firestore-backed
- **Impact**: Instructor DM feature is non-functional
- **Planned**: Wire to Firestore collection for real instructor-student messaging

### 11. iOS Configuration Missing
- **Severity**: LOW (Android-focused)
- **Issue**: No `ios/Runner/GoogleService-Info.plist`
- **Impact**: iOS builds will fail to connect to Firebase
- **Fix**: Download and add `GoogleService-Info.plist` from Firebase Console

### 12. Drawer Placeholder Items
- **Severity**: LOW
- **File**: `chats_screen.dart:426-482` — multiple `_DrawerItem` with `// TODO: navigate to X`
- **Items**: Profile, Updates & Tasks, Announcements, Policies, Share
- **Impact**: Tapping these items does nothing

## Analyzer Warnings
- **File**: `group_chat_screen.dart` — unused variables reported by analyzer
- **Action**: Run `flutter analyze` to see full list, clean up

## Performance Considerations

### 13. Message Deletion Batch Strategy
- **File**: `chats_screen.dart:211-221`
- **Current**: Batches of 500 for message deletion — correct Firestore practice
- **Note**: For very large chats, consider showing progress indicator during deletion

### 14. No Pagination on Messages
- **Issue**: All messages loaded via stream with no pagination
- **Impact**: Large chat histories may cause memory/performance issues
- **Future**: Add pagination or lazy loading for messages
