/// Whether the tour shows on a given launch.
///
/// ── Why this file exists ──────────────────────────────────────────────────
/// `tourDue` was already written and already tested. What was missing was
/// anything that called it — `showTour` was reachable only from the "Take the
/// tour" row in Settings, so a fresh install opened onto an empty dashboard
/// and explained nothing.
///
/// `tourOnLaunch` is the question that had no answer, and these are its cases.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/tour.dart';

final now = DateTime(2026, 8, 27, 9);

void main() {
  group('a fresh install', () {
    /*
      The bug, as a test.

      Nothing done, nothing pending: this is the state of every phone the
      moment the app is installed, and it is the state that produced no tour
      at all for sixty versions.
    */
    test('shows the tour', () {
      expect(tourOnLaunch(const TourState(), now), isTrue);
    });
  });

  group('somebody who finished it', () {
    test('is never shown it again', () {
      expect(
        tourOnLaunch(
            TourState(doneAt: now.subtract(const Duration(days: 1))), now),
        isFalse,
      );
    });

    // Finishing wins over a pending reminder. Somebody who skipped, then went
    // to Settings and took the tour properly, has answered the question — the
    // old reminder must not resurface three days later.
    test('even with a reminder still on the record', () {
      expect(
        tourOnLaunch(
          TourState(
              doneAt: now, remindAt: now.subtract(const Duration(days: 9))),
          now,
        ),
        isFalse,
      );
    });
  });

  group('somebody who skipped', () {
    test('is left alone until the three days are up', () {
      final skipped = TourState(remindAt: remindLater(now));
      expect(tourOnLaunch(skipped, now), isFalse);
      expect(tourOnLaunch(skipped, now.add(const Duration(days: 2))), isFalse);
      expect(
        tourOnLaunch(skipped, now.add(const Duration(days: 2, hours: 23))),
        isFalse,
      );
    });

    test('and is offered it once when they are', () {
      final skipped = TourState(remindAt: remindLater(now));
      expect(tourOnLaunch(skipped, now.add(const Duration(days: 3))), isTrue);
      expect(tourOnLaunch(skipped, now.add(const Duration(days: 30))), isTrue);
    });

    // At the boundary, not past it — the same rule `tourDue` already held.
    test('exactly three days later counts as due', () {
      expect(tourOnLaunch(TourState(remindAt: now), now), isTrue);
    });
  });

  group('the three days', () {
    test('is what remindDays says', () => expect(remindDays, 3));

    test('remindLater lands three days out', () {
      expect(remindLater(now), now.add(const Duration(days: 3)));
    });
  });

  group('the name step', () {
    /*
      Last, and it has to stay last: the sheet writes `onboardedAt` on the
      final tap, which is the same tap that saves the name. A step added after
      it would mean reaching the name, typing one, and then having the tour
      decide it was not finished yet.
    */
    test('is the final step', () {
      expect(tourSteps.last.key, nameStepKey);
      expect(isLastStep(tourSteps.length - 1), isTrue);
    });

    test('and is the only one carrying a field', () {
      expect(tourSteps.where((s) => s.key == nameStepKey).length, 1);
    });
  });
}
