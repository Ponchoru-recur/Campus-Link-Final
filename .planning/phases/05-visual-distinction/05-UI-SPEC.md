---
phase: 5
slug: visual-distinction
status: approved
shadcn_initialized: false
preset: none
created: 2026-05-05
---

# Phase 5 — UI Design Contract

> Visual and interaction contract for Phase 5: Visual Distinction.
> Generated from 05-CONTEXT.md decisions. Verified by gsd-ui-checker.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Flutter Material 3) |
| Preset | none |
| Component library | none (Flutter widgets) |
| Icon library | Icons (Material) |
| Font | default Flutter (Roboto) |

---

## Spacing Scale

Declared values (multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Icon gaps, inline padding |
| sm | 8px | Compact element spacing |
| md | 16px | Default element spacing |
| lg | 24px | Section padding |
| xl | 32px | Layout gaps |

Exceptions: Left border width = 3px (non-standard, intentional for visual distinction)

---

## Typography

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 14px | regular (400) | 1.4 |
| Label | 13px | regular (400) | 1.4 |
| Badge | 9px | medium (500) | 1.2 |
| Title | 15px | semi-bold (600) | 1.3 |
| Heading | 15px | semi-bold (600) | 1.3 |

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | AppColors.primary (#3BB77E) | Group chat tiles, student DM avatars (grey) |
| Secondary (30%) | AppColors.surface (#F5F5F5) | Backgrounds |
| Accent (10%) | AppColors.instructorPurple (#7B5EA7) | Instructor DM border, badge, avatar BG, icon, unread badge |
| Destructive | AppColors.urgentRed (#D32F2F) | Destructive actions only |
| Student DM grey | Colors.grey[400] / AppColors.textSecondary (#757575) | Student DM avatar BG, icon, unread badge (no accent) |

Accent reserved for: Instructor-only visual elements (border, badge, avatar BG, icon, unread badge). Never applied to student DMs.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Role badge (instructor) | "Instructor" |
| Role badge (student) | none (no badge shown) |
| AppBar subtitle (instructor) | "Instructor" |
| AppBar subtitle (student) | "Student" |
| Empty state heading | "No messages yet" |
| Empty state body | "Start a conversation" |

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| none | Flutter widgets (ListTile, Container, CircleAvatar, Text) | not required |

---

## Visual Specification — Instructor DM Tile

### Layout
- **Widget:** `DirectMessageTile` in `direct_message_tile.dart`
- **Border:** Left border only, 3px, `AppColors.instructorPurple`, `BoxDecoration(border: Border(left: BorderSide(...)))`
- **Avatar:** `CircleAvatar` with `backgroundColor: AppColors.instructorPurple.withValues(alpha: 0.15)`, icon `Icons.person` in `AppColors.instructorPurple`
- **Title row:** Name (`Text`, 15px, w600) + `SizedBox(width: 6)` + Pill badge ("Instructor")
- **Pill badge:** `Container` with `color: AppColors.instructorPurple`, `borderRadius: BorderRadius.circular(4)`, `padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2)`, child: `Text('Instructor', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: w500))`
- **Subtitle:** Last message (`Text`, 13px, `AppColors.textSecondary`)
- **Trailing:** Time (`Text`, 11px) + unread count badge (`Container` with `color: AppColors.instructorPurple`, white text)
- **contentPadding:** `EdgeInsets.symmetric(horizontal: 16, vertical: 4)` (add 3px left offset to accommodate border)

### Implementation Notes
- Wrap existing `ListTile` in `Container` with left border decoration
- Pill badge inserted as `Row` children in `title` slot: `[Text(name), SizedBox(6), badge]`
- Keep existing purple accents (avatar BG, icon, unread badge) alongside new border

---

## Visual Specification — Student DM Tile

### Layout
- **Widget:** `DirectMessageTile` in `direct_message_tile.dart`
- **Border:** None (no border)
- **Avatar:** `CircleAvatar` with `backgroundColor: Colors.grey[400].withValues(alpha: 0.15)` or `AppColors.textSecondary.withValues(alpha: 0.15)`, icon `Icons.person` in `Colors.grey[400]` or `AppColors.textSecondary`
- **Title row:** Name only (`Text`, 15px, w600) — NO role badge
- **Subtitle:** Last message (`Text`, 13px, `AppColors.textSecondary`)
- **Trailing:** Time (`Text`, 11px) + unread count badge (`Container` with `Colors.grey[400]`, white text)
- **contentPadding:** `EdgeInsets.symmetric(horizontal: 16, vertical: 4)` (standard, no border offset)

### Implementation Notes
- Remove purple accent usage for student DMs (`isFaculty` check → false branch)
- Match group chat tile styling patterns from `group_chat_tile.dart`
- No role text or badge for students (grey styling is sufficient distinction)

---

## Visual Specification — DM Conversation Screen

### AppBar (IndividualChatScreen)
- **Color:** `AppColors.instructorPurple` for instructors, `AppColors.primary` for students
- **Title:** Name (15px, w600, white) + `SizedBox(width: 10)`
- **Subtitle:** "Instructor" or "Student" (11px, `Colors.white70`)
- **Avatar:** `CircleAvatar` with white BG (`Colors.white.withValues(alpha: 0.2)`), first letter of name

### Message Bubbles
- **No role-based styling** — bubbles stay the same regardless of sender role
- Sender messages: `AppColors.primary` bg, white text
- Other messages: `Color(0xFFF0F0F0)` bg, `AppColors.textPrimary` text

### Message Input Bar
- **Send button:** `AppColors.primary` (teal-green) for ALL DMs (students AND instructors)
- Consistent with other screens in the app

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved 2026-05-05

---

*Generated from 05-CONTEXT.md decisions*
*Phase: 5-Visual Distinction*
