/// The database, in memory.
///
///   dart test test/db_test.dart
///
/// Requires `dart run build_runner build` to have been run at least once —
/// Drift generates the row classes, and nothing here compiles without them.
///
/// ── What this is actually testing ─────────────────────────────────────────
/// Not SQLite. The interesting question is whether a model that goes into the
/// database is the same model that comes back out, because every one of the
/// 658 tests above this layer assumes the objects they are handed are whole.
/// A field silently dropped in `mapping.dart` would break none of them and
/// all of them.
library;

// `Uint8List` comes from drift's own export of dart:typed_data, so there is no
// separate import for it here.
//
// Drift exports `isNull` and `isNotNull` as SQL expression builders — the ones
// that generate `WHERE x IS NULL`. `package:test` exports them as matchers.
// Both are wanted here, so drift's are hidden: this file writes its `where`
// clauses with `.equals(...)`, and every other use of the names is an
// assertion. Any future test that imports both will need the same line.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:stash_it/db/mapping.dart';
import 'package:stash_it/db/open.dart';
import 'package:stash_it/db/tables.dart';
import 'package:stash_it/logic/papers.dart';
import 'package:stash_it/logic/warranty.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/settings.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';
import 'package:test/test.dart';

void main() {
  late StashDatabase db;

  setUp(() => db = openInMemory());
  tearDown(() => db.close());

  group('a new install', () {
    /*
      Both rows are invisible and their absence is not: with no property there
      is nothing to hang an item off, and with no settings row every preference
      read has to cope with there being no answer at all.
    */
    test('has a property to hang things off', () async {
      final rows = await db.select(db.properties).get();
      expect(rows, hasLength(1));
      expect(rows.single.name, 'Home');
    });

    test('and a settings row with the defaults in it', () async {
      final row = await db.select(db.settingsTable).getSingle();
      final s = settingsOf(row);

      expect(s.currency, 'USD');
      expect(s.backupReminderDays, 30);
      expect(s.reminderOffsetsDays, [30]);
      expect(s.devModeEnabled, isFalse);
    });

    test('and nothing has been bought', () async {
      final s = settingsOf(await db.select(db.settingsTable).getSingle());
      expect(s.entitlements.proUnlock, isFalse);
    });
  });

  group('an item round-trips', () {
    final couch = Item(
      id: 'couch',
      propertyId: 'default',
      name: 'Couch',
      brand: 'Ercol',
      model: 'ROMANA',
      serial: 'ER-99-1421',
      roomId: 'lounge',
      purchaseDate: '2026-01-15',
      purchasePriceCents: 129900,
      currency: 'GBP',
      retailer: "John Lewis",
      leadDays: 90,
      notes: 'Delivered damaged, replaced',
      thumbBlobId: 'b1',
      photoBlobId: 'b2',
      createdAt: DateTime(2026, 1, 16, 10),
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
        Coverage(id: 'fabric', label: 'Fabric', unit: CoverageUnit.years, amount: 1),
      ],
    );

    Future<Item> saveAndRead() async {
      await db.into(db.items).insert(itemToRow(couch));
      final row = await (db.select(db.items)..where((t) => t.id.equals('couch'))).getSingle();
      return itemOf(row);
    }

    test('with every scalar field intact', () async {
      final back = await saveAndRead();
      expect(back.name, 'Couch');
      expect(back.brand, 'Ercol');
      expect(back.serial, 'ER-99-1421');
      expect(back.purchaseDate, '2026-01-15');
      expect(back.purchasePriceCents, 129900);
      expect(back.currency, 'GBP');
      expect(back.retailer, 'John Lewis');
      expect(back.notes, 'Delivered damaged, replaced');
      expect(back.thumbBlobId, 'b1');
    });

    /*
      Zero is a real lead time — "tell me on the day" — and null means "use the
      setting". A column that turned one into the other would be invisible
      until somebody's roof warranty stopped warning them a year early.
    */
    test('and a lead time that is neither null nor lost', () async {
      final back = await saveAndRead();
      expect(back.leadDays, 90);
      expect(itemLeadDays(back), 90);
    });

    /*
      THE ONE THE JSON COLUMN EXISTS FOR. Coverages are stored as a document
      inside the row, so this is the assertion that the document survives —
      including the fields nothing indexes, like `covers` and `policyNumber`,
      which are exactly the ones a lazy encoder drops.
    */
    test('and every coverage, in order, whole', () async {
      final back = await saveAndRead();
      expect(back.coverages, hasLength(2));

      final frame = back.coverages.first;
      expect(frame.id, 'frame');
      expect(frame.unit, CoverageUnit.lifetime);
      expect(frame.covers, 'Structural timber and joints');
      expect(frame.policyNumber, 'ER-LIFE-8891');

      expect(back.coverages.last.unit, CoverageUnit.years);
      expect(back.coverages.last.amount, 1);
    });

    /*
      And the logic above the database agrees about what it is looking at. A
      couch with a lifetime frame and twelve months on the fabric is not
      "covered for life" in any sense the owner cares about, and that has to
      still be true after a save and a read.
    */
    test('and the schedule still reads it the same way', () async {
      final back = await saveAndRead();
      final order = coverageSchedule(back, DateTime(2026, 8, 24)).map((d) => d.coverage.id);
      expect(order, ['fabric', 'frame']);
      expect(nextToLapse(back, DateTime(2026, 8, 24))!.coverage.id, 'fabric');
    });

    test('a legacy warranty survives too', () async {
      const old = Item(
        id: 'kettle',
        propertyId: 'default',
        name: 'Kettle',
        purchaseDate: '2026-01-01',
        warranty: Warranty(months: 24, unit: WarrantyUnit.months, amount: 24, provider: 'Bosch'),
      );
      await db.into(db.items).insert(itemToRow(old));
      final back = itemOf(
        await (db.select(db.items)..where((t) => t.id.equals('kettle'))).getSingle(),
      );

      expect(back.warranty!.months, 24);
      expect(back.warranty!.unit, WarrantyUnit.months);
      expect(back.warranty!.provider, 'Bosch');
      expect(coveragesOf(back), hasLength(1));
    });

    test('and an item with no policies at all is not a crash', () async {
      const bare = Item(id: 'lamp', propertyId: 'default', name: 'Lamp');
      await db.into(db.items).insert(itemToRow(bare));
      final back = itemOf(
        await (db.select(db.items)..where((t) => t.id.equals('lamp'))).getSingle(),
      );
      expect(back.coverages, isEmpty);
      expect(back.warranty, isNull);
      expect(warrantyState(back), WarrantyState.unknown);
    });
  });

  group('the other tables round-trip', () {
    test('a document, with its frozen key', () async {
      /*
        `licence` is British, the label people read is American, and the key is
        written into every record ever saved. This is the assertion that makes
        the freeze mean something at the storage layer as well as in a backup.
      */
      const dl = Paper(
        id: 'dl',
        propertyId: 'default',
        kind: PaperKind.licence,
        label: 'Driving license',
        holder: 'Nuno',
        expiresOn: '2027-05-01',
        leadDays: 60,
        authority: 'DMV',
        storedAt: 'Wallet',
      );
      await db.into(db.papers).insert(paperToRow(dl));

      final row = await db.select(db.papers).getSingle();
      expect(row.kind, 'licence', reason: 'the stored key must not be Americanised');

      final back = paperOf(row);
      expect(back.kind, PaperKind.licence);
      expect(kindLabel[back.kind], 'Driving license');
      expect(back.holder, 'Nuno');
      expect(back.leadDays, 60);
      expect(renewBy(back), DateTime(2027, 3, 2));
    });

    test('a subscription', () async {
      const nflx = Subscription(
        id: 'nflx',
        propertyId: 'default',
        name: 'Netflix',
        cadence: Cadence.monthly,
        anchorDate: '2026-08-22',
        amountCents: 1549,
        currency: 'USD',
        remindDays: 3,
        notes: 'Shared with Kelly',
      );
      await db.into(db.subscriptions).insert(subscriptionToRow(nflx));
      final back = subscriptionOf(await db.select(db.subscriptions).getSingle());

      expect(back.cadence, Cadence.monthly);
      expect(back.anchorDate, '2026-08-22');
      expect(back.amountCents, 1549);
      expect(back.remindDays, 3);
      expect(back.notes, 'Shared with Kelly');
    });

    test('a room', () async {
      const kitchen =
          Room(id: 'r1', propertyId: 'default', name: 'Kitchen', sortOrder: 2, isSeed: true);
      await db.into(db.rooms).insert(roomToRow(kitchen));
      final back = roomOf(await db.select(db.rooms).getSingle());
      expect(back.name, 'Kitchen');
      expect(back.sortOrder, 2);
      expect(back.isSeed, isTrue);
    });

    test('and settings', () async {
      final s = Settings(
        reminderOffsetsDays: const [90],
        currency: 'GBP',
        lastBackupAt: DateTime(2026, 8, 1, 9),
        backupReminderDays: 7,
        devModeEnabled: true,
        displayName: 'Nuno',
        theme: ThemeChoice.dark,
        sounds: false,
        roomsView: RoomsView.expanded,
      );
      await db.update(db.settingsTable).write(settingsToRow(s));

      final back = settingsOf(await db.select(db.settingsTable).getSingle());
      expect(back.reminderOffsetsDays, [90]);
      expect(back.currency, 'GBP');
      expect(back.backupReminderDays, 7);
      expect(back.devModeEnabled, isTrue);
      expect(back.displayName, 'Nuno');
      expect(back.theme, ThemeChoice.dark);
      expect(back.sounds, isFalse);
      // Never set, so still "no opinion" rather than false.
      expect(back.haptics, isNull);
      expect(back.roomsView, RoomsView.expanded);
    });

    /*
      THE ONE THAT MUST NOT ROUND-TRIP. Writing settings is how a restore, a
      form and a developer toggle all reach this row — so if a paid unlock
      travelled with the rest of it, every one of those would be a way to grant
      one. It is set by the billing code and by nothing else.
    */
    test('but a paid unlock is not written from a Settings object', () async {
      await db.update(db.settingsTable).write(
            SettingsTableCompanion(proUnlock: const Value(true)),
          );

      const pretend = Settings(entitlements: Entitlements(proUnlock: false));
      await db.update(db.settingsTable).write(settingsToRow(pretend));

      final back = settingsOf(await db.select(db.settingsTable).getSingle());
      expect(back.entitlements.proUnlock, isTrue,
          reason: 'settingsToRow must not be able to revoke it either');
    });
  });

  group('blobs', () {
    /*
      In the database rather than beside it, because the database is encrypted
      and the files directory is not. A photograph of a passport on disk beside
      an encrypted row describing it is the wrong way round.
    */
    test('bytes come back exactly as they went in', () async {
      final bytes = Uint8List.fromList(List.generate(2048, (i) => i % 256));
      await db.into(db.blobs).insert(
            BlobsCompanion.insert(
              id: 'b1',
              bytes: bytes,
              mime: 'image/webp',
              byteLength: Value(bytes.length),
            ),
          );

      final row = await db.select(db.blobs).getSingle();
      expect(row.bytes, bytes);
      expect(row.mime, 'image/webp');
      expect(row.byteLength, 2048);
    });
  });

  group('the bin', () {
    // Set rather than deleted: the thirty-day recovery window only works
    // because nothing is actually removed until the sweep runs.
    test('a deleted item is still there, and still whole', () async {
      const kettle = Item(id: 'k', propertyId: 'default', name: 'Kettle');
      await db.into(db.items).insert(itemToRow(kettle));
      await (db.update(db.items)..where((t) => t.id.equals('k')))
          .write(ItemsCompanion(deletedAt: Value(DateTime(2026, 8, 20))));

      final all = await db.select(db.items).get();
      expect(all, hasLength(1));
      expect(itemOf(all.single).deletedAt, isNotNull);
      expect(itemOf(all.single).name, 'Kettle');
    });
  });

  group('a corrupt row', () {
    /*
      A column that will not parse is one bad record, not a broken screen. The
      alternative is an exception thrown while building a list, which takes out
      the whole page over a row that is recoverable from a backup — while the
      page is not recoverable at all.
    */
    test('does not take the list down with it', () async {
      await db.into(db.items).insert(
            ItemsCompanion.insert(
              id: 'broken',
              propertyId: 'default',
              name: 'Mystery',
              coveragesJson: const Value('{not json at all'),
            ),
          );

      final back = itemOf(await db.select(db.items).getSingle());
      expect(back.name, 'Mystery');
      expect(back.coverages, isEmpty);
    });
  });
}
