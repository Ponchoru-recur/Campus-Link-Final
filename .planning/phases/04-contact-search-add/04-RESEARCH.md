# Phase 4: Contact Search & Add - Research

**Researched:** 2026-05-05
**Domain:** Flutter + Firebase Firestore user search and contact management
**Confidence:** MEDIUM

## Summary

Phase 4 adds contact search and add functionality to Campus Link. Users need to search for peers by email or name within the `@carsu.edu.ph` domain and add them as DM contacts. The search must create `direct_messages` documents in Firestore when a new contact is added.

The main integration point is `chats_screen.dart`, which currently displays group chats and DMs in a simple ListView. A search bar must be added, along with a mechanism to query Firestore `users` collection and display results. When a user taps a search result, a `direct_messages` document is created (if it doesn't exist), and the DM appears in their chat list via the existing stream.

Key challenge: Firestore lacks native full-text search. For a university-scale app (~10k users max), client-side filtering after fetching users is the simplest approach. Alternative is prefix search using Firestore range queries on a lowercase search field.

**Primary recommendation:** Add search icon to AppBar that reveals an inline search bar. Fetch all `users` collection documents once, cache in memory, and filter locally by email/name prefix. Use a `searchName` (lowercase, no dots) and `searchEmail` (lowercase) field on user documents for efficient prefix matching. On search result tap, atomically check-and-create `direct_messages` document with both users as members.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| User search UI | Frontend (Flutter) | — | Search bar and results rendering are client-side UI |
| User search query | Frontend (Flutter) | Firebase Firestore | Client builds query/filter; Firestore stores user data |
| Contact addition | Frontend (Flutter) | Firebase Firestore | Client creates `direct_messages` doc; Firestore persists |
| DM list update | Firebase Firestore | Frontend (Flutter) | Stream automatically updates UI via `arrayContains` query |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `cloud_firestore` | ^5.6.5 (verify) | Firestore queries for `users` collection | Already in use; same pattern as group chat/DM streams |
| `firebase_auth` | ^5.3.1 (verify) | Get current user UID for contact creation | Already in use; needed for `members` array |

**Installation:** Already installed (per `pubspec.yaml`).

**Version verification:**
```bash
flutter pub deps | grep cloud_firestore
flutter pub deps | grep firebase_auth
```
[ASSUMED: versions from training data — verify against pubspec.yaml]

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `rxdart` | ^0.28.0 | Debounce search input | If search needs throttling for server-side queries |

## Architecture Patterns

### System Architecture Diagram

```
[User] --> [Search Bar (chats_screen.dart)]
              |
              v
    [Local User Cache (Map/List)]
              |
              v (filter by email/name prefix)
    [Search Results List (new widget)]
              |
              v (on tap)
    [Check if DM exists: Firestore query]
              |
              +-- Yes --> [Navigate to IndividualChatScreen]
              |
              +-- No  --> [Create direct_messages doc] --> [Stream auto-updates DM list]
```

### Recommended Project Structure
```
lib/pages/home_hamburger/channel_screen/
├── chats_screen.dart          # ADD: search bar, search results overlay
├── direct_message_tile.dart   # KEEP: unchanged (used in DM list)
├── direct_message_item.dart   # KEEP: unchanged (data model)
├── search_result_tile.dart    # NEW: tile for search results
├── contact_search_bar.dart    # NEW: reusable search bar widget (optional)
└── individual_chat_screen.dart # KEEP: unchanged
```

### Pattern 1: Inline Search Bar with Toggle
**What:** Search icon in AppBar expands to show search field inline; search results appear below existing chat list.
**When to use:** When you want search integrated into the main screen without navigation.
**Example:**
```dart
// Source: [ASSUMED: standard Flutter pattern]
bool _isSearching = false;
String _searchQuery = '';

AppBar(
  title: _isSearching
      ? TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search by name or email...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: TextStyle(color: Colors.white),
          onChanged: (value) => setState(() => _searchQuery = value),
        )
      : const Text('Chats'),
  actions: [
    IconButton(
      icon: Icon(_isSearching ? Icons.close : Icons.search),
      onPressed: () => setState(() {
        _isSearching = !_isSearching;
        if (!_isSearching) _searchQuery = '';
      }),
    ),
  ],
)
```

### Pattern 2: Client-Side User Cache with Prefix Filter
**What:** Fetch all users once, store in `List<Map<String, dynamic>>`, filter locally.
**When to use:** University-scale app (< 50k users), simpler than server-side search.
**Example:**
```dart
// Source: [ASSUMED: standard Flutter/Firestore pattern]
List<Map<String, dynamic>> _allUsers = [];
List<Map<String, dynamic>> _searchResults = [];

Future<void> _fetchAllUsers() async {
  final snapshot = await FirebaseFirestore.instance.collection('users').get();
  _allUsers = snapshot.docs.map((doc) {
    final data = doc.data();
    return {
      'uid': doc.id,
      'email': data['email'] ?? '',
      'role': data['role'] ?? 'student',
      'searchEmail': (data['email'] ?? '').toString().toLowerCase(),
      'searchName': _extractName(data['email']).toLowerCase(),
    };
  }).toList();
}

void _onSearchChanged(String query) {
  if (query.isEmpty) {
    setState(() => _searchResults = []);
    return;
  }
  final lowerQuery = query.toLowerCase();
  setState(() {
    _searchResults = _allUsers.where((user) {
      return user['searchEmail'].startsWith(lowerQuery) ||
             user['searchName'].startsWith(lowerQuery);
    }).toList();
  });
}
```

### Anti-Patterns to Avoid
- **Server-side prefix search without search field:** Firestore range queries (`isGreaterThanOrEqualTo`) only work on a single field. Doing email + name search requires two queries and manual merge.
- **Creating duplicate DM documents:** Always check if a `direct_messages` doc with both members already exists before creating. Use a compound query: `where('members', arrayContains: userA).where('members', arrayContains: userB)` — but this requires a composite index.
- **Searching on every keystroke with Firestore:** Firestore doesn't support debouncing natively; rapid queries waste reads. Use client-side cache instead.
- **Hardcoded colors in new widgets:** Follow existing pattern — use `AppColors` with `withValues(alpha:)`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Full-text search | Custom search logic with multiple Firestore queries | Client-side filtering OR Algolia plugin | Firestore range queries are limited; client-side is simpler for university scale |
| Debounce search input | Custom timer logic | `Timer` class (Dart core) | Simple `Timer(Duration(milliseconds: 300), () { ... })` suffices |
| Email validation | Custom regex | Reuse existing `^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$` from `login_screen.dart` | Already tested and enforced in app |

**Key insight:** For a university-scale app, fetching all users once (~10k docs = ~2MB) is simpler and cheaper than complex Firestore queries. Firestore charges per document read, so client-side filtering actually saves money after the initial fetch.

## Runtime State Inventory

> Phase 4 is NOT a rename/refactor/migration phase. This section is omitted per guidelines.

## Common Pitfalls

### Pitfall 1: Duplicate DM Documents
**What goes wrong:** Two users search for each other and both create separate `direct_messages` docs, resulting in two DM threads for the same pair.
**Why it happens:** No atomic check-and-create logic; race condition between read and write.
**How to avoid:** Use a deterministic document ID based on sorted UIDs (e.g., `uid1_uid2` where `uid1 < uid2`). This ensures both users generate the same document ID.
**Warning signs:** User sees two DMs with the same person; messages appear in only one thread.

### Pitfall 2: Firestore Prefix Search Limitations
**What goes wrong:** Trying to do `WHERE email STARTS WITH 'john'` — Firestore doesn't support this natively.
**Why it happens:** Firestore queries are limited to equality, range, and array operations.
**How to avoid:** Use `isGreaterThanOrEqualTo: 'john'` + `isLessThan: 'john~'` pattern on a lowercase search field, OR use client-side filtering.
**Warning signs:** Getting 0 results for partial email searches; queries returning unexpected results.

### Pitfall 3: Search Bar Destroying Chat List Layout
**What goes wrong:** Adding search bar pushes existing chat list down, creating janky UI.
**Why it happens:** Search bar added above chat list without proper conditional rendering.
**How to avoid:** Use `if (_isSearching) ...` to conditionally show search bar, or use `Stack` with overlay for search results.
**Warning signs:** Chat list jumps when search is toggled; scroll position lost.

### Pitfall 4: Forgetting to Cancel User Cache Stream/Subscription
**What goes wrong:** Memory leak from cached user list not being cleared on logout.
**Why it happens:** `_allUsers` list persists in `_ChatsScreenState` but is never cleared.
**How to avoid:** In `dispose()`, clear the cache: `_allUsers.clear()`. Or fetch fresh on each search session.
**Warning signs:** Stale user data after logout/login; memory usage grows over time.

## Code Examples

Verified patterns from existing codebase:

### Existing DM Stream Pattern (from chats_screen.dart lines 111-134)
```dart
// Source: chats_screen.dart (existing code, verified)
void _setupDirectMessagesStream() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || _isDisposed) return;

  _directMessagesSubscription = FirebaseFirestore.instance
      .collection('direct_messages')
      .where('members', arrayContains: user.uid)
      .snapshots()
      .listen((snapshot) {
    if (_isDisposed || !mounted) return;
    setState(() {
      _directMessages = snapshot.docs.map((doc) {
        return DirectMessageItem.fromFirestore(doc, user.uid);
      }).toList();
    });
  });
}
```

### Deterministic DM Document ID (recommended pattern)
```dart
// Source: [ASSUMED: standard Firestore pattern]
String _generateDmDocId(String uid1, String uid2) {
  final sorted = [uid1, uid2]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

Future<void> _addContact(String otherUid) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null || currentUid == otherUid) return;

  final dmDocId = _generateDmDocId(currentUid, otherUid);
  final dmRef = FirebaseFirestore.instance.collection('direct_messages').doc(dmDocId);

  final doc = await dmRef.get();
  if (doc.exists) {
    // Already contacts; just navigate
    return;
  }

  await dmRef.set({
    'members': [currentUid, otherUid],
    'unreadCount': {currentUid: 0, otherUid: 0},
    'lastMessage': '',
    'time': 'Now',
    'createdAt': FieldValue.serverTimestamp(),
  });
}
```

### Search Result Tile (new widget)
```dart
// Source: [ASSUMED: follows DirectMessageTile pattern]
class SearchResultTile extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final VoidCallback onTap;

  const SearchResultTile({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFaculty = role == 'faculty';
    final accentColor = isFaculty ? AppColors.instructorPurple : AppColors.primary;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: accentColor.withValues(alpha: 0.15),
        child: Icon(Icons.person, color: accentColor, size: 22),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          role[0].toUpperCase() + role.substring(1),
          style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w500),
        ),
      ),
      onTap: onTap,
    );
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded `_instructorChats` list | Firestore-backed `direct_messages` stream | Phase 1-2 | DMs now persist and sync in real-time |
| No contact search | Manually know email to contact | Phase 4 (this) | Users can discover peers |

**Deprecated/outdated:**
- `instructor_chats` collection reference in ROADMAP.md success criteria (line 90): Should be `direct_messages` collection, not `instructor_chats`. Phase 1-2 already established `direct_messages` as the schema.

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research. The planner and discuss-phase use this section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `cloud_firestore` version ^5.6.5 and `firebase_auth` version ^5.3.1 are current | Standard Stack | Wrong version may have different API; planner may use incorrect imports |
| A2 | Client-side filtering is acceptable for university scale (~10k users, ~2MB data) | Architecture Patterns, Don't Hand-Roll | If user base is larger than expected, performance may suffer; may need pagination |
| A3 | Deterministic DM doc ID using sorted UIDs is the best approach to avoid duplicates | Code Examples | If Firestore has a better atomic merge pattern, this may be unnecessary |
| A4 | Search bar should use AppBar toggle pattern (search icon expands to field) | Architecture Patterns | User may prefer inline search bar or separate search page |
| A5 | `searchName` should be extracted from email (dot-separated: `first.last@...`) | Code Examples | If users can set display names in profiles, should search those instead |
| A6 | Firestore `users` collection has `email`, `role`, `createdAt`, `emailVerified` fields | Standard Stack, Code Examples | If schema differs, search queries will fail |

## Open Questions (RESOLVED)

1. **[RESOLVED] Do users have display names in Firestore `users` collection, or should search use email-only?**
   - What we know: Current `users/{uid}` schema has `email`, `role`, `createdAt`, `emailVerified` (per CLAUDE.md)
   - What's unclear: Whether a `displayName` or `name` field exists or should be added
   - Resolution: Search email by default. Extract name from email as fallback (split on `@`, replace `.` with ` `, capitalize). If `displayName` field exists in users collection, include it in search.
   - Implemented in: 04-01-PLAN.md Task 2 (filter by email and name)

2. **[RESOLVED] Should the search also show existing DM contacts (to prevent duplicates), or only show new users?**
   - What we know: `_directMessages` stream already shows existing contacts
   - What's unclear: Should search results filter out existing contacts automatically?
   - Resolution: Filter out existing contacts from search results. The DM list shows existing contacts separately.
   - Implemented in: 04-01-PLAN.md Task 2 (filter existing contacts from results)

3. **[RESOLVED] What UI feedback when tapping a search result?**
   - What we know: SnackBar pattern used elsewhere (e.g., group chat deletion)
   - What's unclear: Should we navigate to the new DM immediately, or just show confirmation?
   - Resolution: Show SnackBar "Contact added" and navigate to IndividualChatScreen. The existing DM stream auto-updates the list.
   - Implemented in: 04-02-PLAN.md Task 1 (SnackBar) and Task 2 (navigation)

4. **[RESOLVED] Should we add a `searchName` and `searchEmail` field to `users` documents?**
   - What we know: Firestore queries for prefix search need lowercase fields
   - What's unclear: Can we add fields to existing user documents?
   - Resolution: Client-side filtering approach (from 04-01-PLAN.md) doesn't require `searchName`/`searchEmail` fields. The app fetches users and filters locally (case-insensitive). If server-side search is needed later, these fields can be added.
   - Implemented in: 04-01-PLAN.md Task 2 (client-side filtering, no server-side search fields needed)

## Environment Availability

> Phase 4 has no new external dependencies beyond existing Flutter/Firebase setup.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter | All UI code | ✓ | Check with `flutter --version` | — |
| Firebase Auth | Get current user UID | ✓ | (existing) | — |
| Cloud Firestore | User search, DM creation | ✓ | (existing) | — |

**Missing dependencies with no fallback:** None

**Missing dependencies with fallback:** None

## Validation Architecture

> `workflow.nyquist_validation` is `true` in config.json — section included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | None — uses default |
| Quick run command | `flutter test test/contact_search_test.dart --tags=quick` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IDM-06 | Search bar allows users to search by email or name within @carsu.edu.ph domain | widget | `flutter test test/contact_search_test.dart -t search_bar` | ❌ Wave 0 |
| IDM-07 | Search results show matching users; tapping creates direct_messages document | integration | `flutter test test/contact_search_test.dart -t add_contact` | ❌ Wave 0 |
| IDM-06 | Reuse existing email validation regex `^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$` | unit | `flutter test test/contact_search_test.dart -t validation` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/contact_search_test.dart --tags=quick`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/contact_search_test.dart` — covers IDM-06 (search bar UI, email/name search)
- [ ] `test/contact_search_test.dart` — covers IDM-07 (add contact, DM creation)
- [ ] `test/contact_search_test.dart` — covers email validation regex reuse
- [ ] `test/conftest.dart` — shared fixtures for user documents (if needed)

*(If no gaps: "None — existing test infrastructure covers all phase requirements")*

## Security Domain

> `security_enforcement` is enabled (absent in config.json = enabled). Section included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — (already handled by Firebase Auth) |
| V3 Session Management | No | — (already handled by Firebase Auth) |
| V4 Access Control | Yes | Firestore security rules — users can only create DMs where they are a member |
| V5 Input Validation | Yes | Email validation regex `^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$` on search input |
| V6 Cryptography | No | — (no custom crypto needed) |

### Known Threat Patterns for Flutter + Firestore

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unauthorized DM creation (adding someone not in domain) | Tampering/Elevation | Validate email domain before creating DM; Firestore rule: `request.resource.data.members` contains `request.auth.uid` |
| Search injection (malicious input in search field) | Tampering | Search is client-side filtering, not a query — low risk. Still validate input length (< 100 chars). |
| Email enumeration (search reveals all users) | Information Disclosure | By design, search shows users. Mitigate by requiring authentication before search access. |

**Firestore Security Rule needed for Phase 4:**
```javascript
// Source: [ASSUMED: standard Firestore security rules pattern]
// Allow users to create DMs only with themselves as member
match /direct_messages/{dmId} {
  allow create: if request.auth != null
    && request.resource.data.members.contains(request.auth.uid)
    && request.resource.data.members.size() == 2;
}
```

## Sources

### Primary (HIGH confidence)
- `chats_screen.dart` — analyzed: existing DM stream, chat list layout, AppBar structure
- `direct_message_item.dart` — analyzed: DM data model with `otherParticipantUid`, `otherParticipantName`, `otherParticipantRole`
- `direct_message_tile.dart` — analyzed: tile UI pattern to follow for search results
- `individual_chat_screen.dart` — analyzed: DM conversation screen, message streaming
- `chat_item.dart` — analyzed: `ChatType` enum (`groupChat`, `directMessage`)
- `CLAUDE.md` — analyzed: architecture, Firestore schema, conventions, email regex
- `.planning/ROADMAP.md` — analyzed: Phase 4 goal, requirements IDM-06/IDM-07, success criteria

### Secondary (MEDIUM confidence)
- `docs/REQUIREMENTS.md` — reviewed: user management, messaging, UI screens sections
- `.planning/config.json` — verified: `nyquist_validation: true`

### Tertiary (LOW confidence)
- [ASSUMED: Flutter/Firestore documentation] — Firestore prefix search patterns, deterministic document IDs
- [ASSUMED: standard Flutter patterns] — Search bar UI patterns, client-side filtering approach

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM - versions assumed from training data; need verification against pubspec.yaml
- Architecture: HIGH - based on existing codebase patterns in chats_screen.dart and direct_message_tile.dart
- Pitfalls: HIGH - based on known Firestore limitations and codebase analysis

**Research date:** 2026-05-05
**Valid until:** 2026-06-05 (30 days for stable Flutter/Firebase ecosystem)
