/// When the lock asks again.
///
/// The gate itself needs a platform, a sensor and a widget tree. This is the
/// half that needs none of those, and it is the half that decides whether the
/// lock is usable or gets switched off in a week.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/ui/lock_gate.dart';

void main() {
  group('the grace period', () {
    test('is thirty seconds',
        () => expect(lockGrace, const Duration(seconds: 30)));

    /*
      ── The case this exists for ────────────────────────────────────────────

      This app leaves itself constantly and legitimately: the camera for a
      receipt, the file picker for a manual, the share sheet for every backup.
      All of them background it.

      Without a grace period the lock would put a fingerprint between choosing
      a photo and seeing it attached, and another one after sending a backup.
      That is the version people turn off and never turn on again — so a short
      trip away has to come back open.
    */
    test('a trip to the camera and back does not re-lock', () {
      expect(shouldRelock(enabled: true, away: const Duration(seconds: 4)),
          isFalse);
      expect(shouldRelock(enabled: true, away: const Duration(seconds: 29)),
          isFalse);
    });

    test('a phone put down on a table does', () {
      expect(shouldRelock(enabled: true, away: const Duration(seconds: 30)),
          isTrue);
      expect(shouldRelock(enabled: true, away: const Duration(minutes: 5)),
          isTrue);
      expect(
          shouldRelock(enabled: true, away: const Duration(hours: 9)), isTrue);
    });

    // At the boundary, not past it. Thirty seconds away is thirty seconds, and
    // an off-by-one here is the difference between a rule and a suggestion.
    test('exactly thirty seconds counts as away', () {
      expect(shouldRelock(enabled: true, away: lockGrace), isTrue);
    });

    test('zero is not away', () {
      expect(shouldRelock(enabled: true, away: Duration.zero), isFalse);
    });
  });

  group('the switch still governs everything', () {
    /*
      The gate reads `biometricLock` once at launch and stops caring if it is
      off. This is the guard that says so: no duration, however long, wakes a
      lock nobody asked for.
    */
    test('with the lock off, nothing re-locks', () {
      expect(shouldRelock(enabled: false, away: Duration.zero), isFalse);
      expect(shouldRelock(enabled: false, away: const Duration(hours: 9)),
          isFalse);
      expect(shouldRelock(enabled: false, away: const Duration(days: 30)),
          isFalse);
    });
  });
}
