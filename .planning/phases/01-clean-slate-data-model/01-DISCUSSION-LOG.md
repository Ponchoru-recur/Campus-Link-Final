# Phase 1: Clean Slate & Data Model - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-04
**Phase:** 1-Clean Slate & Data Model
**Areas discussed:** Collection naming, Field naming, UnreadCount struct, Phase 1 scope

---

## Collection Naming

| Option | Description | Selected |
|--------|-------------|----------|
| `instructor_chats` (Recommended) | Matches roadmap/REQUIREMENTS.md exactly. Fits current scope (instructor-student only). | |
| `direct_messages` | Generic name for any 1-on-1. Future-proof if student-student DMs added later (Phase 4 mentions 'student peers'). Requires updating roadmap docs. | ✓ |
| `dms` | Short form, similar to group_chats naming convention. Less verbose in code. | |

**User's choice:** `direct_messages` (generic, future-proof for student-student DMs)

---

## Field Naming

| Option | Description | Selected |
|--------|-------------|----------|
| `members[]` (Recommended) | Matches group_chats convention. Consistent naming across collections. Easier to remember. | ✓ |
| `participants[]` | Original roadmap choice for DMs. Different name signals different semantics (conversation participants vs group members). | |
| `members[]` (DM), `participants[]` (group DM later) | Use members[] for DM collection to match group_chats. Use participants[] only if we add group DM support later. | |

**User's choice:** `members[]` (matches group_chats convention)

---

## UnreadCount Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Map field `{uid: count}` (Recommended) | Map field `{uid1: count1, uid2: count2}`. When constructing ChatItem, read `unreadCount[user.uid]`. When user opens chat, set their count to 0. | ✓ |
| `lastRead` timestamp | Each participant has a lastRead timestamp. Count unread by querying messages with `timestamp > lastRead`. More flexible but more reads. | |
| Single counter | Single `unreadCount` in DM doc. Resets when either user opens chat. Simple but both users see same count (may not be accurate). | |

**User's choice:** Map field `{uid: count}` for per-participant tracking

---

## Phase 1 Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Create models (Recommended) | Create `DirectMessageItem` model + update `ChatType` enum. Phase 2 can reuse immediately. Defines the schema in code. | ✓ |
| Schema only | Just define schema in comments/docs. Models created in Phase 2 when wiring up streams. | |
| Models + placeholder stream | Also add a placeholder Firestore stream (returns empty for now) to replace `_instructorChats` ListView. | |

**User's choice:** Create Dart models in Phase 1

---

## Claude's Discretion

- Message subcollection fields match group chat `Message` model exactly

## Deferred Ideas

None — discussion stayed within phase scope.
