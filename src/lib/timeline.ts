import type { Item, Paper, Subscription } from '@/db/types';
import {
  daysUntilExpiry,
  daysUntilRenewBy,
  expiryOf,
  paperState,
  renewBy,
} from '@/lib/papers';
import { daysUntilRenewal, nextRenewal, reminderDue } from '@/lib/subscriptions';
import { effectiveExpiry, warrantyState } from '@/lib/warranty';

/**
 * One list of everything with a date on it, across all three kinds of record.
 *
 * ── Why this exists ───────────────────────────────────────────────────────
 * The dashboard used to carry three separate "next up" rows — the soonest
 * warranty, the soonest renewal, the soonest document — each sorted only
 * against its own kind and each in its own visual language. So a passport that
 * needed starting last week sat below an MOT that expires in a month, purely
 * because they were in different sections. Nobody thinks in sections. The
 * question is "what should I deal with", and only a merged list can answer it.
 *
 * ── Ranked by consequence, not by date ────────────────────────────────────
 * A strictly chronological list gets this wrong in a specific and expensive
 * way: Netflix charging £15 on Friday comes above a passport that already
 * needed starting, because Friday is sooner than "should have begun in June".
 * One of those is a direct debit and the other is a cancelled holiday.
 *
 * So there are buckets, and dates only sort within them:
 *
 *   overdue  the date has passed and it still matters
 *   now      it is inside the window where acting is the whole point
 *   soon     within a week
 *   later    everything else on the horizon
 *
 * ── What is deliberately not in here ──────────────────────────────────────
 * LAPSED WARRANTIES. An expired warranty is not a thing you can act on — the
 * cover is gone, and the item is still yours. Putting every lapsed item at the
 * top of the list would bury the things that are still saveable under a pile
 * of things that aren't. The Items tab has a Lapsed filter for looking at them
 * on purpose.
 *
 * A lapsed PASSPORT is a different matter and does appear, because an expired
 * document is a problem you still have to solve.
 */

export type TimelineKind = 'item' | 'subscription' | 'paper';

/** Ordering buckets. The numbers are the sort key; the names are the meaning. */
export const URGENCY_RANK = { overdue: 0, now: 1, soon: 2, later: 3 } as const;
export type Urgency = keyof typeof URGENCY_RANK;

export interface Entry {
  /** Unique across kinds — two records can share an id in different tables. */
  key: string;
  kind: TimelineKind;
  id: string;
  title: string;
  /** The second line: what is happening and when. */
  detail: string;
  urgency: Urgency;
  /** Days until the date this is about. Negative once it has passed. */
  days: number;
  /**
   * Whether to draw attention to the row.
   *
   * True for anything overdue or inside its window — the things the screen is
   * for. Everything else is a list you are reading, not a thing shouting.
   */
  flagged: boolean;
}

/**
 * How far ahead the list looks, per kind.
 *
 * Subscriptions get a month, which on a list of nine monthly services is
 * roughly all of them — that is fine, because the list shows the nearest few
 * and the rest are behind "show more". Items use the app's own "ending soon"
 * definition rather than a second threshold invented here, so the dashboard
 * and the warranty colour always agree about what counts as soon.
 */
const SUB_HORIZON = 30;
const PAPER_HORIZON = 30;

export function buildTimeline(
  items: Item[],
  subs: Subscription[],
  papers: Paper[],
  now = new Date(),
): Entry[] {
  const out: Entry[] = [];

  /* ------------------------------------------------------------ warranties */

  for (const item of items) {
    // Only cover that is running out. See the note above on lapsed items.
    if (warrantyState(item, now) !== 'ending-soon') continue;
    const end = effectiveExpiry(item, now);
    if (!end) continue;

    const days = dayGap(now, end);
    out.push({
      key: `item:${item.id}`,
      kind: 'item',
      id: item.id,
      title: item.name,
      detail: `Warranty ends ${dayMonth(end)}`,
      urgency: days <= 7 ? 'soon' : 'later',
      days,
      flagged: false,
    });
  }

  /* --------------------------------------------------------- subscriptions */

  for (const sub of subs) {
    const at = nextRenewal(sub, now);
    const days = daysUntilRenewal(sub, now);
    if (!at || days === null || days > SUB_HORIZON) continue;

    /*
      A reminder is what promotes a renewal out of the ordinary run of them.
      Without it every monthly service would sit in the same bucket and the one
      you asked to be told about would be indistinguishable from the eight you
      didn't. This is now the only thing `remindDays` does, and it does more
      than the banner it replaced: it changes where the row sorts, rather than
      adding a second card saying the same thing further up the page.
    */
    const flagged = reminderDue(sub, now);
    out.push({
      key: `sub:${sub.id}`,
      kind: 'subscription',
      id: sub.id,
      title: sub.name,
      detail: `Renews ${dayMonth(at)}`,
      urgency: flagged ? 'now' : days <= 7 ? 'soon' : 'later',
      days,
      flagged,
    });
  }

  /* -------------------------------------------------------------- documents */

  for (const paper of papers) {
    const state = paperState(paper, now);
    const end = expiryOf(paper);
    if (!end) continue;

    if (state === 'expired') {
      out.push({
        key: `paper:${paper.id}`,
        kind: 'paper',
        id: paper.id,
        title: named(paper),
        detail: `Expired ${dayMonth(end)}`,
        urgency: 'overdue',
        days: daysUntilExpiry(paper, now) ?? 0,
        flagged: true,
      });
      continue;
    }

    if (state === 'renew') {
      out.push({
        key: `paper:${paper.id}`,
        kind: 'paper',
        id: paper.id,
        title: named(paper),
        detail: `Start now · expires ${dayMonth(end)}`,
        urgency: 'now',
        days: daysUntilRenewBy(paper, now) ?? 0,
        flagged: true,
      });
      continue;
    }

    // Still fine, but the day to begin is close enough to mention.
    const start = renewBy(paper);
    const left = daysUntilRenewBy(paper, now);
    if (!start || left === null || left > PAPER_HORIZON) continue;
    out.push({
      key: `paper:${paper.id}`,
      kind: 'paper',
      id: paper.id,
      title: named(paper),
      detail: `Start ${dayMonth(start)}`,
      urgency: left <= 7 ? 'soon' : 'later',
      days: left,
      flagged: false,
    });
  }

  return sortTimeline(out);
}

/**
 * Bucket first, then soonest, then alphabetically.
 *
 * The last one only decides ties, but it has to be there: without it two
 * renewals on the same day swap places between renders, and a list that
 * reorders itself while you look at it reads as broken.
 */
export function sortTimeline(entries: Entry[]): Entry[] {
  return [...entries].sort(
    (a, b) =>
      URGENCY_RANK[a.urgency] - URGENCY_RANK[b.urgency] ||
      a.days - b.days ||
      a.title.localeCompare(b.title),
  );
}

/** How many need doing something about, for the count beside the heading. */
export function flaggedCount(entries: Entry[]): number {
  return entries.filter((e) => e.flagged).length;
}

/**
 * The right-hand column of a row.
 *
 * Days rather than a date — the date is already on the line to the left, and
 * this column exists to be compared down the page.
 *
 * THE 'NOW' CASE IS NOT A COUNTDOWN, and getting that wrong is easy. A
 * passport inside its lead time passed its renew-by months ago, so `days` is a
 * large negative number; printing it as "today" is a small lie and printing it
 * as "68 days late" is a bigger one, because the passport does not expire
 * until February and nothing is actually late. The window to act comfortably
 * is open, which is a state and not a duration.
 */
export function whenLabel(e: Pick<Entry, 'urgency' | 'days'>): string {
  if (e.urgency === 'overdue') return `${Math.abs(e.days)} days late`;
  if (e.urgency === 'now') return 'now';
  if (e.days <= 0) return 'today';
  if (e.days === 1) return 'tomorrow';
  return `${e.days} days`;
}

/** "Nuno's passport" reads better than "Passport" in a mixed list. */
function named(paper: Paper): string {
  const who = paper.holder?.trim();
  return who ? `${paper.label} — ${who}` : paper.label;
}

/**
 * Whole days between two local midnights.
 *
 * Rounded rather than floored, because a day is 23 or 25 hours twice a year
 * and the raw division lands just off a whole number — see addDays in
 * lib/subscriptions for the longer version of that story.
 */
function dayGap(now: Date, then: Date): number {
  const a = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const b = new Date(then.getFullYear(), then.getMonth(), then.getDate());
  return Math.round((b.getTime() - a.getTime()) / 86_400_000);
}

function dayMonth(d: Date): string {
  return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short' });
}

/* --------------------------------------------------------------- the ring */

export interface DatedTally {
  inDate: number;
  needsStarting: number;
  lapsed: number;
  /** Records with nothing to count from. Not drawn, and not in the divisor. */
  noDate: number;
  /** 0..100, whole. */
  percent: number;
  items: number;
  papers: number;
}

/**
 * What the ring counts.
 *
 * ── Subscriptions are not in here, and it took drawing them to see why ────
 * A subscription cannot lapse. It renews, and then it renews again. Counting
 * nine of them as nine healthy units would have inflated "still in date" with
 * things that were never at risk of anything — the number would go up when you
 * added a service and down when you cancelled one, which is exactly backwards.
 * The ring counts what can actually run out: warranties and documents.
 *
 * ── Undated records are excluded from both the ring and the percentage ────
 * An item with no warranty length recorded is not a failure, it is a blank.
 * Including it as a fourth arc would mean the picture and the number disagree
 * — the green wedge would look like 70% next to a headline reading 77% — and
 * putting it in the divisor would mean the score DROPS when you add a record,
 * which punishes the one behaviour the app wants.
 *
 * So it is counted, reported beside the ring, and left out of the maths. The
 * place to act on it is "Needs a minute", which already asks for exactly this.
 */
export function datedTally(items: Item[], papers: Paper[], now = new Date()): DatedTally {
  let inDate = 0;
  let needsStarting = 0;
  let lapsed = 0;
  let noDate = 0;

  for (const item of items) {
    switch (warrantyState(item, now)) {
      case 'covered':
        inDate++;
        break;
      case 'ending-soon':
        needsStarting++;
        break;
      case 'expired':
        lapsed++;
        break;
      default:
        noDate++;
    }
  }

  for (const paper of papers) {
    if (!expiryOf(paper)) {
      noDate++;
      continue;
    }
    switch (paperState(paper, now)) {
      case 'valid':
        inDate++;
        break;
      case 'renew':
        needsStarting++;
        break;
      default:
        lapsed++;
    }
  }

  const tracked = inDate + needsStarting + lapsed;
  return {
    inDate,
    needsStarting,
    lapsed,
    noDate,
    percent: tracked === 0 ? 0 : Math.round((inDate / tracked) * 100),
    items: items.length,
    papers: papers.length,
  };
}
