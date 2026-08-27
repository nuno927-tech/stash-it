/// Ten taps on the version pill.
///
///   dart test test/devmode_test.dart
///
/// Translated from `test/devmode.test.ts`. The rule with a bug in it is the
/// gap: without it the counter accumulates across a week of ordinary use and
/// the developer card appears unbidden on somebody's settings screen.
library;

import 'package:stash_it/logic/devmode.dart';
import 'package:flutter_test/flutter_test.dart';

final start = DateTime(2026, 8, 12, 9);

DateTime at(int ms) => start.add(Duration(milliseconds: ms));

/// Taps `n` times, 200ms apart — a plausible thumb.
TapState drum(int n) {
  var state = noTaps;
  for (var i = 0; i < n; i++) {
    state = tap(state, at(i * 200));
  }
  return state;
}

void main() {
  group('counting', () {
    test('the first tap starts a run', () {
      expect(tap(noTaps, at(0)).count, 1);
    });

    test('a quick second continues it', () {
      expect(tap(tap(noTaps, at(0)), at(200)).count, 2);
    });

    test('ten opens it', () {
      expect(unlocked(drum(tapsToUnlock)), isTrue);
    });

    test('nine does not', () {
      expect(unlocked(drum(tapsToUnlock - 1)), isFalse);
    });
  });

  group('the gap', () {
    /*
      A tap now and a tap tomorrow are two different intentions. Without the
      reset the count would creep up across ordinary use — nine taps over a
      week, then one more, and the card is open.
    */
    test('a pause starts over', () {
      final nearly = drum(9);
      final later = tap(nearly, at(9 * 200 + tapGap.inMilliseconds + 1));
      expect(later.count, 1);
      expect(unlocked(later), isFalse);
    });

    test('but the gap itself is not a pause', () {
      final one = tap(noTaps, at(0));
      expect(tap(one, at(tapGap.inMilliseconds)).count, 2);
    });

    test('and a fresh state is never mid-run', () {
      expect(noTaps.count, 0);
      expect(noTaps.last, isNull);
      expect(unlocked(noTaps), isFalse);
    });
  });

  group('the hint', () {
    /*
      Silence until the tapping is obviously deliberate, then count down.
      Starting the countdown at ten would announce the thing we just decided
      to hide.
    */
    test('nothing is said early on', () {
      expect(tapHint(drum(1)), isNull);
      expect(tapHint(drum(6)), isNull);
      expect(tapHint(drum(tapsToUnlock - 4)), isNull);
    });

    test('then it counts down', () {
      expect(tapHint(drum(tapsToUnlock - 3)), '3 more taps');
      expect(tapHint(drum(tapsToUnlock - 2)), '2 more taps');
      expect(tapHint(drum(tapsToUnlock - 1)), '1 more tap');
    });

    test('and stops once it is open', () {
      expect(tapHint(drum(tapsToUnlock)), isNull);
      expect(tapHint(drum(tapsToUnlock + 5)), isNull);
    });

    test('tapsLeft never goes negative', () {
      expect(tapsLeft(drum(tapsToUnlock + 5)), 0);
    });
  });

  group('staying unlocked', () {
    /*
      Once open it stays open until Hide. Testing a notification means leaving
      Settings, closing the app, waiting, and tapping the notification — and
      coming back to ten more taps every time turns a five-second check into a
      chore, which is how a test bench stops being used.
    */
    setUp(() => rememberUnlocked(false));
    tearDown(() => rememberUnlocked(false));

    test('locked to begin with', () => expect(readUnlocked(), isFalse));

    test('remembering opens it', () {
      rememberUnlocked(true);
      expect(readUnlocked(), isTrue);
    });

    test('and Hide closes it', () {
      rememberUnlocked(true);
      rememberUnlocked(false);
      expect(readUnlocked(), isFalse);
    });

    /*
      The web version needed sessionStorage for this, wrapped in try/catch
      because private browsing throws on storage access. A Flutter process is
      the session, so there is nothing to store and nothing that can throw —
      which is why there is no "storage refused, treat as locked" test here.
    */
  });
}
