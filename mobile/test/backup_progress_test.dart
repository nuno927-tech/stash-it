/// The bar's arithmetic.
///
///   flutter test test/backup_progress_test.dart
///
/// Pure, and the sort of thing that goes wrong quietly: a bar that reaches 100
/// before the work does, or that goes backwards between stages, is worse than
/// no bar because it teaches somebody to stop trusting it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/backup_progress.dart';

void main() {
  group('the fraction never goes backwards', () {
    test('across the stages, in order', () {
      final walk = <double>[
        const BackupProgress(BackupStage.reading).fraction,
        const BackupProgress(BackupStage.packing, done: 0, total: 10).fraction,
        const BackupProgress(BackupStage.packing, done: 5, total: 10).fraction,
        const BackupProgress(BackupStage.packing, done: 10, total: 10).fraction,
        const BackupProgress(BackupStage.sealing).fraction,
        const BackupProgress(BackupStage.done).fraction,
      ];

      for (var i = 1; i < walk.length; i++) {
        expect(walk[i], greaterThanOrEqualTo(walk[i - 1]),
            reason: 'step $i went backwards: $walk');
      }
    });

    test('it starts at zero and ends at one', () {
      expect(const BackupProgress(BackupStage.reading).fraction, 0);
      expect(const BackupProgress(BackupStage.done).fraction, 1);
    });

    test('packing never reaches the end of its own share', () {
      // Sealing still has to happen, and a bar sitting at 100% through it
      // would be the same lie the old weights told.
      final full =
          const BackupProgress(BackupStage.packing, done: 10, total: 10)
              .fraction;
      expect(full, lessThan(1));
      expect(full, const BackupProgress(BackupStage.sealing).fraction);
    });

    test('the counted stage still owns the largest share', () {
      /*
        The reason this is pinned: packing used to end at 0.82, which left two
        of eight acorns to a stage that cannot report and so never filled them.
        Whatever the weights become, the part that can be MEASURED has to be
        the part that moves.

        It owns less than it did, and deliberately. Locking a backup is the
        longest silent stretch in the app, and the bar reaching the end before
        it started is the same lie in a different place — so the last fifth is
        shared between the two stages that cannot count from inside.
      */
      final spans = {
        'packing': const BackupProgress(BackupStage.sealing).fraction -
            const BackupProgress(BackupStage.packing).fraction,
        'sealing': const BackupProgress(BackupStage.locking).fraction -
            const BackupProgress(BackupStage.sealing).fraction,
        'locking': 1 - const BackupProgress(BackupStage.locking).fraction,
      };

      expect(spans['packing'], greaterThan(0.5),
          reason: 'packing spans ${spans['packing']} of the bar');

      for (final other in ['sealing', 'locking']) {
        expect(spans['packing'], greaterThan(spans[other]!),
            reason: '$other owns more of the bar than the counted stage');
      }
    });

    /*
      ── One enum, two journeys ────────────────────────────────────────────────

      A backup climbs reading → packing → sealing → locking. A restore climbs
      unlocking → unpacking → restoring. They share a table of weights, so the
      thing that can go wrong is a stage added for one journey landing in the
      middle of the other — a bar that jumps backwards halfway through.
    */
    test('a locked backup climbs in order', () {
      final walk = <double>[
        const BackupProgress(BackupStage.reading).fraction,
        const BackupProgress(BackupStage.packing, done: 5, total: 10).fraction,
        const BackupProgress(BackupStage.sealing).fraction,
        const BackupProgress(BackupStage.locking).fraction,
        const BackupProgress(BackupStage.done).fraction,
      ];

      for (var i = 1; i < walk.length; i++) {
        expect(walk[i], greaterThanOrEqualTo(walk[i - 1]), reason: '$walk');
      }
    });

    test('a restore climbs in order too', () {
      final walk = <double>[
        const BackupProgress(BackupStage.unlocking).fraction,
        const BackupProgress(BackupStage.unpacking).fraction,
        const BackupProgress(BackupStage.restoring).fraction,
        const BackupProgress(BackupStage.done).fraction,
      ];

      for (var i = 1; i < walk.length; i++) {
        expect(walk[i], greaterThanOrEqualTo(walk[i - 1]), reason: '$walk');
      }
    });

    test('a restore starts at nothing, like everything else', () {
      // The first thing it does is decrypt, which on a big backup is not
      // quick — and a bar that begins a third of the way along says the work
      // started before somebody pressed the button.
      expect(const BackupProgress(BackupStage.unlocking).fraction, 0);
    });
  });

  group('nothing to count', () {
    test('a collection with no files does not divide by zero', () {
      final p = const BackupProgress(BackupStage.packing, done: 0, total: 0);
      expect(p.fraction, isNotNaN);
      expect(p.label, 'Packing');
    });

    test('more done than total is clamped rather than overshooting', () {
      final p = const BackupProgress(BackupStage.packing, done: 99, total: 10);
      expect(p.fraction, lessThanOrEqualTo(1));
    });
  });

  group('what it says', () {
    test('the count is in the words, not just the bar', () {
      expect(
        const BackupProgress(BackupStage.packing, done: 3, total: 12).label,
        'Packing 3 of 12 files',
      );
    });

    test('one file is singular', () {
      expect(
        const BackupProgress(BackupStage.packing, done: 1, total: 1).label,
        'Packing 1 of 1 file',
      );
    });

    test('every stage says something', () {
      for (final stage in BackupStage.values) {
        expect(BackupProgress(stage).label, isNotEmpty, reason: '$stage');
      }
    });
  });
}
