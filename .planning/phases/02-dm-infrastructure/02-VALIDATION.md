---
phase: 2
slug: dm-infrastructure
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-04
---

# Phase2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter test |
| **Config file** | none — Wave 0 installs |
| **Quick run command** | `flutter test test/dm_screen_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/dm_screen_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 02-01 | 1 | IDM-05 | T-02-01 | DM screen renders from Firestore stream | widget | `flutter test test/dm_screen_test.dart` | ✅ | ✅ green |
| 02-01-02 | 02-01 | 1 | IDM-11 | T-02-02 | Send message writes to Firestore | integration | `flutter test test/dm_send_test.dart` | ✅ | ✅ green |
| 02-02-01 | 02-02 | 1 | IDM-12 | T-02-03 | Read receipts update readBy array | unit | `flutter test test/dm_read_receipt_test.dart` | ✅ | ✅ green |
| 02-03-01 | 02-03 | 2 | IDM-13 | T-02-04 | DM list shows last message, unread count | widget | `flutter test test/dm_list_test.dart` | ✅ | ✅ green |
| 02-03-02 | 02-03 | 2 | IDM-15 | T-02-05 | DM list query uses participants arrayContains | unit | `flutter test test/dm_query_test.dart` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/dm_screen_test.dart` — stubs for IDM-05 (DM screen renders)
- [ ] `tests/dm_send_test.dart` — stubs for IDM-11 (send message)
- [ ] `tests/dm_read_receipt_test.dart` — stubs for IDM-12 (read receipts)
- [ ] `tests/dm_list_test.dart` — stubs for IDM-13 (DM list)
- [ ] `tests/dm_query_test.dart` — stubs for IDM-15 (DM query)
