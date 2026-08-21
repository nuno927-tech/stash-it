/// Swiping: between tabs, a row aside, a card away.
///
/// Translated from `src/lib/swipe.ts`.
///
/// The decision of "was that a swipe" is here, pure, because it is entirely
/// made of thresholds and every one of them is a judgement that shows up as a
/// feel. Too eager and the list will not scroll without changing tabs; too
/// strict and the gesture feels broken. Numbers you can argue about in a test
/// are better than numbers buried in an event handler.
///
/// ── Two functions from the web version are not here ───────────────────────
/// `ownsItsSwipe` and `inHorizontalScroller` walked up the DOM asking whether
/// some ancestor had claimed the gesture or scrolled sideways itself. They
/// existed because a browser delivers one touch event to everything at once
/// and something has to arbitrate.
///
/// **Flutter arbitrates for you.** The gesture arena resolves competing
/// recognisers by which one wins the drag, so a horizontally scrolling list
/// inside a page view takes its own swipes without either of them being told
/// about the other. Two tree walks and an HTML data attribute go with them.
library;

/// Every tab, in bar order.
///
/// Subscriptions was once added to the bar and not to this list, so swiping
/// left from Items landed on Settings — it skipped the tab sitting between
/// them and there was nothing on screen to explain why. An enum makes that
/// particular mistake a compile error rather than a feel.
enum Tab { home, items, subs, papers, settings }

enum Direction { left, right }

/// The tab a swipe lands on, or null at the ends.
///
/// No wrapping. Settings → swipe left → Home would put you at the other end of
/// the app from a gesture that means "next", and the bottom bar is right there
/// showing you there is no next.
Tab? nextTab(Tab current, Direction direction) {
  final to = current.index + (direction == Direction.left ? 1 : -1);
  if (to < 0 || to >= Tab.values.length) return null;
  return Tab.values[to];
}

class Gesture {
  const Gesture({
    required this.dx,
    required this.dy,
    required this.elapsed,
    required this.width,
  });

  final double dx;
  final double dy;

  /// From first contact to release.
  final Duration elapsed;

  /// Viewport width, so the threshold scales with the device.
  final double width;
}

/// Distance, or speed. A deliberate drag has to cross a fifth of the screen —
/// far enough that it cannot be a stray thumb while reading. A flick does not:
/// it is short and fast on purpose, and demanding the same distance from it is
/// what makes a gesture feel heavy.
const double minFraction = 0.16;
const double minPixels = 48;
const Duration flickTime = Duration(milliseconds: 350);
const double flickPixels = 36;

/// Horizontal has to beat vertical. At 1.3 a diagonal scroll while skimming a
/// list still does not change tabs — the accident worth preventing — but a real
/// swipe made with the thumb's natural arc does.
const double dominance = 1.3;

Direction? swipeVerdict(Gesture g) {
  final ax = g.dx.abs();
  final ay = g.dy.abs();

  if (ax < flickPixels) return null;
  if (ax < ay * dominance) return null;

  final threshold = g.width * minFraction;
  final far = ax >= (threshold > minPixels ? threshold : minPixels);
  final fast = g.elapsed <= flickTime && ax >= flickPixels;
  if (!far && !fast) return null;

  // Content follows the finger, so dragging left reveals what is to the right.
  return g.dx < 0 ? Direction.left : Direction.right;
}

/// Which way "back" is.
///
/// Content follows the finger, so dragging right reveals what is to the left of
/// the screen — which is where you came from. Named rather than written as a
/// literal in the shell because it has to agree with the sign convention in
/// `swipeVerdict`, and those two live in different files.
const Direction backDirection = Direction.right;

/* -------------------------------------------------- swiping a row aside */

/// How far a list row slides to show the delete button behind it.
///
/// Half the row, roughly — far enough that the button is a comfortable target
/// and that the row plainly has not gone anywhere. A row that slid clean off
/// would be a delete, and this is not a delete: it is the offer of one.
const double rowReveal = 96;

/// Past this, letting go opens the row rather than springing it shut.
///
/// Deliberately less than half of `rowReveal`. Opening costs nothing — the row
/// comes back on the next tap anywhere — so the gesture should succeed on a
/// hesitant drag rather than demand a confident one.
const double rowOpenAt = 34;

/// Only leftwards, and only when it is clearly not a scroll.
///
/// Strictly past the threshold, not at it — "past this" in the constant's own
/// description, and a boundary that reads one way in prose and another in code
/// is a boundary somebody will get wrong later.
bool rowOpens(double dx, double dy) {
  if (dx >= -rowOpenAt) return false;
  return dx.abs() >= dy.abs() * dominance;
}

/// Where the row sits mid-drag: never right of home, never past the button.
///
/// Written out rather than with `clamp`, because `num.clamp` only promises to
/// return a `double` when every argument is one, and a silent widening to
/// `num` here would be caught by the compiler in one place and not the next.
double rowOffset(double dx, bool open) {
  final at = (open ? -rowReveal : 0.0) + dx;
  if (at < -rowReveal) return -rowReveal;
  if (at > 0.0) return 0.0;
  return at;
}

/* --------------------------------------------------- throwing a card away */

/// A drag that means "get this out of my way".
///
/// Either direction. The card it dismisses is centred rather than anchored to
/// an edge, so there is no correct way to throw it — insisting on downwards
/// would only teach people the gesture does not work.
///
/// Looser than the tab swipe on purpose. Changing tabs by accident loses your
/// place; closing a reminder by accident costs nothing, and the reminder is
/// shown after every single save. When the failure is that asymmetric, the
/// threshold should be too.
///
/// **"Looser" means under `minPixels`**, not merely under the tab swipe's
/// effective threshold on a phone. That one scales with the screen and the
/// floor does not, so only beating the floor makes the claim true on every
/// device rather than on the handset it happened to be tuned against. A test
/// holds it to that.
const double dismissPixels = 44;
const double dismissFlickPixels = 24;

class Drag {
  const Drag({required this.dy, required this.elapsed});
  final double dy;

  /// From first contact to release.
  final Duration elapsed;
}

bool dismissedByDrag(Drag d) {
  final ay = d.dy.abs();
  if (ay >= dismissPixels) return true;
  return d.elapsed <= flickTime && ay >= dismissFlickPixels;
}

/// The system back gesture owns the screen edges on Android, and a swipe that
/// starts there is already spoken for. Ours must not also fire, or one gesture
/// does two things.
const double edgeGuard = 26;

bool startedAtEdge(double x, double width) =>
    x <= edgeGuard || x >= width - edgeGuard;
