# Roadmap — Campus Link (Luminescence)

## Phases

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 1 | Clean Slate & Data Model | Remove dummy data, define Firestore schema for 1-on-1 DMs | IDM-01, DB-01, DB-02, DB-03 | 3 | ✓ |
| 2 | DM Infrastructure | Build Firestore-backed individual messaging with real-time streams | IDM-05, IDM-11, IDM-12, IDM-13, IDM-15 | 4 | ✓ |
| 3 | Auto-Wire Contacts | Auto-add instructor contacts when students join group chats; handle instructor additions | IDM-03, IDM-04, IDM-14 | 3 | ✓ |
| 4 | Contact Search & Add | Search bar to find and add student/instructor peers as DM contacts | IDM-06, IDM-07 | 2 |
| 5 | Visual Distinction | Distinguish instructor DMs from student DMs in chat list | IDM-08, IDM-09, IDM-10 | 2 |

Total: **5 phases** | **15 v1 requirements mapped** | All v1 requirements covered

---

### Phase1: Clean Slate & Data Model

**Goal**: Remove hardcoded dummy instructor chats and establish Firestore schema for 1-on-1 messaging.

**Requirements**: IDM-01, DB-01, DB-02, DB-03

**Plans:** 2 plans

**Plan list**:
- [x] 01-01-PLAN.md — Remove _instructorChats and update ChatType enum
- [x] 01-02-PLAN.md — Create DirectMessageItem model and verify DM schema

**Success criteria**:
1. `chats_screen.dart` no longer has hardcoded `_instructorChats` list — DM list is empty until contacts are added
2. Firestore `direct_messages` collection schema defined with `members[]`, `unreadCount` Map per participant, `lastMessage`, `time`, `createdAt`
3. `direct_messages/{chatId}/messages/{messageId}` subcollection schema matches group chat message schema (`senderId`, `senderName`, `text`, `timestamp`, `readBy`, `type`, `editHistory`, `isDeleted`)

---

### Phase2: DM Infrastructure

**Goal**: Build the individual chat conversation screen with real-time Firestore messaging.

**Requirements**: IDM-05, IDM-11, IDM-12, IDM-13, IDM-15

**Plans:** 4 plans

**Plan list**:

**Wave 0 *(test stubs)***
- [x] 02-00-PLAN.md — Create DM test stubs

**Wave 1 *(blocks on Wave 0)***
- [x] 02-01-PLAN.md — Create IndividualChatScreen with Firestore stream and send message
- [x] 02-02-PLAN.md — Implement read receipts in DMs

**Wave 2 *(blocks on Wave 1)***
- [x] 02-03-PLAN.md — Build Firestore-backed DM list in ChatsScreen

**Cross-cutting constraints:**
- `direct_messages` collection schema (Phase 1) — used by all 3 Wave 1+ plans
- `Message` model reuse — required by 02-01 and 02-02
- `AppColors.primary` (#3BB77E) accent — required by 02-01 per 02-UI-SPEC.md

**Success criteria**:
1. New `individual_chat_screen.dart` (or repurposed `instructor_chat_screen.dart`) displays real-time 1-on-1 messages from Firestore stream
2. Users can send/receive messages in DMs with real-time sync (same behavior as group chats)
3. Read receipts work in DMs — `readBy` array updates and displays under sender's messages
4. DM list in `chats_screen.dart` shows last message, timestamp, and unread count per conversation, fetched via `participants arrayContains` query

---

### Phase3: Auto-Wire Contacts

**Goal**: Automatically create DM contacts when students join group chats with instructors, and handle instructor additions.

**Requirements**: IDM-03, IDM-04, IDM-14

**Success criteria**:
1. When a student joins a group chat, any instructors in that group chat are automatically added to the student's DM contact list (Firestore `direct_messages` document created with both participants)
2. When an instructor is added to an existing group chat, they are added to all group members' DM contact lists
3. Faculty/instructors in group chats retain admin privileges (add/remove members, rename group) — verified existing behavior, document in code

---

### Phase4: Contact Search & Add

**Goal**: Allow users to search for and add student/instructor peers as individual contacts.

**Requirements**: IDM-06, IDM-07

**Plans:** 3 plans

**Plan list**:
- [ ] 04-00-PLAN.md — Create test stubs (Wave 0)
- [x] 04-01-PLAN.md — Add search bar UI and user search (Wave 1)
- [ ] 04-02-PLAN.md — Implement add contact with DM creation (Wave 2)

**Success criteria**:
1. Search bar in chat list screen allows users to search by email or name within `@carsu.edu.ph` domain, reusing existing `^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$` regex
2. Search results show matching users from Firestore `users` collection; tapping a result adds them to the user's DM contact list (creates `direct_messages` document if not already existing)

---

### Phase5: Visual Distinction

**Goal**: Make instructor DMs visually distinct from student DMs in the chat list.

**Requirements**: IDM-08, IDM-09, IDM-10

**Success criteria**:
1. Instructor DMs in the chat list use `AppColors.instructorPurple` accent, distinct tile styling (e.g., purple left border or background tint), and a role badge ("Instructor")
2. Student DMs use standard styling (no purple accent, different `ChatType` or role-based styling)
3. In the DM conversation screen, the instructor's name/role is clearly displayed (role badge or purple indicator) so users always know who they're talking to

---

## Traceability

| REQ-ID | Phase |
|---------|-------|
| IDM-01 | 1 |
| DB-01 | 1 |
| DB-02 | 1 |
| DB-03 | 1 |
| IDM-05 | 2 |
| IDM-11 | 2 |
| IDM-12 | 2 |
| IDM-13 | 2 |
| IDM-15 | 2 |
| IDM-03 | 3 |
| IDM-04 | 3 |
| IDM-14 | 3 |
| IDM-06 | 4 |
| IDM-07 | 4 |
| IDM-08 | 5 |
| IDM-09 | 5 |
| IDM-10 | 5 |
