import type { Item, Warranty, WarrantyUnit } from '@/db/types';

export type WarrantyState = 'covered' | 'ending-soon' | 'expired' | 'unknown';

export const ENDING_SOON_DAYS = 30;

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

/** Uses the longer-running of the two policies — extended cover supersedes base. */
export function effectiveExpiry(item: Item): Date | null {
  const base = expiresOn(item.warranty, item.purchaseDate);
  const ext = expiresOn(item.extendedWarranty, item.purchaseDate);
  if (base && ext) return ext > base ? ext : base;
  return base ?? ext;
}

export function warrantyState(item: Item, now = new Date()): WarrantyState {
  const end = effectiveExpiry(item);
  if (!end) return 'unknown';
  const days = daysUntil(end, now);
  if (days < 0) return 'expired';
  if (days <= ENDING_SOON_DAYS) return 'ending-soon';
  return 'covered';
}

/** 0..1 for the ring. Full term remaining = 1, expired = 0. */
export function warrantyProgress(item: Item, now = new Date()): number {
  const end = effectiveExpiry(item);
  const start = item.warranty?.startsOn ?? item.purchaseDate;
  if (!end || !start) return 0;
  const total = daysUntil(end, parseDate(start));
  if (total <= 0) return 0;
  return Math.max(0, Math.min(1, daysUntil(end, now) / total));
}

/**
 * "2y 4m", "21 days", "Ended". Short enough for the list chip.
 *
 * A term entered in days counts down in days for its whole life, however long
 * that is. Someone who typed 90 days is watching a 90-day clock, and showing
 * them "2m" on day one is answering a question they didn't ask.
 */
export function warrantyLabel(item: Item, now = new Date()): string {
  const end = effectiveExpiry(item);
  if (!end) return 'No warranty';

  const days = daysUntil(end, now);
  if (days < 0) return 'Ended';
  if (days === 0) return 'Ends today';

  if (countsInDays(item)) return `${days} ${days === 1 ? 'day' : 'days'}`;
  if (days < 45) return `${days} ${days === 1 ? 'day' : 'days'}`;

  const months = Math.floor(days / 30.44);
  if (months < 12) return `${months}m`;
  const years = Math.floor(months / 12);
  const rem = months % 12;
  return rem ? `${years}y ${rem}m` : `${years}y`;
}

/** True when the policy running the clock was entered in days. */
export function countsInDays(item: Item): boolean {
  const base = expiresOn(item.warranty, item.purchaseDate);
  const ext = expiresOn(item.extendedWarranty, item.purchaseDate);
  const winner = ext && base ? (ext > base ? item.extendedWarranty : item.warranty) : (item.warranty ?? item.extendedWarranty);
  return termOf(winner)?.unit === 'days';
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
