/// The line at the top of the dashboard.
///
///   dart test test/greeting_test.dart
///
/// Translated from `test/greeting.test.ts`. The boundaries are the only thing
/// here worth being sure about, which is why the clock is an argument.
library;

import 'package:stash_it/logic/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime at(int hour, [int minute = 0]) => DateTime(2026, 8, 12, hour, minute);

void main() {
  group('the three windows', () {
    // Three, not four. "Good night" is a farewell in English, not a greeting,
    // and anything cleverer for the small hours is a joke that stops being
    // funny the second time — and it is read every day. Evening runs long.
    test('midnight is evening', () => expect(dayPart(at(0)), DayPart.evening));
    test('04:59 is still evening',
        () => expect(dayPart(at(4, 59)), DayPart.evening));
    test('05:00 turns morning', () => expect(dayPart(at(5)), DayPart.morning));
    test('11:59 is the last of the morning', () {
      expect(dayPart(at(11, 59)), DayPart.morning);
    });
    test('noon is afternoon', () => expect(dayPart(at(12)), DayPart.afternoon));
    test('17:59 is the last of the afternoon', () {
      expect(dayPart(at(17, 59)), DayPart.afternoon);
    });
    test('18:00 turns evening', () => expect(dayPart(at(18)), DayPart.evening));
    test('23:00 is evening', () => expect(dayPart(at(23)), DayPart.evening));
  });

  group('the greeting', () {
    test('a name is used',
        () => expect(greeting('Nuno', at(9)), 'Good morning, Nuno'));
    test('afternoon',
        () => expect(greeting('Nuno', at(14)), 'Good afternoon, Nuno'));
    test('evening',
        () => expect(greeting('Nuno', at(21)), 'Good evening, Nuno'));

    test('no name, no comma',
        () => expect(greeting(null, at(9)), 'Good morning'));
    test('an empty name is the same as none', () {
      expect(greeting('', at(9)), 'Good morning');
    });
    test('so is whitespace',
        () => expect(greeting('   ', at(9)), 'Good morning'));
  });

  group('the name', () {
    test('a full name greets the first',
        () => expect(cleanName('Nuno Silva'), 'Nuno'));
    test('spacing is collapsed',
        () => expect(cleanName('  Nuno   Silva '), 'Nuno'));
    test('an absurd name is cut', () => expect(cleanName('a' * 80).length, 24));
    test('nothing in, nothing out', () => expect(cleanName(null), ''));

    /*
      Nothing is stripped beyond whitespace. A name filter that "cleans"
      O'Brien or 未来 is not tidying anything — it is getting somebody's name
      wrong, on the first screen they see, every day.
    */
    test('apostrophes survive', () => expect(cleanName("O'Brien"), "O'Brien"));
    test('accents survive', () => expect(cleanName('Zoë'), 'Zoë'));
    test('non-latin survives', () => expect(cleanName('未来'), '未来'));
  });

  test('the field allows more than the greeting shows', () {
    // So the field never stops you typing a name it will later shorten.
    expect(maxNameLength, greaterThan(24));
  });
}
