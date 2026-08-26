/// The service catalogue.
///
/// It is generated from the PWA's `services.ts`, so most of what could go
/// wrong here is a bad conversion rather than a bad decision — which is
/// exactly what a test is for. Nothing below asserts a particular logo looks
/// right; they assert the list is usable as a list.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/services.dart';

void main() {
  group('the catalogue', () {
    test('came across whole', () {
      // Fifty-odd. Pinned loosely rather than exactly, because adding a
      // service is a normal thing to do and should not fail a test — but
      // losing half of them in a bad conversion should.
      expect(services.length, greaterThan(40));
    });

    test('the first row is the ones most people have', () {
      // The grid shows five across and the first row should cover most
      // people without scrolling, so the order is load-bearing.
      expect(services.take(5).map((s) => s.id), [
        'netflix',
        'spotify',
        'youtube',
        'prime',
        'disneyplus',
      ]);
    });

    test('every id is unique', () {
      // Two entries sharing an id means `serviceById` silently keeps one, and
      // a subscription saved against the other draws the wrong logo forever.
      final ids = services.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every entry has a name, a colour and a path', () {
      for (final s in services) {
        expect(s.name.trim(), isNotEmpty, reason: s.id);
        expect(s.path.trim(), isNotEmpty, reason: s.id);

        // Opaque. A colour that came across without its alpha channel is a
        // fully transparent tile — invisible, and not obviously a bug.
        expect(s.colour >> 24 & 0xFF, 0xFF, reason: s.id);
      }
    });

    test('no path came across truncated', () {
      // Every one of these is an SVG path and starts with a move command.
      // A conversion that clipped the front of the string would still be a
      // valid Dart string and would draw nothing at all.
      for (final s in services) {
        expect(s.path.trimLeft()[0], anyOf('M', 'm'), reason: s.id);
      }
    });
  });

  group('serviceFor', () {
    test('finds one by id', () {
      expect(serviceFor('netflix')?.name, 'Netflix');
    });

    /*
      Null for both "not chosen" and "chosen something we do not have".

      The caller draws initials in either case, and asking it to tell the two
      apart would be asking it to care about a difference that changes nothing
      it does.
    */
    test('gives back nothing for an unknown or absent id', () {
      expect(serviceFor(null), isNull);
      expect(serviceFor('puregym'), isNull);
    });
  });

  group('searchServices', () {
    test('an empty query is the whole grid', () {
      expect(searchServices('').length, services.length);
      expect(searchServices('   ').length, services.length);
    });

    test('ignores case', () {
      expect(searchServices('NETFLIX').map((s) => s.id), contains('netflix'));
    });

    /*
      Matching anywhere in the name, not only at the start.

      People type "prime" for Amazon Prime and "tv" for Apple TV+. A prefix
      search answers neither, and the failure is invisible — the grid simply
      empties, which reads as "we do not have it".
    */
    test('matches in the middle of a name', () {
      expect(searchServices('prime').map((s) => s.id), contains('prime'));
      expect(searchServices('music').map((s) => s.id), contains('applemusic'));
    });

    test('gives back nothing for something we do not have', () {
      expect(searchServices('puregym'), isEmpty);
    });
  });

  group('initialsFor', () {
    test('two words give two letters', () {
      expect(initialsFor('Water delivery'), 'WD');
      expect(initialsFor('my local gym'), 'ML');
    });

    test('one word gives one', () {
      expect(initialsFor('Gym'), 'G');
      expect(initialsFor('  spotify '), 'S');
    });

    /*
      Never three. At 22px a third letter is the width of the other two and
      reads as noise rather than as a mark.
    */
    test('three words still give two letters', () {
      expect(initialsFor('The London Gym'), 'TL');
    });

    test('nothing typed does not crash', () {
      expect(initialsFor(''), '?');
      expect(initialsFor('   '), '?');
    });
  });
}
