/// Where a notification points.
///
/// The routing itself needs a widget tree; this is the part that does not, and
/// it is the part that has to survive being written by one version of the app
/// and read by another sixty days later.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/deep_link.dart';

void main() {
  group('encode and parse', () {
    test('a record round-trips', () {
      for (final kind in [LinkKind.item, LinkKind.paper, LinkKind.sub]) {
        final link = DeepLink(kind, 'a3f9c1');
        expect(parseLink(encodeLink(link)), link);
      }
    });

    test('home has no id', () {
      expect(encodeLink(const DeepLink.home()), 'home');
      expect(parseLink('home'), const DeepLink.home());
    });

    /*
      ── Null, not a throw and not a guess ───────────────────────────────────

      A payload can arrive from a notification scheduled by a much older build
      — the OS held it for sixty days across an app update — and it is read
      inside a platform callback where a thrown exception has nowhere useful
      to go. The honest answer to a string this version does not understand is
      to open the app normally.
    */
    test('anything unrecognised is nothing', () {
      expect(parseLink(null), isNull);
      expect(parseLink(''), isNull);
      expect(parseLink('   '), isNull);
      expect(parseLink('nonsense'), isNull);
      expect(parseLink('room:abc'), isNull, reason: 'not a kind we route to');
      expect(parseLink(':abc'), isNull, reason: 'no kind');
      expect(parseLink('item:'), isNull, reason: 'no id');
    });

    /*
      Ids are minted by `newId` and contain no colon. Splitting on the first
      one anyway, so an id that ever gains one degrades to a wrong id rather
      than to a crash — and a wrong id resolves to "not found", which already
      has a well-defined outcome.
    */
    test('an id containing a colon does not break the parse', () {
      final link = parseLink('item:a:b');
      expect(link?.kind, LinkKind.item);
      expect(link?.id, 'a:b');
    });

    test('whitespace around it is tolerated', () {
      expect(parseLink('  item:x  '), const DeepLink(LinkKind.item, 'x'));
    });
  });

  group('equality', () {
    // Used as a value in a ValueNotifier, so two equal links must not look
    // like a change — otherwise a rebuild re-opens the same record.
    test('two links with the same parts are the same link', () {
      expect(const DeepLink(LinkKind.item, 'x'), const DeepLink(LinkKind.item, 'x'));
      expect(
        const DeepLink(LinkKind.item, 'x').hashCode,
        const DeepLink(LinkKind.item, 'x').hashCode,
      );
    });

    test('and kind is part of it', () {
      expect(
        const DeepLink(LinkKind.item, 'x'),
        isNot(const DeepLink(LinkKind.paper, 'x')),
      );
    });
  });
}
