/// The queries the screens will call.
///
/// Replaces `src/db/repo.ts`.
///
/// ── Where the rules get enforced ──────────────────────────────────────────
/// `logic/limits.dart` knows what the cap *is*. This is where it *bites* — and
/// the difference has been a real bug twice: a pure `canAddItem` that nothing
/// calls on the save path is a rule written down and not applied.
///
/// So the two places a record can be created — a new save, and a restore from
/// the bin — both go through the same check here, and both refuse the same
/// way. Nothing else can insert.
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../logic/bin.dart';
import '../logic/limits.dart';
import '../models/paper.dart';
import '../models/settings.dart';
import '../models/subscription.dart';
import '../models/types.dart';
import 'mapping.dart';
import 'tables.dart';

/// Thrown when the free tier is full.
///
/// An exception rather than a boolean, because every caller that ignored the
/// boolean would silently write the record anyway — and a cap that is only
/// enforced when the caller remembers is not a cap.
class CapReached implements Exception {
  const CapReached(this.count);

  /// How many are already stored, for the message.
  final int count;

  String get message => restoreBlockedReason(count);

  @override
  String toString() => message;
}

/// Ids that sort by creation time.
///
/// A random id would do — nothing joins on order. This costs nothing extra and
/// means a raw `SELECT *` while debugging comes back oldest-first, which is
/// the order a human reading it expects.
String newId([DateTime? now]) {
  final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final rand = Random.secure().nextInt(1 << 32);
  return '${ms.toRadixString(36).padLeft(9, '0')}'
      '-${rand.toRadixString(36).padLeft(7, '0')}';
}

class Repository {
  Repository(this.db, {this.propertyId = 'default'});

  final StashDatabase db;

  /// Stamped onto anything written. **Not filtered on when reading** — see
  /// below.
  final String propertyId;

  /* ------------------------------------------------------------- reading */

  /*
    ── Reads do not filter by property, and that is deliberate now ─────────

    They used to. Every read carried `where propertyId = 'default'`, ported
    faithfully from a web app whose repository did the same — and it cost a
    day: a restore wrote twenty-one items with the household id from the
    backup file, reported "restored 21 items" truthfully, and every screen
    showed nothing. The rows were there, encrypted, correct, and invisible.

    The first fix made a restore adopt the rows onto the local property. That
    was right and insufficient: it only runs during a restore, so a database
    already in the wrong state stays wrong until someone restores again — and
    nobody restores an app that looks empty.

    So the filter is gone. **This app seeds exactly one property and has no way
    to make a second**, which means the clause was guarding against a state
    that cannot occur while producing one that plainly can. The field is still
    written, so the day multiple households exist the filter comes back — with
    a migration, and with a screen to switch between them.
  */

  /// Everything not in the bin.
  Future<List<Item>> activeItems() async {
    final rows =
        await (db.select(db.items)..where((t) => t.deletedAt.isNull())).get();
    return rows.map(itemOf).toList();
  }

  /// The same list, as a stream.
  ///
  /// This is the reason for Drift. A screen watching this rebuilds when
  /// anything writes — no manual invalidation, and no "why didn't the list
  /// update" bug, which the web version had to solve with a refresh counter
  /// threaded through four components.
  Stream<List<Item>> watchActiveItems() =>
      (db.select(db.items)..where((t) => t.deletedAt.isNull()))
          .watch()
          .map((rows) => rows.map(itemOf).toList());

  Future<Item?> item(String id) async {
    final row = await (db.select(db.items)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : itemOf(row);
  }

  Future<List<Paper>> activePapers() async {
    final rows =
        await (db.select(db.papers)..where((t) => t.deletedAt.isNull())).get();
    return rows.map(paperOf).toList();
  }

  Future<List<Subscription>> activeSubscriptions() async {
    final rows = await (db.select(db.subscriptions)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    return rows.map(subscriptionOf).toList();
  }

  Future<List<Doc>> activeDocs() async {
    final rows =
        await (db.select(db.docs)..where((t) => t.deletedAt.isNull())).get();
    return rows.map(docOf).toList();
  }

  Future<List<Room>> rooms() async {
    final rows = await (db.select(db.rooms)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    return rows.map(roomOf).toList();
  }

  Future<Settings> settings() async =>
      settingsOf(await db.select(db.settingsTable).getSingle());

  /* --------------------------------------------------------------- the cap */

  /// Everything the cap counts: items, subscriptions and documents together.
  ///
  /// All three, which reverses two earlier exemptions. The reasoning for them
  /// was that the cap prices storage and neither a subscription nor a document
  /// holds an attachment — true, and it left the limit meaning "how many
  /// kettles" rather than "how much of this app you are using". A free tier
  /// that allows forty subscriptions and thirty documents but not a sixteenth
  /// kettle is a rule nobody can predict.
  ///
  /// **Deleted rows do not count.** Deleting frees a slot immediately, which is
  /// deliberate — someone at the limit has to be able to make room — and it is
  /// exactly why restoring has to check again.
  /// Counted by fetching rather than by `COUNT(*)`, deliberately.
  ///
  /// A count query is the right instinct and the wrong trade here: the number
  /// being counted is capped at twenty-five for the people this matters to,
  /// and three tiny selects that obviously do what they say beat one clever
  /// aggregate on a path where being wrong means either refusing a save
  /// somebody paid for, or giving away the tier.
  Future<int> cappedCount() async =>
      (await activeItems()).length +
      (await activeSubscriptions()).length +
      (await activePapers()).length;

  Future<bool> canSave() async {
    final e = (await settings()).entitlements;
    return canAddItem(await cappedCount(), e);
  }

  /// The one gate. Both insert paths go through it.
  Future<void> _requireRoom() async {
    final count = await cappedCount();
    final e = (await settings()).entitlements;
    if (!canAddItem(count, e)) throw CapReached(count);
  }

  /* -------------------------------------------------------------- writing */

  /// Saves a new item and returns its id.
  ///
  /// Throws [CapReached] on a full free tier, and writes nothing when it does.
  Future<String> createItem(Item draft) async {
    await _requireRoom();
    final id = draft.id.isEmpty ? newId() : draft.id;
    final now = DateTime.now();
    await db.into(db.items).insert(
          itemToRow(Item(
            id: id,
            name: draft.name,
            propertyId: propertyId,
            brand: draft.brand,
            model: draft.model,
            serial: draft.serial,
            roomId: draft.roomId,
            purchaseDate: draft.purchaseDate,
            purchasePriceCents: draft.purchasePriceCents,
            currency: draft.currency,
            retailer: draft.retailer,
            coverages: draft.coverages,
            warranty: draft.warranty,
            extendedWarranty: draft.extendedWarranty,
            leadDays: draft.leadDays,
            notes: draft.notes,
            thumbBlobId: draft.thumbBlobId,
            photoBlobId: draft.photoBlobId,
            createdAt: now,
          ), now: now),
        );
    return id;
  }

  Future<void> saveItem(Item item) =>
      db.update(db.items).replace(itemToRow(item));

  Future<String> createPaper(Paper draft) async {
    await _requireRoom();
    final id = draft.id.isEmpty ? newId() : draft.id;
    await db.into(db.papers).insert(paperToRow(Paper(
          id: id,
          propertyId: propertyId,
          kind: draft.kind,
          label: draft.label,
          holder: draft.holder,
          expiresOn: draft.expiresOn,
          issuedOn: draft.issuedOn,
          leadDays: draft.leadDays,
          authority: draft.authority,
          storedAt: draft.storedAt,
          notes: draft.notes,
        )));
    return id;
  }

  Future<String> createSubscription(Subscription draft) async {
    await _requireRoom();
    final id = draft.id.isEmpty ? newId() : draft.id;
    await db.into(db.subscriptions).insert(subscriptionToRow(Subscription(
          id: id,
          propertyId: propertyId,
          name: draft.name,
          serviceId: draft.serviceId,
          logoBlobId: draft.logoBlobId,
          cadence: draft.cadence,
          anchorDate: draft.anchorDate,
          amountCents: draft.amountCents,
          currency: draft.currency,
          startedDate: draft.startedDate,
          remindDays: draft.remindDays,
          notes: draft.notes,
        )));
    return id;
  }

  Future<void> savePaper(Paper p) =>
      db.update(db.papers).replace(paperToRow(p));

  Future<void> saveSubscription(Subscription s) =>
      db.update(db.subscriptions).replace(subscriptionToRow(s));

  /*
    Documents and subscriptions go to the bin too.

    The web app hard-deleted both, and the reason was that neither holds an
    attachment so there was nothing to clean up — which is an argument about
    storage, not about people. Deleting the wrong passport is exactly as bad as
    deleting the wrong kettle, and the thirty-day window already exists.
  */
  Future<void> softDeletePaper(String id) =>
      (db.update(db.papers)..where((t) => t.id.equals(id)))
          .write(PapersCompanion(deletedAt: Value(DateTime.now())));

  Future<void> softDeleteSubscription(String id) =>
      (db.update(db.subscriptions)..where((t) => t.id.equals(id)))
          .write(SubscriptionsCompanion(deletedAt: Value(DateTime.now())));

  /// Settings, minus the entitlements and the notification switch — see
  /// `settingsToRow` for why both are structurally excluded rather than merely
  /// left out.
  Future<void> saveSettings(Settings s) =>
      db.update(db.settingsTable).write(settingsToRow(s));

  /// The notification switch, and the record that the question has been put.
  ///
  /// Its own method because `saveSettings` cannot write these — a restore goes
  /// through that function, and a backup must not be able to change this
  /// phone's relationship with its own notification tray. Both columns move
  /// together: enabling without recording the ask would leave the offer dialog
  /// waiting to fire again.
  Future<void> setNotify({required bool enabled, DateTime? askedAt}) =>
      db.update(db.settingsTable).write(
            SettingsTableCompanion(
              notifyEnabled: Value(enabled),
              notifyAskedAt: Value(askedAt ?? DateTime.now()),
            ),
          );

  /* ------------------------------------------------------------- the bin */

  /// Soft delete. Frees a slot immediately; erased after thirty days.
  Future<void> softDeleteItem(String id) =>
      (db.update(db.items)..where((t) => t.id.equals(id)))
          .write(ItemsCompanion(deletedAt: Value(DateTime.now())));

  /// Brings one back, **if there is room**.
  ///
  /// The check is not paranoia. Deleting frees a slot the moment you do it, so
  /// an unchecked restore is a hole you could drive the whole tier through:
  /// fill up, delete the lot, fill up again, restore the lot. Fifty items on a
  /// twenty-five item tier, by pressing undo.
  ///
  /// Nothing is lost when it refuses. The item stays in the bin and its own
  /// countdown is the only thing that can remove it.
  Future<void> restoreItem(String id) async {
    await _requireRoom();
    await (db.update(db.items)..where((t) => t.id.equals(id)))
        .write(ItemsCompanion(deletedAt: Value(null)));
  }

  /// Everything in the bin, **soonest to go first**.
  ///
  /// That order rather than most-recently-deleted: the only question this
  /// screen answers is "what am I about to lose", and the answer belongs at
  /// the top.
  Future<List<Item>> deletedItems() async {
    final rows = await (db.select(db.items)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm(expression: t.deletedAt)]))
        .get();
    return rows.map(itemOf).toList();
  }

  /// Erase one item and everything only it was holding.
  ///
  /// ── One routine, three callers, and that is the point ─────────────────
  /// The thirty-day sweep, the "delete now" button and "empty bin" all end up
  /// here. Two routines that both mean "erase this" and clean up differently
  /// is how blobs get orphaned — invisibly, and only ever visible in the
  /// storage figure.
  ///
  /// **In a transaction**, which the web version could not easily do. A crash
  /// between deleting the blobs and deleting the item used to leave a row
  /// pointing at pictures that no longer existed.
  Future<void> _erase(String itemId) => db.transaction(() async {
        final row = await (db.select(db.items)..where((t) => t.id.equals(itemId)))
            .getSingleOrNull();
        if (row == null) return;

        final docs =
            await (db.select(db.docs)..where((t) => t.itemId.equals(itemId))).get();

        final blobIds = <String>{
          for (final d in docs)
            if (d.blobId != null) d.blobId!,
          if (row.thumbBlobId != null) row.thumbBlobId!,
          if (row.photoBlobId != null) row.photoBlobId!,
        };

        if (blobIds.isNotEmpty) {
          await (db.delete(db.blobs)..where((t) => t.id.isIn(blobIds.toList()))).go();
        }
        await (db.delete(db.docs)..where((t) => t.itemId.equals(itemId))).go();
        await (db.delete(db.items)..where((t) => t.id.equals(itemId))).go();
      });

  /* ── Documents and subscriptions in the bin ─────────────────────────────

     These arrived later than items and were, for one release, soft-deleted
     into nowhere: no list showed them, no sweep collected them, and the delete
     dialog promised a thirty-day window that only items actually had. That is
     the same failure `logic/bin.dart` was written about, reproduced.

     Neither holds an attachment the way an item does — a document has no
     scans by design, a subscription has at most a logo — so erasing one is a
     row delete rather than the transaction `_erase` needs. The logo still has
     to go with it, or `orphanedBlobs` starts finding things.
  */

  Future<List<Paper>> deletedPapers() async {
    final rows = await (db.select(db.papers)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm(expression: t.deletedAt)]))
        .get();
    return rows.map(paperOf).toList();
  }

  Future<List<Subscription>> deletedSubscriptions() async {
    final rows = await (db.select(db.subscriptions)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm(expression: t.deletedAt)]))
        .get();
    return rows.map(subscriptionOf).toList();
  }

  Future<void> restorePaper(String id) async {
    await _requireRoom();
    await (db.update(db.papers)..where((t) => t.id.equals(id)))
        .write(const PapersCompanion(deletedAt: Value(null)));
  }

  Future<void> restoreSubscription(String id) async {
    await _requireRoom();
    await (db.update(db.subscriptions)..where((t) => t.id.equals(id)))
        .write(const SubscriptionsCompanion(deletedAt: Value(null)));
  }

  Future<void> _erasePaper(String id) =>
      (db.delete(db.papers)..where((t) => t.id.equals(id))).go();

  Future<void> _eraseSubscription(String id) => db.transaction(() async {
        final row = await (db.select(db.subscriptions)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (row == null) return;

        final logo = row.logoBlobId;
        if (logo != null) {
          await (db.delete(db.blobs)..where((t) => t.id.equals(logo))).go();
        }
        await (db.delete(db.subscriptions)..where((t) => t.id.equals(id))).go();
      });

  /// Skip the wait. Only reachable from the bin, and only after a confirmation.
  Future<void> purgeItemNow(String id) => _erase(id);
  Future<void> purgePaperNow(String id) => _erasePaper(id);
  Future<void> purgeSubscriptionNow(String id) => _eraseSubscription(id);

  /// Everything in the bin, gone for good. Returns how many.
  Future<int> emptyBin() async {
    final items = await deletedItems();
    for (final item in items) {
      await _erase(item.id);
    }

    final papers = await deletedPapers();
    for (final paper in papers) {
      await _erasePaper(paper.id);
    }

    final subs = await deletedSubscriptions();
    for (final sub in subs) {
      await _eraseSubscription(sub.id);
    }

    return items.length + papers.length + subs.length;
  }

  /// The sweep. Returns how many were erased.
  ///
  /// The cutoff is the same arithmetic `daysLeft` shows on the row, so the
  /// number on screen and the day it actually goes cannot disagree.
  ///
  /// All three kinds, for the same reason: a countdown printed on a row that
  /// nothing ever collects is a lie with a number on it.
  Future<int> purgeExpiredDeletes([DateTime? now]) async {
    final at = now ?? DateTime.now();
    final cutoff = at.subtract(const Duration(days: purgeAfterDays));

    final staleItems = await (db.select(db.items)
          ..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    for (final row in staleItems) {
      await _erase(row.id);
    }

    final stalePapers = await (db.select(db.papers)
          ..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    for (final row in stalePapers) {
      await _erasePaper(row.id);
    }

    final staleSubs = await (db.select(db.subscriptions)
          ..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    for (final row in staleSubs) {
      await _eraseSubscription(row.id);
    }

    return staleItems.length + stalePapers.length + staleSubs.length;
  }

  /* --------------------------------------------------------------- blobs */

  Future<void> putBlob(String id, Uint8List bytes, String mime) =>
      db.into(db.blobs).insertOnConflictUpdate(BlobsCompanion.insert(
            id: id,
            bytes: bytes,
            mime: mime,
            byteLength: Value(bytes.length),
          ));

  Future<BlobRow?> blob(String id) =>
      (db.select(db.blobs)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Every blob nothing points at any more.
  ///
  /// Should always be empty — `_erase` is the only path that removes something
  /// holding one, and it takes the blobs with it. Worth being able to ask,
  /// because "should always be empty" is a claim and this is the check.
  Future<List<String>> orphanedBlobs() async {
    final referenced = <String>{};
    for (final row in await db.select(db.items).get()) {
      if (row.thumbBlobId != null) referenced.add(row.thumbBlobId!);
      if (row.photoBlobId != null) referenced.add(row.photoBlobId!);
    }
    for (final row in await db.select(db.docs).get()) {
      if (row.blobId != null) referenced.add(row.blobId!);
    }
    for (final row in await db.select(db.subscriptions).get()) {
      if (row.logoBlobId != null) referenced.add(row.logoBlobId!);
    }

    final all = await db.select(db.blobs).get();
    return [
      for (final b in all)
        if (!referenced.contains(b.id)) b.id,
    ];
  }
}
