/// The bin.
///
///   dart test test/bin_test.dart
///
/// Translated from the pure half of `test/bin.test.ts`. The other half drove a
/// real Dexie database — deleting, restoring, sweeping — and comes back in
/// phase 2 against Drift. What is here is the arithmetic, which is where both
/// off-by-ones live: whether the day you delete something counts, and whether
/// "0 days left" means today or means gone.
///
/// One web assertion is not here: `daysLeft('not a date')` reading as freshly
/// deleted. `deletedAt` is a `DateTime?`, so the case cannot be built — the
/// same type-level deletion as in nudges_test.dart, and it moves to the backup
/// importer with the others.
library;

import 'package:stash_it/logic/bin.dart';
import 'package:stash_it/logic/limits.dart';
import 'package:stash_it/models/settings.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 8, 12, 9);

DateTime daysAgo(int n) => now.subtract(Duration(days: n));

BinEntry binned(String id, int ago) =>
    BinEntry(id: id, kind: BinKind.item, name: id, deletedAt: daysAgo(ago));

const free = Entitlements();
const pro = Entitlements(proUnlock: true);

void main() {
  group('the countdown', () {
    test('a fresh delete has the full window', () {
      expect(daysLeft(daysAgo(0), now), purgeAfterDays);
    });

    test('a day in, one fewer', () {
      expect(daysLeft(daysAgo(1), now), purgeAfterDays - 1);
    });

    test('the day before it goes', () {
      expect(daysLeft(daysAgo(purgeAfterDays - 1), now), 1);
    });

    test('the day it goes', () {
      expect(daysLeft(daysAgo(purgeAfterDays), now), 0);
    });

    // An item past its date goes on the next launch, and "-2 days left" is not
    // a thing to tell somebody.
    test('never negative', () {
      expect(daysLeft(daysAgo(purgeAfterDays + 5), now), 0);
    });

    // Rounded up: any part of a day remaining is still a day you have. Deleted
    // 28½ days ago leaves 1½ days, which is told to the user as 2.
    test('a part-day counts as a whole one', () {
      final halfway =
          daysAgo(purgeAfterDays - 1).add(const Duration(hours: 12));
      expect(daysLeft(halfway, now), 2);
    });
  });

  group('the label', () {
    test('it counts', () => expect(daysLeftLabel(12), '12 days left'));
    test('one day is named, not numbered',
        () => expect(daysLeftLabel(1), 'Last day'));
    test('and today says so', () => expect(daysLeftLabel(0), 'Goes today'));
    test('as does anything past it',
        () => expect(daysLeftLabel(-3), 'Goes today'));
  });

  group('counting', () {
    /*
      "Things", not "items". The bin holds documents and subscriptions now, and
      "items" is the name of a tab — counting a binned passport as an "item"
      sends somebody to the wrong screen to look for it.
    */
    test('one reads singular', () => expect(binCount(1), '1 thing'));
    test('two do not', () => expect(binCount(2), '2 things'));
  });

  group('the summary', () {
    test('an empty bin says so',
        () => expect(binSummary([], now), 'Nothing here'));

    // The soonest rather than an average — the only deadline that matters is
    // the next one.
    test('it quotes the most urgent', () {
      final rows = [
        binned('Newest', 0),
        binned('Oldest', purgeAfterDays - 1),
        binned('Middle', 10),
      ];
      expect(binSummary(rows, now), '3 things · last day');
    });

    test('and reads singular for one', () {
      expect(binSummary([binned('Only', 0)], now), '1 thing · 30 days left');
    });
  });

  /*
    ── The order, which is the screen's whole argument ───────────────────────

    Every other list in the app is grouped by what a record is. The bin is
    sorted by what is about to go, across all three kinds at once, because the
    only question it answers is "what am I about to lose" — and a passport with
    two days left belongs above a kettle with twenty regardless of which tab
    either came from.
  */
  group('the order', () {
    test('soonest to go, first', () {
      final sorted = sortBin([
        binned('Newest', 0),
        binned('Oldest', 20),
        binned('Middle', 10),
      ]);
      expect(sorted.map((e) => e.name), ['Oldest', 'Middle', 'Newest']);
    });

    test('and the kinds are mixed rather than grouped', () {
      final sorted = sortBin([
        BinEntry(
          id: 'k',
          kind: BinKind.item,
          name: 'Kettle',
          deletedAt: daysAgo(1),
        ),
        BinEntry(
          id: 'p',
          kind: BinKind.paper,
          name: 'Passport',
          deletedAt: daysAgo(28),
        ),
      ]);
      expect(sorted.first.name, 'Passport');
    });

    // A live record in the bin list is a caller's bug. It sorts last rather
    // than crashing or being hurried to the top.
    test('a missing date sorts last', () {
      final sorted = sortBin([
        const BinEntry(
          id: 'x',
          kind: BinKind.item,
          name: 'Never deleted',
          deletedAt: null,
        ),
        binned('Real', 5),
      ]);
      expect(sorted.last.name, 'Never deleted');
    });
  });

  group('restoring', () {
    /*
      Restoring is subject to the cap, and it has to be. Deleting frees a slot
      immediately — deliberate, so someone at the limit can make room — but an
      unchecked restore would be a hole you could drive the whole tier through:
      fill up, delete the lot, fill up again, restore the lot.

      The cap is ON in the shipped app now — see `capEnforced`. These still
      set it explicitly rather than relying on the default: a test that only
      passes because of a global's current value is a test that silently stops
      testing when somebody flips the global.
    */
    setUp(() => capEnforced = true);
    tearDown(() => capEnforced = true);

    test('a subscriber can always restore',
        () => expect(canRestore(999, pro), isTrue));

    test('with room, so can anyone', () {
      expect(canRestore(freeItemLimit - 1, free), isTrue);
    });

    test('at the line, no',
        () => expect(canRestore(freeItemLimit, free), isFalse));
    test('past it, no',
        () => expect(canRestore(freeItemLimit + 4, free), isFalse));

    test('and the refusal says how to fix it, and promises nothing is lost',
        () {
      final why = restoreBlockedReason(freeItemLimit);
      // "Unlock", not "subscribe" — it is one payment, once, and offering the
      // wrong shape of deal answers a question nobody asked.
      expect(why, contains('unlock'));
      expect(why, contains('stays here'));
      expect(why, contains('$freeItemLimit'));
    });

    test('but with the cap off, nothing is refused at all', () {
      capEnforced = false;
      expect(canRestore(freeItemLimit + 100, free), isTrue);
      // Put back by hand as well as by tearDown, so the state is not left
      // wrong for anything sharing this isolate.
      capEnforced = true;
    });
  });
}
