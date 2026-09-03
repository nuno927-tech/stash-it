/// Swipe thresholds.
///
///   dart test test/swipe_test.dart
///
/// Translated from `test/swipe.test.ts`. Every number here is a judgement that
/// shows up as a feel, which is exactly why they are asserted rather than
/// buried in an event handler.
library;

import 'package:stash_it/logic/swipe.dart';
import 'package:flutter_test/flutter_test.dart';

const phone = 390.0; // a normal handset width

Gesture swipe(double dx, {double dy = 0, int ms = 200, double width = phone}) =>
    Gesture(dx: dx, dy: dy, elapsed: Duration(milliseconds: ms), width: width);

void main() {
  group('which tab', () {
    /*
      Subscriptions was once added to the bottom bar and not to the order list,
      so swiping left from Items landed on Settings — it skipped the tab
      sitting between them and nothing on screen explained why. An enum makes
      that a compile error; this asserts the order anyway.
    */
    test('the order matches the bar', () {
      expect(Tab.values,
          [Tab.home, Tab.items, Tab.subs, Tab.papers, Tab.settings]);
    });

    /*
      The three tests that were here walked `nextTab`, which the shell no
      longer calls: the pages are dragged directly and the `PageView` walks
      this list itself, ends included.

      So the order above is the whole contract now — it is what the bar draws,
      what the swipe traverses, and what a tap animates to.
    */
  });

  group('was that a swipe', () {
    test('a long deliberate drag is', () {
      // A fifth of the screen, slowly.
      expect(swipeVerdict(swipe(-120, ms: 900)), Direction.left);
    });

    test('a short fast flick is too', () {
      // Nowhere near a fifth of the screen, but unmistakably deliberate.
      expect(swipeVerdict(swipe(-40, ms: 120)), Direction.left);
    });

    test('but a short slow drag is not', () {
      // Neither far enough to be deliberate nor fast enough to be a flick.
      expect(swipeVerdict(swipe(-40, ms: 900)), isNull);
    });

    test('a tiny movement is never one', () {
      expect(swipeVerdict(swipe(-20, ms: 60)), isNull);
    });

    test('direction follows the finger', () {
      // Content follows the finger, so dragging left reveals what is right.
      expect(swipeVerdict(swipe(-120, ms: 900)), Direction.left);
      expect(swipeVerdict(swipe(120, ms: 900)), Direction.right);
    });

    /*
      THE ACCIDENT WORTH PREVENTING. Skimming a long list with the thumb is a
      diagonal drag, and at 1.3 dominance it still does not change tabs.
    */
    test('a diagonal scroll is left alone', () {
      expect(swipeVerdict(swipe(-100, dy: 90, ms: 900)), isNull);
    });

    test('but a real swipe with a thumb arc is not', () {
      expect(swipeVerdict(swipe(-140, dy: 40, ms: 900)), Direction.left);
    });

    test('the threshold scales with the screen', () {
      // 90px is over a fifth of a small phone and under a fifth of a tablet.
      expect(swipeVerdict(swipe(-90, ms: 2000, width: 360)), Direction.left);
      expect(swipeVerdict(swipe(-90, ms: 2000, width: 1000)), isNull);
    });

    test('and never drops below the pixel floor', () {
      // A very narrow window must still demand a real movement.
      expect(swipeVerdict(swipe(-40, ms: 2000, width: 100)), isNull);
    });
  });

  group('a row sliding aside', () {
    test('a firm leftward drag opens it', () {
      expect(rowOpens(-40, 0), isTrue);
    });

    // Strictly past the threshold, not at it — a boundary that reads one way
    // in prose and another in code is one somebody will get wrong later.
    test('exactly at the threshold does not', () {
      expect(rowOpens(-rowOpenAt, 0), isFalse);
    });

    test('rightwards never does', () {
      expect(rowOpens(40, 0), isFalse);
      expect(rowOpens(200, 0), isFalse);
    });

    test('nor does a mostly-vertical drag', () {
      expect(rowOpens(-40, 60), isFalse);
    });

    test('the row never slides right of home', () {
      expect(rowOffset(50, false), 0);
    });

    test('nor past the button', () {
      expect(rowOffset(-500, false), -rowReveal);
      expect(rowOffset(-500, true), -rowReveal);
    });

    test('and follows the finger in between', () {
      expect(rowOffset(-40, false), -40);
      // Already open, dragging back towards home.
      expect(rowOffset(40, true), -rowReveal + 40);
    });

    test('opening is easier than the reveal is wide', () {
      // Opening costs nothing, so a hesitant drag should succeed.
      expect(rowOpenAt, lessThan(rowReveal / 2));
    });
  });

  group('throwing a card away', () {
    test('a firm drag either way dismisses', () {
      expect(dismissedByDrag(Drag(dy: 50, elapsed: const Duration(seconds: 2))),
          isTrue);
      expect(
          dismissedByDrag(Drag(dy: -50, elapsed: const Duration(seconds: 2))),
          isTrue);
    });

    test('a quick flick does too', () {
      expect(
          dismissedByDrag(
              const Drag(dy: 30, elapsed: Duration(milliseconds: 150))),
          isTrue);
    });

    test('a small slow nudge does not', () {
      expect(dismissedByDrag(const Drag(dy: 30, elapsed: Duration(seconds: 2))),
          isFalse);
    });

    /*
      THE ASYMMETRY, ASSERTED. Changing tabs by accident loses your place;
      closing a reminder by accident costs nothing, and the reminder appears
      after every save. So dismissing must be looser — and looser than the
      *floor*, not merely looser than the tab threshold on whatever handset
      this was tuned against, since that one scales with the screen.
    */
    test('and it is looser than the tab swipe on every device', () {
      expect(dismissPixels, lessThan(minPixels));
      expect(dismissFlickPixels, lessThan(flickPixels));
    });
  });

  group('the screen edges', () {
    // The system back gesture owns them on Android. Ours must not also fire,
    // or one gesture does two things.
    test('the left edge belongs to the system', () {
      expect(startedAtEdge(10, phone), isTrue);
    });

    test('so does the right', () {
      expect(startedAtEdge(phone - 10, phone), isTrue);
    });

    test('the middle is ours', () {
      expect(startedAtEdge(phone / 2, phone), isFalse);
    });

    test('and the guard is narrow enough to leave a screen behind', () {
      expect(edgeGuard * 2, lessThan(phone / 3));
    });
  });
}
