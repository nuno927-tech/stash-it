import type { Coverage, Item, Warranty, WarrantyUnit } from '@/db/types';

export type WarrantyState = 'covered' | 'ending-soon' | 'expired' | 'unknown';

export const DEFAULT_COVERAGE_LABEL = 'Warranty';

export const ENDING_SOON_DAYS = 30;

/**
 * How close to the end counts as "ending soon", in days.
 *
 * A module-level value with a setter, rather than an argument threaded through
 * `warrantyState`, `coverageState`, the dashboard, both list screens and the
 * item page. Every one of those call sites would have to fetch the settings
 * record to pass it, and a fifteen-file signature change is how a preference
 * ends up read in four places out of five.
 *
 * Set once from the live settings record — see Shell in App.tsx — so the whole
 * app agrees on the answer at any instant. Tests set it and put it back.
 */
let endingSoon = ENDING_SOON_DAYS;

export function setEndingSoonDays(days: number): void {
  endingSoon = Math.max(1, Math.min(365, Math.round(days)));
}

export function getEndingSoonDays(): number {
  return endingSoon;
}

/** Parses YYYY-MM-DD as a local calendar date, not UTC midnight. */
export function parseDate(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function toISODate(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/**
 * Calendar-month arithmetic, not 30-day counts. A 24-month warranty bought on
 * 31 Jan ends 31 Jan. Clamps to the last day when the target month is shorter
 * (31 Mar + 1 month = 30 Apr).
 */
export function addMonths(date: Date, months: number): Date {
  const day = date.getDate();
  const out = new Date(date.getFullYear(), date.getMonth() + months, 1);
  const lastDay = new Date(out.getFullYear(), out.getMonth() + 1, 0).getDate();
  out.setDate(Math.min(day, lastDay));
  return out;
}

export function addDays(date: Date, days: number): Date {
  const out = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  out.setDate(out.getDate() + days);
  return out;
}

export interface WarrantyTerm {
  unit: WarrantyUnit;
  amount: number;
}

/**
 * The term as the user expressed it. Records written before units existed only
 * have `months`, and read back as months — which is what they meant.
 */
export function termOf(w: Warranty | undefined): WarrantyTerm | null {
  if (!w) return null;
  if (w.unit && w.amount && w.amount > 0) return { unit: w.unit, amount: w.amount };
  if (w.months > 0) return { unit: 'months', amount: w.months };
  return null;
}

/** Months equivalent, for the legacy field and for anything sorting by length. */
export function termToMonths(term: WarrantyTerm): number {
  if (term.unit === 'years') return term.amount * 12;
  if (term.unit === 'months') return term.amount;
  return Math.max(1, Math.round(term.amount / 30.44));
}

export function expiresOn(w: Warranty | undefined, purchaseDate?: string): Date | null {
  const term = termOf(w);
  if (!term) return null;
  const start = w?.startsOn ?? purchaseDate;
  if (!start) return null;

  const from = parseDate(start);
  // Days are exact. Months and years use calendar arithmetic, so a term bought
  // on the 31st ends on the 31st rather than drifting by the length of
  // whichever months it passed through.
  if (term.unit === 'days') return addDays(from, term.amount);
  return addMonths(from, termToMonths(term));
}

export function daysUntil(target: Date, from = new Date()): number {
  const a = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  const b = new Date(target.getFullYear(), target.getMonth(), target.getDate());
  return Math.round((b.getTime() - a.getTime()) / 86_400_000);
}

/* ------------------------------------------------------------- coverages */

/**
 * Every policy on an item, oldest field first.
 *
 * Records written before `coverages` existed only have `warranty` and
 * `extendedWarranty`, so they're read as a two-entry list here rather than
 * migrated in place. A read-time fold can't half-finish, can't run twice, and
 * can't corrupt a record that a future version understands better — which a
 * database upgrade over every item in the collection can do all three of.
 */
export function coveragesOf(item: Item): Coverage[] {
  if (item.coverages?.length) return item.coverages;

  const out: Coverage[] = [];
  const legacy = (w: Warranty | undefined, id: string, label: string) => {
    const term = termOf(w);
    if (!term || !w) return;
    out.push({
      id,
      label,
      unit: term.unit,
      amount: term.amount,
      startsOn: w.startsOn,
      provider: w.provider,
      policyNumber: w.policyNumber,
      phone: w.phone,
      url: w.url,
    });
  };

  legacy(item.warranty, 'legacy-base', DEFAULT_COVERAGE_LABEL);
  legacy(item.extendedWarranty, 'legacy-extended', 'Extended warranty');
  return out;
}

export function isLifetime(c: Coverage): boolean {
  return c.unit === 'lifetime';
}

/** When a policy runs out. Null for lifetime, and for a term with no start. */
export function coverageEnd(c: Coverage, purchaseDate?: string): Date | null {
  if (isLifetime(c)) return null;
  const start = c.startsOn ?? purchaseDate;
  if (!start || c.amount <= 0) return null;

  const from = parseDate(start);
  if (c.unit === 'days') return addDays(from, c.amount);
  return addMonths(from, c.unit === 'years' ? c.amount * 12 : c.amount);
}

export interface DatedCoverage {
  coverage: Coverage;
  /** Null only for lifetime. */
  end: Date | null;
  /** Null for lifetime; negative once it has lapsed. */
  daysLeft: number | null;
}

/**
 * Every policy with its end date worked out, soonest first, lifetime last.
 *
 * This ordering is the whole feature. A couch with a lifetime frame and twelve
 * months on the fabric is not "covered for life" in any sense the owner cares
 * about — the thing that will actually go wrong and stop being covered is the
 * fabric, and it's three months away. Sorting by what ends first puts the
 * useful answer at the top of every screen that shows this list.
 */
export function coverageSchedule(item: Item, now = new Date()): DatedCoverage[] {
  const dated = coveragesOf(item).map((coverage) => {
    const end = coverageEnd(coverage, item.purchaseDate);
    return { coverage, end, daysLeft: end ? daysUntil(end, now) : null };
  });

  return dated.sort((a, b) => {
    // Lifetime has no date to sort by and belongs at the bottom either way.
    if (!a.end && !b.end) return 0;
    if (!a.end) return 1;
    if (!b.end) return -1;
    return a.end.getTime() - b.end.getTime();
  });
}

/**
 * The policy the countdown belongs to: the next one still running that will
 * lapse. Everything on screen — the number, the colour, the ring, the
 * "expiring" filter — follows this one.
 */
export function nextToLapse(item: Item, now = new Date()): DatedCoverage | null {
  return coverageSchedule(item, now).find((d) => d.daysLeft !== null && d.daysLeft >= 0) ?? null;
}

/** True when at least one policy never runs out. */
export function hasLifetime(item: Item): boolean {
  return coveragesOf(item).some(isLifetime);
}

/** The last dated policy to have lapsed, for "ended 4 months ago". */
function lastLapsed(item: Item, now = new Date()): DatedCoverage | null {
  const lapsed = coverageSchedule(item, now).filter((d) => d.daysLeft !== null && d.daysLeft < 0);
  return lapsed[lapsed.length - 1] ?? null;
}

/** What a policy is called, never blank. */
export function coverageLabel(c: Coverage): string {
  return c.label.trim() || DEFAULT_COVERAGE_LABEL;
}

/** "Lifetime", "90 days", "3 years" — the term itself, not what's left. */
export function coverageTermLabel(c: Coverage): string {
  if (isLifetime(c)) return 'Lifetime';
  const unit = c.amount === 1 ? c.unit.replace(/s$/, '') : c.unit;
  return `${c.amount} ${unit}`;
}

/* ------------------------------------------------------ the item's status */

/**
 * When the item's cover next changes — the soonest policy still running.
 *
 * This used to be the *longest* of the two warranties, on the reasoning that
 * extended cover supersedes the base policy. With a real list that reasoning
 * inverts: reporting the furthest date away is how you tell someone their
 * couch is fine for life on the morning the fabric cover ends.
 */
export function effectiveExpiry(item: Item, now = new Date()): Date | null {
  const next = nextToLapse(item, now);
  if (next) return next.end;
  // Nothing running. The last thing to lapse is the honest answer; an item
  // with only a lifetime policy has no date at all, which is also honest.
  return lastLapsed(item, now)?.end ?? null;
}

export function warrantyState(item: Item, now = new Date()): WarrantyState {
  const all = coveragesOf(item);
  if (all.length === 0) return 'unknown';

  const next = nextToLapse(item, now);
  if (next) {
    return next.daysLeft! <= endingSoon ? 'ending-soon' : 'covered';
  }
  // Every dated policy has run out. A lifetime policy means the item is still
  // covered for something, so it must not be painted as expired.
  if (hasLifetime(item)) return 'covered';
  // A term with no purchase date to run from isn't expired, it's unanswered.
  return lastLapsed(item, now) ? 'expired' : 'unknown';
}

/** 0..1 for the ring, measured against the policy that's counting down. */
export function warrantyProgress(item: Item, now = new Date()): number {
  const next = nextToLapse(item, now);
  if (!next) return hasLifetime(item) ? 1 : 0;

  const start = next.coverage.startsOn ?? item.purchaseDate;
  if (!start || !next.end) return hasLifetime(item) ? 1 : 0;

  const total = daysUntil(next.end, parseDate(start));
  if (total <= 0) return 0;
  return Math.max(0, Math.min(1, next.daysLeft! / total));
}

/**
 * Under six months, the clock switches to days.
 *
 * "5m" and "4m" are the same glance — a month is too coarse to act on, and by
 * the time it reads "1m" the window to do something about an extended plan or
 * a return has usually gone. A number that ticks every day reads as a
 * countdown, which is what the last stretch of a warranty is. Calendar
 * arithmetic rather than a day count, so the switch happens on the same date
 * of the month regardless of which months are in the way.
 */
export function inFinalStretch(end: Date, now = new Date()): boolean {
  return end <= addMonths(new Date(now.getFullYear(), now.getMonth(), now.getDate()), 6);
}

/**
 * "2y 4m", "21 days", "Ended". Short enough for the list chip.
 *
 * A term entered in days counts down in days for its whole life, however long
 * that is. Someone who typed 90 days is watching a 90-day clock, and showing
 * them "2m" on day one is answering a question they didn't ask.
 */
export function warrantyLabel(item: Item, now = new Date()): string {
  const next = nextToLapse(item, now);
  if (!next) {
    if (hasLifetime(item)) return 'Lifetime';
    return lastLapsed(item, now) ? 'Ended' : 'No warranty';
  }

  const days = next.daysLeft!;
  if (days === 0) return 'Ends today';

  if (next.coverage.unit === 'days' || inFinalStretch(next.end!, now)) {
    return `${days} ${days === 1 ? 'day' : 'days'}`;
  }

  const months = Math.floor(days / 30.44);
  if (months < 12) return `${months}m`;
  const years = Math.floor(months / 12);
  const rem = months % 12;
  return rem ? `${years}y ${rem}m` : `${years}y`;
}

/**
 * The same answer, split so a list row can set the number in large type and
 * the unit underneath it. One string at 26px would wrap; "2y 4m" over "left"
 * puts the weight on the part that changes.
 */
export interface WarrantyParts {
  value: string;
  unit: string;
  /**
   * Which policy the number belongs to, once there's more than one and the
   * answer isn't obvious. "96 days left" on a couch with five policies is a
   * fact about the fabric, and a countdown that doesn't say what it's counting
   * is worse than no countdown.
   */
  which?: string;
}

export function warrantyParts(item: Item, now = new Date()): WarrantyParts {
  const all = coveragesOf(item);
  const next = nextToLapse(item, now);

  if (!next) {
    if (hasLifetime(item)) return { value: 'Lifetime', unit: 'no end date' };
    const last = lastLapsed(item, now);
    if (!last) return { value: '—', unit: all.length ? 'no start date' : 'no warranty' };
    return {
      value: 'Ended',
      unit: sinceLabel(-last.daysLeft!),
      which: all.length > 1 ? coverageLabel(last.coverage) : undefined,
    };
  }

  // Named only when the item has more than one policy. On the overwhelming
  // majority of items — one warranty, nothing else — the name would just be
  // the word "Warranty" under every number in the list.
  const which = all.length > 1 ? coverageLabel(next.coverage) : undefined;
  return { ...coverageParts(next, now), which };
}

/**
 * The same countdown for one named policy, for the list on the item page.
 * Every row there is a policy in its own right, so each gets its own number
 * rather than a share of the item's.
 */
export function coverageParts(d: DatedCoverage, now = new Date()): WarrantyParts {
  if (!d.end) return { value: 'Lifetime', unit: 'no end date' };

  const days = d.daysLeft!;
  if (days < 0) return { value: 'Ended', unit: sinceLabel(-days) };
  if (days === 0) return { value: 'Today', unit: 'last day' };

  if (d.coverage.unit === 'days' || inFinalStretch(d.end, now)) {
    return { value: String(days), unit: days === 1 ? 'day left' : 'days left' };
  }

  const months = Math.floor(days / 30.44);
  if (months < 12) return { value: String(months), unit: 'months left' };

  const years = Math.floor(months / 12);
  const rem = months % 12;
  return { value: rem ? `${years}y ${rem}m` : `${years}y`, unit: 'left' };
}

/** The colour a single policy earns, on the same scale as the item's. */
export function coverageState(d: DatedCoverage): WarrantyState {
  if (!d.end) return 'covered';
  if (d.daysLeft! < 0) return 'expired';
  return d.daysLeft! <= endingSoon ? 'ending-soon' : 'covered';
}

/** How much of one policy's term is left, 0..1, for its arc. */
export function coverageProgress(d: DatedCoverage, item: Item): number {
  if (!d.end) return 1; // lifetime: a full circle, because it never empties
  const start = d.coverage.startsOn ?? item.purchaseDate;
  if (!start) return 0;

  const total = daysUntil(d.end, parseDate(start));
  if (total <= 0) return 0;
  return Math.max(0, Math.min(1, d.daysLeft! / total));
}

/**
 * One arc per policy for the list row's ring, soonest to lapse outermost.
 *
 * The caller draws only the first few — see MAX_RINGS — which is why the order
 * matters: the ones that get dropped are the ones furthest from mattering.
 */
export function coverageArcs(
  item: Item,
  now = new Date(),
): { progress: number; state: WarrantyState }[] {
  const schedule = coverageSchedule(item, now);
  if (schedule.length === 0) {
    // Still one ring, drawn as an empty track. A row with no ring at all reads
    // as a different kind of row rather than as an item with nothing recorded.
    return [{ progress: 0, state: 'unknown' }];
  }
  return schedule.map((d) => ({
    progress: coverageProgress(d, item),
    state: coverageState(d),
  }));
}

/**
 * The cover line under an item's name: what ends first, and how many there
 * are. Only for items with more than one policy — on everything else the row
 * keeps showing the model and the year, which is more useful than the word
 * "Warranty" repeated down the page.
 */
export function coverSummary(item: Item, now = new Date()): string | null {
  const all = coveragesOf(item);
  if (all.length < 2) return null;

  // How many there are is drawn on the ring; this line is only for which one.
  // Saying both put a number in two places on the same row, and the count was
  // the less useful half — knowing it's the fabric tells you what to do.
  const next = nextToLapse(item, now);
  if (next) return `${coverageLabel(next.coverage)} ends first`;
  if (hasLifetime(item)) return 'Covered for life';
  return 'Every policy has ended';
}

function sinceLabel(daysAgo: number): string {
  if (daysAgo < 31) return `${daysAgo} ${daysAgo === 1 ? 'day' : 'days'} ago`;
  const months = Math.floor(daysAgo / 30.44);
  if (months < 12) return `${months} ${months === 1 ? 'month' : 'months'} ago`;
  const years = Math.floor(months / 12);
  return `${years} ${years === 1 ? 'year' : 'years'} ago`;
}

/** True when the policy running the clock was entered in days. */
export function countsInDays(item: Item, now = new Date()): boolean {
  return nextToLapse(item, now)?.coverage.unit === 'days';
}

/** "90 days", "2 years", "18 months" — the term itself, not what's left. */
export function termLabel(w: Warranty | undefined): string | null {
  const term = termOf(w);
  if (!term) return null;
  const unit = term.amount === 1 ? term.unit.replace(/s$/, '') : term.unit;
  return `${term.amount} ${unit}`;
}

export function formatMoney(cents: number | undefined, currency = 'USD'): string {
  if (cents == null) return '';
  try {
    return new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(cents / 100);
  } catch {
    return (cents / 100).toFixed(2);
  }
}
