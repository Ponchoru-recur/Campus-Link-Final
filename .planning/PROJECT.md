# Project — Campus Link (Luminescence)

## What This Is

Campus Link is a Flutter mobile app for campus communication at Caraga State University (CarsU). It provides role-based (Student/Faculty) group chats and — with this phase — real instructor-student individual messaging.

**Stack**: Flutter + Firebase (Auth, Firestore, FCM pending)

## Core Value

Private, reliable 1-on-1 messaging between students and instructors, automatically wired when students join group chats with instructors.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Replace dummy instructor DMs with Firestore-backed system | Current `_instructorChats` is hardcoded placeholder, not functional | New `instructor_chats` collection or subcollection |
| Auto-add instructor to student's individual contacts when student joins group chat | Matches how campus communication naturally works | Student sees instructor in DM list automatically |
| Role-based visual distinction in DM list | Instructors and students look different in chat list | Use `AppColors.instructorPurple` for instructor DMs, different tile styling |
| Search bar for adding peers | Users need to find and add contacts | Search by email or name within @carsu.edu.ph domain |

## Requirements

### Validated (Existing)

- ✓ Email/password authentication with @carsu.edu.ph domain restriction
- ✓ Firebase Auth integration with email verification flow
- ✓ Role selection (Student/Faculty) at registration
- ✓ Group chat creation (Faculty only) with name, members[]
- ✓ Real-time group chat messaging (Firestore streams)
- ✓ Message editing within 60 minutes (soft delete, edit history)
- ✓ Message deletion within 60 minutes
- ✓ Read receipts (per-message `readBy` array)
- ✓ Keyword message search in group chats
- ✓ System messages for member add/remove
- ✓ Faculty admin controls in group chats (add/remove members, rename)
- ✓ Settings screen with debug role-switching
- ✓ Material 3 theming (light/dark, currently light only)
- ✓ Announcement dialog (Faculty broadcast, UI only)

### Active (To Build)

- [ ] Remove hardcoded `_instructorChats` dummy data from `chats_screen.dart`
- [ ] Create Firestore-backed individual (1-on-1) messaging system
- [ ] Auto-add instructor to student's DM contacts when student joins a group chat where that instructor is a member
- [ ] Search bar to add student peers or instructor peers as individual contacts
- [ ] Visually distinguish instructor DMs from student DMs in the chat list
- [ ] Individual chat conversation screen with real-time messaging (Firestore-backed)
- [ ] Instructors added to group chats get same privileges as faculty (admin controls)

### Out of Scope (for this phase)

- Priority messaging (Urgent/Standard) — planned, separate feature
- Do Not Disturb scheduling — out of scope for now
- Full FCM push notifications — dependency added, not yet implemented
- Offline caching with Hive CE — added but not initialized
- Channel search/filter in home screen — separate feature
- Firestore security rules — must be created before production, but not part of this feature

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-04 after codebase mapping and project initialization*
