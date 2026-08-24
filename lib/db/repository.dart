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
  final String propertyId;

  /* ------------------------------------------------------------- reading */

  /// Everything not in the bin.
  Future<List<Item>> activeItems() async {
    final rows = await (db.select(db.items)
          ..where((t) => t.propertyId.equals(propertyId) & t.deletedAt.isNull()))
        .get();
    return rows.map(itemOf).toList();
  }

  /// The same list, as a stream.
  ///
  /// This is the reason for Drift. A screen watching this rebuilds when
  /// anything writes — no manual invalidation, and no "why didn't the list
  /// update" bug, which the web version had to solve with a refresh counter
  /// threaded through four components.
  Stream<List<Item>> watchActiveItems() =>
      (db.select(db.items)
            ..where((t) => t.propertyId.equals(propertyId) & t.deletedAt.isNull()))
          .watch()
          .map((rows) => rows.map(itemOf).toList());

  Future<Item?> item(String id) async {
    final row = await (db.select(db.items)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : itemOf(row);
  }

  Future<List<Paper>> activePapers() async {
    final rows = await (db.select(db.papers)
          ..where((t) => t.propertyId.equals(propertyId) & t.deletedAt.isNull()))
        .get();
    return rows.map(paperOf).toList();
  }

  Future<List<Subscription>> activeSubscriptions() async {
    final rows = await (db.select(db.subscriptions)
          ..where((t) => t.propertyId.equals(propertyId) & t.deletedAt.isNull()))
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
          ..where((t) => t.propertyId.equals(propertyId) & t.deletedAt.isNull())
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
  Future<int> cappedCount() async {
    final items = await (db.select(db.items)
          ..where((t) => t.propertyId.equals(propertyId) & t.deletedAt.isNull()))
        .get();
    final subs = await (db.select(db.subscriptions)
          ..where((t) => t.propertyId.equals(propertyId) & t.deletedAt.isNull()))
        .get();
    final papers = await (db.select(db.papers)
          ..where((t) => t.propertyId.equals(propertyId) & t.deletedAt.isNull()))
        .get();

    return items.length + subs.length + papers.length;
  }

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

  /// Settings, minus the entitlements — see `settingsToRow`.
  Future<void> saveSettings(Settings s) =>
      db.update(db.settingsTable).write(settingsToRow(s));

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
          ..where((t) => t.propertyId.equals(propertyId) & t.deletedAt.isNotNull())
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

  /// Skip the wait. Only reachable from the bin, and only after a confirmation.
  Future<void> purgeItemNow(String id) => _erase(id);

  Future<int> emptyBin() async {
    final gone = await deletedItems();
    for (final item in gone) {
      await _erase(item.id);
    }
    return gone.length;
  }

  /// The sweep. Returns how many were erased.
  ///
  /// The cutoff is the same arithmetic `daysLeft` shows on the row, so the
  /// number on screen and the day it actually goes cannot disagree.
  Future<int> purgeExpiredDeletes([DateTime? now]) async {
    final at = now ?? DateTime.now();
    final cutoff = at.subtract(const Duration(days: purgeAfterDays));

    final stale = await (db.select(db.items)
          ..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
        .get();

    for (final row in stale) {
      await _erase(row.id);
    }
    return stale.length;
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
