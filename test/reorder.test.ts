/**
 * Drag-to-reorder arithmetic.
 *
 *   npm run test:reorder
 *
 * Written after the fact, for a bug that shipped: dragging a room downwards
 * did nothing at all. The row you hold is drawn with a transform so it follows
 * your finger, which means its bounding box is always under the pointer — and
 * the hit test took the first row it found, which was that one. It compared
 * the result to where the drag started, saw no change, and returned.
 *
 * Upwards it happened to work, because the row above comes first in the array
 * and matched before the held row did. Exactly the kind of asymmetry nobody
 * spots by dragging something once and seeing it move.
 */

import { dropTarget, moveWithin, type Span } from '@/lib/reorder';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

/** Five rows, 50px tall, stacked from y=0. */
const ROWS: Span[] = [0, 1, 2, 3, 4].map((i) => ({ top: i * 50, bottom: i * 50 + 50 }));

/** The same, but row `held` has been dragged to sit over `y`. */
function dragging(held: number, y: number): Span[] {
  return ROWS.map((r, i) => (i === held ? { top: y - 25, bottom: y + 25 } : r));
}

function main() {
  /* ------------------------------------------------------------ the bug */

  // Holding row 1 and pulling down to the middle of row 2. The held row's box
  // has come with it and also covers the pointer.
  const down = dragging(1, 120);
  check('dragging down finds the row underneath', dropTarget(down, 120, 1) === 2, String(dropTarget(down, 120, 1)));
  check(
    'and not the row in your hand',
    dropTarget(down, 120, 1) !== 1,
    'the held row is under the pointer by construction',
  );

  // The old behaviour, for the record: without skipping the held row the
  // answer was the held row itself, which the caller read as "no change".
  const naive = down.findIndex((r) => 120 >= r.top && 120 <= r.bottom);
  check('the naive version returned the held row', naive === 1, `${naive}`);

  /* ------------------------------------------------------ the other way */

  const up = dragging(3, 80);
  check('dragging up finds the row above', dropTarget(up, 80, 3) === 1, String(dropTarget(up, 80, 3)));

  /* ------------------------------------------------------------- edges */

  check('a pointer past the end targets nothing', dropTarget(ROWS, 9999, 0) === null);
  check('a pointer above the list targets nothing', dropTarget(ROWS, -40, 4) === null);
  check('a gap between rows targets nothing', dropTarget([{ top: 0, bottom: 10 }, null], 40, 0) === null);
  check('an unmeasured row is skipped', dropTarget([null, { top: 0, bottom: 50 }], 25, 5) === 1);
  check('an empty list targets nothing', dropTarget([], 10, 0) === null);

  // Holding the first row and hovering it alone: nothing else to land on.
  check('the only row cannot be dropped on itself', dropTarget([ROWS[0]!], 25, 0) === null);

  /* ---------------------------------------------------------- the move */

  const list = ['a', 'b', 'c', 'd'];
  check('moving down', moveWithin(list, 0, 2).join('') === 'bcad', moveWithin(list, 0, 2).join(''));
  check('moving up', moveWithin(list, 3, 1).join('') === 'adbc', moveWithin(list, 3, 1).join(''));
  check('moving to the end', moveWithin(list, 0, 3).join('') === 'bcda');
  check('a move to the same place is the same list', moveWithin(list, 2, 2) === list);
  check('an out-of-range source is ignored', moveWithin(list, 9, 1) === list);
  check('an out-of-range target is ignored', moveWithin(list, 0, 9) === list);
  check('the original is not mutated', list.join('') === 'abcd');

  /* --------------------------------------------- a whole drag, in steps */

  // Pick up "a" and walk it to the bottom, one row at a time, the way the
  // component does: re-index after each swap, since the held row has moved.
  let order = ['a', 'b', 'c', 'd', 'e'];
  let from = 0;
  for (const target of [1, 2, 3, 4]) {
    const spans = dragging(from, target * 50 + 25);
    const at = dropTarget(spans, target * 50 + 25, from);
    check(`step to row ${target}`, at === target, String(at));
    order = moveWithin(order, from, at!);
    from = at!;
  }
  check('it ends up last', order.join('') === 'bcdea', order.join(''));

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
