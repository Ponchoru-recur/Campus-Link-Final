# Phase 1: Clean Slate & Data Model - Context

**Gathered:** 2026-05-04
**Status:** Ready for planning

<domain>
## Phase Boundary

**Delivers:** Remove hardcoded dummy instructor chats and establish Firestore schema for 1-on-1 messaging.

**In scope:**
- Remove `_instructorChats` dummy data from `chats_screen.dart`
- Define `direct_messages` collection schema (was `instructor_chats` in roadmap)
- Define `direct_messages/{chatId}/messages/{messageId}` subcollection schema
- Create Dart models: `DirectMessageItem`, update `ChatType` enum

**Out of scope:**
- Wiring up Firestore streams (Phase 2)
- Building individual chat screen (Phase 2)
- Auto-wiring contacts (Phase 3)
- Search/add contacts (Phase 4)

</domain>

<decisions>
## Implementation Decisions

### Collection & Field Naming
- **D-01:** Collection name = `direct_messages` (not `instructor_chats`). Generic name future-proofs for student-student DMs if added later (Phase 4 mentions "student peers").
- **D-02:** Field name = `members[]` (matches `group_chats` convention). Not `participants[]` as originally in roadmap.

### Unread Count Structure
- **D-03:** Use Map field `unreadCount: {uid1: count1, uid2: count2}` for per-participant tracking. When constructing `DirectMessageItem`, read `unreadCount[user.uid]`. When user opens chat, set `unreadCount[user.uid] = 0`.

### Phase 1 Scope
- **D-04:** Create Dart models in Phase 1 for Phase 2 reuse:
  - `DirectMessageItem` class (similar to `ChatItem` but with `otherParticipantName`, `otherParticipantUid`, `otherParticipantRole`)
  - Update `ChatType` enum to include `directMessage` (was `groupChat` and `instructor`)

### Claude's Discretion
- Message subcollection fields match group chat `Message` model exactly (`senderId`, `senderName`, `text`, `timestamp`, `readBy`, `type`, `editHistory`, `isDeleted`)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Definition
- `.planning/ROADMAP.md` §Phase1 — Goal, requirements (IDM-01, DB-01, DB-02, DB-03), success criteria
- `.planning/REQUIREMENTS.md` §IDM/DB — Requirement details for Instructor DM and Firestore Structure

### Existing Code (Reuse Patterns)
- `lib/pages/home_hamburger/channel_screen/chat_item.dart` — `ChatItem` model to mirror for `DirectMessageItem`
- `lib/pages/home_hamburger/channel_screen/message.dart` — `Message` model (same fields for DM messages)
- `lib/pages/home_hamburger/channel_screen/chats_screen.dart` — Remove `_instructorChats`, prepare for Firestore stream
- `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` — Pattern to follow for Phase 2 chat screen
- `lib/themes/app_colors.dart` — `AppColors` for any new UI elements

### Data Models
- `.planning/codebase/ARCHITECTURE.md` — StatefulWidget + StreamBuilder pattern, Firestore stream conventions
- `.planning/codebase/INTEGRATIONS.md` — Firestore collection structure, query patterns (`arrayContains`)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`ChatItem` model** (`chat_item.dart`): Mirror for `DirectMessageItem` — `id`, `name`/`otherParticipantName`, `lastMessage`, `time`, `type`, `unreadCount`
- **`Message` model** (`message.dart`): Reuse exactly for DM messages subcollection
- **`GroupChatScreen`** (`group_chat_screen.dart`): Pattern for Phase 2 individual chat screen (StreamBuilder, message list, send message)

### Established Patterns
- **StatefulWidget + StreamBuilder** for real-time Firestore data
- **`setState()`** for local widget state
- **`StreamSubscription`** for Firestore streams (cancel in `dispose`)
- **`shared_preferences`** for simple persistent state

### Integration Points
- **`chats_screen.dart`**: Remove `_instructorChats` list and its `ListView` rendering; prepare for `direct_messages` stream in Phase 2
- **`ChatType` enum** (`chat_item.dart`): Add `directMessage` value
- **New file(s)**: `lib/pages/home_hamburger/channel_screen/direct_message_item.dart` (or merge into `chat_item.dart`)

</code_context>

<specifics>
## Specific Ideas

- `direct_messages` collection uses `members[]` (consistent with `group_chats`)
- Message subcollection: `direct_messages/{chatId}/messages/{messageId}` with same fields as group chat messages
- `DirectMessageItem` should include `otherParticipantUid` and `otherParticipantRole` for display

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 1-Clean Slate & Data Model*
*Context gathered: 2026-05-04*
