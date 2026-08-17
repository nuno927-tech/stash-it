import type { Cadence, Subscription } from '@/db/types';

/**
 * What a subscription costs and when it renews next.
 *
 * All of it is arithmetic on two fields — a cadence and an anchor date — and
 * all of it is here rather than in a screen, because every one of these
 * calculations has an off-by-one in it somewhere and a wrong renewal date is
 * indistinguishable from a right one until the money leaves.
 *
 * WHY AN ANCHOR AND NOT A DAY NUMBER
 *
 * "Which day of the month does it renew" is the obvious model and it can only
 * describe monthly plans. Amazon Prime and YouTube Premium are commonly annual;
 * a lot of services push an annual price precisely because people forget it. A
 * yearly plan stored as a day-of-month becomes a monthly charge, and the
 * dashboard total is then wrong by a factor of twelve — quietly, and in the
 * flattering direction.
 *
 * So: an anchor date, which is one real renewal (usually the first), and a
 * cadence. The day of the month falls out of the anchor for the monthly case,
 * and the annual case is representable.
 */

const DAY = 86_400_000;

/** How many months one period spans. Weekly is handled separately. */
const MONTHS_PER: Record<Exclude<Cadence, 'weekly'>, number> = {
  monthly: 1,
  quarterly: 3,
  yearly: 12,
};

/** Periods in a year, for normalising to a monthly figure. */
const PER_YEAR: Record<Cadence, number> = {
  weekly: 365.25 / 7,
  monthly: 12,
  quarterly: 4,
  yearly: 1,
};

export const CADENCES: Cadence[] = ['weekly', 'monthly', 'quarterly', 'yearly'];

export const CADENCE_LABEL: Record<Cadence, string> = {
  weekly: 'Weekly',
  monthly: 'Monthly',
  quarterly: 'Quarterly',
  yearly: 'Yearly',
};

/** "a month" / "a year" — for "$12.99 a month". */
export const CADENCE_PER: Record<Cadence, string> = {
  weekly: 'a week',
  monthly: 'a month',
  quarterly: 'a quarter',
  yearly: 'a year',
};

/** Local midnight, so comparisons are about days rather than hours. */
export function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

/**
 * Add days by the calendar, never by milliseconds.
 *
 * A day is not 86,400,000 ms. Twice a year it is one hour more or less, and
 * `date.getTime() + DAY` on the morning the clocks go back lands at 23:00 the
 * SAME day. Every consequence of that is silent: a weekly subscription
 * anchored on a Monday started renewing on Sundays after 1 November, and a
 * loop that stepped a cursor forward a day at a time stopped moving
 * altogether and ran until its guard.
 *
 * The Date constructor normalises overflow — day 32 of January is 1 February —
 * and always resolves to real local midnight, whatever the clocks did.
 */
export function addDays(from: Date, days: number): Date {
  return new Date(from.getFullYear(), from.getMonth(), from.getDate() + days);
}

/** Whole days between two local midnights. Rounded, because the DST hour makes
    the raw division 23/24 or 25/24 of a day rather than a whole one. */
function daysBetween(from: Date, to: Date): number {
  return Math.round((to.getTime() - from.getTime()) / DAY);
}

export function parseAnchor(iso: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso.trim());
  if (!m) return null;
  const [y, mo, da] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const d = new Date(y, mo - 1, da);
  // Rejects 2026-02-31 and friends, which `new Date` silently rolls forward.
  return d.getFullYear() === y && d.getMonth() === mo - 1 && d.getDate() === da ? d : null;
}

/**
 * Add months, clamping to the end of the target month.
 *
 * A subscription anchored on the 31st renews on the 30th in April and the 28th
 * in February — that is what the card issuer does, and rolling forward into
 * the 1st of the next month instead would put the renewal in the wrong month
 * on the calendar and quietly shift every subsequent date by one.
 */
export function addMonthsClamped(from: Date, months: number): Date {
  const y = from.getFullYear();
  const m = from.getMonth() + months;
  const lastDay = new Date(y, m + 1, 0).getDate();
  return new Date(y, m, Math.min(from.getDate(), lastDay));
}

/**
 * The next time this renews, on or after `now`.
 *
 * Stepping period by period rather than computing a count, because clamped
 * months don't divide: an anchor on the 31st visits the 28th of February and
 * must come back to the 31st in March, which only works if each step is taken
 * from the original anchor rather than from the previous result.
 */
export function nextRenewal(sub: Pick<Subscription, 'cadence' | 'anchorDate'>, now = new Date()): Date | null {
  const anchor = parseAnchor(sub.anchorDate);
  if (!anchor) return null;

  const today = startOfDay(now);
  if (anchor >= today) return anchor;

  if (sub.cadence === 'weekly') {
    // Counted in days and stepped by the calendar. Done in milliseconds this
    // silently moved every weekly renewal one day earlier for the winter half
    // of the year — see addDays.
    const weeks = Math.ceil(daysBetween(anchor, today) / 7);
    return addDays(anchor, weeks * 7);
  }

  const step = MONTHS_PER[sub.cadence];
  // Start from a floor estimate and walk, so a clamped month can't strand us.
  const months =
    (today.getFullYear() - anchor.getFullYear()) * 12 + (today.getMonth() - anchor.getMonth());
  let periods = Math.max(0, Math.floor(months / step));
  for (let guard = 0; guard < 500; guard++) {
    const at = addMonthsClamped(anchor, periods * step);
    if (at >= today) return at;
    periods++;
  }
  return null;
}

/** Whole days until the next renewal. 0 means today. */
export function daysUntilRenewal(
  sub: Pick<Subscription, 'cadence' | 'anchorDate'>,
  now = new Date(),
): number | null {
  const at = nextRenewal(sub, now);
  if (!at) return null;
  return Math.round((at.getTime() - startOfDay(now).getTime()) / DAY);
}

/**
 * What this costs per month, in cents.
 *
 * Yearly divided by twelve, weekly multiplied by 52.18 — the point of the
 * figure is comparison and a monthly total, so a weekly plan has to be
 * expressed as its true monthly average rather than four weeks, which
 * undercounts by about 8%.
 */
export function monthlyCents(sub: Pick<Subscription, 'cadence' | 'amountCents'>): number {
  if (!Number.isFinite(sub.amountCents) || sub.amountCents <= 0) return 0;
  return Math.round((sub.amountCents * PER_YEAR[sub.cadence]) / 12);
}

export function totalMonthlyCents(subs: Pick<Subscription, 'cadence' | 'amountCents'>[]): number {
  return subs.reduce((sum, s) => sum + monthlyCents(s), 0);
}

/** Yearly spend, from the same normalisation. */
export function totalYearlyCents(subs: Pick<Subscription, 'cadence' | 'amountCents'>[]): number {
  return subs.reduce((sum, s) => sum + Math.round(s.amountCents * PER_YEAR[s.cadence]), 0);
}

/** The single largest recurring charge, normalised to a month. */
export function biggest(subs: Subscription[]): Subscription | null {
  if (subs.length === 0) return null;
  return [...subs].sort((a, b) => monthlyCents(b) - monthlyCents(a))[0]!;
}

/**
 * What actually leaves your account in the next `days`.
 *
 * Not a normalised figure — the real charges, on their real dates. The monthly
 * total answers "what is this costing me", which is a question about the year;
 * this answers "what is about to happen", which is a question about Thursday.
 * A yearly plan renewing on the 14th belongs in this number at its full price,
 * and contributes a twelfth of itself to the other one.
 */
export function dueWithin(
  subs: Subscription[],
  days: number,
  now = new Date(),
): { count: number; cents: number } {
  let count = 0;
  let cents = 0;
  for (const s of subs) {
    const left = daysUntilRenewal(s, now);
    if (left === null || left < 0 || left > days) continue;
    count++;
    cents += s.amountCents;
  }
  return { count, cents };
}

/**
 * The monthly total, per day.
 *
 * The same money said in the unit people actually feel. "$94 a month" is a
 * line on a statement; "about $3 a day" is a coffee, and it is the framing
 * that makes somebody look at the list.
 */
export function dailyCents(subs: Pick<Subscription, 'cadence' | 'amountCents'>[]): number {
  return Math.round((totalYearlyCents(subs) / 365.25) * 100) / 100;
}

/* ------------------------------------------------------------ the shape of it */

/**
 * Every renewal this subscription has between two dates, inclusive.
 *
 * Steps by asking `nextRenewal` again from the day after each hit rather than
 * doing its own arithmetic, so the end-of-month clamping is applied in exactly
 * one place. A weekly plan returns four or five dates in a month; a yearly one
 * returns nothing at all in eleven months of twelve, which is the entire point
 * of drawing this.
 */
export function renewalsBetween(sub: Subscription, from: Date, to: Date): Date[] {
  const out: Date[] = [];
  const last = startOfDay(to);
  let cursor = startOfDay(from);

  // 400 is a year and a half of weekly renewals — far past any window this is
  // called with, and a hard stop if a cadence ever fails to advance.
  for (let guard = 0; guard < 400; guard++) {
    const at = nextRenewal(sub, cursor);
    if (!at || at > last) break;
    out.push(at);
    cursor = addDays(at, 1);
  }
  return out;
}

export interface MonthSpend {
  year: number;
  /** 0-11. */
  month: number;
  /** Real money, at real prices, on the days it actually leaves. */
  cents: number;
  count: number;
}

/**
 * What each of the next `months` calendar months actually costs.
 *
 * THE REASON THIS EXISTS. A monthly total is an average, and an average hides
 * the only thing about subscription spending that ever surprises anybody: it
 * isn't level. Three annual plans that happen to renew in January make January
 * cost four times what October does, and no amount of staring at "$94 a month"
 * will tell you that. The bars do, immediately.
 *
 * Whole months, including the part of this one already spent. A first bar
 * showing only what's left would be a different measurement from the five
 * beside it, which is the one thing a bar chart must never do.
 */
export function spendByMonth(subs: Subscription[], months: number, now = new Date()): MonthSpend[] {
  const out: MonthSpend[] = [];

  for (let i = 0; i < months; i++) {
    const first = new Date(now.getFullYear(), now.getMonth() + i, 1);
    const last = new Date(first.getFullYear(), first.getMonth() + 1, 0);
    let cents = 0;
    let count = 0;

    for (const s of subs) {
      const hits = renewalsBetween(s, first, last);
      count += hits.length;
      cents += hits.length * s.amountCents;
    }

    out.push({ year: first.getFullYear(), month: first.getMonth(), cents, count });
  }

  return out;
}

/** The most expensive month in a run, or null if they're all empty. */
export function heaviest(spend: MonthSpend[]): MonthSpend | null {
  let top: MonthSpend | null = null;
  for (const m of spend) if (m.cents > 0 && (!top || m.cents > top.cents)) top = m;
  return top;
}

/**
 * How lumpy the run is: the heaviest month over the mean.
 *
 * 1 is perfectly level. The caller uses it to decide whether the chart is
 * worth a sentence — pointing at a "heaviest month" that costs 4% more than
 * the others is a caption that invents a finding.
 */
export function spread(spend: MonthSpend[]): number {
  if (spend.length === 0) return 1;
  const total = spend.reduce((sum, m) => sum + m.cents, 0);
  if (total === 0) return 1;
  const mean = total / spend.length;
  const top = heaviest(spend)!;
  return top.cents / mean;
}

/* ------------------------------------------------------------ what needs you */

export type SubGapKind = 'soon' | 'bigsoon';

export interface SubGap {
  kind: SubGapKind;
  count: number;
  cents: number;
  label: string;
  why: string;
}

/** Cadences where one charge is a meaningful lump rather than a monthly bill. */
const LUMPY: Cadence[] = ['quarterly', 'yearly'];

/**
 * The subscription jobs, in the sense the dashboard means it: not missing
 * data, but money about to move while you can still do something about it.
 *
 * Deliberately NOT "you haven't set a reminder" or "you haven't filled in the
 * start date". Both are things the app would like to have; neither is a thing
 * the user needs. A dashboard that asks you to feed it is a dashboard people
 * learn to scroll past, and the reminder default is off on purpose — see
 * `reminderDue`.
 *
 * The two windows don't overlap. A yearly plan renewing on Friday is this
 * week's problem and appears once, in the first line.
 */
export function subGaps(subs: Subscription[], now = new Date()): SubGap[] {
  const out: SubGap[] = [];

  const week = subs.filter((s) => {
    const d = daysUntilRenewal(s, now);
    return d !== null && d >= 0 && d <= 7;
  });

  const lump = subs.filter((s) => {
    if (!LUMPY.includes(s.cadence)) return false;
    const d = daysUntilRenewal(s, now);
    return d !== null && d > 7 && d <= 30;
  });

  if (week.length) {
    out.push({
      kind: 'soon',
      count: week.length,
      cents: week.reduce((n, s) => n + s.amountCents, 0),
      label: week.length === 1 ? 'renews this week' : 'renew this week',
      why: 'The last week you can cancel before the money goes.',
    });
  }

  if (lump.length) {
    out.push({
      kind: 'bigsoon',
      count: lump.length,
      cents: lump.reduce((n, s) => n + s.amountCents, 0),
      label: lump.length === 1 ? 'large charge this month' : 'large charges this month',
      why: 'A quarter or a year at once, with time left to decide.',
    });
  }

  return out;
}

/* --------------------------------------------------------------- reminders */

/** Days before renewal a reminder can be set for. `0` means none. */
export const REMIND_CHOICES = [0, 1, 3, 7] as const;
export type RemindDays = (typeof REMIND_CHOICES)[number];

/**
 * Whether this subscription wants to be mentioned right now.
 *
 * "Right now" means the next time the app is opened, because that is the only
 * moment it can say anything: there is no server and nothing runs while the
 * app is closed. Everything about the wording around this setting has to be
 * honest about that — a reminder that only appears once you've opened the app
 * is a note, and calling it an alert would be a promise the app can't keep.
 */
export function reminderDue(sub: Subscription, now = new Date()): boolean {
  if (!sub.remindDays) return false;
  const days = daysUntilRenewal(sub, now);
  if (days === null) return false;
  return days >= 0 && days <= sub.remindDays;
}

/** Everything that wants mentioning, soonest first. */
export function dueReminders(subs: Subscription[], now = new Date()): Subscription[] {
  return subs
    .filter((s) => reminderDue(s, now))
    .sort((a, b) => (daysUntilRenewal(a, now) ?? 0) - (daysUntilRenewal(b, now) ?? 0));
}

/* ----------------------------------------------------------- the calendar */

export interface RenewalDay {
  /** 1..31 */
  day: number;
  subs: Subscription[];
}

/**
 * Which day of a given month each subscription lands on.
 *
 * Computed by walking the month rather than reading the anchor's day number,
 * so a weekly plan appears four or five times and a yearly one appears in only
 * one month of the twelve — which is the whole reason to draw a calendar
 * rather than a list of day numbers.
 */
export function renewalsInMonth(
  subs: Subscription[],
  year: number,
  month: number,
  now = new Date(),
): RenewalDay[] {
  const days = new Date(year, month + 1, 0).getDate();
  const out: RenewalDay[] = [];

  for (let day = 1; day <= days; day++) {
    const date = new Date(year, month, day);
    const on = subs.filter((s) => {
      const at = nextRenewal(s, date <= startOfDay(now) ? now : date);
      return at ? at.getFullYear() === year && at.getMonth() === month && at.getDate() === day : false;
    });
    if (on.length) out.push({ day, subs: on });
  }
  return out;
}

/** "Renews today" / "Renews tomorrow" / "Renews in 6 days". */
export function renewalLabel(days: number | null): string {
  if (days === null) return 'No renewal date';
  if (days <= 0) return 'Renews today';
  if (days === 1) return 'Renews tomorrow';
  return `Renews in ${days} days`;
}

/** "3rd", for the compact row under a logo. */
export function ordinal(n: number): string {
  const rest = n % 100;
  if (rest >= 11 && rest <= 13) return `${n}th`;
  return `${n}${['th', 'st', 'nd', 'rd'][n % 10] ?? 'th'}`;
}
