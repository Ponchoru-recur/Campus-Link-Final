---
date: 2026-05-04
focus: quality
---

# Conventions — Campus Link (Luminescence)

## Code Style

- **Lint rules**: `flutter_lints ^6.0.0` via `analysis_options.yaml` — no custom rules
- **Null safety**: Enabled (Dart 3.x, sound null safety)
- **Formatting**: Standard `dart format` defaults

## Naming Patterns

| Element | Convention | Example |
|---------|------------|---------|
| Files | `snake_case.dart` | `group_chat_screen.dart` |
| Classes | `PascalCase` | `GroupChatScreen`, `ChatsScreen` |
| Variables | `lowerCamelCase` | `_groupChats`, `_userRole` |
| Constants | `lowerCamelCase` + `const` | `const ChatsScreen({...})` |
| Enum values | `lowerCamelCase` | `ChatType.groupChat` |
| Widget methods | `lowerCamelCase` with `_` prefix for private | `_buildDrawer()`, `_openGroupChat()` |

## State Management Pattern

**No state management library** — mix of:
- `setState()` for local widget state (`_groupChats`, `_userRole`, `_isCreatingGroup`)
- `StreamBuilder` for auth state (`AuthWrapper`)
- `StreamSubscription` for Firestore streams (MUST cancel in `dispose()`)
- `SharedPreferences` for cross-session persistence

**Widget lifecycle pattern** (seen in `chats_screen.dart`, `group_chat_screen.dart`):
```dart
class _XxxScreenState extends State<XxxScreen> {
  StreamSubscription? _subscription;
  bool _isDisposed = false;  // guard flag

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    _subscription = someStream.listen((data) {
      if (_isDisposed || !mounted) return;
      setState(() { ... });
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
```

## Color Usage

- **Preferred**: `AppColors.*` static constants from `lib/themes/app_colors.dart`
- **Also used** (should migrate): hardcoded `Colors.grey[100]`, `Colors.green`, `Colors.blue`, `Colors.white`, `Colors.black`
- **Deprecated API**: `withOpacity()` used in `chats_screen.dart`, `login_screen.dart`, `sign_up_screen.dart`, `verify_email_screen.dart`, `reset_password_screen.dart`
- **Preferred API**: `withValues(alpha:)` — already used in some places

## Role Checks

```dart
// In State classes:
_userRole == 'faculty'   // or 'student'
widget.role == 'faculty'   // passed via constructor
```

Faculty privileges:
- Create group chats (checked in `chats_screen.dart:552`)
- Admin controls in group chats (checked in `group_chat_screen.dart`)
- Announcement button visibility (AppBar action in `chats_screen.dart:526-534`)

## Email Validation

Regex pattern (enforced in login, signup, add-member dialog):
```dart
RegExp(r'^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$')
```

## Navigation Pattern

```dart
// Named routes (defined in main.dart):
Navigator.pushNamed(context, '/login');
Navigator.pushNamedAndRemoveUntil(context, '/chatScreen', (route) => false);

// Constructor navigation (most screens):
Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(chat: chat)));
```

## Error Handling

- **Pattern**: `try/catch` with `debugPrint()` for logging
- **User feedback**: `ScaffoldMessenger.of(context).showSnackBar(...)` with `AppColors.successGreen` or `AppColors.urgentRed`
- **Mounted checks**: `if (mounted) ...` before `setState()` or `ScaffoldMessenger`
- **Disposed guards**: `_isDisposed` flag used in `chats_screen.dart` to prevent state updates after dispose

## Async Patterns

- `async/await` for Firebase operations
- `WidgetsBinding.instance.addPostFrameCallback` for state updates after frame (see `chats_screen.dart:61-67`)
- `FutureBuilder` for one-time async in `AuthWrapper._resolveUser`
