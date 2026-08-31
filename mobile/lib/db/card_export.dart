/// Gathering the rows a card is made of, and writing them back on arrival.
///
/// The counterpart to `db/backup.dart`, and deliberately not part of it: a
/// backup gathers everything and a card gathers a chosen few, and the one
/// thing that must never happen is a code path that can do either depending on
/// an argument. Restoring replaces the database. Importing adds to it. Keeping
/// them in separate files means no flag can flip one into the other.
library;

import 'package:drift/drift.dart';

import '../logic/bundle_write.dart';
import '../logic/card.dart';
import '../models/paper.dart';
import '../models/subscription.dart';
import '../models/types.dart';

import 'mapping.dart';
import 'tables.dart';

/// The tables and blobs for one card, ready for `writeBundle`.
class CardContents {
  const CardContents(this.tables, this.blobs, this.summarySource);

  final Map<String, Object?> tables;
  final Map<String, List<int>> blobs;

  /// The decoded rows, so the caller can write the message text from the same
  /// data the file was built from rather than reading the database twice.
  final CardSource summarySource;
}

class CardSource {
  const CardSource(this.items, this.papers, this.subscriptions);
  final List<Item> items;
  final List<Paper> papers;
  final List<Subscription> subscriptions;
}

/// Reads exactly what was picked, and nothing that was not.
///
/// ── Rooms travel, settings do not ─────────────────────────────────────────
/// A room is the only context an item carries that would otherwise arrive as a
/// blank — "the kettle" is less useful than "the kettle, in the kitchen". Only
/// the rooms actually referenced go, because sending somebody a list of every
/// room in your house to deliver one kettle tells them more about your home
/// than you meant to.
///
/// Settings are not in the file at all. That is what makes it structurally
/// impossible for a paid unlock — or a name, or a reminder time — to travel in
/// something you texted to a colleague.
Future<CardContents> gatherCard(StashDatabase db, CardPick pick) async {
  final items = pick.items.isEmpty
      ? <Item>[]
      : (await (db.select(db.items)
                ..where((t) => t.id.isIn(pick.items) & t.deletedAt.isNull()))
              .get())
          .map(itemOf)
          .toList();

  final papers = pick.papers.isEmpty
      ? <Paper>[]
      : (await (db.select(db.papers)
                ..where((t) => t.id.isIn(pick.papers) & t.deletedAt.isNull()))
              .get())
          .map(paperOf)
          .toList();

  final subs = pick.subscriptions.isEmpty
      ? <Subscription>[]
      : (await (db.select(db.subscriptions)
                ..where((t) =>
                    t.id.isIn(pick.subscriptions) & t.deletedAt.isNull()))
              .get())
          .map(subscriptionOf)
          .toList();

  // Only the docs belonging to the items being sent. A doc whose item stayed
  // behind would arrive attached to nothing.
  final itemIds = items.map((i) => i.id).toList();
  final docs = itemIds.isEmpty
      ? <Doc>[]
      : (await (db.select(db.docs)
                ..where((t) => t.itemId.isIn(itemIds) & t.deletedAt.isNull()))
              .get())
          .map(docOf)
          .toList();

  final roomIds = {
    for (final item in items)
      if (item.roomId != null) item.roomId!,
  };
  final rooms = roomIds.isEmpty
      ? <Room>[]
      : (await (db.select(db.rooms)..where((t) => t.id.isIn(roomIds.toList())))
              .get())
          .map(roomOf)
          .toList();

  /*
    ── The attachments branch, and where it is enforced ──────────────────────

    Off, and the blob map is empty. The ids still sit in the JSON, and the
    receiving side turns a reference with no file behind it into null rather
    than a broken thumbnail — see `planCardMerge`.

    Enforced HERE, at the read, rather than by filtering later. A blob that was
    never fetched cannot be included by a subsequent mistake, and "the bytes
    were never in memory" is a much stronger statement than "the bytes were
    removed before writing".
  */
  final blobs = <String, List<int>>{};
  if (pick.attachments) {
    final wanted = <String>{
      for (final item in items) ...[
        if (item.thumbBlobId != null) item.thumbBlobId!,
        if (item.photoBlobId != null) item.photoBlobId!,
      ],
      for (final doc in docs)
        if (doc.blobId != null) doc.blobId!,
      for (final sub in subs)
        if (sub.logoBlobId != null) sub.logoBlobId!,
    };

    if (wanted.isNotEmpty) {
      final rows = await (db.select(db.blobs)
            ..where((t) => t.id.isIn(wanted.toList())))
          .get();
      for (final b in rows) {
        blobs[blobPath(b.id, b.mime)] = b.bytes;
      }
    }
  }

  return CardContents(
    {
      'items': [for (final i in items) itemToJson(i)],
      'docs': [for (final d in docs) docToJson(d)],
      'rooms': [for (final r in rooms) roomToJson(r)],
      'subscriptions': [for (final s in subs) subscriptionToJson(s)],
      'papers': [for (final p in papers) paperToJson(p)],
    },
    blobs,
    CardSource(items, papers, subs),
  );
}

/// Writes a received card into the database.
///
/// One transaction: a card is a unit, and half of one arriving is worse than
/// none — a receipt with no item, an item pointing at a room that was rolled
/// back. Nothing here updates an existing row, only inserts, which is what
/// makes an import unable to damage what was already there.
Future<void> applyCardMerge(StashDatabase db, CardMerge merge) async {
  await db.transaction(() async {
    for (final room in merge.newRooms) {
      await db.into(db.rooms).insert(roomToRow(room));
    }
    for (final entry in merge.blobs.entries) {
      await db.into(db.blobs).insert(
            BlobsCompanion.insert(
              id: entry.key,
              bytes: Uint8List.fromList(entry.value.bytes),
              mime: entry.value.mime,
              byteLength: Value(entry.value.bytes.length),
            ),
          );
    }
    for (final item in merge.items) {
      await db.into(db.items).insert(itemToRow(item));
    }
    for (final doc in merge.docs) {
      await db.into(db.docs).insert(docToRow(doc));
    }
    for (final paper in merge.papers) {
      await db.into(db.papers).insert(paperToRow(paper));
    }
    for (final sub in merge.subscriptions) {
      await db.into(db.subscriptions).insert(subscriptionToRow(sub));
    }
  });
}
