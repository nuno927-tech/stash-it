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
      ── The cap is on now ────────────────────────────────────────────────

      It was off for most of the port and kept whole rather than deleted — see
      `capEnforced`. It stayed tested the whole time, because the hard part was
      never the comparison: it was that **both** insert paths go through the
      same gate. Keeping that property true while the rule was dormant is what
      made switching it on a one-line change rather than a rebuild with a hole
      in it.

      Still set explicitly here rather than leaned on. A test that only passes
      because of a global's current value stops testing the moment somebody
      flips the global.
    */
    setUp(() => capEnforced = true);
    tearDown(() => capEnforced = true);

    /*
      ── Paying is the only way in ──────────────────────────────────────────

      `grantUnlock` is the one door, and `saveSettings` deliberately has no way
      to open it — see `settingsToRow`. This checks both halves: that the door
      works, and that the wide-open path beside it still cannot.
    */
    test('an unlock lifts the cap, and only billing can write one', () async {
      await fillTo(freeItemLimit);
      expect(await repo.canSave(), isFalse);

      await repo.grantUnlock('play');
      expect(await repo.canSave(), isTrue);
      expect((await repo.settings()).entitlements.source, 'play');

      // The restore path, trying to take it away again.
      final settings = await repo.settings();
      await repo.saveSettings(settings);
      expect((await repo.settings()).entitlements.proUnlock, isTrue,
          reason: 'saveSettings must not be able to revoke it either');
    });

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
        expect(e.message, contains('unlock'));
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

  group('with the cap off', () {
    /*
      ── This group had no setUp, and that was the bug ────────────────────────

      It was written when `capEnforced` shipped false, so it leaned on the
      default and asserted "which is how the app ships today" in its own name.
      The day the app started shipping with the cap on, both tests failed —
      not because the behaviour changed but because the sentence they were
      standing on did.

      Which is the exact failure the comment on the group above warns about. A
      test that only passes because of a global's current value stops testing
      the moment somebody flips the global, and it takes its own explanation
      down with it.

      The rule stays worth testing: `capEnforced` is a switch, and a switch
      that has only ever been tested in one position is a switch nobody knows
      the other end of.
    */
    setUp(() => capEnforced = false);
    tearDown(() => capEnforced = true);

    test('nothing is refused', () async {
      await fillTo(freeItemLimit + 10);
      expect(await repo.cappedCount(), freeItemLimit + 10);
      expect(await repo.canSave(), isTrue);
    });

    test('and a restore from the bin is never blocked', () async {
      await fillTo(freeItemLimit + 5);
      final victim = (await repo.activeItems()).first;

      await repo.softDeleteItem(victim.id);
      await repo.restoreItem(victim.id);

      expect((await repo.activeItems()).map((i) => i.id), contains(victim.id));
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
      ── Restoring, with the cap on ───────────────────────────────────────────

      These set it explicitly rather than leaning on the default, even now that
      the default is on. The hole below is a property of the cap and can only
      be demonstrated with one in place — and a group two hundred lines up
      already proved what happens to a test that lets a global speak for it.
    */
    group('and restoring when the cap is on', () {
      setUp(() => capEnforced = true);
      tearDown(() => capEnforced = true);

      /*
        THE HOLE THIS CLOSES. Deleting frees a slot immediately, so an
        unchecked restore is a hole you could drive the whole tier through:
        fill up, delete the lot, fill up again, restore the lot. Fifty items on
        a twenty-five item tier, by pressing undo.
      */
      test('is refused when there is no room for it', () async {
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
      // The cap is off in the shipping app, so the second half of this test —
      // the half that proves the pretend unlock bought nothing — has to switch
      // it on to have anything to prove.
      capEnforced = true;
      addTearDown(() => capEnforced = true);

      const pretend = Settings(entitlements: Entitlements(proUnlock: true));
      await repo.saveSettings(pretend);

      expect((await repo.settings()).entitlements.proUnlock, isFalse);
      await fillTo(freeItemLimit);
      expect(repo.createItem(draft('Nope')), throwsA(isA<CapReached>()));
    });
  });

  /*
    ── Documents and subscriptions in the bin ────────────────────────────────

    THE GAP THIS CLOSES, AND IT WAS ONE I MADE. Delete went onto documents and
    subscriptions in the same release that gave them forms — with the same
    dialog promising thirty days — while the bin, the restore and the sweep all
    still handled items only. So a deleted passport left the list, appeared
    nowhere, could not be brought back, and sat in the database for ever.

    Every assertion below goes through the repository rather than the tables,
    because the two suites either side of this gap were both green: the delete
    worked, and the sweep worked, and nothing tied them together.
  */
  group('the bin holds all three kinds', () {
    Future<String> aPaper([String label = 'Passport']) => repo.createPaper(
          Paper(
            id: '',
            propertyId: 'default',
            kind: PaperKind.passport,
            label: label,
            expiresOn: '2027-02-11',
          ),
        );

    Future<String> aSub([String name = 'Netflix']) => repo.createSubscription(
          Subscription(
            id: '',
            propertyId: 'default',
            name: name,
            cadence: Cadence.monthly,
            anchorDate: '2026-09-01',
            amountCents: 999,
            currency: 'USD',
          ),
        );

    test('a deleted document is listed, not lost', () async {
      final id = await aPaper();
      await repo.softDeletePaper(id);

      expect(await repo.activePapers(), isEmpty);
      expect((await repo.deletedPapers()).single.id, id);
    });

    test('a deleted subscription is listed, not lost', () async {
      final id = await aSub();
      await repo.softDeleteSubscription(id);

      expect(await repo.activeSubscriptions(), isEmpty);
      expect((await repo.deletedSubscriptions()).single.id, id);
    });

    test('a document comes back whole', () async {
      final id = await aPaper('Driving licence');
      await repo.softDeletePaper(id);
      await repo.restorePaper(id);

      final back = (await repo.activePapers()).single;
      expect(back.id, id);
      expect(back.label, 'Driving licence');
      expect(back.deletedAt, isNull);
    });

    test('and so does a subscription', () async {
      final id = await aSub('The gym');
      await repo.softDeleteSubscription(id);
      await repo.restoreSubscription(id);

      final back = (await repo.activeSubscriptions()).single;
      expect(back.id, id);
      expect(back.name, 'The gym');
      expect(back.deletedAt, isNull);
    });

    /*
      THE ONE THAT WOULD HAVE STAYED BROKEN LONGEST. A sweep that collects only
      items leaves documents and subscriptions in the database for ever, and
      nothing on any screen would ever show it — they are deleted, so no list
      includes them, and the only symptom is a file that slowly grows.
    */
    test('the sweep collects all three', () async {
      final item = await repo.createItem(draft('Kettle'));
      final paper = await aPaper();
      final sub = await aSub();

      final longAgo = DateTime.now().subtract(const Duration(days: 40));
      await (db.update(db.items)..where((t) => t.id.equals(item)))
          .write(ItemsCompanion(deletedAt: Value(longAgo)));
      await (db.update(db.papers)..where((t) => t.id.equals(paper)))
          .write(PapersCompanion(deletedAt: Value(longAgo)));
      await (db.update(db.subscriptions)..where((t) => t.id.equals(sub)))
          .write(SubscriptionsCompanion(deletedAt: Value(longAgo)));

      expect(await repo.purgeExpiredDeletes(), 3);

      expect(await repo.deletedItems(), isEmpty);
      expect(await repo.deletedPapers(), isEmpty);
      expect(await repo.deletedSubscriptions(), isEmpty);
    });

    // And anything still inside its window is left alone. A sweep that is too
    // keen is worse than one that never runs.
    test('but leaves anything still inside its window', () async {
      final id = await aPaper();
      await repo.softDeletePaper(id);

      expect(await repo.purgeExpiredDeletes(), 0);
      expect((await repo.deletedPapers()).single.id, id);
    });

    test('emptying takes all three', () async {
      await repo.softDeleteItem(await repo.createItem(draft('Kettle')));
      await repo.softDeletePaper(await aPaper());
      await repo.softDeleteSubscription(await aSub());

      expect(await repo.emptyBin(), 3);
      expect(await repo.deletedPapers(), isEmpty);
      expect(await repo.deletedSubscriptions(), isEmpty);
    });

    // Erasing must not leave a blob behind. `orphanedBlobs` is the claim that
    // nothing ever does; this is a case that would break it if the logo were
    // forgotten.
    test('and a subscription takes its logo with it', () async {
      final id = await aSub();
      await repo.putBlob('logo', Uint8List.fromList([1, 2, 3]), 'image/png');
      await (db.update(db.subscriptions)..where((t) => t.id.equals(id)))
          .write(const SubscriptionsCompanion(logoBlobId: Value('logo')));

      await repo.softDeleteSubscription(id);
      await repo.purgeSubscriptionNow(id);

      expect(await repo.blob('logo'), isNull);
      expect(await repo.orphanedBlobs(), isEmpty);
    });
  });

  /*
    ── The notification switch, and the two things that must not touch it ────

    This is the same shape of guarantee as the entitlements above, for a
    different reason. Entitlements are excluded from `settingsToRow` so a file
    cannot buy an unlock; the notification switch is excluded so a restore
    cannot silently turn somebody's reminders off — a backup taken on another
    phone, or on this one before reminders existed, carries a null for both
    columns, and writing it through would look exactly like "switch it off and
    ask again".

    Both are enforced by the same mechanism: `settingsToRow` cannot write them,
    and `settingsToRow` is the only route a restore has.
  */
  group('the notification switch', () {
    test('starts as null, which is not the same as off', () async {
      final s = await repo.settings();
      expect(s.notifyEnabled, isNull);
      expect(s.notifyAskedAt, isNull);
    });

    test('setNotify records the answer and that it was asked', () async {
      await repo.setNotify(enabled: true);

      final s = await repo.settings();
      expect(s.notifyEnabled, isTrue);
      expect(s.notifyAskedAt, isNotNull);
    });

    // Declining is an answer, and has to be remembered as one — otherwise the
    // offer dialog reappears on the next save, forever.
    test('and declining is remembered as an answer, not as silence', () async {
      await repo.setNotify(enabled: false);

      final s = await repo.settings();
      expect(s.notifyEnabled, isFalse);
      expect(s.notifyAskedAt, isNotNull);
    });

    test('saving settings cannot switch it off', () async {
      await repo.setNotify(enabled: true);

      // A Settings object with nulls in it, which is exactly what the backup
      // decoder produces.
      await repo.saveSettings(const Settings(currency: 'GBP'));

      final s = await repo.settings();
      expect(s.currency, 'GBP', reason: 'the rest of the row still saves');
      expect(s.notifyEnabled, isTrue, reason: 'and this one is untouchable');
      expect(s.notifyAskedAt, isNotNull);
    });
  });
}
