/// Restoring a backup into the database.
///
///   flutter test test/restore_test.dart
///
/// ── Why this suite exists, written the day it was needed ──────────────────
/// `bundle_test.dart` proves a file is read correctly. `db_test.dart` proves a
/// model survives the database. Both passed, and a restore still produced an
/// app with nothing in it.
///
/// Every record carries a `propertyId`, and a backup carries whichever one the
/// app that wrote it had generated. The repository reads with
/// `where propertyId = 'default'`. So twenty-one items went in, the restore
/// reported "restored 21 items" — truthfully — and not one of them was
/// reachable by any query in the app.
///
/// **The gap was between two green suites.** Nothing asserted that what a
/// restore writes is what the app can then read, so this file asserts exactly
/// that and nothing else.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/db/open.dart';
import 'package:stash_it/db/repository.dart';
import 'package:stash_it/db/restore.dart';
import 'package:stash_it/db/tables.dart';
import 'package:stash_it/io/bundle_file.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/types.dart';

void main() {
  late StashDatabase db;
  late Repository repo;

  setUp(() {
    db = openInMemory();
    repo = Repository(db);
  });
  tearDown(() => db.close());

  /// A backup written by some other install, with its own household id.
  List<int> foreignBackup() => writeBundle(tables: {
        'items': [
          {
            'id': 'kettle',
            'name': 'Kettle',
            'propertyId': 'p-from-the-web-app',
            'purchaseDate': '2026-01-15',
            'warranty': {'months': 24, 'unit': 'months', 'amount': 24},
          },
          {
            'id': 'lamp',
            'name': 'Lamp',
            'propertyId': 'p-from-the-web-app',
          },
        ],
        'papers': [
          {
            'id': 'pp',
            'propertyId': 'p-from-the-web-app',
            'kind': 'passport',
            'label': 'Passport',
            'expiresOn': '2027-02-11',
          },
        ],
        'subscriptions': [
          {
            'id': 'nflx',
            'propertyId': 'p-from-the-web-app',
            'name': 'Netflix',
            'cadence': 'monthly',
            'anchorDate': '2026-08-22',
            'amountCents': 1549,
            'currency': 'USD',
          },
        ],
        'rooms': [
          {'id': 'r1', 'propertyId': 'p-from-the-web-app', 'name': 'Kitchen'},
        ],
        'docs': [
          {
            'id': 'd1',
            'itemId': 'kettle',
            'kind': 'receipt',
            'title': 'Receipt'
          },
        ],
      }, blobs: {
        'blobs/b1.webp': [1, 2, 3],
      });

  group('a restore is readable afterwards', () {
    /*
      THE ASSERTION THAT WAS MISSING. Not "were rows written" — they always
      were — but "can the app see them". Every one of these goes through the
      repository, which is what the screens use.
    */
    test('items come back through the repository', () async {
      await restoreInto(db, parseBackupBytes(foreignBackup()));

      final items = await repo.activeItems();
      expect(items, hasLength(2));
      expect(items.map((i) => i.name), containsAll(['Kettle', 'Lamp']));
    });

    test('and so do documents, subscriptions and rooms', () async {
      await restoreInto(db, parseBackupBytes(foreignBackup()));

      expect(await repo.activePapers(), hasLength(1));
      expect(await repo.activeSubscriptions(), hasLength(1));
      expect(await repo.rooms(), hasLength(1));
      expect(await repo.activeDocs(), hasLength(1));
    });

    test('the cap counts them', () async {
      await restoreInto(db, parseBackupBytes(foreignBackup()));
      // Two items, one document, one subscription.
      expect(await repo.cappedCount(), 4);
    });

    test('and the watched stream sees them', () async {
      await restoreInto(db, parseBackupBytes(foreignBackup()));
      expect(await repo.watchActiveItems().first, hasLength(2));
    });
  });

  group('adoption', () {
    // A restore means "this data is mine, on this phone, now".
    test('rewrites the household id onto this install', () async {
      await restoreInto(db, parseBackupBytes(foreignBackup()));

      for (final row in await db.select(db.items).get()) {
        expect(row.propertyId, 'default');
      }
      for (final row in await db.select(db.papers).get()) {
        expect(row.propertyId, 'default');
      }
    });

    test('and honours a different one when asked', () async {
      await restoreInto(
        db,
        parseBackupBytes(foreignBackup()),
        propertyId: 'somewhere-else',
      );

      final rows = await db.select(db.items).get();
      expect(rows.every((r) => r.propertyId == 'somewhere-else'), isTrue);
    });

    /*
      THE ASSERTION THAT WOULD HAVE SAVED A DAY. Reads do not filter by
      property, so a row with an unexpected household id is still visible.

      The alternative — the behaviour this replaces — is a database full of
      correct, encrypted, unreachable records and an app that looks empty. A
      filter guarding against a state that cannot occur, producing one that
      plainly can.
    */
    test('and a row with any household id is still readable', () async {
      await restoreInto(
        db,
        parseBackupBytes(foreignBackup()),
        propertyId: 'somewhere-else',
      );

      expect(await repo.activeItems(), hasLength(2));
      expect(await repo.activePapers(), hasLength(1));
      expect(await repo.cappedCount(), 4);
    });
  });

  group('what the restore keeps', () {
    test('the record ids, so a second restore is idempotent', () async {
      await restoreInto(db, parseBackupBytes(foreignBackup()));
      await restoreInto(db, parseBackupBytes(foreignBackup()));

      expect(await repo.activeItems(), hasLength(2));
      expect((await repo.activeItems()).first.id, isNotEmpty);
    });

    test('the coverage inside an item', () async {
      await restoreInto(db, parseBackupBytes(foreignBackup()));

      final kettle =
          (await repo.activeItems()).firstWhere((i) => i.name == 'Kettle');
      expect(kettle.warranty!.months, 24);
      expect(kettle.purchaseDate, '2026-01-15');
    });

    test('and the blobs', () async {
      await restoreInto(db, parseBackupBytes(foreignBackup()));
      expect((await repo.blob('b1'))!.bytes, [1, 2, 3]);
    });

    // `licence` is the frozen key — see the note on PaperKind.
    test('and a document kind reads back as the right kind', () async {
      await restoreInto(db, parseBackupBytes(foreignBackup()));
      expect((await repo.activePapers()).single.kind, PaperKind.passport);
    });
  });

  group('replace, not merge', () {
    /*
      The web app offered both. Merge is the harder promise — two records with
      the same id and different contents need a rule, and "newest wins" is only
      right when both devices agreed about the clock. Replace is what a restore
      usually means: this phone is new, or this phone is wrong, and the file is
      the truth.
    */
    test('anything already here is gone afterwards', () async {
      await repo.createItem(
        const Item(id: 'local', propertyId: 'default', name: 'Typed by hand'),
      );
      expect(await repo.activeItems(), hasLength(1));

      await restoreInto(db, parseBackupBytes(foreignBackup()));

      final names = (await repo.activeItems()).map((i) => i.name);
      expect(names, isNot(contains('Typed by hand')));
      expect(names, hasLength(2));
    });
  });
}
