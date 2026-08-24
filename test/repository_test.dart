/// The queries, and the rules they enforce.
///
///   dart test test/repository_test.dart
///
/// ── What this suite is really for ─────────────────────────────────────────
/// `logic/limits.dart` has always known what the cap is, and there has always
/// been a test proving `canAddItem` returns the right answer. That test would
/// have gone on passing if nothing on the save path ever called it — which is
/// the bug worth writing a suite about. Everything below is about the rule
/// biting, not the rule existing.
library;

// Drift's `isNull`/`isNotNull` are SQL builders; the matchers are wanted here.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:stash_it/db/open.dart';
import 'package:stash_it/db/repository.dart';
import 'package:stash_it/db/tables.dart';
import 'package:stash_it/logic/bin.dart';
import 'package:stash_it/logic/limits.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/settings.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StashDatabase db;
  late Repository repo;

  setUp(() {
    db = openInMemory();
    repo = Repository(db);
  });
  tearDown(() => db.close());

  Item draft(String name) => Item(id: '', propertyId: 'default', name: name);

  Future<void> fillTo(int n) async {
    for (var i = 0; i < n; i++) {
      await repo.createItem(draft('Thing $i'));
    }
  }

  Future<void> unlockPro() => db
      .update(db.settingsTable)
      .write(const SettingsTableCompanion(proUnlock: Value(true)));

  group('ids', () {
    test('are unique', () {
      final seen = {for (var i = 0; i < 500; i++) newId()};
      expect(seen, hasLength(500));
    });

    test('and sort by when they were made', () {
      final earlier = newId(DateTime(2026, 1, 1));
      final later = newId(DateTime(2026, 8, 1));
      expect(earlier.compareTo(later), lessThan(0));
    });
  });

  group('saving', () {
    test('an item comes back in the active list', () async {
      final id = await repo.createItem(draft('Kettle'));
      final all = await repo.activeItems();
      expect(all.single.id, id);
      expect(all.single.name, 'Kettle');
    });

    test('and gets a created-at even though the draft had none', () async {
      await repo.createItem(draft('Kettle'));
      expect((await repo.activeItems()).single.createdAt, isNotNull);
    });

    test('the property is the repository\'s, not the draft\'s', () async {
      await repo.createItem(
        const Item(id: '', propertyId: 'somewhere-else', name: 'Kettle'),
      );
      expect((await repo.activeItems()), hasLength(1));
    });

    /*
      This is the reason for Drift. A screen watching this rebuilds when
      anything writes — no manual invalidation, and no "why didn't the list
      update" bug, which the web version solved with a refresh counter threaded
      through four components.
    */
    test('and the list is watchable', () async {
      final seen = <int>[];
      final sub = repo.watchActiveItems().listen((rows) => seen.add(rows.length));

      // Let the initial query land before writing, so the first emission is
      // reliably the empty table rather than a race with the inserts.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.createItem(draft('One'));
      await repo.createItem(draft('Two'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(seen.first, 0);
      expect(seen.last, 2);
    });
  });

  group('the cap', () {
    /*
      THE ASSERTION THE FILE EXISTS FOR. `canAddItem` was always right; what
      matters is that the save path asks it.
    */
    test('a full free tier refuses the next save', () async {
      await fillTo(freeItemLimit);
      expect(repo.createItem(draft('One too many')), throwsA(isA<CapReached>()));
    });

    test('and writes nothing when it refuses', () async {
      await fillTo(freeItemLimit);
      try {
        await repo.createItem(draft('One too many'));
      } on CapReached {
        // expected
      }
      expect(await repo.cappedCount(), freeItemLimit);
    });

    test('the refusal says how to fix it and promises nothing is lost', () async {
      await fillTo(freeItemLimit);
      try {
        await repo.createItem(draft('One too many'));
        fail('should have refused');
      } on CapReached catch (e) {
        expect(e.message, contains('subscribe'));
        expect(e.message, contains('$freeItemLimit'));
      }
    });

    test('one under the line is fine', () async {
      await fillTo(freeItemLimit - 1);
      expect(await repo.canSave(), isTrue);
      await repo.createItem(draft('The last one'));
      expect(await repo.cappedCount(), freeItemLimit);
    });

    test('and a subscriber is never refused', () async {
      await unlockPro();
      await fillTo(freeItemLimit + 5);
      expect(await repo.cappedCount(), freeItemLimit + 5);
    });

    /*
      All three tables count. The limit means "how much of this app you are
      using", not "how many kettles" — a free tier that allows forty
      subscriptions and thirty documents but not a sixteenth kettle is a rule
      nobody can predict.
    */
    test('documents and subscriptions count against it too', () async {
      await fillTo(freeItemLimit - 2);
      await repo.createPaper(const Paper(
        id: '',
        propertyId: 'default',
        kind: PaperKind.passport,
        label: 'Passport',
        expiresOn: '2027-02-11',
      ));
      await repo.createSubscription(const Subscription(
        id: '',
        propertyId: 'default',
        name: 'Netflix',
        cadence: Cadence.monthly,
        anchorDate: '2026-08-22',
        amountCents: 1549,
        currency: 'USD',
      ));

      expect(await repo.cappedCount(), freeItemLimit);
      expect(repo.createItem(draft('Nope')), throwsA(isA<CapReached>()));
    });

    // Deleting frees a slot the moment you do it — deliberate, so someone at
    // the limit can make room.
    test('deleting frees a slot immediately', () async {
      await fillTo(freeItemLimit);
      final first = (await repo.activeItems()).first;

      await repo.softDeleteItem(first.id);
      expect(await repo.cappedCount(), freeItemLimit - 1);
      expect(await repo.canSave(), isTrue);
    });
  });

  group('the bin', () {
    test('a deleted item leaves the list and appears in the bin', () async {
      final id = await repo.createItem(draft('Kettle'));
      await repo.softDeleteItem(id);

      expect(await repo.activeItems(), isEmpty);
      expect((await repo.deletedItems()).single.id, id);
    });

    test('restoring brings it back whole', () async {
      final id = await repo.createItem(draft('Kettle'));
      await repo.softDeleteItem(id);
      await repo.restoreItem(id);

      final back = (await repo.activeItems()).single;
      expect(back.id, id);
      expect(back.name, 'Kettle');
      expect(back.deletedAt, isNull);
    });

    /*
      THE HOLE THIS CLOSES. Deleting frees a slot immediately, so an unchecked
      restore is a hole you could drive the whole tier through: fill up, delete
      the lot, fill up again, restore the lot. Fifty items on a twenty-five
      item tier, by pressing undo.
    */
    test('but not when there is no room for it', () async {
      await fillTo(freeItemLimit);
      final victim = (await repo.activeItems()).first;

      await repo.softDeleteItem(victim.id);
      await repo.createItem(draft('Took the slot'));

      expect(repo.restoreItem(victim.id), throwsA(isA<CapReached>()));
    });

    // Nothing is lost when it refuses. The item stays in the bin, and its own
    // countdown is the only thing that can remove it.
    test('and it stays in the bin when it refuses', () async {
      await fillTo(freeItemLimit);
      final victim = (await repo.activeItems()).first;
      await repo.softDeleteItem(victim.id);
      await repo.createItem(draft('Took the slot'));

      try {
        await repo.restoreItem(victim.id);
      } on CapReached {
        // expected
      }
      expect((await repo.deletedItems()).map((i) => i.id), contains(victim.id));
    });

    /*
      Soonest to go first. The only question the bin answers is "what am I
      about to lose", and the answer belongs at the top.
    */
    test('lists what goes first, first', () async {
      final oldest = await repo.createItem(draft('Oldest'));
      final newest = await repo.createItem(draft('Newest'));

      await (db.update(db.items)..where((t) => t.id.equals(oldest)))
          .write(ItemsCompanion(deletedAt: Value(DateTime(2026, 7, 1))));
      await (db.update(db.items)..where((t) => t.id.equals(newest)))
          .write(ItemsCompanion(deletedAt: Value(DateTime(2026, 8, 1))));

      expect((await repo.deletedItems()).map((i) => i.name), ['Oldest', 'Newest']);
    });
  });

  group('erasing', () {
    Future<String> itemWithFiles() async {
      final id = await repo.createItem(draft('Camera'));
      await repo.putBlob('thumb', Uint8List.fromList([1]), 'image/webp');
      await repo.putBlob('photo', Uint8List.fromList([2]), 'image/webp');
      await repo.putBlob('receipt', Uint8List.fromList([3]), 'application/pdf');
      await repo.putBlob('unrelated', Uint8List.fromList([4]), 'image/png');

      await (db.update(db.items)..where((t) => t.id.equals(id))).write(
        const ItemsCompanion(
          thumbBlobId: Value('thumb'),
          photoBlobId: Value('photo'),
        ),
      );
      await db.into(db.docs).insert(DocsCompanion.insert(
            id: 'd1',
            itemId: id,
            kind: const Value('receipt'),
            blobId: const Value('receipt'),
          ));
      return id;
    }

    /*
      One routine, three callers. The sweep, "delete now" and "empty bin" all
      end up in `_erase` — two routines that both mean "erase this" and clean
      up differently is how blobs get orphaned, invisibly, and only ever
      visible in the storage figure.
    */
    test('takes the documents and the files with it', () async {
      final id = await itemWithFiles();
      await repo.purgeItemNow(id);

      expect(await repo.activeItems(), isEmpty);
      expect(await db.select(db.docs).get(), isEmpty);
      expect(await repo.blob('thumb'), isNull);
      expect(await repo.blob('photo'), isNull);
      expect(await repo.blob('receipt'), isNull);
    });

    test('and touches nothing it does not own', () async {
      final id = await itemWithFiles();
      await repo.purgeItemNow(id);
      expect(await repo.blob('unrelated'), isNotNull);
    });

    test('leaving nothing orphaned', () async {
      final id = await itemWithFiles();
      await repo.purgeItemNow(id);
      // 'unrelated' was never referenced, so it is the only one left over.
      expect(await repo.orphanedBlobs(), ['unrelated']);
    });

    test('emptying the bin erases all of it, and nothing else', () async {
      final gone = await repo.createItem(draft('Gone'));
      await repo.createItem(draft('Staying'));
      await repo.softDeleteItem(gone);

      expect(await repo.emptyBin(), 1);
      expect((await repo.activeItems()).single.name, 'Staying');
      expect(await repo.deletedItems(), isEmpty);
    });
  });

  group('the sweep', () {
    Future<String> deletedDaysAgo(int days) async {
      final id = await repo.createItem(draft('Old $days'));
      await (db.update(db.items)..where((t) => t.id.equals(id))).write(
        ItemsCompanion(
          deletedAt: Value(DateTime(2026, 8, 24).subtract(Duration(days: days))),
        ),
      );
      return id;
    }

    /*
      The cutoff is the same arithmetic `daysLeft` shows on the row, so the
      number on screen and the day it actually goes cannot disagree. These two
      assertions are the pair that keeps them tied.
    */
    test('with a day left it survives, and the screen agrees', () async {
      await deletedDaysAgo(purgeAfterDays - 1);
      expect(await repo.purgeExpiredDeletes(DateTime(2026, 8, 24)), 0);
      expect(await repo.deletedItems(), hasLength(1));
      expect(
        daysLeft(DateTime(2026, 8, 24).subtract(const Duration(days: purgeAfterDays - 1)),
            DateTime(2026, 8, 24)),
        1,
      );
    });

    test('a day over and it goes, and the screen agreed it was due', () async {
      await deletedDaysAgo(purgeAfterDays + 1);
      expect(await repo.purgeExpiredDeletes(DateTime(2026, 8, 24)), 1);
      expect(await repo.deletedItems(), isEmpty);
      expect(
        daysLeft(DateTime(2026, 8, 24).subtract(const Duration(days: purgeAfterDays + 1)),
            DateTime(2026, 8, 24)),
        0,
      );
    });

    test('and it never touches a live item', () async {
      await repo.createItem(draft('Alive'));
      await deletedDaysAgo(purgeAfterDays + 1);

      expect(await repo.purgeExpiredDeletes(DateTime(2026, 8, 24)), 1);
      expect((await repo.activeItems()).single.name, 'Alive');
    });
  });

  group('settings', () {
    test('round-trip through the repository', () async {
      final before = await repo.settings();
      await repo.saveSettings(
        Settings(
          currency: 'GBP',
          backupReminderDays: 7,
          lastBackupAt: DateTime(2026, 8, 1),
          entitlements: before.entitlements,
        ),
      );

      final after = await repo.settings();
      expect(after.currency, 'GBP');
      expect(after.backupReminderDays, 7);
      expect(after.lastBackupAt, DateTime(2026, 8, 1));
    });

    /*
      The unlock is set by the billing code and by nothing else. A restore, a
      settings form and a developer toggle all reach this row through
      `saveSettings`, so if entitlements travelled with it, all three would be
      a way to grant one.
    */
    test('but saving them cannot grant a paid unlock', () async {
      const pretend = Settings(entitlements: Entitlements(proUnlock: true));
      await repo.saveSettings(pretend);

      expect((await repo.settings()).entitlements.proUnlock, isFalse);
      await fillTo(freeItemLimit);
      expect(repo.createItem(draft('Nope')), throwsA(isA<CapReached>()));
    });
  });
}
