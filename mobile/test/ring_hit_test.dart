/// Where a tap on the ring lands.
///
///   flutter test test/ring_hit_test.dart
///
/// ── Why this is worth a file of its own ────────────────────────────────────
/// The ring is painted, not built, so nothing about this can be caught by
/// looking at the screen: an arc and the region that answers for it are two
/// separate pieces of arithmetic that happen to agree. When they stop
/// agreeing, the ring still looks perfect and tapping the red sliver opens the
/// list of things that are fine.
///
/// The specific way it goes wrong is a quarter turn. The canvas measures
/// angles from three o'clock; the ring is drawn from twelve.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/ring_hit.dart';

/// A point on the ring's line, [turns] of the way round from twelve o'clock.
({double dx, double dy}) at(double turns, {double radius = 85}) {
  final angle = turns * 2 * math.pi - math.pi / 2;
  return (dx: math.cos(angle) * radius, dy: math.sin(angle) * radius);
}

RingWedge? hit(
  double turns, {
  double covered = 1,
  double soon = 1,
  double lapsed = 1,
  double radius = 85,
}) {
  final p = at(turns, radius: radius);
  return wedgeAt(
    dx: p.dx,
    dy: p.dy,
    radius: 85,
    covered: covered,
    soon: soon,
    lapsed: lapsed,
  );
}

void main() {
  group('which wedge', () {
    test('twelve o\'clock is the start of the first wedge', () {
      // The one that pins the quarter turn. If this says `lapsed`, the angles
      // are being measured from three o'clock and every tap is 90 degrees out.
      expect(hit(0), RingWedge.covered);
    });

    test('three equal wedges divide the clock in three', () {
      expect(hit(0.10), RingWedge.covered);
      expect(hit(0.30), RingWedge.covered);
      expect(hit(0.40), RingWedge.soon);
      expect(hit(0.60), RingWedge.soon);
      expect(hit(0.70), RingWedge.lapsed);
      expect(hit(0.99), RingWedge.lapsed);
    });

    test('the whole circle is covered, with no dead angles', () {
      /*
        Walked rather than sampled at the boundaries, because the failure this
        catches is a gap: the painter shortens each sweep to make room for its
        round caps, and a hit test that copied that shortening would leave five
        pixels of ring that answer nothing.
      */
      for (var i = 0; i < 720; i++) {
        expect(hit(i / 720), isNotNull, reason: 'nothing at ${i / 2} degrees');
      }
    });

    test('one wedge owning everything owns the whole circle', () {
      for (var i = 0; i < 90; i++) {
        expect(
          hit(i / 90, covered: 7, soon: 0, lapsed: 0),
          RingWedge.covered,
          reason: 'at ${i * 4} degrees',
        );
      }
    });

    test('a wedge counting nothing is never returned', () {
      // It spans nothing, so it cannot be tapped — which is what stops a tap
      // opening a list that was always going to be empty.
      for (var i = 0; i < 360; i++) {
        expect(
          hit(i / 360, covered: 5, soon: 0, lapsed: 2),
          isNot(RingWedge.soon),
          reason: 'at $i degrees',
        );
      }
    });

    test('the proportions are the painter\'s, not equal thirds', () {
      // Nine in date, one lapsed: green owns nine tenths of the turn.
      expect(hit(0.85, covered: 9, soon: 0, lapsed: 1), RingWedge.covered);
      expect(hit(0.95, covered: 9, soon: 0, lapsed: 1), RingWedge.lapsed);
    });
  });

  group('what it refuses', () {
    test('the middle, where the number lives', () {
      // The biggest thing on the dashboard sits here and must not navigate.
      expect(
        wedgeAt(dx: 0, dy: 0, radius: 85, covered: 1, soon: 1, lapsed: 1),
        isNull,
      );
    });

    test('outside the ring altogether', () {
      expect(hit(0.25, radius: 140), isNull);
    });

    test('just inside and just outside the band', () {
      for (final radius in [85 - ringTouchBand + 1, 85 + ringTouchBand - 1]) {
        expect(hit(0.25, radius: radius), isNotNull, reason: '$radius');
      }
      for (final radius in [85 - ringTouchBand - 1, 85 + ringTouchBand + 1]) {
        expect(hit(0.25, radius: radius), isNull, reason: '$radius');
      }
    });

    test('an empty ring answers nothing anywhere', () {
      // Nothing is drawn, so there is nothing to have tapped — and every
      // destination behind it would be an empty list.
      for (var i = 0; i < 360; i++) {
        expect(hit(i / 360, covered: 0, soon: 0, lapsed: 0), isNull);
      }
    });
  });
}
