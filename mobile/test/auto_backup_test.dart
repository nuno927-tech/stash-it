/// When a backup writes itself, and which old ones it throws away.
///
///   flutter test test/auto_backup_test.dart
///
/// Two rules, and both of them can lose somebody's data if they are wrong in
/// the wrong direction. Due too rarely and the backup is stale; prune too
/// eagerly and the backup is gone. Neither failure is visible on a screen —
/// they happen in a folder nobody looks at, on a schedule nobody watches.
///
/// So the rules are pure and pinned here, and the part that cannot be tested
/// without a phone is kept as thin as it can be around them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/auto_backup.dart';
import 'package:stash_it/logic/dates.dart';

/// 1 March 2026, as everywhere else in these tests.
final today = DateTime(2026, 3, 1);

const folder = 'content://com.example.provider/tree/backups';

bool due({
  String? folder = folder,
  int everyDays = 30,
  int itemCount = 10,
  DateTime? lastAt,
}) =>
    autoBackupDue(
      folder: folder,
      everyDays: everyDays,
      itemCount: itemCount,
      lastAt: lastAt,
      now: today,
    );

void main() {
  group('when it does not run', () {
    test('no folder is the off switch', () {
      /*
        The folder IS the setting. There is no separate boolean, so this is
        the whole of "switched off" — and an empty string counts, because a
        setting cleared by hand or by a bad restore should not be read as a
        destination.
      */
      expect(due(folder: null), isFalse);
      expect(due(folder: '   '), isFalse);
    });

    test('an interval of zero means never', () {
      // Same reading `backupWakes` gives it. Somebody who set the interval to
      // nothing meant nothing, not "every zero days".
      expect(due(everyDays: 0), isFalse);
      expect(due(everyDays: -1), isFalse);
    });

    test('an empty stash is left alone', () {
      // The first thing a new install would otherwise do is write an empty
      // file into somebody's cloud folder.
      expect(due(itemCount: 0), isFalse);
    });

    test('a backup made yesterday is not repeated', () {
      expect(due(lastAt: addDays(today, -1)), isFalse);
    });

    test('nor one made a day short of the interval', () {
      expect(due(everyDays: 30, lastAt: addDays(today, -29)), isFalse);
    });
  });

  group('when it runs', () {
    test('never having run counts as due', () {
      /*
        The case that matters most. The interval is measured from the last
        backup, so with no last backup there is nothing to measure — and the
        reading that treats "no date" as "not yet" would mean the folder gets
        its first file one interval after being chosen, which is a fortnight of
        somebody believing they are protected and not being.
      */
      expect(due(lastAt: null), isTrue);
    });

    test('exactly the interval is due, not one day later', () {
      expect(due(everyDays: 30, lastAt: addDays(today, -30)), isTrue);
    });

    test('and long overdue is still due', () {
      expect(due(everyDays: 30, lastAt: addDays(today, -400)), isTrue);
    });

    test('the time of day does not matter', () {
      // Compared as days, so a backup at 23:50 does not make the next one
      // eleven minutes late a fortnight later.
      expect(
        autoBackupDue(
          folder: folder,
          everyDays: 7,
          itemCount: 1,
          lastAt: DateTime(2026, 2, 22, 23, 50),
          now: DateTime(2026, 3, 1, 0, 5),
        ),
        isTrue,
      );
    });
  });

  group('what counts as one of ours', () {
    test('only files this app named', () {
      /*
        THE DANGEROUS ONE. The folder belongs to the person, not to this app —
        it may hold their tax returns, their photographs, their will. A prune
        that guessed would be the worst bug this app could have, and it would
        be silent.
      */
      expect(isOurBackup('stash-it-backup-2026-03-01.stashit'), isTrue);

      expect(isOurBackup('tax-return-2025.pdf'), isFalse);
      expect(isOurBackup('backup.stashit'), isFalse);
      expect(isOurBackup('stash-it-notes.txt'), isFalse);
      expect(isOurBackup('my stash-it-backup-2026-03-01.stashit'), isFalse);
    });

    test('including a name a provider added an extension to', () {
      // Some document providers rename on the way in. `contains` rather than
      // `endsWith` for exactly that: the file is still ours and still ought to
      // be pruned, or the folder fills up with them for ever.
      expect(isOurBackup('stash-it-backup-2026-03-01.stashit.bin'), isTrue);
    });
  });

  group('which old ones go', () {
    List<String> pruned(List<String> names, {int keep = backupsToKeep}) =>
        backupsToPrune(names, nameOf: (n) => n, keep: keep);

    String on(int day) =>
        'stash-it-backup-2026-03-${day.toString().padLeft(2, '0')}.stashit';

    test('nothing goes while there is room', () {
      expect(pruned([for (var d = 1; d <= 5; d++) on(d)]), isEmpty);
    });

    test('the oldest go once there are too many', () {
      final all = [for (var d = 1; d <= 8; d++) on(d)];
      expect(pruned(all), [on(3), on(2), on(1)]);
    });

    test('sorted by the name, not by the order they were listed', () {
      // A folder synced from another device hands them over in whatever order
      // it likes. The date is in the name, and the name is ISO, which is the
      // whole reason `backupFileName` is written that way round.
      final jumbled = [on(4), on(1), on(8), on(2), on(6), on(3), on(7), on(5)];
      expect(pruned(jumbled), [on(3), on(2), on(1)]);
    });

    test('nothing that is not ours, however many there are', () {
      final mixed = [
        for (var d = 1; d <= 8; d++) on(d),
        'passport-scan.pdf',
        'IMG_0042.jpg',
        'household budget.xlsx',
      ];

      final gone = pruned(mixed);
      expect(gone, everyElement(startsWith('stash-it-backup-')));
      expect(gone, hasLength(3));
    });

    test('a folder of nothing but other people’s files is left alone', () {
      expect(pruned(['a.pdf', 'b.jpg', 'c.docx']), isEmpty);
    });

    test('keeping one keeps the newest one', () {
      final all = [for (var d = 1; d <= 4; d++) on(d)];
      expect(pruned(all, keep: 1), [on(3), on(2), on(1)]);
    });
  });
}
