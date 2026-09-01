/// When a card counts as finished.
///
/// The scrolling itself is in `ui/auto_advance.dart` and is mostly rules about
/// when NOT to move the page. This is the one part that is a predicate, and it
/// is the part that was wrong in the web version first time round.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/auto_advance.dart';

void main() {
  group('cardFilled', () {
    test('needs every field, not the interesting one', () {
      expect(cardFilled(['Kettle', '', '']), isFalse);
      expect(cardFilled(['Kettle', 'Russell Hobbs', '2026-01-04']), isTrue);
    });

    /*
      This is the rule the web version got wrong, and the reason the whole
      inventory is passed rather than the field that matters. Watching only the
      name threw somebody past the price, the date and the serial number the
      moment they typed "Kettle" — which is not "answering the last question",
      it is answering the first one.
    */
    test('one important answer does not finish a card', () {
      expect(cardFilled(['Passport', '']), isFalse,
          reason: 'Whose is still empty');
    });

    test('a space bar is not an answer', () {
      expect(cardFilled(['   ']), isFalse);
      expect(cardFilled(['Kettle', '  ']), isFalse);
    });

    test('nulls are unanswered', () {
      expect(cardFilled([null]), isFalse);
      expect(cardFilled(['Kettle', null]), isFalse);
    });

    /*
      Not everything on a card is text. A room is an id, a photograph is a
      pile of bytes, a toggle is a bool — and all three mean "answered" by
      existing rather than by having a length.
    */
    test('anything non-null and not false counts', () {
      expect(cardFilled(['room-3']), isTrue);
      expect(cardFilled([true]), isTrue);
      expect(cardFilled([0]), isTrue, reason: 'zero is a real answer');
      expect(cardFilled([false]), isFalse);
    });

    test('an empty card is finished, vacuously', () {
      // No caller does this today. It is here so that a card whose fields are
      // all conditional cannot silently become a card that never advances.
      expect(cardFilled([]), isTrue);
    });
  });
}
