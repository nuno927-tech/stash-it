/// Write a backup, read it back, and check nothing changed.
///
///   flutter test test/backup_roundtrip_test.dart
///
/// ── Why one test is worth more than fifty here ────────────────────────────
/// `bundle_write.dart` is the mirror of `bundle.dart`, field for field. The
/// only way either can be wrong is by disagreeing with the other, and the only
/// way to catch that is to send something through both.
///
/// Asserting individual fields would pass happily while an encoder wrote
/// `expires` and a decoder read `expiresOn`. A round trip cannot.
library;

import 'dart:convert';

// Drift's `isNull`/`isNotNull` are SQL builders; the matchers are wanted here.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/db/backup.dart';
import 'package:stash_it/db/open.dart';
import 'package:stash_it/db/repository.dart';
import 'package:stash_it/db/restore.dart';
import 'package:stash_it/db/tables.dart';
import 'package:stash_it/io/bundle_file.dart';
import 'package:stash_it/logic/warranty.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';

void main() {
  late StashDatabase db;
  late Repository repo;

  setUp(() {
    db = openInMemory();
    repo = Repository(db);
  });
  tearDown(() => db.close());

  /// A household with one of everything awkward in it.
  Future<void> fill() async {
    await repo.createItem(Item(
      id: 'couch',
      propertyId: 'default',
      name: 'Couch',
      brand: 'Ercol',
      model: 'ROMANA',
      serial: 'ER-99-1421',
      purchaseDate: '2026-01-15',
      purchasePriceCents: 129900,
      currency: 'GBP',
      retailer: 'John Lewis',
      leadDays: 90,
      notes: 'Delivered damaged, replaced',
      thumbBlobId: 'b1',
      createdAt: DateTime.utc(2026, 1, 16, 10),
      coverages: const [
        Coverage(
          id: 'frame',
          label: 'Frame',
          unit: CoverageUnit.lifetime,
          amount: 0,
          covers: 'Structural timber and joints',
          provider: 'Ercol',
          policyNumber: 'ER-LIFE-8891',
        ),
        Coverage(
            id: 'fabric', label: 'Fabric', unit: CoverageUnit.years, amount: 1),
      ],
    ));

    await repo.createItem(const Item(
      id: 'kettle',
      propertyId: 'default',
      name: 'Kettle',
      purchaseDate: '2026-01-01',
      warranty: Warranty(
          months: 24, unit: WarrantyUnit.months, amount: 24, provider: 'Bosch'),
    ));

    await repo.createPaper(const Paper(
      id: 'dl',
      propertyId: 'default',
      kind: PaperKind.licence,
      label: 'Driving license',
      holder: 'Nuno',
      expiresOn: '2027-05-01',
      leadDays: 60,
      authority: 'DMV',
      storedAt: 'Wallet',
    ));

    await repo.createSubscription(const Subscription(
      id: 'nflx',
      propertyId: 'default',
      name: 'Netflix',
      cadence: Cadence.monthly,
      anchorDate: '2026-08-22',
      amountCents: 1549,
      currency: 'USD',
      remindDays: 3,
      notes: 'Shared with Kelly',
    ));

    await repo.putBlob(
        'b1', Uint8List.fromList([82, 73, 70, 70]), 'image/webp');

    /*
      ── A document WITH A FILE ON IT, which was missing from this fixture ────

      There were no documents here at all, and that omission cost real data.
      `Doc` had no `blobId` field, so the importer dropped it, the exporter
      never wrote it, and a restore imported 37 receipts and 76 files and
      connected none of them. Every layer was individually correct; the loss
      lived in a field three of them had agreed not to mention.

      A fixture with no documents in it cannot catch that, which is the actual
      lesson: the round trip is only as good as the awkwardness in `fill`.
    */
    await repo.putBlob(
        'receipt-pdf', Uint8List.fromList([37, 80, 68, 70]), 'application/pdf');
    await repo.createDoc(const Doc(
      id: 'd1',
      itemId: 'couch',
      kind: DocKind.receipt,
      title: 'John Lewis receipt',
      blobId: 'receipt-pdf',
    ));

    // And one that is a link rather than a file, because the two travel
    // differently and only one of them has bytes to carry.
    await repo.createDoc(const Doc(
      id: 'd2',
      itemId: 'kettle',
      kind: DocKind.manual,
      title: 'Bosch manual',
      url: 'https://example.com/manual.pdf',
    ));

    // Something in the bin. A restore has to be able to undo a delete, so the
    // bin travels — a backup that quietly drops it turns "I deleted the wrong
    // thing and restored yesterday's file" into a dead end.
    final binned = await repo.createItem(
      const Item(id: 'gone', propertyId: 'default', name: 'Old lamp'),
    );
    await repo.softDeleteItem(binned);
  }

  Future<ParsedBundleLike> roundTrip() async {
    final bytes = await exportBackup(db);
    final parsed = parseBackupBytes(bytes);

    // Into a second, empty database — which is what a restore onto a new
    // phone actually is.
    final other = openInMemory();
    await restoreInto(other, parsed);
    return ParsedBundleLike(other, Repository(other));
  }

  /*
    ── The bug this group exists for ─────────────────────────────────────────

    A restore used to import the documents and import the files and join them
    to nothing. On a real phone that looked like success: 37 documents, 76
    files, no error — and not one receipt that could ever be opened again.

    Both assertions go through the repository rather than the tables, because
    the two suites either side of the gap were green. The doc importer was
    correct at what it claimed to do; what it claimed was too little.
  */
  group('a document keeps hold of its file', () {
    test('through a full round trip', () async {
      await fill();
      final there = await roundTrip();

      final docs = await there.repo.docsForItem('couch');
      expect(docs, hasLength(1));
      expect(docs.single.title, 'John Lewis receipt');
      expect(docs.single.blobId, 'receipt-pdf');
      expect(docs.single.isLocal, isTrue);

      // And the bytes are actually there, which is the part that matters.
      final blob = await there.repo.blob(docs.single.blobId!);
      expect(blob, isNotNull);
      expect(blob!.mime, 'application/pdf');

      await there.db.close();
    });

    test('and a link survives as a link', () async {
      await fill();
      final there = await roundTrip();

      final docs = await there.repo.docsForItem('kettle');
      expect(docs.single.url, 'https://example.com/manual.pdf');
      expect(docs.single.blobId, isNull);
      expect(docs.single.isLocal, isFalse);

      await there.db.close();
    });

    // Nothing should be left pointing at nothing. This is the check that would
    // have failed loudly on the broken importer, which is why it is here.
    test('and no file is left orphaned by the restore', () async {
      await fill();
      final there = await roundTrip();

      expect(await there.repo.orphanedBlobs(), isEmpty);

      await there.db.close();
    });
  });

  group('a full round trip', () {
    test('every item comes back', () async {
      await fill();
      final there = await roundTrip();

      final items = await there.repo.activeItems();
      expect(items.map((i) => i.name), containsAll(['Couch', 'Kettle']));

      await there.db.close();
    });

    /*
      THE ONE THE JSON COLUMN AND THE ENCODER BOTH HAVE TO GET RIGHT. A couch
      with a lifetime frame and twelve months on the fabric is not "covered for
      life" in any sense the owner cares about — and that has to still be true
      after being written to a zip, hashed, unzipped and decoded.
    */
    test('with its coverage list, in order, whole', () async {
      await fill();
      final there = await roundTrip();

      final couch =
          (await there.repo.activeItems()).firstWhere((i) => i.name == 'Couch');

      expect(couch.coverages, hasLength(2));
      expect(couch.coverages.first.id, 'frame');
      expect(couch.coverages.first.unit, CoverageUnit.lifetime);
      expect(couch.coverages.first.covers, 'Structural timber and joints');
      expect(couch.coverages.first.policyNumber, 'ER-LIFE-8891');

      final order = coverageSchedule(couch, DateTime(2026, 8, 24))
          .map((d) => d.coverage.id);
      expect(order, ['fabric', 'frame']);

      await there.db.close();
    });

    test('and every scalar on it', () async {
      await fill();
      final there = await roundTrip();

      final couch =
          (await there.repo.activeItems()).firstWhere((i) => i.name == 'Couch');

      expect(couch.brand, 'Ercol');
      expect(couch.serial, 'ER-99-1421');
      expect(couch.purchaseDate, '2026-01-15');
      expect(couch.purchasePriceCents, 129900);
      expect(couch.currency, 'GBP');
      expect(couch.retailer, 'John Lewis');
      expect(couch.notes, 'Delivered damaged, replaced');
      // Zero is a real lead time and null means "use the setting" — an encoder
      // that turned one into the other would be invisible for a year.
      expect(couch.leadDays, 90);
      expect(couch.thumbBlobId, 'b1');

      await there.db.close();
    });

    test('a legacy warranty survives', () async {
      await fill();
      final there = await roundTrip();

      final kettle = (await there.repo.activeItems())
          .firstWhere((i) => i.name == 'Kettle');
      expect(kettle.warranty!.months, 24);
      expect(kettle.warranty!.provider, 'Bosch');
      expect(coveragesOf(kettle), hasLength(1));

      await there.db.close();
    });

    /*
      `licence` is British, the label is American, and the key is written into
      every record ever saved. An encoder that wrote the label would make every
      backup unreadable by every other build of the app.
    */
    test('and the frozen document key is written as stored', () async {
      await fill();
      final bytes = await exportBackup(db);

      final there = await roundTrip();
      final dl = (await there.repo.activePapers()).single;
      expect(dl.kind, PaperKind.licence);
      expect(dl.holder, 'Nuno');
      expect(dl.leadDays, 60);
      expect(dl.storedAt, 'Wallet');

      /*
        And in the JSON itself, not merely after a decode that could be
        forgiving about an unknown value.

        Read out of the unzipped entry rather than the file's bytes — **a zip
        is compressed**, so searching the raw bytes for a word finds nothing
        whatever the file says. The first version of this assertion did
        exactly that and failed honestly; the same mistake in the entitlements
        test below would have passed for no reason at all.
      */
      final papersJson = utf8.decode(unzipBundle(bytes)['papers.json']!);
      expect(papersJson.contains('"kind":"licence"'), isTrue);

      await there.db.close();
    });

    test('a subscription keeps its cadence and its reminder', () async {
      await fill();
      final there = await roundTrip();

      final nflx = (await there.repo.activeSubscriptions()).single;
      expect(nflx.cadence, Cadence.monthly);
      expect(nflx.anchorDate, '2026-08-22');
      expect(nflx.amountCents, 1549);
      expect(nflx.remindDays, 3);
      expect(nflx.notes, 'Shared with Kelly');

      await there.db.close();
    });

    test('the blobs are byte-identical', () async {
      await fill();
      final there = await roundTrip();

      expect((await there.repo.blob('b1'))!.bytes, [82, 73, 70, 70]);
      expect((await there.repo.blob('b1'))!.mime, 'image/webp');

      await there.db.close();
    });

    test('and the bin travels', () async {
      await fill();
      final there = await roundTrip();

      final binned = await there.repo.deletedItems();
      expect(binned.map((i) => i.name), ['Old lamp']);

      await there.db.close();
    });
  });

  group('what a backup must never carry', () {
    /*
      Entitlements are not written and are not read. A guarantee that only
      holds on one side of a round trip is not a guarantee — so this asserts
      both: nothing in the bytes, and nothing unlocked after a restore.
    */
    test('a paid unlock does not survive an export', () async {
      await fill();
      await db.update(db.settingsTable).write(
            const SettingsTableCompanion(proUnlock: Value(true)),
          );

      final bytes = await exportBackup(db);

      // The unzipped settings entry, for the reason in the test above: a
      // search of the compressed bytes finds nothing either way, so it would
      // have passed whether or not the unlock was written.
      final settingsJson = utf8.decode(unzipBundle(bytes)['settings.json']!);
      expect(settingsJson.contains('proUnlock'), isFalse);
      expect(settingsJson.contains('entitlements'), isFalse);

      final there = await roundTrip();
      expect((await there.repo.settings()).entitlements.proUnlock, isFalse);

      await there.db.close();
    });
  });

  group('the manifest', () {
    test('counts what is actually in the file', () async {
      await fill();
      final parsed = parseBackupBytes(await exportBackup(db));

      // Three items — two live and one in the bin — and two blobs: the couch's
      // thumbnail and the receipt PDF attached to it.
      expect(parsed.manifest.itemCount, 3);
      expect(parsed.manifest.blobCount, 2);
      expect(parsed.manifest.schemaVersion, schemaVersion);
    });

    test('and the checksum matches, which is the whole point', () async {
      await fill();
      final bytes = await exportBackup(db);

      // `parseBundle` refuses on a mismatch, so reading it back at all is the
      // assertion. A backup this app cannot read is worse than no backup: it
      // looks like insurance and is not.
      expect(() => parseBackupBytes(bytes), returnsNormally);
    });
  });

  group('after a backup', () {
    // The dashboard line and the nudge both read this. Forgetting to set it
    // would leave the app telling somebody to back up immediately after they
    // just did.
    test('the app knows when it happened', () async {
      await fill();
      expect((await repo.settings()).lastBackupAt, isNull);

      await exportBackup(db);
      expect((await repo.settings()).lastBackupAt, isNotNull);
    });
  });

  group('the filename', () {
    test('is dated, not stamped', () {
      expect(
        backupFileName(DateTime(2026, 8, 24)),
        'stash-it-backup-2026-08-24.stashit',
      );
    });

    test('and pads a single-digit month', () {
      expect(
        backupFileName(DateTime(2026, 1, 5)),
        'stash-it-backup-2026-01-05.stashit',
      );
    });
  });
}

/// A second database and its repository, so a test can read the restored copy
/// without shadowing the one it exported from.
class ParsedBundleLike {
  const ParsedBundleLike(this.db, this.repo);
  final StashDatabase db;
  final Repository repo;
}
