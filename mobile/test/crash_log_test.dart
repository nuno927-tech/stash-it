/// The crash log's shape, caps and tolerance for damage.
///
///   flutter test test/crash_log_test.dart
///
/// ── Why the caps are the interesting part ──────────────────────────────────
/// A crash logger is written once and then runs on phones nobody is watching,
/// in exactly the situation where things are already going wrong. The two ways
/// it turns from a help into a problem are both about size: a message with no
/// ceiling — an exception that quotes the file it failed to parse — and a
/// crash loop that appends for ever.
///
/// The third is damage. This file is appended to from inside an error handler,
/// so a process killed mid-write leaves half a line, and a reader that gives
/// up on it loses every crash before it too.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/crash_log.dart';

CrashNote note(String message, {DateTime? at, String stack = ''}) => CrashNote(
      at: at ?? DateTime(2026, 9, 2, 12),
      source: CrashSource.flutter,
      message: message,
      stack: stack,
      version: '1.4.0',
    );

String frames(int count) =>
    [for (var i = 0; i < count; i++) '#$i      Widget.build (parts.dart:$i)']
        .join('\n');

void main() {
  group('what it will not let grow', () {
    test('a short message is left exactly as it is', () {
      expect(shorten('Bad state: no element', 400), 'Bad state: no element');
    });

    test('a long one is cut, and says how much it lost', () {
      // Silently truncated text reads as a complete message that happens to
      // end oddly, and somebody debugs the wrong sentence.
      final cut = shorten('x' * 500, 400);

      expect(cut, startsWith('x' * 400));
      expect(cut, contains('100 more'));
    });

    test('an exception quoting a whole file cannot fill the phone', () {
      final made = noteFor(
        error: 'FormatException: ${'a' * 2000000}',
        stack: null,
        source: CrashSource.platform,
        version: '1.4.0',
      );

      expect(made.message.length, lessThan(crashMessageLimit + 60));
    });

    test('a stack keeps its top frames and drops the rest', () {
      final trimmed = trimStack(frames(60));

      expect(trimmed.split('\n'), hasLength(crashStackFrames + 1));
      expect(trimmed, startsWith('#0 '));
      expect(trimmed, contains('${60 - crashStackFrames} more frames'));
    });

    test('a short stack is untouched, and says nothing about frames', () {
      final trimmed = trimStack(frames(3));

      expect(trimmed.split('\n'), hasLength(3));
      expect(trimmed, isNot(contains('more frames')));
    });

    test('no stack at all is not an error', () {
      // Common: an error thrown inside a plugin arrives with none.
      final made = noteFor(
        error: 'PlatformException',
        stack: null,
        source: CrashSource.platform,
        version: '1.4.0',
      );

      expect(made.stack, isEmpty);
    });

    test('only the newest handful are kept', () {
      final many = [
        for (var i = 0; i < 100; i++)
          note('crash $i', at: DateTime(2026, 1, 1).add(Duration(hours: i))),
      ];

      final kept = newestFirst(many);

      expect(kept, hasLength(crashesToKeep));
      expect(kept.first.message, 'crash 99');
    });

    test('newest first even when the file is not in order', () {
      /*
        Sorted rather than trusted from the file. The file is appended to, so
        its order is the order things happened — and a clock that moved
        backwards, which a time zone change does, would otherwise pin an old
        crash to the top for ever.
      */
      final jumbled = [
        note('middle', at: DateTime(2026, 5, 1)),
        note('newest', at: DateTime(2026, 9, 1)),
        note('oldest', at: DateTime(2026, 1, 1)),
      ];

      expect(
        newestFirst(jumbled).map((n) => n.message),
        ['newest', 'middle', 'oldest'],
      );
    });
  });

  group('out and back', () {
    test('everything written is read back the same', () {
      final original = CrashNote(
        at: DateTime(2026, 9, 2, 14, 30, 5),
        source: CrashSource.platform,
        message: 'Bad state: no element',
        stack: frames(3),
        version: '1.4.0',
      );

      final back = decodeCrashes(encodeCrash(original)).single;

      expect(back.at, original.at);
      expect(back.source, CrashSource.platform);
      expect(back.message, original.message);
      expect(back.stack, original.stack);
      expect(back.version, '1.4.0');
    });

    test('a message with newlines in it survives one line of JSON', () {
      // The whole file format rests on one crash being one line. An exception
      // message containing a newline would end the line early if it were not
      // encoded, and take the next crash with it.
      final original = note('line one\nline two\nline three');
      final back = decodeCrashes(encodeCrash(original)).single;

      expect(back.message, 'line one\nline two\nline three');
    });

    test('several in a file come back in order', () {
      final file = [
        encodeCrash(note('first', at: DateTime(2026, 1, 1))),
        encodeCrash(note('second', at: DateTime(2026, 2, 1))),
      ].join('\n');

      expect(decodeCrashes(file), hasLength(2));
    });
  });

  group('damage', () {
    test('a half-written last line loses only itself', () {
      /*
        The failure this exists for: the log is appended to from inside an
        error handler, on a phone that is already in trouble. A process killed
        mid-write leaves exactly this.
      */
      final good = encodeCrash(note('the one before'));
      final file = '$good\n{"at":"2026-09-02T12:00:00.000","mess';

      final read = decodeCrashes(file);

      expect(read, hasLength(1));
      expect(read.single.message, 'the one before');
    });

    test('a line that is not an object at all is skipped', () {
      final file = '[1,2,3]\n"just a string"\n${encodeCrash(note('real'))}';

      expect(decodeCrashes(file).single.message, 'real');
    });

    test('a record with no readable time is dropped, not guessed at', () {
      // A crash whose time is unknown sorts wherever the default put it, which
      // is worse than not showing it.
      final file = '{"source":"flutter","message":"when?"}';

      expect(decodeCrashes(file), isEmpty);
    });

    test('an unknown source reads as reported rather than failing', () {
      // Forwards compatibility: a later version adding a source must not make
      // this one drop the crash it is being asked about.
      final file =
          '{"at":"2026-09-02T12:00:00.000","source":"telepathy",'
          '"message":"hm","stack":"","version":"9.9.9"}';

      expect(decodeCrashes(file).single.source, CrashSource.caught);
    });

    test('an empty file is an empty list, not a crash of its own', () {
      expect(decodeCrashes(''), isEmpty);
      expect(decodeCrashes('\n\n\n'), isEmpty);
    });
  });

  group('the block that goes on the clipboard', () {
    test('it says so when there is nothing', () {
      expect(crashReport(const []), 'No crashes recorded.');
    });

    test('every crash contributes its time, its version and its message', () {
      final text = crashReport([note('Bad state: no element')]);

      expect(text, contains('2026-09-02'));
      expect(text, contains('v1.4.0'));
      expect(text, contains('Bad state: no element'));
      expect(text, contains(crashSourceLabel[CrashSource.flutter]!));
    });

    test('it is capped the same way the screen is', () {
      final many = [
        for (var i = 0; i < 100; i++)
          note('crash $i', at: DateTime(2026, 1, 1).add(Duration(hours: i))),
      ];

      // Nobody pastes a hundred stack traces into an email, and a report that
      // long is one nobody reads before sending — which is the whole risk.
      expect('crash 99'.allMatches(crashReport(many)).length, 1);
      expect(crashReport(many), isNot(contains('crash 0\n')));
    });

    test('every source has a name a person can read', () {
      for (final source in CrashSource.values) {
        expect(crashSourceLabel[source], isNotNull, reason: '$source');
      }
    });
  });
}
