/// What the app writes down when something throws.
///
/// ── Why an app with no network needs this ──────────────────────────────────
/// Nothing here catches a crash today. No `FlutterError.onError`, no handler
/// on the platform dispatcher — which is consistent with having no server to
/// send anything to, and leaves "it crashed" as a sentence with no evidence
/// attached. During a tester period that is the difference between a fix and a
/// fortnight of asking what they were doing at the time.
///
/// So the app writes them down, on the phone, and nothing sends them anywhere.
/// A person can read the list, copy it, and choose to paste it into an email.
///
/// ── This is NOT the diagnostics block, and the difference matters ──────────
/// `diagnostics.dart` is safe to paste to a stranger without reading: counts,
/// sizes, versions, no names. A stack trace is not a count. An exception
/// message is written by whoever threw it and may quote whatever it choked on
/// — a document label, a file name, a record's title.
///
/// That cannot be scrubbed reliably, so it is not pretended otherwise. The
/// screen says so, the text is shown in full before anybody copies it, and
/// nothing is ever sent automatically.
///
/// ── Everything here is pure ────────────────────────────────────────────────
/// Writing to disk is in `io/crash_log.dart`. This is the shape, the caps and
/// the parsing, because those are what quietly go wrong: a message with no
/// ceiling fills the phone, and one half-written line loses the log.
library;

import 'dart:convert';

/// How many are kept. The newest ones are the ones being asked about.
const int crashesToKeep = 20;

/// How much of one message is kept.
///
/// An exception can carry a whole decoded file in its message — a parse
/// failure quoting the document it failed on is the obvious one. Without a
/// ceiling, one bad import writes megabytes into a log nobody asked for.
const int crashMessageLimit = 400;

/// How many frames of stack are kept.
///
/// The top ten are the app; below that is the framework's own plumbing, which
/// is the same on every crash and is what makes a log unreadable.
const int crashStackFrames = 12;

/// Where it was caught. Not a severity — all three are equally uncaught.
enum CrashSource {
  /// A widget threw while building, laying out or painting.
  flutter,

  /// An asynchronous error nothing awaited.
  platform,

  /// Written by hand from a catch block that has nowhere to report to.
  caught,
}

const Map<CrashSource, String> crashSourceLabel = {
  CrashSource.flutter: 'While drawing',
  CrashSource.platform: 'In the background',
  CrashSource.caught: 'Reported',
};

/// One thing that went wrong.
class CrashNote {
  const CrashNote({
    required this.at,
    required this.source,
    required this.message,
    required this.stack,
    required this.version,
  });

  final DateTime at;
  final CrashSource source;

  /// The exception, trimmed to [crashMessageLimit].
  final String message;

  /// The top frames, already trimmed. Empty when there was no stack, which is
  /// common for errors thrown from a plugin.
  final String stack;

  /// Which build it happened on. Without this every report from a tester
  /// needs a second question asked before it can be read.
  final String version;

  Map<String, Object?> toJson() => {
        'at': at.toIso8601String(),
        'source': source.name,
        'message': message,
        'stack': stack,
        'version': version,
      };

  static CrashNote? fromJson(Map<String, Object?> json) {
    final at = DateTime.tryParse('${json['at']}');
    if (at == null) return null;

    return CrashNote(
      at: at,
      source: CrashSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => CrashSource.caught,
      ),
      message: '${json['message'] ?? ''}',
      stack: '${json['stack'] ?? ''}',
      version: '${json['version'] ?? ''}',
    );
  }
}

/// Builds one, applying every cap on the way in.
///
/// Capped here rather than at the point of writing, so that no caller can add
/// an uncapped one by forgetting.
CrashNote noteFor({
  required Object error,
  required StackTrace? stack,
  required CrashSource source,
  required String version,
  DateTime? at,
}) =>
    CrashNote(
      at: at ?? DateTime.now(),
      source: source,
      message: shorten('$error', crashMessageLimit),
      stack: trimStack('${stack ?? ''}'),
      version: version,
    );

/// The first [limit] characters, with a mark where the rest went.
///
/// The mark matters: silently truncated text reads as a complete message that
/// happens to end oddly, and somebody will debug the wrong sentence.
String shorten(String text, int limit) {
  final flat = text.trim();
  if (flat.length <= limit) return flat;

  return '${flat.substring(0, limit)}… (${flat.length - limit} more)';
}

/// The top frames of a stack, and nothing below them.
String trimStack(String stack) {
  final lines = [
    for (final line in const LineSplitter().convert(stack))
      if (line.trim().isNotEmpty) line.trimRight(),
  ];

  if (lines.length <= crashStackFrames) return lines.join('\n');

  return [
    ...lines.take(crashStackFrames),
    '… ${lines.length - crashStackFrames} more frames',
  ].join('\n');
}

/// The newest [crashesToKeep], newest first.
///
/// Sorted here rather than trusted from the file: the file is appended to, so
/// its order is the order things happened, and a clock that moved backwards —
/// a time zone change, a manual adjustment — would otherwise put an old crash
/// at the top for ever.
List<CrashNote> newestFirst(List<CrashNote> notes, {int keep = crashesToKeep}) {
  final sorted = [...notes]..sort((a, b) => b.at.compareTo(a.at));
  return sorted.length <= keep ? sorted : sorted.sublist(0, keep);
}

/// One note per line, for a file that is only ever appended to.
String encodeCrash(CrashNote note) => jsonEncode(note.toJson());

/// Reads a whole file back, skipping anything that will not parse.
///
/// ── A damaged line must not lose the log ───────────────────────────────────
/// This file is appended to from a crash handler, which is by definition
/// running while the app is in trouble — a process killed mid-write leaves
/// half a line. One line of JSON per crash is chosen precisely so that the
/// damage is bounded to the crash that was being written, and everything
/// before it still reads.
List<CrashNote> decodeCrashes(String contents) {
  final out = <CrashNote>[];

  for (final line in const LineSplitter().convert(contents)) {
    if (line.trim().isEmpty) continue;

    try {
      final json = jsonDecode(line);
      if (json is! Map<String, Object?>) continue;

      final note = CrashNote.fromJson(json);
      if (note != null) out.add(note);
    } catch (_) {
      // A half-written line. The rest of the file is still good.
      continue;
    }
  }

  return out;
}

/// The whole log as one block of text, for the clipboard.
String crashReport(List<CrashNote> notes) {
  if (notes.isEmpty) return 'No crashes recorded.';

  final out = StringBuffer();

  for (final note in newestFirst(notes)) {
    out
      ..writeln('${note.at.toIso8601String()}  '
          '${crashSourceLabel[note.source]}  v${note.version}')
      ..writeln(note.message);

    if (note.stack.isNotEmpty) out.writeln(note.stack);
    out.writeln();
  }

  return out.toString().trimRight();
}
