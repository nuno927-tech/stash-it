/// When the app is allowed to ask for a rating.
///
///   flutter test test/review_test.dart
///
/// ── Every test here is a refusal ──────────────────────────────────────────
/// One case says yes. The rest are the reasons not to, and they are the point:
/// an app that asks for five stars before it has earned any is asking somebody
/// to vouch for something they have not used, and the honest answer to that is
/// one star.
///
/// The thresholds are judgements. Having them here means changing one is an
/// argument with a failing test rather than a number quietly edited inside a
/// widget.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/review.dart';

final now = DateTime(2026, 9, 3, 19);

DateTime daysAgo(int n) => now.subtract(Duration(days: n));

/// Somebody the app has served well: two months in, used often, a real stash,
/// backups working, nothing broken. Every test below takes this and spoils
/// exactly one thing.
///
/// The two "has it happened at all" facts are booleans rather than nullable
/// dates, and that is not a style choice — `backedUpAt ?? daysAgo(1)` reads a
/// deliberately-passed null as "not supplied" and hands back the default, so
/// the test for "no backup yet" was quietly testing a stash WITH a backup. It
/// passed for the wrong reason until the assertion caught it.
ReviewFacts earned({
  DateTime? installedAt,
  bool everInstalled = true,
  int daysUsed = 20,
  int records = 30,
  bool backedUp = true,
  DateTime? lastCrashAt,
  DateTime? askedAt,
  int asks = 0,
}) =>
    ReviewFacts(
      installedAt:
          everInstalled ? (installedAt ?? daysAgo(60)) : null,
      daysUsed: daysUsed,
      records: records,
      backedUpAt: backedUp ? daysAgo(1) : null,
      lastCrashAt: lastCrashAt,
      askedAt: askedAt,
      asks: asks,
    );

void main() {
  group('the one time it says yes', () {
    test('a stash that has been used, backed up and not broken', () {
      expect(timeToAsk(earned(), now: now), isTrue);
    });
  });

  group('too early', () {
    test('a fortnight is the floor', () {
      expect(
        timeToAsk(earned(installedAt: daysAgo(13)), now: now),
        isFalse,
      );
      expect(
        timeToAsk(earned(installedAt: daysAgo(14)), now: now),
        isTrue,
      );
    });

    /*
      An install that predates the column has no date, and the app genuinely
      does not know how long they have had it. Not knowing is a reason to wait
      rather than a reason to ask — the alternative is every existing user
      being prompted the day they upgrade.
    */
    test('and an unknown install date waits', () {
      expect(timeToAsk(earned(everInstalled: false), now: now), isFalse);
    });
  });

  group('not used enough to have an opinion', () {
    /*
      Days, not launches. A launch count rewards an app that is hard to use:
      five trips back because something did not save is five launches and no
      evidence of anything.
    */
    test('five separate days', () {
      expect(timeToAsk(earned(daysUsed: 4), now: now), isFalse);
      expect(timeToAsk(earned(daysUsed: 5), now: now), isTrue);
    });

    test('and ten records', () {
      expect(timeToAsk(earned(records: 9), now: now), isFalse);
      expect(timeToAsk(earned(records: 10), now: now), isTrue);
    });
  });

  /*
    ── The app has to have kept its promise first ──────────────────────────

    Stash it's whole pitch is that a lost phone is not a lost stash. Somebody
    whose backup has never run has not had that, and asking them to vouch for
    it is asking about something that has not happened.
  */
  test('nothing until a backup has actually worked', () {
    expect(timeToAsk(earned(backedUp: false), now: now), isFalse);
  });

  group('not on the back of a bad week', () {
    /*
      The prompt lands on whatever the app last made somebody feel. A crash a
      fortnight ago is history; a crash on Tuesday is the reason they would
      leave two stars and mean it.
    */
    test('a crash this week stops it', () {
      expect(timeToAsk(earned(lastCrashAt: daysAgo(2)), now: now), isFalse);
      expect(timeToAsk(earned(lastCrashAt: daysAgo(6)), now: now), isFalse);
    });

    test('an old one does not', () {
      expect(timeToAsk(earned(lastCrashAt: daysAgo(7)), now: now), isTrue);
      expect(timeToAsk(earned(lastCrashAt: daysAgo(90)), now: now), isTrue);
    });
  });

  group('and twice is the whole allowance', () {
    test('not again within four months', () {
      expect(
        timeToAsk(earned(askedAt: daysAgo(119), asks: 1), now: now),
        isFalse,
      );
    });

    test('a second one, once the gap has passed', () {
      expect(
        timeToAsk(earned(askedAt: daysAgo(120), asks: 1), now: now),
        isTrue,
      );
    });

    /*
      Somebody who has declined twice has answered the question. An app that
      keeps asking is telling them their answer did not count.
    */
    test('never a third, however long it has been', () {
      expect(
        timeToAsk(earned(askedAt: daysAgo(900), asks: 2), now: now),
        isFalse,
      );
    });
  });
}
