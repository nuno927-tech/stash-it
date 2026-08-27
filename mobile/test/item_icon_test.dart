/// Choosing an icon for an item with no photo.
///
///   dart test test/item_icon_test.dart
///
/// Translated from `test/itemicon.test.ts`. The interesting cases are all about
/// precedence: which field wins, and which keyword wins inside a field.
library;

import 'package:stash_it/logic/item_icon.dart';
import 'package:flutter_test/flutter_test.dart';

IconKey iconFor({String? name, String? brand, String? model, String? notes}) =>
    iconKeyFor(IconSubject(name: name, brand: brand, model: model, notes: notes));

void main() {
  group('the obvious ones', () {
    test('a fridge', () => expect(iconFor(name: 'Fridge'), IconKey.fridge));
    test('a dishwasher', () => expect(iconFor(name: 'Bosch Dishwasher'), IconKey.dishwasher));
    test('a synonym counts', () => expect(iconFor(name: 'Refrigerator'), IconKey.fridge));
    test('and case does not', () => expect(iconFor(name: 'KETTLE'), IconKey.kettle));
  });

  group('the floor', () {
    // A wrong icon is worse than a neutral one: it looks like the app has
    // misunderstood the thing.
    test('nothing recognisable is a box', () {
      expect(iconFor(name: 'Thing'), IconKey.box);
    });

    test('and nothing at all is too', () => expect(iconFor(), IconKey.box));
    test('an empty name is too', () => expect(iconFor(name: ''), IconKey.box));
  });

  group('longest phrase wins', () {
    /*
      THE PRECEDENCE THE INDEX EXISTS FOR. "washing machine" and "washer" are
      different keys, and "machine" appears inside the first. Sorted by length,
      the phrase is tested before either word inside it.
    */
    test('a washing machine is a washer, not whatever "machine" would be', () {
      expect(iconFor(name: 'Washing machine'), IconKey.washer);
    });

    test('a table saw is a saw, not a table', () {
      expect(iconFor(name: 'DeWalt table saw'), IconKey.saw);
    });

    test('a pizza oven is a grill, not an oven', () {
      expect(iconFor(name: 'Ooni pizza oven'), IconKey.grill);
    });

    test('an air fryer is an oven, not a fan', () {
      expect(iconFor(name: 'Air fryer'), IconKey.oven);
    });
  });

  group('word boundaries', () {
    // "microwave" must not match inside "wave", and nothing should match a
    // word it merely happens to be a substring of.
    test('a keyword inside a longer word does not match', () {
      expect(iconFor(name: 'Microwaves are loud'), IconKey.box);
      expect(iconFor(name: 'Carpet'), IconKey.box);
      expect(iconFor(name: 'Sawdust'), IconKey.box);
    });

    test('but a keyword next to punctuation does', () {
      expect(iconFor(name: 'TV, wall-mounted'), IconKey.tv);
      expect(iconFor(name: '(kettle)'), IconKey.kettle);
    });

    /*
      "e-bike" ends in a word character but begins next to a hyphen, and the
      hyphen is why `\b` was not trusted: a phrase whose edge is punctuation
      needs the boundary written out.
    */
    test('and a hyphenated one does', () {
      expect(iconFor(name: 'Specialized e-bike'), IconKey.bike);
    });
  });

  group('which field wins', () {
    /*
      The name gets its own pass first, because it carries the most intent.
      "Bosch SHXM4AY55N" in a model field tells you nothing; "dishwasher" in
      the name tells you everything.
    */
    test('the name beats the notes', () {
      expect(
        iconFor(name: 'Kettle', notes: 'bought at the same time as the sofa'),
        IconKey.kettle,
      );
    });

    test('but the rest is used when the name says nothing', () {
      expect(iconFor(name: 'The big one', notes: 'chest freezer'), IconKey.fridge);
    });

    test('brand and model are searched too', () {
      expect(iconFor(name: 'Spare', model: 'Roomba j7'), IconKey.vacuum);
    });
  });

  test('every key except box has at least one keyword', () {
    for (final key in IconKey.values) {
      final words = keywords[key];
      expect(words, isNotNull, reason: '$key is missing from the keyword table');
      if (key != IconKey.box) {
        expect(words, isNotEmpty, reason: '$key has no keywords');
      }
    }
  });

  test('and no keyword is claimed by two keys', () {
    final seen = <String, IconKey>{};
    keywords.forEach((key, words) {
      for (final w in words) {
        expect(seen.containsKey(w), isFalse,
            reason: '"$w" is claimed by both ${seen[w]} and $key');
        seen[w] = key;
      }
    });
  });
}
