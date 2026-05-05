---
phase: 05-visual-distinction
plan: 00
subsystem: [ui, database]
tags: [direct-messages, visual-distinction, role-based-styling, firestore]

# Dependency graph
requires:
  - phase: 04-contact-search-add
    provides: [DM creation, direct_messages collection, search UI]
provides:
  - Visual distinction for instructor vs student DMs in chat list
  - Role-based styling and badges
affects: [direct-messages, chat-list, ui-polish]

# Tech tracking
tech-stack:
  added: []
  patterns: [role-based-ui, Container border, Chip/badge widgets]

key-files:
  created: [lib/pages/home_hamburger/channel_screen/direct_message_tile.dart]
  modified: [lib/pages/home_hamburger/channel_screen/chats_screen.dart, lib/pages/home_hamburger/channel_screen/direct_message_item.dart]

key-decisions:
  - "Instructor DMs: purple left border (3px), purple badge, purple accents"
  - "Student DMs: grey-only styling (no purple elements)"
  - "Search TextField: filled: true with semi-transparent white background"
  - "DM creation: save participantRoles map to Firestore"

patterns-established:
  - "Role-based visual distinction via Container border + Chip badge"
  - "Store participant roles in Firestore participantRoles map for offline access"

requirements-completed: [IDM-08, IDM-09, IDM-10]

# Metrics
duration: 15min
completed: 2026-05-05
---

# Phase 5: Visual Distinction Summary

**Enhanced DM list with role-based visual distinction — instructor DMs show purple accents, left border, and "Instructor" badge; student DMs use neutral grey styling.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-05T10:00:00Z
- **Completed:** 2026-05-05T10:15:00Z
- **Tasks:** 2 planned + 3 bug fixes
- **Files modified:** 3

## Accomplishments

- Instructor DMs in chat list display purple left border (3px), "Instructor" pill badge, and purple accents (avatar BG, icon, unread badge)
- Student DMs use grey-only styling (Colors.grey[400] avatar BG, Colors.grey[600] icon/unread) with no purple elements
- IndividualChatScreen already satisfied IDM-10 (role text "Instructor"/"Student" displayed, purple AppBar for faculty)
- Fixed: Search TextField now has visible text (filled: true with white semi-transparent background)
- Fixed: DM creation now saves `participantRoles` map to Firestore (resolves "Unknown" role issue)
- Fixed: `DirectMessageItem.fromFirestore` reads `participantRoles` map with fallback to `otherParticipantRole`

## Task Commits

Each task was committed atomically:

1. **Task 1: Verify IDM-10 Compliance** - No commit (already satisfied, no changes needed)
2. **Task 2: Enhance DM Tile Visual Distinction** - `a2f466f` (feat)
3. **Bug Fix: Search TextField visibility** - `47b18c4` (fix)
4. **Bug Fix: Save participantRoles to DM doc** - `d23c373` (fix)
5. **Bug Fix: Read participantRoles from Firestore** - `409ec3e` (fix)

**Plan metadata:** `05-00-PLAN.md` (docs: complete plan)

## Files Created/Modified

- `lib/pages/home_hamburger/channel_screen/direct_message_tile.dart` - New file with role-based DM tile styling
- `lib/pages/home_hamburger/channel_screen/chats_screen.dart` - Modified: search TextField visibility fix, DM creation saves participantRoles
- `lib/pages/home_hamburger/channel_screen/direct_message_item.dart` - Modified: reads participantRoles from Firestore

## Decisions Made

- Used `AppColors.instructorPurple` (Color(0xFF7B5EA7)) for all instructor accents
- Used `Colors.grey[400]` and `Colors.grey[600]` for student DM styling (no purple)
- Added 3px purple left border via `Container(decoration: Border(left: BorderSide(...)))` for instructor DMs
- Added "Instructor" pill badge using `Container + Text` next to name in tile title Row
- Search TextField uses `filled: true` with `fillColor: Colors.white.withValues(alpha: 0.15)` for visibility
- DM creation saves `participantRoles: {uid: role}` map to Firestore for reliable role lookup

## Deviations from Plan

None - plan executed exactly as written. Bug fixes were additional work identified during user verification.

## Issues Encountered

1. **Search text invisible** - TextField style was `Colors.white` but no filled background made text hard to see. Fixed by adding `filled: true` with semi-transparent white fill.
2. **Student role shows as "Unknown"** - `otherParticipantRole` not saved to Firestore on DM creation. Fixed by saving `participantRoles` map with both users' roles.
3. **`DirectMessageItem.fromFirestore` couldn't read role** - Added fallback logic to read from `participantRoles` map first, then `otherParticipantRole` field.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Visual distinction complete, DM list now clearly shows instructor vs student contacts
- Role data properly stored in Firestore for all new DMs
- Ready for next phase (if any remaining in milestone v1.0)

---
*Phase: 05-visual-distinction*
*Completed: 2026-05-05*
