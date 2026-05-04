# Requirements — Campus Link (Luminescence)

## v1 Requirements (Active)

### Instructor Direct Messaging (IDM)

- [ ] **IDM-01**: Remove hardcoded `_instructorChats` dummy data from `lib/pages/home_hamburger/channel_screen/chats_screen.dart`
- [ ] **IDM-02**: Create Firestore `instructor_chats` collection (or equivalent) for 1-on-1 messaging between students and instructors
- [ ] **IDM-03**: When a student joins a group chat, auto-add instructors who are members of that group chat to the student's individual DM contact list
- [ ] **IDM-04**: When an instructor is added to a group chat, auto-add them to all existing members' individual DM contact lists
- [ ] **IDM-05**: Build individual chat conversation screen with real-time Firestore stream (similar to `group_chat_screen.dart` but 1-on-1)
- [ ] **IDM-06**: Add search bar in the chat list screen to search and add student peers or instructor peers as individual contacts
- [ ] **IDM-07**: Search must restrict to `@carsu.edu.ph` domain (reuse existing regex validation)
- [ ] **IDM-08**: Visually distinguish instructor DMs from student DMs in the chat list (e.g., purple accent for instructors, different tile styling)
- [ ] **IDM-09**: Instructors in DMs should display a role badge or distinct visual indicator (use `AppColors.instructorPurple`)
- [ ] **IDM-10**: Student DMs should have standard styling (different from instructor styling)
- [ ] **IDM-11**: Individual DMs should be private 1-on-1 conversations (not group chats)
- [ ] **IDM-12**: Send/receive messages in individual DMs with real-time sync (Firestore subcollection under DM document)
- [ ] **IDM-13**: Read receipts for individual DMs (per-message `readBy` array, similar to group chat messages)
- [ ] **IDM-14**: Instructors added to group chats get admin privileges (same as faculty) — already partially implemented, verify
- [ ] **IDM-15**: DM list should show last message, timestamp, and unread count per conversation

### Firestore Structure (for IDM)

- [ ] **DB-01**: Create `instructor_chats/{chatId}` document structure: `participants[]` (2 UIDs), `participantRoles{}` (uid→role mapping), `lastMessage`, `time`, `createdAt`, `unreadCount` per participant
- [ ] **DB-02**: Create `instructor_chats/{chatId}/messages/{messageId}` subcollection with same fields as group chat messages
- [ ] **DB-03**: Create index or query pattern for fetching a user's DM list (query where `participants` arrayContains user.uid)

## v2 Requirements (Deferred)

### Priority Messaging System
- [ ] **PMSG-01**: Categorize messages as "Urgent" or "Standard" with visual toggle in message compose area
- [ ] **PMSG-02**: Different notification handling per priority level (Urgent vs Standard)
- [ ] **PMSG-03**: Visual distinction for urgent messages (different background/border)

### Do Not Disturb (DND) Scheduling
- [ ] **DND-01**: Set custom DND time periods
- [ ] **DND-02**: Suppress standard notifications during DND
- [ ] **DND-03**: Urgent messages pass through DND

### Announcement System (Full Implementation)
- [ ] **ANN-01**: Broadcast to all enrolled students in a channel (Faculty only)
- [ ] **ANN-02**: Distinct visual styling (special background color, badge indicators)

### Push Notifications (FCM)
- [ ] **PUSH-01**: Firebase Cloud Messaging integration
- [ ] **PUSH-02**: Urgent vs standard notification handling
- [ ] **PUSH-03**: DND-aware notification delivery
- [ ] **PUSH-04**: Notification tap opens relevant channel/DM

### Offline Caching
- [ ] **CACHE-01**: Initialize Hive CE (`Hive.init()`, `HiveFlutter.init()`)
- [ ] **CACHE-02**: Cache recent messages for offline access
- [ ] **CACHE-03**: Auto-sync when connectivity returns

### Channel Search/Filter
- [ ] **SRCH-01**: Search/filter channels in home screen
- [ ] **SRCH-02**: Filter by course, name, or unread status

### Security Rules
- [ ] **SEC-01**: Create `firestore.rules` with @carsu.edu.ph domain validation
- [ ] **SEC-02**: Channel access authorization (members only)
- [ ] **SEC-03**: Message read/write permissions
- [ ] **SEC-04**: DM access (only participants can read/write)

## Out of Scope

- **Cross-Platform iOS** — Minimum iOS 12.0 support, but not a priority (`docs/REQUIREMENTS.md` section 9)
- **User Documentation** — In-app help, tooltips, quick-start guide PDF (`docs/REQUIREMENTS.md` section 10)
- **External OAuth** — Google/Facebook login (stick with email/password per current implementation)

## Traceability

| REQ-ID | Mapped to Phase |
|---------|-----------------|
| IDM-01 | Phase 1 |
| DB-01 | Phase 1 |
| DB-02 | Phase 1 |
| DB-03 | Phase 1 |
| IDM-05 | Phase 2 |
| IDM-11 | Phase 2 |
| IDM-12 | Phase 2 |
| IDM-13 | Phase 2 |
| IDM-15 | Phase 2 |
| IDM-03 | Phase 3 |
| IDM-04 | Phase 3 |
| IDM-14 | Phase 3 |
| IDM-06 | Phase 4 |
| IDM-07 | Phase 4 |
| IDM-08 | Phase 5 |
| IDM-09 | Phase 5 |
| IDM-10 | Phase 5 |
| PMSG-01 through PMSG-03 | Deferred (v2) |
| DND-01 through DND-03 | Deferred (v2) |
| ANN-01 through ANN-02 | Deferred (v2) |
| PUSH-01 through PUSH-04 | Deferred (v2) |
| CACHE-01 through CACHE-03 | Deferred (v2) |
| SRCH-01 through SRCH-02 | Deferred (v2) |
| SEC-01 through SEC-04 | Deferred (v2) |
