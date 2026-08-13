/**
 * The arithmetic behind drag-to-reorder, kept out of the component so it can
 * be run in Node rather than judged by feel.
 *
 * ── The bug this file was written to fix ──────────────────────────────────
 * The row being dragged is drawn with `transform: translateY(...)` so it
 * follows your finger. Its bounding box moves with it. The old hit test
 * searched every row for the one under the pointer and took the first match —
 * which, while dragging downwards, was the held row itself, because the held
 * row is always under the pointer by construction. It then compared that to
 * the row it started from, found them equal, and did nothing.
 *
 * So dragging down never reordered anything, and dragging up worked only when
 * the row above happened to come first in the array. The fix is one line — skip
 * the row you're holding — and the reason it's here rather than inline is that
 * it's exactly the kind of off-by-one that reads as correct in a diff.
 */

export interface Span {
  top: number;
  bottom: number;
}

/**
 * Which row the pointer is over, ignoring the one in your hand.
 *
 * Returns null when the pointer is between rows or outside the list, which the
 * caller treats as "no change yet" rather than as an error.
 */
export function dropTarget(rows: (Span | null)[], y: number, held: number): number | null {
  for (let i = 0; i < rows.length; i++) {
    if (i === held) continue;
    const r = rows[i];
    if (!r) continue;
    if (y >= r.top && y <= r.bottom) return i;
  }
  return null;
}

/** Moves one entry, closing the gap behind it. Out-of-range moves are no-ops. */
export function moveWithin<T>(list: T[], from: number, to: number): T[] {
  if (from === to) return list;
  if (from < 0 || from >= list.length) return list;
  if (to < 0 || to >= list.length) return list;

  const next = [...list];
  const [held] = next.splice(from, 1);
  if (held === undefined) return list;
  next.splice(to, 0, held);
  return next;
}
