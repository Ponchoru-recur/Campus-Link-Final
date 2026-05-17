# Fix: Scroll-to-Message + Student @everyone

## Context

Two bugs found in audit sheet (`_buildAuditList`) in `group_chat_screen.dart`:

1. **Scroll-to-message broken**: Tapping @everyone or @you entry always jumps to first message of that kind. Root cause: `_messages.indexWhere((m) => m.id == messageId)` at tap time finds wrong index because `_messages` gets fully cleared/rebuild on every stream snapshot (line 348 `_messages.clear()`). Though IDs are unique, the async timing between `Navigator.pop` and `indexWhere` query on `_messages` (which is being rebuilt by live stream listener) can return stale/offset results. **Fix**: capture message index at build time like `_buildSearchResults` does (line 1327), not lazily at tap time.

2. **Student @everyone blocked**: Lines 110-116 gate `@everyone` with `_isFaculty`. Students' `@everyone` silently stripped. Audit log (lines 132-145) also gated by `_isFaculty`. **Fix**: remove `_isFaculty` check for both the `@everyone` pin/trigger and the audit log write. Keep `pinnedUntil` for all roles (24h TTL applies to everyone's @everyone calls).

## Changes

### File: `group_chat_screen.dart`

**Bug 1 — scroll-to-message** (lines 1396-1437):
- In `_buildAuditList` `itemBuilder`, find message index at build time using `_messages.indexWhere` and capture it per-item (like `_buildSearchResults` at line 1327).
- Store captured index in a variable `msgIndex`.
- Tap handler uses captured `msgIndex` directly instead of calling `_messages.indexWhere` lazily.

**Bug 2 — student @everyone** (lines 107-116, 131-145):
- Remove `_isFaculty` guard from `@everyone` logic. Students get same 24h pinned behavior.
- Remove `_isFaculty` guard from `everyone_calls` audit write. All roles write audit entries.
- Keep notification tiering (`isEveryone: hasEveryone` already passed to notification service — students' @everyone will dispatch to all members, which is correct).

## Verification

1. Open chat with multiple @everyone messages. Tap second @everyone in audit sheet → scrolls to correct message, not first one.
2. Send @everyone as student → message pins, appears in @everyone audit tab.
3. @you tab still scrolls correctly (same fix as @everyone).
4. `flutter analyze` passes.