/// Writing a parsed backup into the database.
///
/// `logic/bundle.dart` decides whether a file is readable and what is in it.
/// This puts it somewhere. The split is deliberate: everything that can refuse
/// a file happens before a single row is written.
///
/// ── Replace, not merge ────────────────────────────────────────────────────
/// The web app offered both. Merge is the harder promise — two records with
/// the same id and different contents need a rule, and "newest wins" is only
/// right when both devices agreed about the clock. Replace is what a restore
/// usually means: this phone is new, or this phone is wrong, and the file is
/// the truth.
///
/// Merge comes back when there is a second device to merge with.
library;

import 'package:drift/drift.dart';

import '../logic/bundle.dart';
import 'mapping.dart';
import 'tables.dart';

class RestoreResult {
  const RestoreResult({
    required this.items,
    required this.docs,
    required this.rooms,
    required this.subscriptions,
    required this.papers,
    required this.blobs,
    required this.settingsRestored,
  });

  final int items;
  final int docs;
  final int rooms;
  final int subscriptions;
  final int papers;
  final int blobs;
  final bool settingsRestored;

  int get total => items + docs + rooms + subscriptions + papers;
}

/// Replaces everything with the contents of a bundle.
///
/// **One transaction.** A restore that half-succeeded would leave documents
/// pointing at items that were never written and blobs nothing references —
/// and it would do it to a database the user just told us to overwrite,
/// meaning the thing they wanted back is gone and what replaced it is broken.
/// Either all of it lands or none of it does.
Future<RestoreResult> restoreInto(StashDatabase db, ParsedBundle bundle) async {
  final data = bundle.data;

  return db.transaction(() async {
    // Order matters only for readability; there are no foreign keys declared
    // yet, and the whole thing is inside one transaction regardless.
    await db.delete(db.items).go();
    await db.delete(db.docs).go();
    await db.delete(db.rooms).go();
    await db.delete(db.subscriptions).go();
    await db.delete(db.papers).go();
    await db.delete(db.blobs).go();

    for (final item in data.items) {
      await db.into(db.items).insert(itemToRow(item));
    }
    for (final doc in data.docs) {
      await db.into(db.docs).insert(docToRow(doc));
    }
    for (final room in data.rooms) {
      await db.into(db.rooms).insert(roomToRow(room));
    }
    for (final sub in data.subscriptions) {
      await db.into(db.subscriptions).insert(subscriptionToRow(sub));
    }
    for (final paper in data.papers) {
      await db.into(db.papers).insert(paperToRow(paper));
    }

    for (final entry in bundle.blobs.entries) {
      await db.into(db.blobs).insert(BlobsCompanion.insert(
            id: entry.key,
            bytes: Uint8List.fromList(entry.value.bytes),
            mime: entry.value.mime,
            byteLength: Value(entry.value.bytes.length),
          ));
    }

    /*
      Settings restore, minus the entitlements — `settingsToRow` cannot write
      them, which is exactly why the restore path goes through it rather than
      building a companion of its own. A backup file must not be a way to hand
      someone a paid unlock, and the guarantee is structural rather than
      remembered.
    */
    final settings = data.settings;
    if (settings != null) {
      await db.update(db.settingsTable).write(settingsToRow(settings));
    }

    return RestoreResult(
      items: data.items.length,
      docs: data.docs.length,
      rooms: data.rooms.length,
      subscriptions: data.subscriptions.length,
      papers: data.papers.length,
      blobs: bundle.blobs.length,
      settingsRestored: settings != null,
    );
  });
}
