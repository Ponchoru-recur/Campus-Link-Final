---
date: 2026-05-04
focus: quality
---

# Testing — Campus Link (Luminescence)

## Current State

**NO TESTS EXIST.** The `test/` directory is empty. There are no:
- Widget tests
- Unit tests
- Integration tests
- Firebase mocking

## Test Framework

| Item | Status |
|------|--------|
| Package | `flutter_test` (from SDK) |
| Lint rules | `flutter_lints ^6.0.0` |
| Test directory | `test/` (empty) |
| Widget test file | `test/widget_test.dart` (referenced in commands, may not exist) |

## Test Commands

```bash
flutter test                    # Run all tests
flutter test test/widget_test.dart  # Run specific file
flutter analyze               # Static analysis (run this!)
```

## What Should Be Tested

### Critical paths (when tests are added):
1. **Auth flow** — login, signup, email verification, role persistence
2. **Firestore operations** — message send/edit/delete, group chat CRUD
3. **Role-based access** — faculty vs student UI differences
4. **Message editing/deletion** — 60-minute window logic, soft delete
5. **Read receipts** — `readBy` array updates
6. **Email validation** — `@carsu.edu.ph` regex

### Testing Challenges
- **Firebase dependencies**: Need `firebase_core` initialized for most tests
- **Possible approach**: `firebase_core` has test alternatives, or use `mockito`/`fake_cloud_firestore` packages
- **StreamBuilder widgets**: Need to pump and settle with stream data

## Test Patterns (Recommended)

### Widget test skeleton:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:luminescence/main.dart';

void main() {
  testWidgets('App renders login screen when not authenticated', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Login'), findsOneWidget);
  });
}
```

### Firebase mocking (when added):
- Consider `fake_cloud_firestore` package for in-memory Firestore testing
- Consider `mockito` for `FirebaseAuth` mocking
- Or use `firebase_core` test utilities if available
