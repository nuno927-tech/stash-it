/// Where the manual button sends you.
///
///   flutter test test/manuals_test.dart
///
/// The table itself cannot be tested — whether Bosch's support page still
/// answers that URL is a fact about Bosch's website, not about this code, and
/// a test that hit the network would fail on a train. What IS worth pinning is
/// the matching: that brands are found however somebody spells them, that an
/// unknown brand still gets somewhere useful, and that a model number with a
/// space or a slash in it does not produce a broken URL.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/manuals.dart';

void main() {
  group('finding the manufacturer', () {
    test('however the brand is capitalised or punctuated', () {
      for (final spelling in ['Bosch', 'BOSCH', 'bosch', ' Bosch ']) {
        expect(sourceFor(spelling)?.brand, 'Bosch', reason: spelling);
      }
    });

    test('punctuation is not part of the name', () {
      // "G.E." and "GE" are one manufacturer to everybody except a string
      // comparison.
      expect(sourceFor('G.E.')?.brand, 'GE');
      expect(sourceFor("De'Longhi")?.brand, "De'Longhi");
    });

    test('a brand with a range after it still matches', () {
      expect(sourceFor('Bosch Serie 6')?.brand, 'Bosch');
      expect(sourceFor('Samsung Bespoke')?.brand, 'Samsung');
    });

    test('a short first word does not match by accident', () {
      /*
        The first-word fallback needs a floor. Without one, "Le Creuset" would
        match anything in the table beginning "le", and a two-letter word
        matches far too much. The genuinely short brands are caught by the
        exact lookup before the fallback runs, which this checks too.
      */
      expect(sourceFor('Le Creuset'), isNull);
      expect(sourceFor('LG')?.brand, 'LG');
      expect(sourceFor('GE')?.brand, 'GE');
    });

    test('an unknown brand, or none at all, finds nothing', () {
      expect(sourceFor('Acme Widgets'), isNull);
      expect(sourceFor(''), isNull);
      expect(sourceFor(null), isNull);
    });
  });

  group('the URL it builds', () {
    test('a known brand goes to that manufacturer, with the model', () {
      final where = manualSearch(brand: 'Bosch', model: 'SMV4HCX40G');
      expect(where.host, contains('bosch'));
      expect(where.toString(), contains('SMV4HCX40G'));
    });

    test('an unknown brand falls back to a web search for both', () {
      final where = manualSearch(brand: 'Acme', model: 'X1');
      expect(where.host, contains('duckduckgo'));
      expect(Uri.decodeFull(where.toString()), contains('Acme X1 manual'));
    });

    test('a model with spaces and slashes survives encoding', () {
      // Model numbers are full of these, and an unencoded slash would end the
      // path rather than being part of the query.
      final where = manualSearch(brand: 'Acme', model: 'AB 12/34');
      expect(where.toString(), isNot(contains(' ')));
      expect(where.queryParameters['q'], contains('AB 12/34'));
    });

    test('it still goes somewhere with only a brand', () {
      final where = manualSearch(brand: 'Acme');
      expect(where.host, isNotEmpty);
      expect(Uri.decodeFull(where.toString()), contains('Acme manual'));
    });
  });

  group('what the button says', () {
    test('a known brand is named, because that is the promise', () {
      expect(manualButtonLabel('Bosch'), 'Look on Bosch');
      expect(manualButtonLabel('lg'), 'Look on LG');
    });

    test('an unknown one is honest about being a search', () {
      expect(manualButtonLabel('Acme'), 'Search the web');
      expect(manualButtonLabel(null), 'Search the web');
    });
  });

  group('the table itself', () {
    test('every entry has somewhere to put the model', () {
      // An entry missing its placeholder would send everybody to the same
      // page regardless of what they own — and it would look like it worked.
      for (final entry in manualSources.entries) {
        expect(entry.value.url, contains('{q}'),
            reason: '${entry.key} has no {q}');
      }
    });

    test('every key is already folded, so lookups can find it', () {
      for (final key in manualSources.keys) {
        expect(foldBrand(key), key, reason: '$key is not in folded form');
      }
    });

    test('every entry is https', () {
      for (final entry in manualSources.entries) {
        expect(entry.value.url, startsWith('https://'), reason: entry.key);
      }
    });
  });
}
