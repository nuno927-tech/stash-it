/// The crash log, on disk.
///
/// ── A crash logger that throws is worse than none ──────────────────────────
/// Everything here runs from inside an error handler, on a phone that is
/// already having a bad time. An exception raised while recording an exception
/// replaces a bug somebody could have fixed with a crash inside the thing
/// meant to explain it — so every function in this file swallows its own
/// failure and returns.
///
/// That is the one place in this app where a bare `catch (_)` with an empty
/// body is right, and it is why they are all in here rather than spread
/// through the handlers that call them.
///
/// ── Not in the backup, and not in the database ─────────────────────────────
/// A plain file in the app's support directory. Not a table: writing to
/// SQLCipher from a crash handler means the database, which may well be what
/// just threw. Not in the backup either — a stack trace from a phone somebody
/// no longer owns has no business being restored onto a new one.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logic/crash_log.dart';

/// Guarded, because two errors arriving together would otherwise interleave
/// their writes and leave two half-lines rather than one whole one.
Future<void>? _writing;

Future<File?> _file() async {
  try {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'crashes.jsonl'));
  } catch (_) {
    return null;
  }
}

/// Appends one, and trims the file when it has grown past the cap.
///
/// Never throws and never awaits anything the caller must wait for — a crash
/// handler that blocks is a frame that never finishes.
Future<void> recordCrash(CrashNote note) async {
  // Chained rather than concurrent. See `_writing`.
  _writing = (_writing ?? Future<void>.value()).then((_) => _append(note));
  return _writing;
}

Future<void> _append(CrashNote note) async {
  try {
    final file = await _file();
    if (file == null) return;

    await file.writeAsString(
      '${encodeCrash(note)}\n',
      mode: FileMode.append,
      flush: true,
    );

    /*
      Trimmed on the way in rather than on the way out.

      Reading is done by a person opening a screen; writing happens on a phone
      that may crash in a loop, which is exactly the case where a log with no
      ceiling eats the storage. So the cap is enforced where the growth is.
    */
    final all = decodeCrashes(await file.readAsString());
    if (all.length <= crashesToKeep) return;

    final keep = newestFirst(all).reversed.map(encodeCrash).join('\n');
    await file.writeAsString('$keep\n', flush: true);
  } catch (_) {
    // See the note at the top: this is the one place that is right.
  }
}

/// Everything recorded, newest first. Empty when there is nothing, and empty
/// when the file cannot be read — neither is worth an error on a screen whose
/// whole job is to report errors.
Future<List<CrashNote>> readCrashes() async {
  try {
    final file = await _file();
    if (file == null || !await file.exists()) return const [];

    return newestFirst(decodeCrashes(await file.readAsString()));
  } catch (_) {
    return const [];
  }
}

/// Throws the log away.
Future<void> clearCrashes() async {
  try {
    final file = await _file();
    if (file != null && await file.exists()) await file.delete();
  } catch (_) {
    // Nothing to say. The screen re-reads and shows an empty list either way.
  }
}
