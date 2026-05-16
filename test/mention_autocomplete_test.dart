import 'package:flutter_test/flutter_test.dart';

void main() {
  group('@mention autocomplete', () {
    // Simulate the uidToName map that will exist in group_chat_screen
    final Map<String, String> uidToName = {
      'uid1': 'John Doe',
      'uid2': 'Jane Smith',
      'uid3': 'Bob Wilson',
    };

    // Simulate the mention regex from RESEARCH.md Pattern 1
    // Matches @ followed by one or more word characters (single name tokens).
    // Autocomplete works incrementally, so we match each token separately.
    final mentionRegex = RegExp(r'@(\w+)');

    List<MapEntry<String, String>> filterMembers(String query) {
      return uidToName.entries
          .where((e) => e.value.toLowerCase().contains(query.toLowerCase()))
          .take(10)
          .toList();
    }

    test('returns matching members when typing @Jo', () {
      final results = filterMembers('Jo');
      expect(results.length, 1);
      expect(results.first.value, 'John Doe');
    });

    test('returns matching members when typing @ja', () {
      final results = filterMembers('ja');
      expect(results.length, 1);
      expect(results.first.value, 'Jane Smith');
    });

    test('returns empty list when no matches', () {
      final results = filterMembers('zzz');
      expect(results, isEmpty);
    });

    test('returns all members when @ with no query', () {
      final results = filterMembers('');
      expect(results.length, 3);
    });

    test('mention regex matches @DisplayName tokens', () {
      const text = 'Hey @John check this out';
      final matches = mentionRegex.allMatches(text);
      expect(matches.length, 1);
      expect(matches.first.group(1), 'John');
    });

    test('mention regex matches multiple @mentions', () {
      const text = '@John and @Jane please review';
      final matches = mentionRegex.allMatches(text);
      expect(matches.length, 2);
      expect(matches.first.group(1), 'John');
      expect(matches.last.group(1), 'Jane');
    });

    test('mention regex does not match standalone @', () {
      expect(mentionRegex.hasMatch('@'), false);
    });
  });
}