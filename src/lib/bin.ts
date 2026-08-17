import { canAddItem, PURGE_AFTER_DAYS } from '@/db/repo';
import type { Entitlements, Item } from '@/db/types';
import { FREE_ITEM_LIMIT } from '@/db/types';

/**
 * The bin: how long a deleted item has left, and whether it can come back.
 *
 * This exists because the delete dialog made a promise — "it goes to the bin
 * for 30 days, so you can change your mind" — that nothing in the app kept.
 * `restoreItem` had been sitting in the repo since the beginning, called from
 * nowhere. Items were being soft-deleted, counted down, and purged, and the
 * only observable part of that was that they vanished. A recovery window
 * nobody can reach is a thirty-day delay, not a safety net.
 *
 * The arithmetic is here rather than in the screen because both halves of it
 * are easy to get wrong by one: whether the day you delete something counts,
 * and whether "0 days left" means today or means gone.
 */

const DAY = 86_400_000;

/**
 * Whole days until this item is erased.
 *
 * Counted from the moment of deletion, not from midnight — the purge runs on
 * elapsed time, so anything else would print a number the sweep disagrees
 * with. Never negative: an item past its date is about to go on the next
 * launch, and "-2 days left" is not a thing to tell somebody.
 */
export function daysLeft(deletedAt: string, now = new Date(), retain = PURGE_AFTER_DAYS): number {
  const at = new Date(deletedAt).getTime();
  // An unparseable date shouldn't quietly read as "expires today" and hurry
  // something towards deletion. Treat it as freshly deleted.
  if (Number.isNaN(at)) return retain;
  const gone = at + retain * DAY;
  return Math.max(0, Math.ceil((gone - now.getTime()) / DAY));
}

/** The countdown as it's written on the row. */
export function daysLeftLabel(days: number): string {
  if (days <= 0) return 'Goes today';
  if (days === 1) return 'Last day';
  return `${days} days left`;
}

/**
 * Whether a deleted item can come back.
 *
 * Restoring is subject to the cap, and it has to be. Deleting frees a slot
 * immediately — that's deliberate, so someone at the limit can make room — but
 * it means an unchecked restore would be a hole you could drive fifteen items
 * through: fill up, delete the lot, fill up again, restore the lot. Thirty
 * items on a fifteen-item tier, by pressing undo.
 *
 * Nothing is lost either way. The item stays in the bin, and its own countdown
 * is the only thing that can remove it.
 */
export function canRestore(activeCount: number, e: Entitlements): boolean {
  return canAddItem(activeCount, e);
}

export function restoreBlockedReason(activeCount: number): string {
  return `You're at ${activeCount} of ${FREE_ITEM_LIMIT} saved things. Remove something, or subscribe, and this comes straight back — it stays here either way.`;
}

/** "3 items" / "1 item", for the entry row and the heading. */
export function binCount(n: number): string {
  return `${n} ${n === 1 ? 'item' : 'items'}`;
}

/**
 * The bin's own summary line: how many, and how long the most urgent one has.
 * Stating the soonest rather than an average — the only deadline that matters
 * is the next one.
 */
export function binSummary(items: Item[], now = new Date()): string {
  if (items.length === 0) return 'Nothing here';
  const soonest = Math.min(...items.map((i) => daysLeft(i.deletedAt ?? '', now)));
  return `${binCount(items.length)} · ${daysLeftLabel(soonest).toLowerCase()}`;
}
