/// The two things `logic/bundle.dart` refuses to do itself: unzip, and hash.
///
/// ── Why they are here and not there ───────────────────────────────────────
/// `parseBundle` takes both as arguments. That was not squeamishness about
/// dependencies — it is what makes the whole parser testable without ever
/// producing a zip file, which is why `test/bundle_test.dart` can assert forty
/// things about damaged backups using nothing but maps and a fake hash.
///
/// This file is the real implementations, kept small enough to read in one
/// go, so that the part with the judgement in it stays pure and the part with
/// the packages in it stays boring.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:crypto/crypto.dart';

import '../db/backup.dart';
import '../logic/backup_progress.dart';
import '../db/tables.dart';
import '../logic/bundle.dart';
import '../models/types.dart';

/// The real hash. Injected into `parseBundle` so the parser never imports it.
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// Turns the bytes of a `.stashit` file into the map `parseBundle` wants.
///
/// Directory entries are skipped: a zip written on one platform and read on
/// another disagrees about whether folders are entries at all, and a "file"
/// with no bytes would otherwise land in the blob map as an empty attachment.
Map<String, List<int>> unzipBundle(List<int> bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    // Deliberately catching everything. The zip decoder throws several
    // unrelated types on a truncated file, and every one of them means the
    // same thing to the person holding it.
    throw const BundleError(
      'That file is not a readable backup — the zip could not be opened.',
    );
  }

  final out = <String, List<int>>{};
  for (final entry in archive) {
    if (!entry.isFile) continue;
    final content = entry.content;
    out[entry.name] = content is List<int> ? content : const <int>[];
  }
  return out;
}

/// Reads a `.stashit` file from disk.
///
/// The one function in the port that touches the filesystem, and the reason
/// `dart:io` appears nowhere else: on a phone the bytes arrive from a share
/// sheet or a file picker, not from a path. `parseBackupBytes` is the entry
/// point that will actually be used; this one exists so the whole chain can be
/// run against a real backup from a terminal.
ParsedBundle parseBackupFile(String path) =>
    parseBackupBytes(File(path).readAsBytesSync());

ParsedBundle parseBackupBytes(List<int> bytes) =>
    parseBundle(unzipBundle(bytes), sha256Hex: sha256Hex);

/* ---------------------------------------------------------------- writing */

/// Builds a `.stashit` in memory.
///
/// Started life as a test fixture and is now the real exporter, which is the
/// right outcome: the bytes a test asserts against are the bytes a person gets.
///
/// The caller supplies the tables — see `db/backup.dart` for where they come
/// from — and this does the two things `logic/bundle.dart` refuses to do,
/// hashing and zipping, in the same place it does them for reading.
List<int> writeBundle({
  Map<String, Object?> tables = const {},
  Map<String, List<int>> blobs = const {},
  Map<String, Object?> manifestOverrides = const {},
}) {
  final entries = <String, List<int>>{
    for (final e in tables.entries)
      '${e.key}.json': utf8.encode(jsonEncode(e.value)),
    ...blobs,
  };

  final manifest = <String, Object?>{
    'format': backupFormat,
    'formatVersion': backupFormatVersion,
    // The constant, not a literal. A file claiming a version the app does not
    // actually write is the one lie this format cannot survive.
    'schemaVersion': schemaVersion,
    'appVersion': 'dart-port',
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'counts': {
      'items': (tables['items'] as List?)?.length ?? 0,
      'docs': (tables['docs'] as List?)?.length ?? 0,
      'blobs': blobs.length,
    },
    'sha256': sha256Hex(checksumInput(entries)),
    'encrypted': false,
    ...manifestOverrides,
  };

  final archive = Archive();
  final all = {...entries, 'manifest.json': utf8.encode(jsonEncode(manifest))};

  for (final e in all.entries) {
    final file = ArchiveFile(e.key, e.value.length, e.value);

    /*
      ── Photographs are stored, not deflated ─────────────────────────────────

      This was the whole reason a backup took long enough to look like a crash.
      Deflate was being run over every JPEG and WebP in the collection, and
      those formats are already compressed — the pass costs seconds on a
      hundred and sixty megabytes and saves a fraction of a percent, because
      there is nothing left in them to squeeze.

      The JSON still deflates, where it earns its keep: a table of dates and
      names compresses to a fraction of its size.

      Stored entries are ordinary zip members — method 0 rather than 8 — so
      every reader, including this app's own, opens them without knowing the
      difference.
    */
    if (e.key.startsWith('blobs/')) file.compress = false;

    archive.addFile(file);
  }

  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) throw StateError('the zip encoder produced nothing');
  return Uint8List.fromList(encoded);
}

/// The whole export: gather, encode, hash, zip.
///
/// Kept as one function because the alternative — a caller assembling these
/// four steps itself — is a caller that can get the order wrong, and getting
/// the order wrong means a checksum over bytes that are not the bytes in the
/// file. The reader would then refuse every backup this app produced.
Future<List<int>> exportBackup(
  StashDatabase db, {
  BackupWatcher? onStep,
}) async {
  final contents = await gatherBackup(db, onStep: onStep);

  onStep?.call(const BackupProgress(BackupStage.sealing));

  /*
    ── Hashed and zipped on another isolate ─────────────────────────────────

    This is the step that made the app look like it had crashed. Encoding the
    JSON, hashing it and deflating a hundred and sixty megabytes is one long
    synchronous push, and on the UI isolate it blocks every frame for its whole
    duration — no spinner, no bar, no touch response. Adding a progress
    indicator without moving this would have produced a progress indicator that
    freezes, which is worse: it looks broken rather than busy.

    `compute` spawns an isolate, so the work happens where it cannot stop the
    screen. Everything crossing over is plain data — maps, lists, bytes — which
    is exactly what `writeBundle` was already built to take, because it was
    written to be testable without a database.
  */
  final bytes = await compute(_seal, (
    tables: contents.tables,
    blobs: contents.blobs,
    counts: contents.counts,
  ));

  await markBackedUp(db);
  onStep?.call(const BackupProgress(BackupStage.done));
  return bytes;
}

/// The isolate's half of `exportBackup`. Top-level, because `compute` cannot
/// send a closure.
List<int> _seal(
  ({
    Map<String, Object?> tables,
    Map<String, List<int>> blobs,
    (int, int, int) counts,
  }) work,
) =>
    writeBundle(
      tables: work.tables,
      blobs: work.blobs,
      manifestOverrides: {
        'counts': {
          'items': work.counts.$1,
          'docs': work.counts.$2,
          'blobs': work.counts.$3,
        },
      },
    );
