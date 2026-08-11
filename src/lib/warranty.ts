import type { Item, Warranty } from '@/db/types';

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

export function expiresOn(w: Warranty | undefined, purchaseDate?: string): Date | null {
  if (!w?.months) return null;
  const start = w.startsOn ?? purchaseDate;
  if (!start) return null;
  return addMonths(parseDate(start), w.months);
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

/** "2y 4m", "21 days", "Ended". Short enough for the list chip. */
export function warrantyLabel(item: Item, now = new Date()): string {
  const end = effectiveExpiry(item);
  if (!end) return 'No warranty';
  const days = daysUntil(end, now);
  if (days < 0) return 'Ended';
  if (days === 0) return 'Ends today';
  if (days < 45) return `${days} day${days === 1 ? '' : 's'}`;
  const months = Math.floor(days / 30.44);
  if (months < 12) return `${months}m`;
  const years = Math.floor(months / 12);
  const rem = months % 12;
  return rem ? `${years}y ${rem}m` : `${years}y`;
}

export function formatMoney(cents: number | undefined, currency = 'USD'): string {
  if (cents == null) return '';
  try {
    return new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(cents / 100);
  } catch {
    return (cents / 100).toFixed(2);
  }
}
