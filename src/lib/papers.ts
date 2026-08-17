import type { Paper, PaperKind } from '@/db/types';
import { PAPER_KINDS } from '@/db/types';
import { addDays, parseAnchor, startOfDay } from '@/lib/subscriptions';

/**
 * When a document stops being useful, which is not when it expires.
 *
 * ── The whole argument for this file ──────────────────────────────────────
 * A warranty's useful date is its expiry: the day before, you can claim; the
 * day after, you can't. A passport is not like that, and neither is most
 * paperwork worth tracking.
 *
 * Two things sit in front of the printed date. Renewals take time — weeks for
 * a passport, longer at peak. And a great many countries refuse entry unless
 * the passport has three to six months left to run, so a passport "valid until
 * March" stops being usable for travel somewhere around the previous summer.
 *
 * An app that counts down to March is saying something true and useless. The
 * date worth showing is the RENEW-BY: expiry minus however much runway this
 * particular document needs. Everything here is built around that one idea.
 *
 * ── Why the lead time is a field and not a rule ───────────────────────────
 * Because the right number depends on the document, the country that issued
 * it, and where you're going — and none of those are things this app knows. A
 * confident wrong lead time is worse than a prompt. So: a sensible default per
 * kind, editable on every record, and the form says what the default is for.
 */

/** Local midnight today, reused so every comparison is about days. */
const today = (now: Date) => startOfDay(now);

export const KIND_LABEL: Record<PaperKind, string> = {
  passport: 'Passport',
  id: 'ID card',
  licence: 'Driving licence',
  visa: 'Visa or permit',
  vehicle: 'Vehicle',
  insurance: 'Insurance',
  certification: 'Certification',
  membership: 'Membership',
  other: 'Other',
};

/**
 * How much runway each kind needs, in days.
 *
 * PASSPORT IS 240 and it looks wrong until you add it up: six months of
 * validity that destination countries commonly demand, plus roughly two months
 * to actually get the new one. Eight months of warning on a ten-year document
 * is proportionate, and it is the number that stops somebody booking a holiday
 * they can't take.
 *
 * The rest are shorter because nothing else has the validity rule on top —
 * they're renewal time and a margin, nothing more.
 */
export const DEFAULT_LEAD_DAYS: Record<PaperKind, number> = {
  passport: 240,
  id: 90,
  licence: 60,
  visa: 120,
  vehicle: 30,
  insurance: 30,
  certification: 90,
  membership: 30,
  other: 30,
};

/** What the default is there for, said in the form rather than assumed. */
export const LEAD_REASON: Record<PaperKind, string> = {
  passport: 'Many countries want six months left on it, and renewals take weeks.',
  id: 'Long enough to book an appointment and wait for the card.',
  licence: 'Renewal is quick, but driving on a lapsed one is not a small thing.',
  visa: 'Applications are slow and often need the passport posted off.',
  vehicle: 'Enough to book the test and fix whatever it fails on.',
  insurance: 'Time to shop around before it auto-renews at a worse price.',
  certification: 'Courses and assessments need booking well ahead.',
  membership: 'Enough notice to decide whether you still want it.',
  other: 'A month, unless you know better.',
};

export const KINDS = PAPER_KINDS;

export function leadDaysFor(paper: Pick<Paper, 'kind' | 'leadDays'>): number {
  // Zero is a real answer — "tell me on the day" — so only undefined falls
  // back to the default. `||` would silently overwrite it.
  return paper.leadDays ?? DEFAULT_LEAD_DAYS[paper.kind];
}

/** The printed date, or null if it can't be read. */
export function expiryOf(paper: Pick<Paper, 'expiresOn'>): Date | null {
  return parseAnchor(paper.expiresOn);
}

/**
 * The date this actually needs dealing with: expiry minus its lead time.
 *
 * This is the date the app counts down to, and the one the list sorts by.
 */
export function renewBy(paper: Pick<Paper, 'kind' | 'leadDays' | 'expiresOn'>): Date | null {
  const end = expiryOf(paper);
  return end ? addDays(end, -leadDaysFor(paper)) : null;
}

/** Days until the printed date. Negative once it has passed. */
export function daysUntilExpiry(
  paper: Pick<Paper, 'expiresOn'>,
  now = new Date(),
): number | null {
  const end = expiryOf(paper);
  if (!end) return null;
  return Math.round((end.getTime() - today(now).getTime()) / 86_400_000);
}

/** Days until it needs starting. Negative means it needed starting already. */
export function daysUntilRenewBy(
  paper: Pick<Paper, 'kind' | 'leadDays' | 'expiresOn'>,
  now = new Date(),
): number | null {
  const at = renewBy(paper);
  if (!at) return null;
  return Math.round((at.getTime() - today(now).getTime()) / 86_400_000);
}

/**
 * Three states, and the middle one is the point.
 *
 * `expired` — the printed date has passed. The document is not valid.
 * `renew`   — still valid, but inside its lead time. This is the state the
 *             feature exists to surface, and the only one you can act on
 *             usefully: there is still time, and there won't be for long.
 * `valid`   — nothing to do.
 */
export type PaperState = 'valid' | 'renew' | 'expired';

export function paperState(paper: Paper, now = new Date()): PaperState {
  const left = daysUntilExpiry(paper, now);
  // An unreadable date is not an expired document. Saying "expired" about a
  // record whose date failed to parse would be inventing bad news.
  if (left === null) return 'valid';
  if (left < 0) return 'expired';
  return (daysUntilRenewBy(paper, now) ?? 1) <= 0 ? 'renew' : 'valid';
}

/**
 * The line under the name, phrased so the verb carries the state — the same
 * approach as warrantyDateLabel, and for the same reason: this text sits at
 * 12px in a list and has to work before any colour is read.
 *
 * The renew case names the printed date rather than the renew-by, because
 * "renew now" plus "expires in June" is the pair of facts that makes sense of
 * each other. Saying "renew by 12 September" when it is already past the 12th
 * would be the app scolding you with a date in the past.
 */
export function paperLabel(paper: Paper, now = new Date()): string {
  const end = expiryOf(paper);
  if (!end) return 'No expiry date';

  const state = paperState(paper, now);
  if (state === 'expired') return `Expired ${monthYear(end)}`;
  if (state === 'renew') return `Renew now — expires ${dayMonth(end)}`;

  const start = renewBy(paper)!;
  // Inside a month of needing to start, the month alone is too coarse.
  const soon = (daysUntilRenewBy(paper, now) ?? 999) <= 31;
  return `Start ${soon ? dayMonth(start) : monthYear(start)}`;
}

/** "Valid to Mar 2029" — the printed fact, for the detail line. */
export function expiryLabel(paper: Paper): string {
  const end = expiryOf(paper);
  return end ? `Valid to ${monthYear(end)}` : 'No expiry date';
}

function monthYear(d: Date): string {
  return d.toLocaleDateString(undefined, { month: 'short', year: 'numeric' });
}

function dayMonth(d: Date): string {
  return d.toLocaleDateString(undefined, { day: 'numeric', month: 'short' });
}

/**
 * Soonest to need doing first, by renew-by rather than by expiry.
 *
 * Those two orders genuinely differ: a passport expiring in nine months needs
 * starting before a driving licence expiring in four, because one needs eight
 * months of runway and the other needs two. Sorting by the printed date would
 * put them the wrong way round, which is the exact mistake this file exists to
 * prevent.
 */
export function sortPapers(papers: Paper[], now = new Date()): Paper[] {
  return [...papers].sort((a, b) => {
    const da = daysUntilRenewBy(a, now);
    const db = daysUntilRenewBy(b, now);
    if (da === null && db === null) return a.label.localeCompare(b.label);
    if (da === null) return 1;
    if (db === null) return -1;
    if (da !== db) return da - db;
    return a.label.localeCompare(b.label);
  });
}

/** Everything past its renew-by date, worst first. Expired counts. */
export function needsRenewing(papers: Paper[], now = new Date()): Paper[] {
  return sortPapers(
    papers.filter((p) => paperState(p, now) !== 'valid'),
    now,
  );
}

/** The next one that will need starting, ignoring those already overdue. */
export function nextUp(papers: Paper[], now = new Date()): Paper | null {
  return sortPapers(papers, now).find((p) => paperState(p, now) === 'valid') ?? null;
}

/**
 * Whether this wants mentioning on the dashboard now.
 *
 * Measured against the renew-by date, not the expiry — a reminder three days
 * before a passport expires is a reminder three days before a holiday is
 * cancelled. Same honesty caveat as subscriptions: there is no push, so the
 * next time the app is opened is the only moment it can say anything.
 */
export const REMIND_CHOICES = [0, 1, 3, 7] as const;

export function reminderDue(paper: Paper, now = new Date()): boolean {
  if (!paper.remindDays) return false;
  const left = daysUntilRenewBy(paper, now);
  if (left === null) return false;
  return left >= 0 && left <= paper.remindDays;
}

/** Papers with a holder, grouped for a household list. Empty when nobody
    filled the field in, which is the common case and should cost nothing. */
export function holders(papers: Paper[]): string[] {
  const seen = new Set<string>();
  for (const p of papers) {
    const who = p.holder?.trim();
    if (who) seen.add(who);
  }
  return [...seen].sort((a, b) => a.localeCompare(b));
}
