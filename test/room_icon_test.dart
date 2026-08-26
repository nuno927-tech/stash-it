/// Which glyph a room gets.
///
/// Mirrors `item_icon_test.dart`, and exists for the same reason: the matching
/// is a pile of keywords with an ordering rule, and an ordering rule that is
/// not tested is an ordering rule that is wrong on the day somebody appends to
/// the list.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/room_icon.dart';

void main() {
  group('roomIconKey', () {
    test('matches the plain names', () {
      expect(roomIconKey('Kitchen'), RoomIconKey.kitchen);
      expect(roomIconKey('Garage'), RoomIconKey.garage);
      expect(roomIconKey('Office'), RoomIconKey.office);
      expect(roomIconKey('Attic'), RoomIconKey.attic);
    });

    test('ignores case and surrounding words', () {
      expect(roomIconKey('  UPSTAIRS BATHROOM '), RoomIconKey.bathroom);
      expect(roomIconKey('Dad\'s office'), RoomIconKey.office);
      expect(roomIconKey('Second bedroom'), RoomIconKey.bedroom);
    });

    /*
      ── The rule the whole index exists for ─────────────────────────────────

      Nearly every phrase in the list ends in the word "room". Sorted by
      declaration order, "Living Room" would match whichever key happened to be
      written first and every one of them would collapse to the generic house.
      Longest phrase wins, so the specific one is always tried first.
    */
    test('the longest phrase wins', () {
      expect(roomIconKey('Living Room'), RoomIconKey.living);
      expect(roomIconKey('Dining Room'), RoomIconKey.dining);
      expect(roomIconKey('Powder Room'), RoomIconKey.bathroom);
      expect(roomIconKey('Family Room'), RoomIconKey.family);
      expect(roomIconKey('Games Room'), RoomIconKey.family);
    });

    /*
      Whole words only.

      "Garden" contains "den", "Sunbathing deck" contains "bath", and
      "Workshop" contains "shop" — which is harmless, since both are the
      workshop key, but the first two are not. Without the boundary guard a
      garden gets a sofa.
    */
    test('does not match inside a longer word', () {
      expect(roomIconKey('Garden'), RoomIconKey.outdoor);
      expect(roomIconKey('Bathing hut'), RoomIconKey.room);
      expect(roomIconKey('Kitchener Street storage'), RoomIconKey.storage);
    });

    test('an apostrophe is a boundary, not a letter', () {
      expect(roomIconKey("Kid's room"), RoomIconKey.nursery);
    });

    test('the synonyms carry, because people do not say "outdoor"', () {
      expect(roomIconKey('The Shed'), RoomIconKey.workshop);
      expect(roomIconKey('Loft'), RoomIconKey.attic);
      expect(roomIconKey('Cellar'), RoomIconKey.basement);
      expect(roomIconKey('Lounge'), RoomIconKey.living);
      expect(roomIconKey('Larder'), RoomIconKey.pantry);
      expect(roomIconKey('Back patio'), RoomIconKey.outdoor);
    });

    /*
      The fallback is the point of the whole design.

      Rooms are invented by the person using the app, so an unrecognised name
      is the normal case rather than the error case — and it costs nothing,
      because what an unrecognised room gets is a house, which is what a room
      is. Nothing downstream asks whether the match was real.
    */
    test('anything unrecognised gets a house', () {
      expect(roomIconKey('Narnia'), RoomIconKey.room);
      expect(roomIconKey(''), RoomIconKey.room);
      expect(roomIconKey('   '), RoomIconKey.room);
      expect(roomIconKey('Unit 4'), RoomIconKey.room);
    });
  });
}
