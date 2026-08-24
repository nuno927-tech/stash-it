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
import 'package:crypto/crypto.dart';

import '../logic/bundle.dart';

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

/* ------------------------------------------------------------- for tests */

/// Builds a bundle in memory, so the reader can be tested against something
/// this file did not also produce a shortcut for.
///
/// Not an exporter — writing a real backup is a later job with its own
/// decisions about naming and where the file goes. This is the smallest thing
/// that produces bytes `parseBackupBytes` should accept.
List<int> writeBundle({
  Map<String, Object?> tables = const {},
  Map<String, List<int>> blobs = const {},
  Map<String, Object?> manifestOverrides = const {},
}) {
  final entries = <String, List<int>>{
    for (final e in tables.entries) '${e.key}.json': utf8.encode(jsonEncode(e.value)),
    ...blobs,
  };

  final manifest = <String, Object?>{
    'format': backupFormat,
    'formatVersion': backupFormatVersion,
    'schemaVersion': 4,
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
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
  }

  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) throw StateError('the zip encoder produced nothing');
  return Uint8List.fromList(encoded);
}
