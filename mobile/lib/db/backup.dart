/// Making a `.stashit` from what is in the database.
///
/// ── Why this is the most load-bearing thing in the app ────────────────────
/// The database is encrypted with a key held in this handset's Keystore, and
/// that key never leaves. A factory reset, a lost phone, or a restore onto new
/// hardware produces a file nobody can open — including us.
///
/// So the backup is not a convenience feature. It is the only copy of the data
/// that can survive the phone, and the dashboard says so on a line that never
/// goes away.
library;

import 'package:drift/drift.dart';

import '../logic/bundle_write.dart';
import 'mapping.dart';
import 'tables.dart';

/// The tables and blobs of a bundle, ready to be zipped.
class BackupContents {
  const BackupContents(this.tables, this.blobs, this.counts);

  final Map<String, Object?> tables;
  final Map<String, List<int>> blobs;

  /// items, docs, blobs — the three the manifest records.
  final (int, int, int) counts;
}

/// Everything, **including the bin**.
///
/// Soft-deleted rows travel. A restore has to be able to undo an accidental
/// delete, and a backup that quietly drops the bin turns "I deleted the wrong
/// thing and restored yesterday's file" into a dead end.
Future<BackupContents> gatherBackup(StashDatabase db) async {
  final items = await db.select(db.items).get();
  final docs = await db.select(db.docs).get();
  final rooms = await db.select(db.rooms).get();
  final subs = await db.select(db.subscriptions).get();
  final papers = await db.select(db.papers).get();
  final blobs = await db.select(db.blobs).get();
  final settings = await db.select(db.settingsTable).getSingleOrNull();

  /*
    The keys are the table names the reader expects, and their order in the
    zip does not matter — `checksumInput` imposes `tableOrder` on both sides.
    Which is the point of that function existing.
  */
  final tables = <String, Object?>{
    'items': [for (final r in items) itemToJson(itemOf(r))],
    'docs': [for (final r in docs) docToJson(docOf(r))],
    'rooms': [for (final r in rooms) roomToJson(roomOf(r))],
    'subscriptions': [
      for (final r in subs) subscriptionToJson(subscriptionOf(r))
    ],
    'papers': [for (final r in papers) paperToJson(paperOf(r))],
    if (settings != null) 'settings': settingsToJson(settingsOf(settings)),
  };

  return BackupContents(
    tables,
    {
      for (final b in blobs) blobPath(b.id, b.mime): b.bytes,
    },
    (items.length, docs.length, blobs.length),
  );
}

/// `stash-it-backup-2026-08-24.stashit`
///
/// The date, not a timestamp: a file made twice in one day overwrites the
/// first, which is almost always what somebody wants and never surprising.
String backupFileName([DateTime? now]) {
  final d = now ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'stash-it-backup-${d.year}-${two(d.month)}-${two(d.day)}.stashit';
}

/// Records that a backup was made.
///
/// The dashboard line and the nudge both read this, so forgetting it would
/// leave the app telling somebody to back up immediately after they did.
Future<void> markBackedUp(StashDatabase db, [DateTime? at]) => db
    .update(db.settingsTable)
    .write(SettingsTableCompanion(lastBackupAt: Value(at ?? DateTime.now())));
