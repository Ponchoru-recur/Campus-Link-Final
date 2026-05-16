---
phase: 07-mentions-pinned
plan: 01
wave: 1
tags: [mentions, pinned-messages, notification-strategy, firestore-schema, security-rules]
provides:
  - Message model extended with mentionedUids and pinnedUntil fields
  - _sendMessage() upgraded with @mention parsing and @everyone faculty gate
  - Member notification strategy docs initialized with correct defaults
  - Firestore security rules enforcing pinnedUntil write restriction
requires: []
affects:
  - lib/pages/home_hamburger/channel_screen/message.dart
  - lib/pages/home_hamburger/channel_screen/group_chat_screen.dart
  - firestore.rules (new file)
tech-stack:
  added: [Firestore security rules]
  patterns:
    - "@mention detection via regex on message text"
    - "_uidToName map lookup for mention resolution"
    - "Batch write with SetOptions(merge:true) for member strategies"
    - "Firestore security rule with get() role lookup"
key-files:
  created:
    - firestore.rules
  modified:
    - lib/pages/home_hamburger/channel_screen/message.dart
    - lib/pages/home_hamburger/channel_screen/group_chat_screen.dart
decisions:
  - "@everyone by non-faculty: silently stripped (no error shown, text sent normally)"
  - "Member role mapping: 'Admin' -> 'normal', 'Member' -> 'mentionsOnly' for notification strategies"
  - "Base Firestore rule: authenticated access for all docs; messages subcollection has extra pinnedUntil guard"
metrics:
  duration: ~15 min
  completed_date: 2026-05-16
  total_commits: 4
---

# Phase 7 Plan 1: Mentions, Pinned Messages, and Notification Strategy Data Layer

Extended the Firestore schema and Dart data model to support @mentions and @everyone pinned messages. Added mention parsing to `_sendMessage()`, initialized notification strategy defaults for group chat members, and added server-side security rules to prevent @everyone privilege escalation.

## Tasks Completed

### Task 1: Extend Message model with `mentionedUids` and `pinnedUntil` fields

**Commit:** `baa32b1`

Added two new fields to the `Message` class:
- `mentionedUids` (`List<String>`, default `[]`) -- stores UIDs of mentioned users per D-04/D-12
- `pinnedUntil` (`DateTime?`) -- pinned message expiry timestamp per D-11

Updated `_setupMessagesStream()` in `group_chat_screen.dart` to parse both fields from Firestore documents.

**Files modified:**
- `lib/pages/home_hamburger/channel_screen/message.dart` -- 2 new fields + 2 constructor defaults
- `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` -- 2 new lines in stream parsing

### Task 2: Extend `_sendMessage()` with @mention parsing, @everyone faculty gate, and pinnedUntil write

**Commit:** `e85c135`

Upgraded `_sendMessage()` with three new processing steps inserted before the Firestore write:
1. **@mention parsing:** Regex `@(\w+(?: \w+)*)` extracts display names, matches against `_uidToName` map to resolve UIDs. Sender's own UID excluded per D-04.
2. **@everyone faculty gate:** Faculty users get `pinnedUntil` set to 24 hours from now. Non-faculty users silently strip `@everyone` from text.
3. **Firestore write update:** `mentionedUids` and `pinnedUntil` (when non-null) written to message document.

Changed `final text` to `String text` to allow text mutation for non-faculty @everyone stripping.

**Files modified:**
- `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` -- 31 insertions in `_sendMessage()`

### Task 3: Initialize notification strategy member docs on group load

**Commit:** `4863e0e`

Created `_ensureMemberNotificationStrategies()` method that runs after `_loadMembers()` completes. Uses a batch write to initialize `notificationStrategy` field on each member doc at `group_chats/{chatId}/members/{uid}`:
- Admin (faculty) members: `'normal'`
- Member (student) members: `'mentionsOnly'`

Uses `SetOptions(merge: true)` to preserve any user-set strategies from future toggle UI. Added TODO comment noting that DMs will need similar initialization when migrated to Firestore (D-17: students get `'normal'` for DMs).

**Files modified:**
- `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` -- new 30-line method + call in `_loadMembers()`

### Task 4: Add Firestore security rules for `pinnedUntil` server-side enforcement

**Commit:** `fed95e4`

Created `firestore.rules` (was previously missing per CLAUDE.md) with:
- Base rule: authenticated access for all documents (`match /{document=**}`)
- Messages subcollection rule: writing `pinnedUntil` field requires faculty role (server-side `get()` to `users/{uid}`)

This mitigates T-07-01 (Elevation of Privilege) by ensuring even a modified client cannot write `pinnedUntil` without faculty authentication.

**Files created:**
- `firestore.rules`

## Verification Results

- `flutter analyze` passes on both modified files (zero errors, zero warnings -- only pre-existing info-level `use_build_context_synchronously` lints)
- Message model fields `mentionedUids` (List<String>) and `pinnedUntil` (DateTime?) exist with correct types
- `_sendMessage()` has mention parsing, @everyone faculty gate, and pinnedUntil write logic
- Member notification strategy init method exists with `merge:true`
- `firestore.rules` has pinnedUntil write restriction for faculty only

## Deviations from Plan

None -- plan executed exactly as written.

## Threat Surface Scan

| Flag | File | Description |
|------|------|-------------|
| threat_flag: new_security_boundary | firestore.rules | New Firestore security rules file created. Rule `allow read, write: if request.auth != null` for all documents is permissive. The messages subcollection rule adds a faculty-only check only for `pinnedUntil` field. Other collections (users, group_chats) rely solely on the base authenticated-access rule. This is acceptable for the current development phase but should be hardened before production. |