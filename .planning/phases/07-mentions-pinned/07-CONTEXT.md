# Phase 7: @Mentions & Pinned Messages - Context

**Gathered:** 2026-05-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Add @mention system in group chats with two variants (@user, @everyone) and full FCM push notification integration with tiered delivery. Replace old announcement feature with @everyone as replacement.

**@user mention:** Autocomplete dropdown when typing @, highlights message for mentioned user, everyone sees @ badge.
**@everyone mention:** Auto-pins message to collapsible top bar for 24h, faculty-only, faculty-only.

**Push notification tiered model:**
| Tier | Channel | Notify? | Type |
|------|---------|---------|------|
| 1 | DMs | Always | Full push (banner+sound) |
| 2 | @mention / @everyone | Always | Full push (banner+sound) |
| 3 | Task create/delete | Always | Full push (banner+sound) |
| 4 | Normal group messages | Silent push only | Badge + in-app, no banner/sound |
| 5 | Faculty→Student in group (no @) | Silent push only | Same as tier 4 |

</domain>

<decisions>
## Implementation Decisions

### @user Mentions
- **D-01:** Autocomplete dropdown appears when typing @. Filters group members by typed chars. Tap to insert as `@DisplayName`.
- **D-02:** @username stored as plain text in message body. Parsed on send to extract mentioned UIDs.
- **D-03:** Mentioned user sees highlighted message bubble (amber/yellow tint). Non-mentioned users see small @ badge on message.
- **D-04:** `mentionedUids: List<String>` field on message doc in Firestore.

### @everyone Mentions
- **D-05:** Faculty-only. Checked server-side via role lookup or `createdBy`.
- **D-06:** Auto-pins message to collapsible bar at top of chat for 24h.
- **D-07:** Pinned bar shows: sender name, message preview, age label ("2h ago", "yesterday").
- **D-08:** Visual fading: <1h = highlighted, <24h = normal, >24h = dimmed.
- **D-09:** Users can manually unpin (dismiss from bar; message stays in stream).
- **D-10:** After 24h, drops from pinned bar automatically (Firestore query filter).

### Firestore Schema
- **D-11:** Add `pinnedUntil: Timestamp` field to message documents in group_chats/{chatId}/messages.
- **D-12:** Add `mentionedUids: List<String>` field to message documents.
- **D-13:** Pinned bar query: `where('pinnedUntil', '>', now)` on messages subcollection.
- **D-14:** Add `notificationStrategy` enum field to each group chat member document (`members/{uid}` subcollection): `normal`, `mentionsOnly`, `muted`.

### Push Notification Integration
- **D-15:** FCM full integration — register tokens, send via Cloudflare Worker (zero cost, no credit card).
- **D-16:** Tiered delivery based on notificationStrategy + message type:
  - `normal` strategy: full push for everything in that chat.
  - `mentionsOnly` strategy: full push only for @mentions, @everyone, task events; silent for normal messages.
  - `muted` strategy: nothing.
- **D-17:** Default: students get `mentionsOnly` for group chats, `normal` for DMs. Faculty default `normal` for everything.
- **D-18:** Silent push = delivered with badge count, no banner/sound/lock screen.
- **D-19:** Notification tap opens relevant chat/thread.
- **D-20:** Cloudflare Worker receives 1 POST from sender with chatId, senderId, messageId, mentionedUsers[]. Worker queries Firestore REST API for members + strategies, fans out FCM to correct recipients.
- **D-21:** FCM Server Key stored as Cloudflare Worker environment variable (not hardcoded).

### Notification Toggle UI
- **D-20:** Per-group-chat toggle in group info/settings panel.
- **D-21:** Everyone can toggle their own notificationStrategy per chat.
- **D-22:** Three options: Normal (all notifications), Mentions Only, Muted.

### Pinned Bar UI
- **D-23:** Collapsible bar between AppBar and message ListView.
- **D-24:** Shows most recent pinned message (or carousel if multiple).
- **D-25:** Display: sender avatar/name, truncated message preview, age label.
- **D-26:** Dismiss button for manual unpin.
- **D-27:** Bar appears only when pinned messages exist (from query).

### Claude's Discretion
- Exact amber/yellow shade for @mention highlight bubbles.
- @ badge icon style and position on message bubble.
- Pinned bar exact height, padding, animation for collapse/expand.
- Age label format ("2h", "2h ago", "2 hours ago").
- Carousel vs single display for multiple simultaneous pinned messages.
- FCM cloud function implementation details.

</decisions>

<canonical_refs>
## Canonical References

### Phase Definition
- `.planning/ROADMAP.md` §Phase7 — Goal and scope

### Existing Code (Must Read)
- `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` — Main group chat screen, message sending, stream setup
- `lib/pages/home_hamburger/channel_screen/message.dart` — Message model (add mentionedUids, pinnedUntil fields)
- `lib/pages/home_hamburger/channel_screen/message_actions.dart` — Long-press action sheet pattern
- `lib/pages/home_hamburger/channel_screen/message_edit_delete.dart` — Message mutation pattern
- `lib/pages/home_hamburger/channel_screen/chats_screen.dart` — Chat list, role checks, drawer

### Data Models
- `lib/pages/home_hamburger/channel_screen/chat_item.dart` — ChatItem model (ChatType enum)
- `lib/pages/home_hamburger/channel_screen/message.dart` — Message model

### Architecture & Conventions
- `.planning/codebase/ARCHITECTURE.md` — Real-time stream patterns, data flow
- `.planning/codebase/CONVENTIONS.md` — Role checks, color usage, widget patterns
- `.planning/codebase/STRUCTURE.md` — Directory layout

### Prior Decisions
- `.planning/phases/06-create-tasks-features/06-CONTEXT.md` — Task feature decisions (task messages trigger push)
- `.planning/phases/05-visual-distinction/05-CONTEXT.md` — Visual patterns, role badge, color scheme

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Message model** (`message.dart`) — Add `mentionedUids`, `pinnedUntil` fields. Existing pattern for adding fields.
- **Group chat screen** (`group_chat_screen.dart`) — Message sending, stream parsing, bubble rendering. Insert @ detection here.
- **Action sheet pattern** (`message_actions.dart`) — Reusable bottom sheet. Can extend for notification toggle.
- **Role check pattern** (`_userRole == 'faculty'`) — Used throughout for faculty-only features.

### Established Patterns
- **StatefulWidget + StreamSubscription** — GroupChatScreen uses this. Pin bar needs own stream subscription.
- **Firestore field additions** — Existing pattern (Message model fields). Add `mentionedUids`, `pinnedUntil`.
- **Batch writes** — Used for message deletion. Pinned bar queries are read-only.
- **Role-based visibility** — Faculty-only checks already in group_chat_screen.dart.

### Integration Points
- **`group_chat_screen.dart` `_sendMessage()`** — Must parse @mentions, write mentionedUids and pinnedUntil.
- **`group_chat_screen.dart` message list** — Must render @ badges and highlight bubbles.
- **`group_chat_screen.dart` layout** — Insert pinned bar widget between AppBar and ListView.
- **`group_chat_screen.dart` group info panel** — Add notification strategy toggle.
- **Firestore `group_chats/{chatId}/members/{uid}`** — New subcollection for per-member notificationStrategy.
- **FCM token registration** — New integration point in auth flow or chat screen init.

</code_context>

<specifics>
## Specific Ideas

- **Like Discord/Slack** — @ autocomplete dropdown style, chip/pill in input
- **@everyone replaces old announcement feature** — More flexible, persistent in chat stream
- **Tiered notification model reduces fatigue ~80%** — Silent push for normal messages, full push for signals
- **Faculty may manage many groups** — Per-chat toggle lets them prioritize active courses

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 7-@Mentions & Pinned Messages*
*Context gathered: 2026-05-16*