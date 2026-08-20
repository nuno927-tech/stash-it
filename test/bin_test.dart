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
import 'package:stash_it/models/types.dart';
import 'package:test/test.dart';

final now = DateTime(2026, 8, 12, 9);

DateTime daysAgo(int n) => now.subtract(Duration(days: n));

Item binned(String id, int ago) =>
    Item(id: id, name: id, propertyId: 'p', deletedAt: daysAgo(ago));

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
      final halfway = daysAgo(purgeAfterDays - 1).add(const Duration(hours: 12));
      expect(daysLeft(halfway, now), 2);
    });
  });

  group('the label', () {
    test('it counts', () => expect(daysLeftLabel(12), '12 days left'));
    test('one day is named, not numbered', () => expect(daysLeftLabel(1), 'Last day'));
    test('and today says so', () => expect(daysLeftLabel(0), 'Goes today'));
    test('as does anything past it', () => expect(daysLeftLabel(-3), 'Goes today'));
  });

  group('counting', () {
    test('one item reads singular', () => expect(binCount(1), '1 item'));
    test('two do not', () => expect(binCount(2), '2 items'));
  });

  group('the summary', () {
    test('an empty bin says so', () => expect(binSummary([], now), 'Nothing here'));

    // The soonest rather than an average — the only deadline that matters is
    // the next one.
    test('it quotes the most urgent', () {
      final rows = [
        binned('Newest', 0),
        binned('Oldest', purgeAfterDays - 1),
        binned('Middle', 10),
      ];
      expect(binSummary(rows, now), '3 items · last day');
    });

    test('and reads singular for one', () {
      expect(binSummary([binned('Only', 0)], now), '1 item · 30 days left');
    });
  });

  group('restoring', () {
    /*
      Restoring is subject to the cap, and it has to be. Deleting frees a slot
      immediately — deliberate, so someone at the limit can make room — but an
      unchecked restore would be a hole you could drive the whole tier through:
      fill up, delete the lot, fill up again, restore the lot.
    */
    test('a subscriber can always restore', () => expect(canRestore(999, pro), isTrue));

    test('with room, so can anyone', () {
      expect(canRestore(freeItemLimit - 1, free), isTrue);
    });

    test('at the line, no', () => expect(canRestore(freeItemLimit, free), isFalse));
    test('past it, no', () => expect(canRestore(freeItemLimit + 4, free), isFalse));

    test('and the refusal says how to fix it, and promises nothing is lost', () {
      final why = restoreBlockedReason(freeItemLimit);
      expect(why, contains('subscribe'));
      expect(why, contains('stays here'));
      expect(why, contains('$freeItemLimit'));
    });
  });
}
