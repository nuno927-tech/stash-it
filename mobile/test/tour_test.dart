/// The tour.
///
///   dart test test/tour_test.dart
///
/// Translated from `test/tour.test.ts`. Two things are worth asserting: that
/// "remind me later" means something specific, and that the script still says
/// true things about the app it is introducing.
///
/// The second one is not decoration. The `notify` step had to be rewritten for
/// this port — the web copy promised that "the only thing that leaves this
/// phone is a delivery address and the days something is due", which was true
/// of web push and is now a lie, on the one screen written to earn trust. The
/// last group below is the guard against that happening again.
library;

import 'package:stash_it/logic/tour.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 8, 12, 9);

void main() {
  group('when it is due', () {
    test('never offered without a reminder pending', () {
      // The alternative is an app that periodically decides you would like to
      // be taught how to use it.
      expect(tourDue(const TourState(), now), isFalse);
    });

    test('nor once it has been done', () {
      final done = TourState(
        doneAt: DateTime(2026, 1, 1),
        remindAt: DateTime(2026, 1, 1),
      );
      expect(tourDue(done, now), isFalse);
    });

    test('a reminder still in the future waits', () {
      expect(tourDue(TourState(remindAt: now.add(const Duration(days: 1))), now), isFalse);
    });

    test('one that has come due fires', () {
      expect(tourDue(TourState(remindAt: now.subtract(const Duration(days: 1))), now), isTrue);
    });

    test('and the moment itself counts as due', () {
      expect(tourDue(TourState(remindAt: now), now), isTrue);
    });
  });

  group('remind me later', () {
    test('means three days, not "never"', () {
      expect(remindLater(now).difference(now).inDays, remindDays);
      expect(remindDays, 3);
    });

    test('and what it sets does not fire early', () {
      final state = TourState(remindAt: remindLater(now));
      expect(tourDue(state, now), isFalse);
      expect(tourDue(state, now.add(const Duration(days: remindDays))), isTrue);
    });
  });

  group('stepping', () {
    test('the last step knows it is last', () {
      expect(isLastStep(tourSteps.length - 1), isTrue);
      expect(isLastStep(0), isFalse);
    });

    test('an index past the end is clamped rather than thrown', () {
      expect(stepAt(999).key, tourSteps.last.key);
      expect(stepAt(-4).key, tourSteps.first.key);
    });
  });

  group('the script', () {
    /*
      A tour is a budget. Every screen added has to displace one, or it is not
      worth the tap it costs — documents, subscriptions and reminders all
      arrived after this was written, and appending a screen each would have
      made a fourteen-tap introduction to an app whose pitch is that it is
      quick.
    */
    /*
      ── Nine, and the ninth had to argue for itself ────────────────────────

      This said eight, and it failed the moment a step was added — which is
      the test doing exactly what it was written to do. The budget is not a
      style note; it is the difference between an introduction and a queue.

      The ninth earns its place by not being a tour screen. The other eight
      explain the app; this one collects the single thing the app needs back,
      and it is the last tap rather than an extra one before the end.

      Raise this number again only with a sentence of the same kind. "It
      seemed useful" is how a fourteen-tap onboarding gets built one
      reasonable step at a time.
    */
    test('is nine screens, and no more', () {
      expect(tourSteps.length, 9);
    });

    test('every step has a key, a title and words', () {
      for (final s in tourSteps) {
        expect(s.key, isNotEmpty);
        expect(s.title, isNotEmpty);
        expect(s.body.length, greaterThan(40), reason: s.key);
      }
    });

    test('and no key or pose is used twice', () {
      expect(tourSteps.map((s) => s.key).toSet().length, tourSteps.length);
      expect(tourSteps.map((s) => s.pose).toSet().length, tourSteps.length);
    });

    test('the paper step comes straight after adding', () {
      // That is the minute the receipt is still in your hand. Told at the end
      // it is advice; told there it is an instruction you can act on.
      final keys = tourSteps.map((s) => s.key).toList();
      expect(keys.indexOf('paper'), keys.indexOf('add') + 1);
    });

    /*
      ── The assertions that keep the script honest ────────────────────────

      Anyone being asked to put a passport into an app is entitled to know what
      it will actually hold before they start. These pin the two promises the
      app makes about itself, so a copy edit cannot quietly withdraw one.
    */
    test('the documents step still says no scans and no numbers', () {
      final papers = tourSteps.firstWhere((s) => s.key == 'papers');
      expect(papers.body, contains('no scans'));
      expect(papers.body, contains('no document numbers'));
    });

    test('and promises to warn before it is too late, not after', () {
      final papers = tourSteps.firstWhere((s) => s.key == 'papers');
      expect(papers.body.toLowerCase(), contains('start renewing'));
    });

    /*
      THE ONE THE PORT BROKE. The web copy described a delivery address being
      uploaded to a push server, because that is what web push required. There
      is no server here, so any sentence implying an upload is now false — and
      false in onboarding is the worst place for it.
    */
    test('the notify step does not describe an upload', () {
      final notify = tourSteps.firstWhere((s) => s.key == 'notify');
      final body = notify.body.toLowerCase();
      for (final gone in ['delivery address', 'leaves this phone', 'endpoint']) {
        expect(body.contains(gone), isFalse, reason: 'still says "$gone"');
      }
    });

    test('and says the phone keeps the schedule itself', () {
      final notify = tourSteps.firstWhere((s) => s.key == 'notify');
      expect(notify.body.toLowerCase(), contains('nothing is sent'));
    });

    test('the backup step still puts the backup on the user', () {
      final safe = tourSteps.firstWhere((s) => s.key == 'safe');
      expect(safe.body, contains('no account'));
      expect(safe.body.toLowerCase(), contains('back up now'));
    });
  });
}
