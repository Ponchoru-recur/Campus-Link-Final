---
date: 2026-05-04
focus: arch
---

# Architecture — Campus Link (Luminescence)

## Pattern

**Stateful Widget + StreamBuilder** — no formal state management library (Bloc, Provider, Riverpod).

- `setState()` for local widget state
- `StreamBuilder` for auth state (`main.dart:41`)
- `StreamSubscription` for Firestore streams (remember to `cancel()` in `dispose`)
- `SharedPreferences` for persistent simple state across sessions

## Layers

```
┌─────────────────────────────────────────┐
│                 UI Layer                │
│  StatelessWidget / StatefulWidget     │
│  lib/pages/**/*.dart                  │
│  lib/themes/**                        │
├─────────────────────────────────────────┤
│              Data Layer                 │
│  FirebaseAuth.instance (singleton)     │
│  FirebaseFirestore.instance (singleton)│
│  SharedPreferences.getInstance()         │
│  Hive (planned, not initialized)      │
├─────────────────────────────────────────┤
│           External Services             │
│  Firebase Auth (email/password)        │
│  Cloud Firestore (NoSQL DB)           │
│  FCM (planned, not integrated)         │
└─────────────────────────────────────────┘
```

## Data Flow

### Auth Flow
```
FirebaseAuth.authStateChanges()
  → AuthWrapper (StreamBuilder)
    → user == null → RoleSelectionScreen
    → user != null && emailVerified → ChatsScreen
    → user != null && !emailVerified → VerifyEmailScreen (loads role from SharedPreferences)
```

### Messaging Flow
```
GroupChatScreen
  → Firestore stream: group_chats/{chatId}/messages subcollection
  → StreamBuilder → List<Message> → ListView
  → Send: messagesRef.add({senderId, senderName, text, timestamp, readBy})
  → Read receipts: message.readBy array, displayed under sender's messages
```

### Group Chat List Flow
```
ChatsScreen
  → Firestore query: group_chats where members arrayContains user.uid
  → StreamSubscription → List<ChatItem> → ListView
  → Create: group_chats.add({name, members, createdBy, ...})
  → Delete: batched delete of messages subcollection + group_chat doc
```

## Entry Points

| Entry Point | File | Description |
|-------------|------|-------------|
| `main()` | `lib/main.dart:11` | `WidgetsFlutterBinding.ensureInitialized()` → `Firebase.initializeApp()` → `runApp(MyApp())` |
| `MyApp` | `lib/main.dart:17` | MaterialApp with themes, routes, `AuthWrapper` as home |
| `AuthWrapper` | `lib/main.dart:36` | StreamBuilder on auth state, routes to correct screen |

## Key Abstractions

### Data Models
- **`ChatItem`** (`lib/pages/home_hamburger/channel_screen/chat_item.dart`) — id, name, lastMessage, time, type (ChatType enum), unreadCount, isOnline
- **`Message`** (`lib/pages/home_hamburger/channel_screen/message.dart`) — id, senderId, senderName, text, timestamp, type, readBy, editHistory, isDeleted; `isEdited` getter

### Theme System
- **`AppColors`** (`lib/themes/app_colors.dart`) — Shared color palette, constants for both light/dark
- **`light_mode.dart`** / **`dark_mode.dart`** — ThemeData definitions
- **`app_theme.dart`** — Barrel export file
- **Note**: `ThemeMode.light` hardcoded in `main.dart:25` — dark mode themes defined but not functional

## Navigation

- **Named routes** (in `main.dart:27-31`): `/roleSelection`, `/login`, `/chatScreen`
- **Constructor navigation**: `SignUpScreen`, `VerifyEmailScreen`, `ChatsScreen`, `GroupChatScreen`, `InstructorChatScreen`, `SettingsScreen` — pushed via `Navigator.push(MaterialPageRoute(...))`
- **Stack control**: `pushNamedAndRemoveUntil` used for logout and post-login navigation to clear stack
