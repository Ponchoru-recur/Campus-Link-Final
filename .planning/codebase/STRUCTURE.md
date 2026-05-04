---
date: 2026-05-04
focus: arch
---

# Structure — Campus Link (Luminescence)

## Directory Layout

```
luminescence/
├── lib/
│   ├── main.dart                          # Entry point, AuthWrapper, routes, theme setup
│   ├── themes/
│   │   ├── app_theme.dart                # Barrel export
│   │   ├── app_colors.dart               # Color palette (AppColors class)
│   │   ├── light_mode.dart               # Material 3 light theme
│   │   └── dark_mode.dart               # Material 3 dark theme (not active)
│   └── pages/
│       ├── role_selection/
│       │   └── role_selection_screen.dart # Role selection on app start
│       ├── login/
│       │   └── login_screen.dart         # Login with email validation
│       ├── signup/
│       │   └── sign_up_screen.dart       # Registration screen
│       ├── verify_email/
│       │   └── verify_email_screen.dart   # Email verification with countdown
│       ├── reset_password/
│       │   └── reset_password_screen.dart # Password reset flow
│       └── home_hamburger/
│           ├── settings_screen/
│           │   └── settings_screen.dart   # Settings with debug role-switching
│           └── channel_screen/
│               ├── chats_screen.dart     # Main channel list + drawer
│               ├── group_chat_screen.dart # Group chat conversation
│               ├── instructor_chat_screen.dart # Instructor DM (placeholder)
│               ├── chat_item.dart        # ChatItem data model
│               ├── message.dart          # Message data model
│               ├── group_chat_tile.dart  # Group chat list tile
│               ├── instructor_chat_tile.dart # Instructor chat list tile
│               ├── chat_avatars.dart     # Chat avatar widgets
│               ├── message_edit_delete.dart # Edit/delete message functionality
│               ├── message_actions.dart  # Message action handlers
│               ├── announcement_button/
│               │   └── announcement_dialog.dart # Faculty announcement dialog
│               └── create_group_chat_button.dart # Create group chat UI
├── assets/
│   └── images/                         # App images (avatar.png, etc.)
├── docs/
│   └── REQUIREMENTS.md                  # Full feature requirements
├── .planning/                           # GSD project management (new)
│   └── codebase/                        # Codebase maps (new)
├── android/                              # Android platform config
│   └── app/
│       └── google-services.json          # Firebase Android config
├── ios/                                  # iOS platform config (incomplete)
├── test/                                 # Tests (EMPTY — no tests yet)
├── pubspec.yaml                          # Dependencies, assets, SDK config
├── analysis_options.yaml                  # Lint rules (flutter_lints only)
├── CLAUDE.md                            # Project instructions for Claude Code
└── README.md                            # (if exists)
```

## Key Locations

| What | Where |
|------|-------|
| App entry point | `lib/main.dart:11` |
| Auth flow | `lib/main.dart:36-81` (AuthWrapper) |
| Theme definitions | `lib/themes/light_mode.dart`, `lib/themes/dark_mode.dart` |
| Color palette | `lib/themes/app_colors.dart` |
| Group chat list | `lib/pages/home_hamburger/channel_screen/chats_screen.dart` |
| Group chat conversation | `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` |
| Message model | `lib/pages/home_hamburger/channel_screen/message.dart` |
| Chat item model | `lib/pages/home_hamburger/channel_screen/chat_item.dart` |
| Firebase init | `lib/main.dart:13` |
| Requirements | `docs/REQUIREMENTS.md` |
| Firestore rules | NOT EXISTS — must be created |

## Naming Conventions

- **Files**: `snake_case` (e.g., `group_chat_screen.dart`, `chat_item.dart`)
- **Classes**: `PascalCase` (e.g., `ChatsScreen`, `GroupChatScreen`, `Message`)
- **Variables**: `lowerCamelCase` (e.g., `_groupChats`, `_userRole`, `_controller`)
- **Constants**: `lowerCamelCase` with `const` (e.g., `const ChatsScreen({...})`)
- **Enum**: `PascalCase` (e.g., `ChatType.groupChat`, `ChatType.instructor`)
- **Package imports**: `package:luminescence/...` prefix for all internal imports

## Import Pattern

All internal imports use `package:luminescence/...` prefix:
```dart
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_item.dart';
import 'package:luminescence/themes/app_colors.dart';
```

Firebase imports:
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
```

## Test Structure

- `test/` directory exists but is **empty** — no widget tests, no unit tests
- `flutter_test` package available in dev_dependencies
- `widget_test.dart` referenced in `flutter test` command but may not exist
