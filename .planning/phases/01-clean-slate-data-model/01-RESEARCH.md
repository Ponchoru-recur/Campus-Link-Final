# Phase 1: Clean Slate & Data Model - Research

**Researched:** 2026-05-04
**Domain:** Flutter + Cloud Firestore (direct messaging data model)
**Confidence:** HIGH (code-verified) / MEDIUM (Firestore schema patterns from training)

## Summary

Phase 1 removes hardcoded `_instructorChats` dummy data from `chats_screen.dart` and establishes the Firestore schema for 1-on-1 direct messaging. The collection is named `direct_messages` (decision D-01) to future-proof for student-student DMs. The schema mirrors `group_chats` patterns: `members[]` array field (not `participants[]`), Map-based `unreadCount` for per-participant tracking, and subcollection `messages` with identical fields to group chat messages.

The existing codebase provides clear patterns: `ChatItem` model in `chat_item.dart`, `Message` model in `message.dart`, and `arrayContains` query in `chats_screen.dart` line 82. Phase 1 creates `DirectMessageItem` model and updates `ChatType` enum to include `directMessage`.

**Primary recommendation:** Mirror `group_chats` schema exactly for `direct_messages`, reuse `Message` model unchanged for subcollection, and remove `_instructorChats` as a clean deletion (no replacement UI yet -- Phase 2 adds Firestore stream).

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Collection name = `direct_messages` (not `instructor_chats`). Generic name future-proofs for student-student DMs if added later (Phase 4 mentions "student peers").
- **D-02:** Field name = `members[]` (matches `group_chats` convention). Not `participants[]` as originally in roadmap.
- **D-03:** Use Map field `unreadCount: {uid1: count1, uid2: count2}` for per-participant tracking. When constructing `DirectMessageItem`, read `unreadCount[user.uid]`. When user opens chat, set `unreadCount[user.uid] = 0`.
- **D-04:** Create Dart models in Phase 1 for Phase 2 reuse:
  - `DirectMessageItem` class (similar to `ChatItem` but with `otherParticipantName`, `otherParticipantUid`, `otherParticipantRole`)
  - Update `ChatType` enum to include `directMessage` (was `groupChat` and `instructor`)

### Claude's Discretion
- Message subcollection fields match group chat `Message` model exactly (`senderId`, `senderName`, `text`, `timestamp`, `readBy`, `type`, `editHistory`, `isDeleted`)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| IDM-01 | Remove hardcoded `_instructorChats` dummy data from `chats_screen.dart` | Located at lines 114-130; clean deletion, no replacement UI |
| DB-01 | Create `direct_messages/{chatId}` document structure: `members[]`, `lastMessage`, `time`, `createdAt`, `unreadCount` Map | Schema defined below, mirrors `group_chats` convention |
| DB-02 | Create `direct_messages/{chatId}/messages/{messageId}` subcollection with same fields as group chat messages | Reuse `Message` model from `message.dart` unchanged |
| DB-03 | Create index or query pattern for fetching a user's DM list (query where `members arrayContains` user.uid) | Same pattern as `group_chats` query at `chats_screen.dart:82` |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Direct message list query | API / Backend (Firestore) | Frontend (StreamBuilder) | Firestore query with `arrayContains` runs server-side; StreamBuilder renders results |
| Direct message data model | Frontend (Dart models) | — | `DirectMessageItem` and `Message` are Dart classes for type-safe UI consumption |
| Unread count per participant | API / Backend (Firestore Map) | Frontend (read/write) | Map field `unreadCount` stored in Firestore document; UI reads/writes specific uid key |
| Dummy data removal | Frontend (chats_screen.dart) | — | Purely local code deletion; no backend changes |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| cloud_firestore | ^6.1.3 | Firestore DB access | Already in pubspec.yaml, used for group_chats [VERIFIED: pubspec.yaml] |
| firebase_auth | ^6.2.0 | Current user UID for queries | Already in pubspec.yaml, used in chats_screen.dart [VERIFIED: pubspec.yaml] |
| flutter | 3.41.4 / Dart 3.11.1 | UI framework | Project SDK [VERIFIED: flutter --version] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| shared_preferences | ^2.2.2 | Pending verification state | Already used for `pending_role` in AuthWrapper [VERIFIED: pubspec.yaml] |

**Installation:**
```bash
flutter pub get
```
All dependencies already present in pubspec.yaml. Run `flutter pub get` to ensure resolved.

**Version verification:**
- `flutter --version` → Flutter 3.41.4, Dart 3.11.1 [VERIFIED]
- `cloud_firestore` → ^6.1.3 in pubspec.yaml [VERIFIED]

## Architecture Patterns

### System Architecture Diagram

```
[User] → [ChatsScreen] → [Firestore: direct_messages collection]
                ↓
         (Phase 2) StreamBuilder ← where('members', arrayContains: uid)
                ↓
         DirectMessageItem list tiles
                ↓
         (Phase 2) DirectMessageScreen → [Firestore: direct_messages/{id}/messages subcollection]
```

Data flow: User opens ChatsScreen → StreamBuilder queries `direct_messages` where `members` arrayContains `user.uid` → Documents mapped to `DirectMessageItem` list → Tiles rendered → Tap opens DM screen (Phase 2) with messages subcollection stream.

### Recommended Project Structure
```
lib/pages/home_hamburger/channel_screen/
├── chat_item.dart          # ChatItem model, ChatType enum (UPDATE: add directMessage)
├── direct_message_item.dart # NEW: DirectMessageItem model
├── chats_screen.dart       # REMOVE _instructorChats, prepare for DM stream
├── group_chat_screen.dart  # Reference pattern for Phase 2 DM screen
├── message.dart            # REUSE for DM messages subcollection
└── direct_chat_screen.dart # Phase 2: New file (not Phase 1)
```

### Pattern 1: arrayContains Query for User's DM List
**What:** Query Firestore collection where an array field contains the current user's UID.
**When to use:** Fetching all DMs where current user is a participant.
**Example:**
```dart
// Source: [VERIFIED: chats_screen.dart line 80-84]
FirebaseFirestore.instance
    .collection('direct_messages')
    .where('members', arrayContains: user.uid)
    .snapshots()
    .listen((snapshot) {
  // snapshot.docs contains all DM documents where members[] contains user.uid
});
```
**Note:** Identical pattern to `group_chats` query at `chats_screen.dart:82` [VERIFIED].

### Pattern 2: Map Field for Per-Participant Unread Count
**What:** Use Firestore Map field to track unread count per user, not a single integer.
**When to use:** Direct messages with exactly 2 participants; each user needs their own unread counter.
**Example:**
```dart
// Source: [ASSUMED] - Standard Firestore Map field pattern
// Document structure in Firestore:
// direct_messages/{chatId}:
//   members: ['uid1', 'uid2']
//   unreadCount: { 'uid1': 3, 'uid2': 0 }
//   lastMessage: 'Hello there'
//   time: '10:30 AM'
//   createdAt: <timestamp>

// Reading current user's unread count:
final unreadForMe = (doc['unreadCount'] as Map<String, dynamic>)[user.uid] ?? 0;

// Resetting unread count when user opens chat:
await FirebaseFirestore.instance
    .collection('direct_messages')
    .doc(chatId)
    .update({ 'unreadCount.${user.uid}': 0 });
```

### Anti-Patterns to Avoid
- **Using `participants[]` instead of `members[]`:** Breaks convention with `group_chats` schema. Always use `members[]` per decision D-02.
- **Single integer `unreadCount`:** Cannot track per-participant. Must use Map field per D-03.
- **Keeping `ChatType.instructor`:** Phase 1 should rename/update to `directMessage` to match new collection name. Old `instructor` value is stale.
- **Creating new Message model:** Reuse existing `Message` class from `message.dart` unchanged.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DM list query | Custom filtered list from all DMs | `arrayContains` Firestore query | Server-side filtering, real-time updates, matches `group_chats` pattern [VERIFIED: chats_screen.dart] |
| Per-user unread tracking | Separate counter documents | Firestore Map field `unreadCount` | Atomic updates, single document read, standard pattern [ASSUMED] |
| Message data model | New DM-specific message class | Existing `Message` model from `message.dart` | Identical fields, `isEdited` getter, `readBy` array [VERIFIED: message.dart] |

**Key insight:** The existing codebase already solved these problems for group chats. Mirror, don't reinvent.

## Runtime State Inventory

> Rename/refactor phase only -- Step 2.5 not applicable (no rename in Phase 1).

**Note:** Phase 1 removes `_instructorChats` (in-memory dummy data). No runtime state changes -- the list exists only in Dart code, not in Firestore, SharedPreferences, or OS-registered state.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None -- no `direct_messages` collection exists in Firestore yet | None |
| Live service config | None -- Firestore collections are schema-less at rest | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

## Common Pitfalls

### Pitfall 1: Leaving `ChatType.instructor` After Adding `directMessage`
**What goes wrong:** Both `instructor` and `directMessage` exist in enum, causing confusion about which to use.
**Why it happens:** Incremental updates without cleaning up deprecated values.
**How to avoid:** Remove `instructor` from `ChatType` enum when adding `directMessage`. Update all references (there are none yet beyond `_instructorChats` which is deleted).
**Warning signs:** Enum has both `instructor` and `directMessage` values.

### Pitfall 2: Using `arrayContains` on `unreadCount` Map
**What goes wrong:** Trying to query `where('unreadCount', arrayContains: user.uid)` -- fails because `unreadCount` is a Map, not an array.
**Why it happens:** Confusing the `members[]` array field with the `unreadCount` Map field.
**How to avoid:** Remember: `arrayContains` only works on Array fields. `unreadCount` is a Map -- access via `unreadCount[user.uid]`.
**Warning signs:** Firestore query errors mentioning "field is not an array".

### Pitfall 3: Forgetting to Cancel StreamSubscription
**What goes wrong:** Memory leaks when ChatsScreen disposes but Firestore stream keeps listening.
**Why it happens:** Following `group_chats` stream pattern but forgetting to add DM subscription to dispose.
**How to avoid:** In Phase 2, mirror the `_groupChatsSubscription` pattern: store `StreamSubscription? _dmSubscription;` and cancel in `dispose()`.
**Warning signs:** Debug console shows Firestore stream errors after navigating away. [VERIFIED: chats_screen.dart lines 27, 107-112]

## Code Examples

### DirectMessageItem Model (to create)
```dart
// Source: [ASSUMED] - Mirrors ChatItem pattern from chat_item.dart
class DirectMessageItem {
  final String id;
  final String otherParticipantName;
  final String otherParticipantUid;
  final String? otherParticipantRole; // 'faculty' or 'student'
  final String lastMessage;
  final String time;
  final int unreadCount;
  final ChatType type = ChatType.directMessage;

  const DirectMessageItem({
    required this.id,
    required this.otherParticipantName,
    required this.otherParticipantUid,
    this.otherParticipantRole,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
  });

  // Factory to create from Firestore doc + current user UID
  factory DirectMessageItem.fromFirestore(
    DocumentSnapshot doc,
    String currentUserId,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final members = List<String>.from(data['members'] ?? []);
    final otherUid = members.firstWhere(
      (uid) => uid != currentUserId,
      orElse: () => '',
    );
    // Note: otherParticipantName and role fetched separately or stored in doc
    return DirectMessageItem(
      id: doc.id,
      otherParticipantName: data['otherParticipantName'] ?? 'Unknown',
      otherParticipantUid: otherUid,
      otherParticipantRole: data['otherParticipantRole'],
      lastMessage: data['lastMessage'] ?? '',
      time: data['time'] ?? 'Now',
      unreadCount: (data['unreadCount'] is Map)
          ? (data['unreadCount'][currentUserId] ?? 0)
          : 0,
    );
  }
}
```

### Updated ChatType Enum
```dart
// Source: [VERIFIED: chat_item.dart line 22]
// REPLACE existing enum:
enum ChatType { groupChat, directMessage }
// Remove 'instructor' -- replaced by directMessage
```

### Firestore Document Structure (direct_messages/{chatId})
```dart
// Source: [ASSUMED] - Standard Firestore document pattern
// Document fields:
{
  'members': ['uid1', 'uid2'],           // Array, matches group_chats convention
  'lastMessage': 'Hello',                // String
  'time': '10:30 AM',                   // String (or use Timestamp)
  'createdAt': FieldValue.serverTimestamp(), // Firestore Timestamp
  'unreadCount': {                       // Map field for per-participant
    'uid1': 0,
    'uid2': 2,
  },
  'otherParticipantName': 'Dr. Smith',   // Denormalized for list display
  'otherParticipantRole': 'faculty',     // Denormalized for styling
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ChatType.instructor` | `ChatType.directMessage` | Phase 1 | Aligns with `direct_messages` collection name |
| `_instructorChats` hardcoded list | Firestore `direct_messages` collection | Phase 1 → Phase 2 | Data moves from in-memory to persistent Firestore |
| `participants[]` (roadmap) | `members[]` (decision D-02) | Phase 1 | Consistent with `group_chats` schema |

**Deprecated/outdated:**
- `ChatType.instructor`: Replaced by `directMessage` in Phase 1.
- `_instructorChats` const list: Deleted in Phase 1 (lines 114-130 of chats_screen.dart).
- Roadmap's `instructor_chats` collection name: Replaced by `direct_messages` per D-01.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Firestore Map fields can store per-user unreadCount with dot-notation updates (`unreadCount.${uid}`) | Don't Hand-Roll, Code Examples | If Map field updates don't work as expected, need alternative (separate counter doc) |
| A2 | `Message` model from `message.dart` works unchanged for DM subcollection | Standard Stack, Architecture Patterns | If DM messages need different fields, must update model (but CONTEXT.md says reuse exactly) |
| A3 | `direct_messages` collection can use identical query pattern to `group_chats` | Architecture Patterns, Code Examples | If Firestore limits apply differently, need alternative query strategy |
| A4 | Removing `ChatType.instructor` won't break anything beyond `_instructorChats` | Common Pitfalls | If other code references `ChatType.instructor`, will get compile error (easy fix) |

## Open Questions

1. **Should `direct_messages` documents store `otherParticipantName` and `otherParticipantRole` denormalized, or fetch from `users` collection?**
   - What we know: Group chats only store `name` in the document itself [VERIFIED: chats_screen.dart line 91]
   - What's unclear: Whether to denormalize participant info or do a separate `users` fetch
   - Recommendation: Denormalize `otherParticipantName` and `otherParticipantRole` in `direct_messages` doc for list display performance (same as group chats). Store during DM creation.

2. **Should `time` field be a String or Firestore Timestamp?**
   - What we know: `group_chats` uses String `'Now'` [VERIFIED: chats_screen.dart line 93]
   - What's unclear: Whether to migrate to Timestamp for proper sorting
   - Recommendation: Use Timestamp for `createdAt` and last message time. Group chats use String for simplicity; DMs should use Timestamp for correct chronological order.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter | All UI code | ✓ | 3.41.4 | — |
| Dart | All Dart code | ✓ | 3.11.1 | — |
| cloud_firestore | Firestore queries | ✓ | ^6.1.3 | — |
| Firebase Auth | User UID for queries | ✓ | ^6.2.0 | — |
| Firebase project | Firestore DB | ✓ | campus-link-aac60 | — |

**Missing dependencies with no fallback:**
- None

**Missing dependencies with fallback:**
- None

## Validation Architecture

> `workflow.nyquist_validation: true` in `.planning/config.json` -- section included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | None — see Wave 0 |
| Quick run command | `flutter test test/widget_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IDM-01 | `_instructorChats` removed from `chats_screen.dart` | static analysis / grep | `grep -q '_instructorChats' lib/pages/home_hamburger/channel_screen/chats_screen.dart && exit 1 || exit 0` | ❌ Wave 0 |
| DB-01 | `DirectMessageItem` model exists with correct fields | unit | `flutter test test/direct_message_item_test.dart` | ❌ Wave 0 |
| DB-02 | `Message` model reusable for DM subcollection | unit (existing) | `flutter test test/message_test.dart` | ❌ Wave 0 |
| DB-03 | `arrayContains` query pattern documented/implementable | static analysis | N/A — pattern verified in codebase | ✅ (in codebase) |

### Sampling Rate
- **Per task commit:** `flutter test test/widget_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/direct_message_item_test.dart` — covers DB-01 (model creation, `fromFirestore` factory)
- [ ] `test/message_test.dart` — covers DB-02 (reuse of Message model, fields verification)
- [ ] `test/chats_screen_test.dart` — covers IDM-01 (`_instructorChats` removal verification)
- [ ] `test/chat_item_test.dart` — covers ChatType enum update (remove `instructor`, add `directMessage`)

*(Note: test directory is currently empty per CLAUDE.md "Known Issues: No tests")*

## Security Domain

> `security_enforcement` not set to `false` in config -- section included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | `FirebaseAuth.instance.authStateChanges()` in AuthWrapper [VERIFIED: main.dart] |
| V3 Session Management | No | DM sessions not applicable (Firestore real-time) |
| V4 Access Control | Yes | `arrayContains` query ensures user only sees DMs where they are a member [ASSUMED] |
| V5 Input Validation | Yes | `@carsu.edu.ph` domain regex for contact search (Phase 4) [VERIFIED: CLAUDE.md] |
| V6 Cryptography | No | No custom crypto -- Firebase handles auth tokens |

### Known Threat Patterns for Flutter + Firestore

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unauthorized DM access | Information Disclosure | Firestore security rules: only `members` can read/write (Phase future: SEC-04) [ASSUMED] |
| Domain bypass in contact search | Spoofing | Enforce `^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$` regex [VERIFIED: CLAUDE.md] |
| Message tampering | Tampering | Firestore rules validate `senderId` matches auth uid (Phase future) [ASSUMED] |

## Sources

### Primary (HIGH confidence)
- `chats_screen.dart` lines 80-84, 114-130 — `arrayContains` pattern, `_instructorChats` location [VERIFIED: Read tool]
- `chat_item.dart` lines 1-22 — `ChatItem` model, `ChatType` enum [VERIFIED: Read tool]
- `message.dart` lines 1-36 — `Message` model fields [VERIFIED: Read tool]
- `pubspec.yaml` — Dependency versions [VERIFIED: Read tool]
- `flutter --version` — Flutter 3.41.4, Dart 3.11.1 [VERIFIED: Bash tool]
- CONTEXT.md (01-CONTEXT.md) — All decisions D-01 through D-04 [VERIFIED: Read tool]
- ROADMAP.md — Phase 1 goal and success criteria [VERIFIED: Read tool]
- REQUIREMENTS.md — IDM-01, DB-01, DB-02, DB-03 details [VERIFIED: Read tool]

### Secondary (MEDIUM confidence)
- None (WebSearch unavailable due to API credits, WebFetch blocked by context-mode hook)

### Tertiary (LOW confidence)
- Firestore Map field dot-notation updates [ASSUMED: training knowledge]
- Firestore subcollection behavior identical to group_chats [ASSUMED: training knowledge]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All dependencies verified from pubspec.yaml and codebase
- Architecture: HIGH - Patterns verified from existing code (arrayContains, ChatItem, Message)
- Pitfalls: MEDIUM - Some from training knowledge (stream subscription dispose pattern verified)

**Research date:** 2026-05-04
**Valid until:** 2026-06-03 (30 days for stable Flutter/Firestore ecosystem)
