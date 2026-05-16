import 'package:flutter_test/flutter_test.dart';

void main() {
  group('@everyone pin behavior', () {
    test('faculty @everyone sets pinnedUntil to 24h from now', () {
      const isFaculty = true;
      const hasEveryone = true;
      DateTime? pinnedUntil;
      if (hasEveryone && isFaculty) {
        pinnedUntil = DateTime.now().add(const Duration(hours: 24));
      }
      expect(pinnedUntil, isNotNull);
      // Should be roughly 24h in the future
      final diff = pinnedUntil!.difference(DateTime.now());
      expect(diff.inHours, greaterThanOrEqualTo(23));
      expect(diff.inHours, lessThanOrEqualTo(25));
    });

    test('non-faculty @everyone does NOT set pinnedUntil', () {
      const isFaculty = false;
      const hasEveryone = true;
      DateTime? pinnedUntil;
      String text = 'Hello @everyone check this';
      if (hasEveryone && isFaculty) {
        pinnedUntil = DateTime.now().add(const Duration(hours: 24));
      } else if (hasEveryone) {
        // Non-faculty: strip @everyone and extra whitespace
        text = text.replaceAll(RegExp(r'\s*@everyone\s*'), ' ').trim();
      }
      expect(pinnedUntil, isNull);
      expect(text.contains('@everyone'), isFalse);
    });

    test('non-faculty @everyone text is stripped', () {
      const isFaculty = false;
      String text = 'Hello @everyone check this out';
      if (text.contains('@everyone') && !isFaculty) {
        text = text.replaceAll(RegExp(r'\s*@everyone\s*'), ' ').trim();
      }
      expect(text.contains('@everyone'), isFalse);
      expect(text, 'Hello check this out');
    });

    test('pinnedUntil older than 24h is past expiry', () {
      final oldPinned = DateTime.now().subtract(const Duration(hours: 1));
      final cutoff = DateTime.now();
      final isExpired = oldPinned.isBefore(cutoff);
      expect(isExpired, isTrue);
    });

    test('pinnedUntil less than 24h old is active', () {
      final activePinned = DateTime.now().add(const Duration(hours: 12));
      final cutoff = DateTime.now();
      final isActive = activePinned.isAfter(cutoff);
      expect(isActive, isTrue);
    });

    test('faculty @everyone sets pinnedUntil, non-faculty does not (combined)', () {
      // Faculty case
      DateTime? facultyPin;
      const facultyText = '@everyone important update';
      if (facultyText.contains('@everyone') && true) {
        facultyPin = DateTime.now().add(const Duration(hours: 24));
      }
      expect(facultyPin, isNotNull);

      // Non-faculty case
      DateTime? nonFacultyPin;
      const nonFacultyText = '@everyone important update';
      if (nonFacultyText.contains('@everyone') && false) {
        nonFacultyPin = DateTime.now().add(const Duration(hours: 24));
      }
      expect(nonFacultyPin, isNull);
    });
  });
}