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
    const weeks = Math.ceil((today.getTime() - anchor.getTime()) / (7 * DAY));
    return new Date(anchor.getTime() + weeks * 7 * DAY);
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
