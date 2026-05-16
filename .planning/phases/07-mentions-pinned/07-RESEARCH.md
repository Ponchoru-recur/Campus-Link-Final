# Phase 7: @Mentions & Pinned Messages - Research

**Researched:** 2026-05-16
**Domain:** @mention autocomplete, FCM push notifications, pinned message bar, Firestore real-time queries
**Confidence:** HIGH

## Summary

Phase 7 adds three major feature groups: (1) @user and @everyone mention system with autocomplete overlay and visual highlighting in group chats, (2) automatic pinned message bar for @everyone messages that expires after 24 hours, and (3) full FCM push notification integration with a tiered delivery model that respects per-user notification strategies.

The largest engineering surface is FCM integration -- it requires adding two dependencies (`firebase_messaging`, `flutter_local_notifications`), a top-level background message handler, FCM token registration, Android manifest updates for notification channels, and either a Cloud Functions endpoint or a lightweight server to dispatch FCM messages. The @mention autocomplete is best done as a custom implementation inside `_MessageInputBar` (no well-maintained Flutter package exists for this). The pinned bar is a pure client-side widget with a Firestore query filter.

**Primary recommendation:** Implement in five waves: (1) Firestore schema updates + @mention parsing, (2) @mention autocomplete UI, (3) visual @mention highlighting and @everyone pin bar, (4) notification strategy storage and toggle UI, (5) full FCM push notification pipeline.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Autocomplete dropdown appears when typing @. Filters group members by typed chars. Tap to insert as `@DisplayName`.
- **D-02:** @username stored as plain text in message body. Parsed on send to extract mentioned UIDs.
- **D-03:** Mentioned user sees highlighted message bubble (amber/yellow tint). Non-mentioned users see small @ badge on message.
- **D-04:** `mentionedUids: List<String>` field on message doc in Firestore.
- **D-05:** Faculty-only. Checked server-side via role lookup or `createdBy`.
- **D-06:** Auto-pins message to collapsible bar at top of chat for 24h.
- **D-07:** Pinned bar shows: sender name, message preview, age label ("2h ago", "yesterday").
- **D-08:** Visual fading: <1h = highlighted, <24h = normal, >24h = dimmed.
- **D-09:** Users can manually unpin (dismiss from bar; message stays in stream).
- **D-10:** After 24h, drops from pinned bar automatically (Firestore query filter).
- **D-11:** Add `pinnedUntil: Timestamp` field to message documents in group_chats/{chatId}/messages.
- **D-12:** Add `mentionedUids: List<String>` field to message documents.
- **D-13:** Pinned bar query: `where('pinnedUntil', '>', now)` on messages subcollection.
- **D-14:** Add `notificationStrategy` enum field to each group chat member document (`members/{uid}` subcollection): `normal`, `mentionsOnly`, `muted`.
- **D-15:** FCM full integration -- register tokens, send via Cloud Functions or server.
- **D-16:** Tiered delivery based on notificationStrategy + message type:
  - `normal` strategy: full push for everything in that chat.
  - `mentionsOnly` strategy: full push only for @mentions, @everyone, task events; silent for normal messages.
  - `muted` strategy: nothing.
- **D-17:** Default: students get `mentionsOnly` for group chats, `normal` for DMs. Faculty default `normal` for everything.
- **D-18:** Silent push = delivered with badge count, no banner/sound/lock screen.
- **D-19:** Notification tap opens relevant chat/thread.
- **D-20:** Per-group-chat toggle in group info/settings panel.
- **D-21:** Everyone can toggle their own notificationStrategy per chat.
- **D-22:** Three options: Normal (all notifications), Mentions Only, Muted.
- **D-23:** Collapsible bar between AppBar and message ListView.
- **D-24:** Shows most recent pinned message (or carousel if multiple).
- **D-25:** Display: sender avatar/name, truncated message preview, age label.
- **D-26:** Dismiss button for manual unpin.
- **D-27:** Bar appears only when pinned messages exist (from query).

### Claude's Discretion
- Exact amber/yellow shade for @mention highlight bubbles.
- @ badge icon style and position on message bubble.
- Pinned bar exact height, padding, animation for collapse/expand.
- Age label format ("2h", "2h ago", "2 hours ago").
- Carousel vs single display for multiple simultaneous pinned messages.
- FCM cloud function implementation details.

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

No explicitly numbered requirement IDs were provided for Phase 7 in CONTEXT.md. The scope is defined by the Implementation Decisions (D-01 through D-27) listed above.
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| @mention autocomplete UI | Client (Flutter) | -- | Input overlay, keyboard handling, text insertion are pure UI concerns |
| @mention parsing on send | Client (Flutter) | Firestore (storage) | Parse `mentionedUids` from text before Firestore write |
| Visual @mention highlight | Client (Flutter) | -- | Bubble rendering based on `mentionedUids` field |
| @everyone faculty gate | Client (Flutter) | Firestore (role lookup) | Role check before setting `pinnedUntil` |
| Pinned bar query + display | Client (Flutter) | Firestore (query) | Real-time stream filtering `pinnedUntil > now` |
| FCM token registration | Client (Flutter) | Firestore (storage) | Token stored per-user for server dispatch |
| FCM dispatch decision | Server (Cloud Functions) | -- | Must run server-side to read notificationStrategy per member per message |
| FCM send (server->device) | Server (Cloud Functions) | FCM (Google) | FCM HTTP v1 API called from server |
| Silent vs full push delivery | Server (Cloud Functions) | -- | Server decides `notification` vs `data` payload based on strategy |
| Foreground notification display | Client (Flutter) | -- | `flutter_local_notifications` shows local notification when app in foreground |
| Notification tap -> chat | Client (Flutter) | -- | Parse FCM data payload, navigate to correct screen |
| Notification strategy storage | Firestore | Client (Flutter) | `group_chats/{chatId}/members/{uid}.notificationStrategy` |
| Notification strategy toggle UI | Client (Flutter) | -- | Bottom sheet / group info panel |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `firebase_messaging` | ^16.2.2 | FCM token registration, message listening, topic management | Official Firebase Flutter plugin, Flutter Favorite, 2M+ downloads |
| `flutter_local_notifications` | ^21.0.0 | Local notification display when app is in foreground | Official companion to firebase_messaging, handles Android notification channels |

### Supporting (none needed beyond existing stack)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `cloud_firestore` | ^6.1.3 | Already in project -- pinned message queries, notification strategy storage | Existing dependency |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom @mention implementation | `multi_trigger_autocomplete` (v1.0.0) | Package is 2 years old, not actively maintained, requires `flutter_portal` dependency. Custom is simpler for the single `@` trigger we need. |
| Custom @mention implementation | `perfect_text_field` (v2.3.2+3) | Most maintained option (8 months old) but download count is tiny (18/wk). Adds unnecessary phone number parsing dependency. |
| Cloud Functions | Firebase Admin SDK (standalone server) | Cloud Functions is the standard Firebase ecosystem choice, no extra infrastructure to maintain. |

**Installation:**
```bash
flutter pub add firebase_messaging flutter_local_notifications
```

**Version verification:**
```bash
# Already verified via flutter pub add --dry-run
# firebase_messaging 16.2.2  (Published 2026-05-14)
# flutter_local_notifications 21.0.0  (Published 2026)
```

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CLIENT (Flutter App)                         │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                  GroupChatScreen                             │   │
│  │  ┌─────────────────────┐   ┌────────────────────────────┐   │   │
│  │  │ PinnedBar Widget    │   │ Message List + Bubble      │   │   │
│  │  │  - Stream: pinned   │   │  - mentionedUids check     │   │   │
│  │  │    msgs query       │   │  - @highlight tint         │   │   │
│  │  │  - Collapse/expand  │   │  - @badge icon             │   │   │
│  │  └─────────────────────┘   └────────────────────────────┘   │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │ _MessageInputBar (+ @autocomplete overlay)           │   │   │
│  │  │  - TextEditingController listener for '@'            │   │   │
│  │  │  - OverlayEntry with member list                     │   │   │
│  │  │  - Insert @DisplayName on tap                        │   │   │
│  │  │  - _sendMessage() parses mentionedUids + pinnedUntil  │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │ _showGroupInfo() + Notification strategy toggle      │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────┐                                   │
│  │ FCM Token Registration       │                                   │
│  │  - getToken() on auth/login  │                                   │
│  │  - store in users/{uid}/fcm  │                                   │
│  └──────────────────────────────┘                                   │
│                                                                     │
│  ┌──────────────────────────────┐                                   │
│  │ FCM Message Handlers         │                                   │
│  │  - onMessage (foreground)    │                                   │
│  │  - onBackgroundMessage       │                                   │
│  │  - onMessageOpenedApp (tap)  │                                   │
│  │  - getInitialMessage (cold)  │                                   │
│  └──────────────────────────────┘                                   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ FCM send (HTTP v1)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   SERVER (Cloud Functions)                          │
│                                                                     │
│  Trigger: Firestore onCreate on group_chats/{id}/messages/{msg}     │
│                                                                     │
│  1. Read message doc → senderId, text, mentionedUids, pinnedUntil, │
│     type, chatId                                                    │
│  2. Read group_chat doc → members[], notificationStrategy map      │
│  3. For each member (skip sender):                                 │
│     a. Read their notificationStrategy for this chat                │
│     b. Determine tier based on message type + strategy              │
│     c. Build payload (full push vs silent data-only)                │
│     d. Retrieve FCM token from users/{uid}/fcmTokens                │
│     e. Send FCM message                                             │
│  4. Return                                                          │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ Firestore read
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        FIRESTORE                                     │
│                                                                      │
│  group_chats/{chatId}                                                │
│  ├── name, members[], createdBy, lastMessage, time, unreadCount{}    │
│  ├── members/{uid}                                                   │
│  │   └── notificationStrategy: "normal"|"mentionsOnly"|"muted"     │
│  └── messages/{msgId}                                                │
│      ├── senderId, senderName, text, timestamp, type, readBy[]       │
│      ├── mentionedUids: List<String>   ← NEW D-04                   │
│      ├── pinnedUntil: Timestamp       ← NEW D-11                    │
│      ├── editHistory[], isDeleted, taskId                            │
│      └── ...existing fields...                                       │
│                                                                      │
│  users/{uid}                                                         │
│  └── email, role, createdAt, emailVerified, fcmTokens[]  ← NEW      │
└─────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

No new directories needed. Add files alongside existing patterns:

```
lib/
├── pages/
│   └── home_hamburger/
│       └── channel_screen/
│           ├── group_chat_screen.dart          # MODIFY: _sendMessage, _MessageInputBar, message bubble rendering, pinned bar, notification toggle
│           ├── message.dart                    # MODIFY: add mentionedUids, pinnedUntil fields
│           └── message_actions.dart            # (unchanged)
├── services/
│   ├── task_service.dart                      # (unchanged)
│   └── notification_service.dart              # NEW: FCM init, token registration, onMessage/onBackgroundMessage/onMessageOpenedApp
└── main.dart                                  # MODIFY: add FirebaseMessaging.onBackgroundMessage initialization
```

### New File: `lib/services/notification_service.dart`

Centralizes all FCM lifecycle management:

```dart
// Core responsibilities:
// 1. Request permissions (Android auto-grants, iOS needs request)
// 2. Get FCM token on login, store in users/{uid}/fcmTokens
// 3. Listen onMessage (foreground) → show local notification via flutter_local_notifications
// 4. Register onBackgroundMessage top-level handler (30s isolate)
// 5. Listen onMessageOpenedApp → parse data payload → navigate to chat
// 6. Check getInitialMessage on cold start → navigate to chat
// 7. Create Android notification channels (tiered: high importance for @mentions/DMs, low for silent)
// 8. setForegroundNotificationPresentationOptions on iOS
```

### Pattern 1: @mention Autocomplete Custom Implementation
**What:** A custom overlay that appears when user types `@` in the message input, filters group members, and inserts the mention as `@DisplayName` on selection.
**When to use:** Only one trigger character (`@`), member list is already loaded in `_uidToName`. A full package is overkill.
**Example:**

```dart
// In _GroupChatScreenState:
final LayerLink _mentionLayerLink = LayerLink();
OverlayEntry? _mentionOverlay;
String _mentionQuery = '';
bool _showMentionSuggestions = false;

void _onTextChanged() {
  final text = _controller.text;
  final cursorPos = _controller.selection.baseOffset;
  if (cursorPos < 0 || cursorPos > text.length) {
    _removeMentionOverlay();
    return;
  }

  // Find the last @ before cursor
  final textBeforeCursor = text.substring(0, cursorPos);
  final atIndex = textBeforeCursor.lastIndexOf('@');
  if (atIndex == -1 || (atIndex > 0 && textBeforeCursor[atIndex - 1] != ' ' && atIndex != 0)) {
    _removeMentionOverlay();
    return;
  }

  final query = textBeforeCursor.substring(atIndex + 1);
  final filtered = _uidToName.entries
      .where((e) => e.value.toLowerCase().contains(query.toLowerCase()))
      .take(10)
      .toList();

  if (filtered.isEmpty) {
    _removeMentionOverlay();
    return;
  }

  _showMentionSuggestions = true;
  _mentionQuery = query;
  _showOrUpdateMentionOverlay(filtered);
}

void _selectMention(MapEntry<String, String> entry) {
  final text = _controller.text;
  final cursorPos = _controller.selection.baseOffset;
  final textBeforeCursor = text.substring(0, cursorPos);
  final atIndex = textBeforeCursor.lastIndexOf('@');
  final beforeAt = text.substring(0, atIndex);
  final afterCursor = text.substring(cursorPos);
  _controller.value = TextEditingValue(
    text: '$beforeAt@${entry.value} $afterCursor',
    selection: TextSelection.collapsed(offset: beforeAt.length + entry.value.length + 2),
  );
  _removeMentionOverlay();
}
```

### Pattern 2: Firestore Pinned Messages Query
**What:** Real-time stream filtering for active pinned messages.
**When to use:** In `_setupPinnedStream()` alongside `_setupMessagesStream()`.
**Key consideration:** This query needs a composite index on `group_chats/{chatId}/messages` (collection group not needed -- scoped to one chat).

```dart
StreamSubscription<QuerySnapshot>? _pinnedSubscription;

void _setupPinnedStream() {
  _pinnedSubscription = FirebaseFirestore.instance
      .collection('group_chats')
      .doc(widget.chat.id)
      .collection('messages')
      .where('pinnedUntil', isGreaterThan: Timestamp.now())
      .orderBy('pinnedUntil', descending: false)
      .snapshots()
      .listen((snapshot) {
    if (!mounted) return;
    setState(() {
      _pinnedMessages = snapshot.docs.map((doc) {
        // Parse to Message model with pinnedUntil
      }).toList();
    });
  });
}
```

**Composite index required:** `messages` collection, fields: `pinnedUntil ASC`, `__name__ ASC` (Firebase automatically creates this via error-link on first query run).

### Pattern 3: _sendMessage() with Mention/Pin Logic
**What:** Extend the existing `_sendMessage()` to parse `@DisplayName` mentions from the text body, extract their UIDs, and conditionally set `pinnedUntil`.
**When to use:** In the send flow, before the `messagesRef.add()` call.

```dart
Future<void> _sendMessage() async {
  final text = _controller.text.trim();
  if (text.isEmpty) return;
  // ... existing user/senderName setup ...

  // Parse @mentions
  final mentionRegex = RegExp(r'@(\w+(?: \w+)*)');
  final mentionMatches = mentionRegex.allMatches(text);
  final mentionedUids = <String>[];
  for (final match in mentionMatches) {
    final displayName = match.group(1)!;
    final uid = _uidToName.entries
        .firstWhere(
          (e) => e.value.toLowerCase() == displayName.toLowerCase(),
          orElse: () => const MapEntry('', ''),
        )
        .key;
    if (uid.isNotEmpty) mentionedUids.add(uid);
  }

  // Check for @everyone
  bool isEveryone = text.contains('@everyone') && _isFaculty;

  final messageData = <String, dynamic>{
    'senderId': user.uid,
    'senderName': senderName,
    'text': text,
    'timestamp': FieldValue.serverTimestamp(),
    'type': 'text',
    'readBy': [user.uid],
    'mentionedUids': mentionedUids,  // D-04
  };

  if (isEveryone) {
    messageData['pinnedUntil'] = Timestamp.fromDate(
      DateTime.now().add(const Duration(hours: 24)),  // D-06
    );
  }

  await messagesRef.add(messageData);
  // ... existing unreadCount update ...
}
```

### Anti-Patterns to Avoid
- **Storing FCM tokens in a Firestore array on the user doc without versioning:** Tokens can become stale (app reinstall, device change). Use a `fcmTokens` array with a periodic cleanup function or a Cloud Function that removes invalidated tokens.
- **Sending FCM messages directly from the Flutter client:** This exposes API keys. Always send from a trusted server environment (Cloud Functions).
- **Using `FieldValue.serverTimestamp()` for `pinnedUntil` locally:** The client cannot compare `Timestamp.now()` against `FieldValue.serverTimestamp()` reliably due to clock skew. Either store `pinnedUntil` as a client-side timestamp that matches the query filter offset, or use the server timestamp from the message write and calculate 24h on the server side.
- **Polling for pinned messages instead of streaming:** Use `snapshots()` not `get()` for real-time pin bar updates.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| FCM message dispatch | Custom server with raw HTTP calls | Firebase Cloud Functions (Firestore onCreate trigger) | Zero-infrastructure, built-in auth, automatic retry, co-located with Firestore |
| Local notification display | Native Android/iOS notification channels from Dart | `flutter_local_notifications` | Handles Android channel creation, iOS presentation options, cross-platform fallback |
| Background message handler | Isolate management code | Firebase.Messaging.onBackgroundMessage | Firebase handles isolate lifecycle, 30s execution window, re-initializes Firebase |
| FCM token management | Custom token refresh polling | `FirebaseMessaging.instance.onTokenRefresh` | Built-in stream for token changes, handles app reinstall / device migration |

**Key insight:** FCM has many edge cases (token refresh, notification delivery on foreground vs background, notification tap opening the app, Android notification channels, iOS permission dialogs, silent vs full push differentiation). Each of these has a well-established FlutterFire pattern. Don't deviate from the official usage docs.

## Common Pitfalls

### Pitfall 1: FCM onBackgroundMessage Must Be a Top-Level Function
**What goes wrong:** If you define the background handler as a class method or closure, the app crashes silently on background message receipt. Messages are lost.
**Why it happens:** The handler runs in a separate isolate and cannot access instance state, closures, or any non-top-level scope.
**How to avoid:** Define as a standalone function in its own file, call `Firebase.initializeApp()` inside it, and register it in `main()` before `runApp()`.
**Warning signs:** Background messages not being received, crash logs referencing isolate state.

### Pitfall 2: Firestore Array Contains Query + Complex Filters Don't Mix
**What goes wrong:** If you try `where('pinnedUntil', '>', now)` on the messages subcollection, and the message doc is large with `mentionedUids` array, performance is fine for subcollections (documents per chat are bounded). However, avoid collection-group queries across all chats -- that would be unindexable.
**Why it happens:** The `pinnedUntil` query is scoped to one chat's messages subcollection, so it only scans that chat's messages. That is efficient.
**How to avoid:** Keep the pinned query scoped to `group_chats/{chatId}/messages`. Do not use a collection group query.
**Warning signs:** Firestore "index required" error on first query run -- create the composite index from the error link.

### Pitfall 3: Notification Strategy Reads at Message Send Time
**What goes wrong:** If the server reads `notificationStrategy` at the moment a message is written, but the strategy changes before the server processes it, a user might get wrong-tier notifications.
**Why it happens:** Firestore triggers have eventual consistency with the trigger document, but reading related documents (the `members/{uid}` subcollection) can have read-after-write delays.
**How to avoid:** Accept millisecond-level staleness as acceptable. The strategy can be read from the `members/{uid}` doc at trigger time. If a user just changed their strategy, a one-message lag is acceptable.
**Warning signs:** Rare race condition, hard to reproduce.

### Pitfall 4: Silent Push vs Full Push Confusion
**What goes wrong:** Sending a "silent" message with FCM data-only payload may be treated as low priority by Android/iOS and not delivered reliably.
**Why it happens:** Data-only (silent) messages on Android need `priority: "high"` to be reliably delivered. iOS needs `content-available: 1` and specific APNs headers. Apple also discourages silent pushes that wake the app for non-essential purposes.
**How to avoid:** For silent pushes, set `android: { priority: "high" }` and `apns: { payload: { aps: { contentAvailable: true } }, headers: { "apns-push-type": "background", "apns-priority": "5" } }`. Only use silent pushes for badge count updates -- not for content delivery.
**Warning signs:** Users report missing badge updates but FCM console shows messages as "delivered."

### Pitfall 5: @everyone Faculty-Only Check on Client Side
**What goes wrong:** A malicious student could send a crafted Firestore write with `pinnedUntil` set (or reverse-engineer the @everyone check).
**Why it happens:** Client-side role checks are bypassable by anyone who can write to Firestore directly.
**How to avoid:** In addition to client-side role check, enforce in Firestore Security Rules:
```
function isFaculty() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'faculty';
}
allow write: if resource.data.pinnedUntil == null || isFaculty();
```
**Warning signs:** None until abuse occurs -- prevention required.

## Code Examples

### FCM Handler Registration (`lib/main.dart`)
```dart
// Source: https://firebase.flutter.dev/docs/messaging/usage
import 'package:firebase_messaging/firebase_messaging.dart';

// Must be top-level -- runs in separate isolate
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Can write to Firestore, make HTTP requests, schedule local notifications
  // Cannot update UI
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}
```

### FCM Token Registration + Message Listeners (`lib/services/notification_service.dart`)
```dart
// Source: https://firebase.flutter.dev/docs/messaging/usage
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Create notification channels (Android)
    const androidChannel = AndroidNotificationChannel(
      'high_importance_channel',  // id
      'Important Notifications',  // name
      description: 'For @mentions, DMs, and task notifications',
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    const silentChannel = AndroidNotificationChannel(
      'silent_channel',
      'Silent Notifications',
      description: 'For badge-only updates',
      importance: Importance.min,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(silentChannel);

    // 2. Request permissions (iOS only, no-op on Android)
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Get initial FCM token
    final token = await _firebaseMessaging.getToken();
    if (token != null) await _saveToken(token);

    // 4. Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveToken);

    // 5. Handle foreground messages (show local notification)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 6. Handle notification tap (from background state)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 7. Check if app was opened from a terminated notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show local notification using flutter_local_notifications
    // Parse message.data to determine which channel to use
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Parse message.data.chatId and message.data.chatType
    // Navigate to GroupChatScreen or IndividualChatScreen
  }
}
```

### Mention Highlight in Message Bubble
```dart
// In _MessageBubble.build(), after determining message.isMe:
final isMentioned = message.mentionedUids.contains(currentUid);

// Replace Container decoration:
decoration: BoxDecoration(
  color: isMentioned
      ? (isMe ? AppColors.primary.withValues(alpha: 0.8) : Colors.amber.withValues(alpha: 0.3))
      : isMe ? AppColors.primary : const Color(0xFFF0F0F0),
  borderRadius: BorderRadius.only(...),
),

// Add @ badge for everyone (non-mentioned users):
// Near the sender name or timestamp:
if (!isMentioned && !isMe && message.mentionedUids.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Icon(Icons.alternate_email, size: 12, color: AppColors.textSecondary),
  ),
```

### Firestore Security Rules for @everyone
```javascript
// Prevent non-faculty from setting pinnedUntil
match /group_chats/{chatId}/messages/{messageId} {
  allow create: if request.auth != null;
  allow update: if request.auth != null
    && (!request.resource.data.keys.hasAny(['pinnedUntil'])
        || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'faculty');
}
```

## Runtime State Inventory

> This section is omitted -- Phase 7 is a greenfield feature addition, not a rename/refactor/migration.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Announcement feature (deleted file) | @everyone with auto-pin bar | This phase | More flexible, persistent in chat stream, replaces old announcement UI entirely |
| No push notifications | Full FCM tiered delivery | This phase | Users get real-time alerts; requires server-side dispatch |
| No @mention system | @user mentions with autocomplete + highlights | This phase | Discord/Slack-style collaboration patterns |
| firebase_messaging not in dependency tree | firebase_messaging ^16.2.2 | This phase | Requires Android manifest metadata for default notification channel |

**Deprecated/outdated:**
- Announcement feature files (`announcement_button/`, `announcement_dialog.dart`) were already deleted in prior commits. @everyone is the replacement.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Firestore composite index for `pinnedUntil` query on messages subcollection is auto-created via error link | Architecture Patterns | Low -- Firebase provides the index creation URL in the error response. Just needs one manual click. |
| A2 | Cloud Functions is the appropriate FCM dispatch mechanism | Standard Stack | Medium -- If no Firebase Blaze plan is available, need a lightweight Node.js server instead |
| A3 | FCM tokens stored in `users/{uid}/fcmTokens` array | Code Examples | Medium -- Could use a subcollection for versioned tokens |
| A4 | Android minSdkVersion (24) is sufficient for firebase_messaging | Standard Stack | Low -- firebase_messaging has required API 21+ for years |
| A5 | `flutter_local_notifications` ^21.0.0 is compatible with Flutter 3.41 | Standard Stack | Low -- verified via `flutter pub add --dry-run`, resolved successfully |

## Open Questions

1. **FCM Dispatch: Cloud Functions vs separate server?**
   - What we know: Firebase Cloud Functions (Firestore onCreate trigger) is the canonical pattern. It runs in the same GCP project, has built-in auth, and can use `firebase-admin` directly.
   - What's unclear: Whether the Firebase project has Cloud Functions enabled (requires Blaze plan). Initial check shows google-services.json exists but no `functions/` directory.
   - Recommendation: Assume Cloud Functions. If Blaze plan is not available or user prefers minimal infrastructure, the fallback is a lightweight Node.js server (e.g., Railway, Render) that listens to Firestore changes via the Admin SDK's `onSnapshot` listener.

2. **Silent push badge count implementation?**
   - What we know: D-18 specifies silent push = badge count, no banner/sound.
   - What's unclear: How badge count should be calculated. Per-chat unread count is already stored in `group_chats/{chatId}/unreadCount.{uid}`.
   - Recommendation: The FCM data payload for silent pushes includes `{ "badge": <unread_count>, "chatId": <id>, "type": "silent" }`. On receipt, the client can set the app icon badge number. This works cross-platform.

3. **@everyone Faculty check -- how to verify server-side?**
   - What we know: Client checks `_isFaculty`. D-05 says "Checked server-side via role lookup or `createdBy`."
   - What's unclear: The Cloud Function trigger receives the new message doc. It needs to verify the sender is faculty before processing `pinnedUntil`. It can do this by reading `users/{senderId}/role`.
   - Recommendation: Cloud Function reads sender role from Firestore. If not faculty, return early without processing `pinnedUntil` (but still dispatch the message normally).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `firebase_messaging` | FCM token registration/handling | No (not in pubspec) | ^16.2.2 (dry-run verified) | Add with `flutter pub add firebase_messaging` |
| `flutter_local_notifications` | Foreground notification display | No (not in pubspec) | ^21.0.0 (dry-run verified) | Add with `flutter pub add flutter_local_notifications` |
| `cloud_firestore` | Mention/pin storage, strategy storage | Yes | ^6.1.3 | Already in project |
| `firebase_core` | Firebase initialization | Yes | ^4.5.0 | Already in project |
| Flutter 3.41.4 | All | Yes | 3.41.4 | SDK constraint satisfied |
| Dart 3.11.1 | All | Yes | 3.11.1 | SDK constraint satisfied |
| Firebase Cloud Functions | FCM dispatch | Unknown | -- | Fallback: standalone Node.js server |
| Firebase Blaze plan | Cloud Functions | Unknown | -- | Fallback: standalone Node.js server |

**Missing dependencies with no fallback:**
- `firebase_messaging` and `flutter_local_notifications` must be added to pubspec.yaml before any FCM code compiles.

**Missing dependencies with fallback:**
- Cloud Functions (if Blaze plan unavailable) -- use a standalone Node.js/TypeScript server with the Firebase Admin SDK that listens to Firestore changes.

## Validation Architecture

> `workflow.nyquist_validation` is `true` in config.json -- this section is required.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (Dart SDK 3.11.1) |
| Config file | `test/` directory exists with existing tests |
| Quick run command | `flutter test test/path/to/test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| D-04 | Message model includes `mentionedUids` field | unit | `flutter test test/widget_test.dart` (update) | Existing, needs update |
| D-11 | Message model includes `pinnedUntil` field | unit | `flutter test test/widget_test.dart` (update) | Existing, needs update |
| D-01 | Autocomplete overlay appears on @ | widget | NEW: `flutter test test/mention_autocomplete_test.dart` | Awaiting Wave 0 |
| D-03 | Mentioned messages have highlight tint | widget | NEW: `flutter test test/mention_highlight_test.dart` | Awaiting Wave 0 |
| D-06 | @everyone writes pinnedUntil 24h | integration | NEW: `flutter test test/everyone_pin_test.dart` | Awaiting Wave 0 |
| D-14 | Members subcollection stores notificationStrategy | unit | NEW: `flutter test test/notification_strategy_test.dart` | Awaiting Wave 0 |
| D-15 | FCM token registered on login | integration | Manual | No FCM test utilities available |
| D-16 | Tiered notification delivery | integration | Manual | Requires Cloud Functions |

### Sampling Rate
- **Per task commit:** `flutter test test/widget_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/mention_autocomplete_test.dart` -- covers D-01 (autocomplete overlay)
- [ ] `test/mention_highlight_test.dart` -- covers D-03 (highlight tint, @badge)
- [ ] `test/everyone_pin_test.dart` -- covers D-06, D-10 (pinnedUntil write, faculty gate)
- [ ] `test/notification_strategy_test.dart` -- covers D-14, D-20 (subcollection reads/writes)
- [ ] Update `test/widget_test.dart` -- add `mentionedUids` and `pinnedUntil` to Message model tests

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | Firebase Auth (existing) |
| V4 Access Control | Yes | Firestore Security Rules for pinnedUntil write gate |
| V5 Input Validation | Yes | @everyone regex check, @DisplayName sanitization |
| V6 Cryptography | Yes | FCM transport encryption (built-in) |
| V17 Communications Security | Yes | FCM uses TLS (built-in) |

### Known Threat Patterns for Flutter/Firebase Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unauthorized @everyone use (student sets pinnedUntil) | Elevation of Privilege | Firestore Security Rules: `allow write: if !request.resource.data.keys.hasAny(['pinnedUntil']) || isFaculty()` |
| FCM token spoofing | Spoofing | FCM tokens are generated by Google Play Services / APNs, not user-controlled |
| Notification spam (large group @everyone) | Denial of Service | Rate limiting on Cloud Functions (max 1 @everyone per N minutes per chat) |
| @mention list leakage (non-member can see member list) | Information Disclosure | @autocomplete uses `_uidToName` which is already loaded from group membership -- no new exposure |

## Sources

### Primary (HIGH confidence)
- [firebase_messaging pub.dev] -- version 16.2.2, setup requirements, platform support
- [flutter_local_notifications pub.dev] -- version 21.0.0, channel creation API
- [FCM FlutterFire Usage Docs](https://firebase.flutter.dev/docs/messaging/usage) -- onMessage, onBackgroundMessage, onMessageOpenedApp, getToken, permissions
- [FCM FlutterFire Notifications Docs](https://firebase.flutter.dev/docs/messaging/notifications) -- notification channels, foreground handling, iOS options
- [FCM FlutterFire Overview](https://firebase.flutter.dev/docs/messaging/overview) -- installation steps

### Secondary (MEDIUM confidence)
- [multi_trigger_autocomplete pub.dev] -- v1.0.0, verified but 2 years stale, requires flutter_portal
- [perfect_text_field pub.dev] -- v2.3.2+3, most recent mention package, 18 weekly downloads
- Flutter 3.41.4, Dart 3.11.1 -- verified via `flutter --version`, `dart --version`

### Tertiary (LOW confidence)
- Firebase project's Blaze plan status -- cannot verify from local files. Cloud Functions may not be available.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- verified via `flutter pub add --dry-run` and official Firebase docs
- Architecture: HIGH -- patterns directly map to existing codebase (`group_chat_screen.dart` stream pattern, `_MessageInputBar` pattern)
- Pitfalls: HIGH -- based on official Firebase docs warnings and common FCM anti-patterns documented by FlutterFire team

**Research date:** 2026-05-16
**Valid until:** 2026-06-16 (30 days -- Flutter ecosystem moves moderately; FCM API is stable)