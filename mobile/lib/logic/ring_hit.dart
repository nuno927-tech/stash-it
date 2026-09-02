/// Which part of the dashboard ring a finger landed on.
///
/// ── Why this is not in the painter ─────────────────────────────────────────
/// The ring is a `CustomPaint`, so there is nothing to hit-test against: no
/// child widgets, no boxes, just three arcs drawn on a canvas. Working out
/// which arc was tapped means running the painter's own arithmetic backwards,
/// and that arithmetic is the sort that is wrong by a quarter turn until
/// somebody checks it — the canvas measures angles from three o'clock and the
/// ring is drawn from twelve.
///
/// So it lives here, in pure Dart, with a test that walks the whole circle.
/// A hit test that disagrees with the paint by one wedge is not a wrong pixel;
/// it is a tap on "lapsed" that opens the list of things that are fine.
///
/// ── The gap is deliberately ignored ────────────────────────────────────────
/// The painter shortens every sweep by five pixels so the round caps have room
/// — see `RingPainter`. Those gaps are not dead zones: a finger landing in one
/// is claimed by whichever wedge the angle nominally belongs to, because a
/// five-pixel hole that swallows taps is indistinguishable from a bug.
library;

import 'dart:math' as math;

/// The three arcs, in the order they are drawn.
enum RingWedge { covered, soon, lapsed }

/// How far either side of the ring's line still counts as touching it.
///
/// The line itself is six pixels. Six pixels is not a touch target, so the
/// band is widened to something a thumb can find — but not so far that it
/// swallows the number in the middle, which is the largest thing on the screen
/// and must stay untappable. Eighteen puts the near edge well outside "100%"
/// at full width.
const double ringTouchBand = 18;

/// Which wedge the point falls in, or null when the touch missed the band, or
/// when there is nothing drawn to hit.
///
/// [dx] and [dy] are measured from the centre of the ring, y pointing down —
/// which is Flutter's own convention, so a caller subtracts the centre from a
/// local position and passes it straight in.
RingWedge? wedgeAt({
  required double dx,
  required double dy,
  required double radius,
  required double covered,
  required double soon,
  required double lapsed,
  double band = ringTouchBand,
}) {
  final total = covered + soon + lapsed;
  if (total <= 0) return null;

  final distance = math.sqrt(dx * dx + dy * dy);
  if ((distance - radius).abs() > band) return null;

  /*
    From twelve o'clock, clockwise, as a fraction of the whole turn.

    `atan2` measures from three o'clock and increases towards positive y, which
    on a canvas is downwards — so it already runs clockwise and only the start
    has to move. That is the quarter turn this function exists to get right
    once: the painter starts every sweep at `-pi / 2` and so does this.
  */
  final turn = 2 * math.pi;
  final from = math.atan2(dy, dx) + math.pi / 2;
  final fraction = ((from % turn) + turn) % turn / turn;

  var walked = 0.0;
  for (final wedge in [
    (RingWedge.covered, covered),
    (RingWedge.soon, soon),
    (RingWedge.lapsed, lapsed),
  ]) {
    // A wedge counting nothing spans nothing, so this can never return one.
    final share = wedge.$2 / total;
    if (fraction < walked + share) return wedge.$1;
    walked += share;
  }

  // Only reachable when rounding leaves the fraction a hair past the end.
  return RingWedge.lapsed;
}
