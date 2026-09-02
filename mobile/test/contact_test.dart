/// What the contact links carry.
///
///   flutter test test/contact_test.dart
///
/// ── The interesting part is what gets attached ─────────────────────────────
/// A bug report used to arrive as a sentence and a version number, so every
/// question that followed cost a round trip. The Problem link now brings the
/// diagnostics block and the crash log with it.
///
/// That is a privacy decision as much as a support one, and it rests on two
/// things being true: the evidence is in the BODY where it can be read, and it
/// is under a rule that says deleting it is allowed. Both are tested here,
/// because a later edit that moves either one turns a helpful email into an
/// app that quietly sends somebody's document titles to a stranger.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/contact.dart';

void main() {
  group('the body without evidence', () {
    test('a question carries nothing but the version', () {
      final body = contactBody(ContactKind.question, '1.5.1');

      expect(body, contains('1.5.1'));
      expect(body, isNot(contains(evidenceRule)));
    });

    test('the cursor lands above the context line, not below it', () {
      // The two newlines at the front are what put it there.
      final body = contactBody(ContactKind.idea, '1.5.1');

      expect(body, startsWith('\n\n'));
      expect(body.trimRight(), endsWith('Android'));
    });

    test('an empty evidence block is the same as none', () {
      expect(
        contactBody(ContactKind.bug, '1.5.1', evidence: '   \n  '),
        contactBody(ContactKind.bug, '1.5.1'),
      );
    });
  });

  group('the body with evidence', () {
    final body = contactBody(
      ContactKind.bug,
      '1.5.1',
      evidence: 'Items: 33\nDocuments: 8',
    );

    test('it is separated from what the person wrote', () {
      expect(body, contains(evidenceRule));
      expect(body.indexOf(evidenceRule), greaterThan(body.indexOf('1.5.1')));
    });

    test('it says deleting it is allowed, before it starts', () {
      // Everything this app does about privacy rests on somebody being able to
      // see what is about to be sent and take it out.
      expect(body, contains('delete'));
      expect(
        body.indexOf('delete'),
        lessThan(body.indexOf('Items: 33')),
      );
    });

    test('the evidence itself is there in full', () {
      expect(body, contains('Items: 33'));
      expect(body, contains('Documents: 8'));
    });
  });

  group('the cap', () {
    test('a long log is cut, and says where the rest is', () {
      final long = [for (var i = 0; i < 2000; i++) 'line $i'].join('\n');
      final body = contactBody(ContactKind.bug, '1.5.1', evidence: long);

      expect(body.length, lessThan(evidenceLimit + 600));
      expect(body, contains('cut here'));
      expect(body, contains('Crashes'));
    });

    test('it cuts at a line, not mid-word', () {
      /*
        Mid-word is where a mail client would cut it, silently, and a stack
        trace that ends in the middle of a frame looks complete. Cutting a
        whole line short and saying so is the difference between evidence and
        a puzzle.
      */
      final long = [for (var i = 0; i < 2000; i++) 'frame $i'].join('\n');
      final body = contactBody(ContactKind.bug, '1.5.1', evidence: long);

      final cut = body.indexOf('\n\n(cut here');
      final kept = body.substring(0, cut);

      // The last line that survived is a whole one.
      expect(kept.split('\n').last, matches(RegExp(r'^frame \d+$')));
    });

    test('a short log is left exactly as it is', () {
      const short = 'Items: 1';
      final body = contactBody(ContactKind.bug, '1.5.1', evidence: short);

      expect(body, contains(short));
      expect(body, isNot(contains('cut here')));
    });
  });

  group('the link', () {
    test('every part is encoded, so nothing truncates the body', () {
      // A subject with an ampersand in it would otherwise end the body at that
      // point, which is the sort of bug that shows up only on somebody else's
      // mail client.
      final uri = contactUri(ContactKind.bug, '1.5.1', evidence: 'a & b');

      expect(uri.scheme, 'mailto');
      expect(uri.path, developerEmail);
      expect(uri.query, contains('%26'));
      expect(uri.queryParameters['body'], contains('a & b'));
    });

    test('a link with no evidence still opens cleanly', () {
      final uri = contactUri(ContactKind.question, '1.5.1');

      expect(uri.queryParameters['body'], isNot(contains(evidenceRule)));
      expect(uri.queryParameters['subject'], contains('question'));
    });

    test('the three kinds do not share a subject', () {
      final subjects = {
        for (final kind in ContactKind.values)
          contactUri(kind, '1.5.1').queryParameters['subject'],
      };

      expect(subjects, hasLength(ContactKind.values.length));
    });
  });
}
