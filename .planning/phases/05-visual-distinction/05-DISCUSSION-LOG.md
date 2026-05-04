# Phase 5: Visual Distinction - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-05
**Phase:** 5-Visual Distinction
**Areas discussed:** Tile styling, Role badge design, Student DM styling, DM conversation header

---

## Tile Styling

| Option | Description | Selected |
|--------|-------------|----------|
| Left border (Recommended) | Purple left border (3-4px) on instructor tiles. Subtle but clear. | ✓ |
| Background tint | Light purple background (instructorPurple.withValues(alpha:0.08)). More visible. | |
| Both border + tint | Combined approach - purple left border AND subtle background tint. | |
| You decide | You pick the best approach based on existing app patterns. | |

**User's choice:** Left border (Recommended)
**Notes:** Success criteria mentions "purple left border or background tint". User chose border only.

| Option | Description | Selected |
|--------|-------------|----------|
| 2px (thin) | Subtle, matches other UI borders in the app. | |
| 3px (medium) (Recommended) | Visible but not overpowering. Good balance. | ✓ |
| 4px (thick) | Bold statement. Maximum visual distinction. | |

**User's choice:** 3px (medium) (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep all purple accents (Recommended) | Keep current purple avatar BG + icon + unread badge, add the left border. | ✓ |
| Border only, remove other purple | Remove purple from avatar/icon/unread, use ONLY the left border. | |
| You decide | You decide the right balance of purple accents. | |

**User's choice:** Keep all purple accents (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Static border color (Recommended) | Border stays purple in all states. Consistent look. | ✓ |
| Reactive (darker when pressed) | Border darkens when tile is pressed/tapped. Interactive feedback. | |
| You decide | You decide the best border behavior. | |

**User's choice:** Static border color (Recommended)

---

## Role Badge Design

| Option | Description | Selected |
|--------|-------------|----------|
| Pill badge next to name (Recommended) | Small pill/badge next to the name. Uses AppColors.instructorPurple background. | ✓ |
| Text in subtitle | Text label in the subtitle below the name. Simpler. | |
| Icon only (Icons.school) | Small instructor icon next to name, no text. Minimalist. | |
| You decide | You design the best badge for the app's style. | |

**User's choice:** Pill badge next to name (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Purple bg + white text (Recommended) | Purple background (AppColors.instructorPurple) with white text. | ✓ |
| White bg + purple border | White background with purple border + purple text. | |
| Outline style (no fill) | Transparent bg, purple border+text. Minimalist. | |
| You decide | You decide the best color scheme. | |

**User's choice:** Purple bg + white text (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Compact (Recommended) | fontSize 9, horizontal padding 6, vertical 2. Fits well next to name. | ✓ |
| Standard size | fontSize 10, horizontal padding 8, vertical 3. More readable. | |
| You decide | You decide the right size. | |

**User's choice:** Compact (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Text only (Recommended) | Text only: 'Instructor'. Clean and simple. | ✓ |
| With school icon | Icons.school + 'Instructor'. More visual. | |
| You decide | You decide icon usage. | |

**User's choice:** Text only (Recommended)

---

## Student DM Styling

| Option | Description | Selected |
|--------|-------------|----------|
| No accent - grey only (Recommended) | Grey avatar/icon/unread badge. No accent color. | ✓ |
| Keep teal-green (AppColors.primary) | Keep current AppColors.primary (teal-green) as the 'standard' accent. | |
| You decide | You decide what 'standard styling' means. | |

**User's choice:** No accent - grey only (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Match group chat tile style (Recommended) | Student DM tiles match group chat tiles. Consistent 'standard' look. | ✓ |
| Current layout, just grey | Student DMs keep current layout but with grey accents. | |

**User's choice:** Match group chat tile style (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| No role text (Recommended) | No role text. Grey styling is enough to distinguish. | ✓ |
| Show 'Student' text | Show 'Student' in subtitle or as a muted badge. | |

**User's choice:** No role text (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep single enum (Recommended) | Keep ChatType.directMessage for both. Use otherParticipantRole field. | ✓ |
| Add new enum value | Add ChatType.studentDirectMessage. Explicit typing. | |

**User's choice:** Keep single enum (Recommended)

---

## DM Conversation Header

| Option | Description | Selected |
|--------|-------------|----------|
| AppBar text is enough (Recommended) | Current AppBar shows 'Instructor' text below name. Sufficient. | ✓ |
| Persistent role badge in chat | Add a persistent purple role badge below AppBar. Sticky while scrolling. | |
| You decide | You decide if AppBar is enough or more needed. | |

**User's choice:** AppBar text is enough (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| No bubble changes (Recommended) | No, message bubbles stay the same regardless of sender role. | ✓ |
| Purple accent on instructor messages | Instructor messages get purple left border or background tint. | |

**User's choice:** No bubble changes (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| AppBar only (Recommended) | AppBar purple is enough. No other changes to the conversation screen. | ✓ |
| Purple divider below AppBar | Add a purple divider below AppBar for subtle reinforcement. | |
| Purple background tint | Light purple background tint on the chat area. | |

**User's choice:** AppBar only (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep teal-green send button (Recommended) | Keep AppColors.primary (teal-green) for send button. Consistent. | ✓ |
| Purple send button for instructors | Change send button to AppColors.instructorPurple when chatting with instructor. | |

**User's choice:** Keep teal-green send button (Recommended)

---

## Claude's Discretion

- Exact grey shade for student DM avatars/icons/unread badges - choose color that matches "standard styling"
- Whether to use `withValues(alpha:)` for student avatar BG or flat grey
- Exact padding/layout adjustments needed to accommodate the 3px left border

## Deferred Ideas

None — discussion stayed within phase scope.
