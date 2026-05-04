# Phase 5: Visual Distinction - Context

**Gathered:** 2026-05-05
**Status:** Ready for planning

<domain>
## Phase Boundary

**Delivers:** Visually distinguish instructor DMs from student DMs in the chat list and DM conversation screen.

**In scope:**
- Add purple left border to instructor DM tiles (3px, AppColors.instructorPurple)
- Add "Instructor" pill badge next to name in DM tiles
- Style student DMs with standard/grey styling (no accent colors)
- Keep AppBar role text ("Instructor"/"Student") in DM conversation screen

**Out of scope:**
- Changing message bubble styling based on role
- Animated borders or interactive feedback on tiles
- Persistent role indicators beyond AppBar in conversation screen
- Priority messaging (Urgent/Standard) - deferred to v2

</domain>

<decisions>
## Implementation Decisions

### Tile Styling (Instructor DMs)
- **D-01:** Left border approach (not background tint, not both). Uses `Container` wrapper with `BoxDecoration(border: Border(left: ...))`.
- **D-02:** 3px thickness (medium). Balanced visibility without overpowering the tile.
- **D-03:** Keep all purple accents - avatar BG (`instructorPurple.withValues(alpha: 0.15)`), icon color (`instructorPurple`), unread badge color (`instructorPurple`) - PLUS the new left border.
- **D-04:** Static border color (not reactive to press/selected states). Consistent look.

### Role Badge Design
- **D-05:** Pill badge next to name (e.g., "John Doe [Instructor]"). Use `Row` with `Text` for name + `Container` for badge in `title` slot of `ListTile`.
- **D-06:** Purple bg (`AppColors.instructorPurple`) + white text. Matches the border accent.
- **D-07:** Compact size - fontSize 9, horizontal padding 6, vertical 2. Fits well next to name.
- **D-08:** Text only (no icon). Clean and simple.

### Student DM Styling
- **D-09:** No accent - grey only. Avatar BG, icon, unread badge all use grey colors (no `AppColors.primary` teal-green).
- **D-10:** Match group chat tile style (consistent 'standard' look). Uses similar padding, font weights, layout as `GroupChatTile`.
- **D-11:** No role text for students. Grey styling is sufficient to distinguish from purple instructor tiles.
- **D-12:** Keep single enum (`ChatType.directMessage` for both). Use `otherParticipantRole` field for styling decisions.

### DM Conversation Screen (IndividualChatScreen)
- **D-13:** AppBar text ("Instructor"/"Student" below name) is enough. No persistent role badge needed below AppBar.
- **D-14:** No message bubble changes. Bubbles stay the same regardless of sender role.
- **D-15:** AppBar only - no other visual distinction (no purple divider, no background tint).
- **D-16:** Keep teal-green send button (`AppColors.primary`) even for instructor DMs. Consistent with other screens.

### Claude's Discretion
- Exact grey shade for student DM avatars/icons/unread badges - choose color that matches "standard styling" and is readable
- Whether to use `withValues(alpha:)` for student avatar BG or flat grey
- Exact padding/layout adjustments needed to accommodate the 3px left border

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Definition
- `.planning/ROADMAP.md` §Phase5 — Goal, requirements (IDM-08, IDM-09, IDM-10), success criteria
- `.planning/REQUIREMENTS.md` §IDM-08, IDM-09, IDM-10 — Requirement details for Visual Distinction

### Prior Phase Context
- `.planning/phases/01-clean-slate-data-model/01-CONTEXT.md` — Prior decisions: `direct_messages` collection, `members[]` field, `ChatType.directMessage` enum

### Existing Code (Reuse Patterns)
- `lib/themes/app_colors.dart` — `AppColors.instructorPurple` (#7B5EA7), `AppColors.primary` (teal-green), grey colors
- `lib/pages/home_hamburger/channel_screen/direct_message_tile.dart` — Current DM tile with role-based coloring (modify to add border + badge)
- `lib/pages/home_hamburger/channel_screen/direct_message_item.dart` — `DirectMessageItem` model with `otherParticipantRole` field
- `lib/pages/home_hamburger/channel_screen/chat_item.dart` — `ChatType` enum (`groupChat`, `directMessage`)
- `lib/pages/home_hamburger/channel_screen/individual_chat_screen.dart` — DM conversation screen with AppBar role display (line 260-263)
- `lib/pages/home_hamburger/channel_screen/group_chat_tile.dart` — Group chat tile (reference for "standard styling")

### Data Models
- `.planning/codebase/ARCHITECTURE.md` — StatefulWidget + StreamBuilder pattern, Firestore stream conventions
- `.planning/codebase/CONVENTIONS.md` — Color usage (`AppColors.*`), role checks, widget patterns
- `.planning/codebase/STRUCTURE.md` — Directory layout, key file locations
- `.planning/codebase/STACK.md` — Flutter/Material 3, no state management library

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`DirectMessageTile`** (`direct_message_tile.dart`): Already has role-based coloring (`isFaculty ? AppColors.instructorPurple : AppColors.primary`). Modify to add left border + pill badge.
- **`ChatType` enum** (`chat_item.dart:22`): `groupChat` and `directMessage` values. No change needed.
- **`DirectMessageItem`** (`direct_message_item.dart`): Has `otherParticipantRole` field ('faculty' or 'student'). Factory parses from Firestore.
- **`AppColors.instructorPurple`** (`app_colors.dart:14`): Color(0xFF7B5EA7) - use for border, badge bg, avatar accent.

### Established Patterns
- **StatelessWidget for tiles** — `DirectMessageTile` is StatelessWidget (no state needed)
- **Role-based conditional styling** — `final isFaculty = chat.otherParticipantRole == 'faculty'` pattern already in use
- **ListTile with custom contentPadding** — Current tile uses ` EdgeInsets.symmetric(horizontal: 16, vertical: 4)`, `dense: true`
- **Pill badge pattern** — Drawer header role badge uses `Container` with `borderRadius` and `color` (see `chats_screen.dart` drawer)

### Integration Points
- **`chats_screen.dart`**: DM list uses `DirectMessageTile` — modifications here affect all DM tiles
- **`individual_chat_screen.dart`**: AppBar already shows role text (line 260-263) — no changes needed per D-13
- **`direct_message_tile.dart`**: Primary file to modify for border + badge implementation

</code_context>

<specifics>
## Specific Ideas

- Instructor DM tile: purple left border (3px) + purple pill badge ("Instructor") next to name + existing purple accents (avatar BG, icon, unread)
- Student DM tile: grey-only styling (no accent colors) to match group chat tile appearance
- Pill badge: `Container` with `BoxDecoration(color: AppColors.instructorPurple, borderRadius: BorderRadius.circular(4))`, child: `Text('Instructor', style: white, fontSize 9)`
- Border implementation: Wrap `ListTile` in `Container(decoration: BoxDecoration(border: Border(left: BorderSide(color: AppColors.instructorPurple, width: 3)))`
- Grey avatar: `Colors.grey[400]` or `AppColors.textSecondary` for student DM avatar BG

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---
*Phase: 5-Visual Distinction*
*Context gathered: 2026-05-05*
