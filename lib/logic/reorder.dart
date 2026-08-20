/// The arithmetic behind drag-to-reorder, kept out of the widget so it can be
/// run in a test rather than judged by feel.
///
/// Translated from `src/lib/reorder.ts`.
///
/// ── The bug this file was written to fix ──────────────────────────────────
/// The row being dragged is drawn offset so it follows your finger, so its
/// bounding box moves with it. The old hit test searched every row for the one
/// under the pointer and took the first match — which, while dragging
/// downwards, was **the held row itself**, because the held row is always under
/// the pointer by construction. It then compared that to the row it started
/// from, found them equal, and did nothing.
///
/// So dragging down never reordered anything, and dragging up worked only when
/// the row above happened to come first in the list. The fix is one line — skip
/// the row you are holding — and the reason it lives here rather than inline is
/// that it is exactly the kind of off-by-one that reads as correct in a diff.
///
/// Flutter has `ReorderableListView`, which does its own hit testing. This is
/// still ported: the app's list is not a plain list of rows — it is grouped by
/// room with headers between — and the moment a custom gesture is involved,
/// this is the arithmetic it needs. If the stock widget turns out to fit, this
/// file goes, and the tests go with it.
library;

/// A row's vertical extent, in whatever coordinate space the caller measured.
class Span {
  const Span(this.top, this.bottom);
  final double top;
  final double bottom;
}

/// Which row the pointer is over, **ignoring the one in your hand**.
///
/// Returns null when the pointer is between rows or outside the list, which the
/// caller treats as "no change yet" rather than as an error.
///
/// A null entry is a row that has not been measured yet, and is skipped rather
/// than treated as a zero-height row at the origin.
int? dropTarget(List<Span?> rows, double y, int held) {
  for (var i = 0; i < rows.length; i++) {
    if (i == held) continue;
    final r = rows[i];
    if (r == null) continue;
    if (y >= r.top && y <= r.bottom) return i;
  }
  return null;
}

/// Moves one entry, closing the gap behind it. Out-of-range moves are no-ops.
///
/// Returns the **same list instance** when nothing moves, so a caller can use
/// identity to decide whether to rebuild. The original is never mutated.
List<T> moveWithin<T>(List<T> list, int from, int to) {
  if (from == to) return list;
  if (from < 0 || from >= list.length) return list;
  if (to < 0 || to >= list.length) return list;

  final next = [...list];
  final held = next.removeAt(from);
  next.insert(to, held);
  return next;
}
