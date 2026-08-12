import type { Item } from '@/db/types';
import { warrantyParts, warrantyState, type WarrantyState } from '@/lib/warranty';

/**
 * How long is left, drawn the same way everywhere it appears.
 *
 * It used to be markup inside the item row, and the dashboard's "next to
 * expire" card wrote its own version from `warrantyLabel` — so the same item
 * read "5m" in a chip on one screen and "5 / months left" on the other, and
 * the number that mattered was the small one on the screen you land on first.
 * One component, one answer.
 */

const TONE: Record<WarrantyState, string> = {
  covered: 'ok',
  'ending-soon': 'warn',
  expired: 'dead',
  unknown: 'none',
};

export function TimeLeft({ item }: { item: Item }) {
  const left = warrantyParts(item);

  // "Ended", "Today" and "2y 4m" are words, not a two-digit number, and at
  // 27px they crowd the item name off the row. Decided here rather than left
  // to the stylesheet to guess from the content.
  const wordy = /^\d+$/.test(left.value) ? '' : ' wordy';

  return (
    <div className={`timeleft ${TONE[warrantyState(item)]}${wordy}`}>
      <strong>{left.value}</strong>
      <small>{left.unit}</small>
      {/* Which policy the number belongs to, on items that have several. A
          countdown that doesn't say what it's counting is worse than none. */}
      {left.which && <small className="whichcov">{left.which}</small>}
    </div>
  );
}
