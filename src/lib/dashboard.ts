/**
 * Dashboard figures.
 *
 * Pure over arrays the caller already has, so it's testable and cheap to
 * recompute on every change. Everything here answers a question someone would
 * actually ask about their own stuff — how much of it is still covered, what
 * lapses next, and which items would fail me at claim time.
 */

import type { Doc, Item } from '@/db/types';
import { coveragesOf, daysUntil, effectiveExpiry, warrantyState } from './warranty';

export interface Metrics {
  total: number;
  covered: number;
  endingSoon: number;
  expired: number;
  untracked: number;
  /** Totals per currency. Never converted — an offline app has no rates. */
  valueByCurrency: { currency: string; cents: number }[];
  documents: number;
  /** Items with no receipt and no warranty document attached. */
  missingPaperwork: number;
  nextToExpire: { item: Item; days: number } | null;
  /** Newest first, for the recent strip. */
  recent: Item[];
}

export function metricsFor(items: Item[], docs: Doc[]): Metrics {
  const live = items.filter((i) => !i.deletedAt);
  const liveDocs = docs.filter((d) => !d.deletedAt);

  const proofKinds = new Set(['receipt', 'warranty']);
  const withProof = new Set(
    liveDocs.filter((d) => proofKinds.has(d.kind)).map((d) => d.itemId),
  );

  const byCurrency = new Map<string, number>();
  let covered = 0;
  let endingSoon = 0;
  let expired = 0;
  let untracked = 0;
  let next: { item: Item; days: number } | null = null;

  for (const item of live) {
    switch (warrantyState(item)) {
      case 'covered':
        covered++;
        break;
      case 'ending-soon':
        endingSoon++;
        break;
      case 'expired':
        expired++;
        break;
      default:
        untracked++;
    }

    if (item.purchasePriceCents != null) {
      const c = item.currency ?? 'USD';
      byCurrency.set(c, (byCurrency.get(c) ?? 0) + item.purchasePriceCents);
    }

    const end = effectiveExpiry(item);
    if (end) {
      const days = daysUntil(end);
      if (days >= 0 && (!next || days < next.days)) next = { item, days };
    }
  }

  return {
    total: live.length,
    covered,
    endingSoon,
    expired,
    untracked,
    valueByCurrency: [...byCurrency.entries()]
      .map(([currency, cents]) => ({ currency, cents }))
      .sort((a, b) => b.cents - a.cents),
    documents: liveDocs.length,
    missingPaperwork: live.filter((i) => !withProof.has(i.id)).length,
    nextToExpire: next,
    recent: [...live].sort((a, b) => b.createdAt.localeCompare(a.createdAt)).slice(0, 3),
  };
}

/**
 * What the collection is worth, per currency, largest first.
 *
 * Never converted. An offline app has no exchange rates and inventing one
 * would produce a total that is confidently wrong and impossible to check —
 * so a mixed collection reports its biggest currency and says which.
 *
 * Split out of `metricsFor` when this moved off the dashboard and onto the
 * items list, where it belongs: it is a fact about what you own, not about
 * what needs you.
 */
export function valueByCurrency(items: Item[]): { currency: string; cents: number }[] {
  const totals = new Map<string, number>();
  for (const item of items) {
    if (item.deletedAt || item.purchasePriceCents == null) continue;
    const c = item.currency ?? 'USD';
    totals.set(c, (totals.get(c) ?? 0) + item.purchasePriceCents);
  }
  return [...totals.entries()]
    .map(([currency, cents]) => ({ currency, cents }))
    .sort((a, b) => b.cents - a.cents);
}

/**
 * "$12.4K" once the number gets long.
 *
 * The exact figure belongs in a report; a line this size is read at a glance,
 * and Intl already knows how every locale abbreviates.
 */
export function shortMoney({ currency, cents }: { currency: string; cents: number }): string {
  const units = cents / 100;
  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency,
      notation: units >= 10_000 ? 'compact' : 'standard',
      maximumFractionDigits: units >= 10_000 ? 1 : 0,
    }).format(units);
  } catch {
    return `${Math.round(units)}`;
  }
}

/* ------------------------------------------------------------------ gaps */

/**
 * The things that are missing.
 *
 * Ordered by what it costs you to be missing it, not by how many there are.
 * A receipt is the one thing a claim will actually ask for and the one thing
 * you cannot recreate later — a shop will not reissue a receipt from 2023. A
 * photo you can take this afternoon. Sorting by count would put the cheap
 * problem at the top on most people's data.
 */
export type GapKind = 'receipt' | 'warranty' | 'date' | 'photo';

export interface Gap {
  kind: GapKind;
  count: number;
  /** Second person, and specific: "3 items have no receipt". */
  label: string;
  why: string;
}

const GAP_ORDER: GapKind[] = ['receipt', 'warranty', 'date', 'photo'];

const GAP_COPY: Record<GapKind, { one: string; many: string; why: string }> = {
  receipt: {
    one: '1 item has no receipt',
    many: 'items have no receipt',
    why: "It's the first thing a claim asks for, and shops won't reissue one.",
  },
  warranty: {
    one: '1 item has no warranty length',
    many: 'items have no warranty length',
    why: "Without it there's nothing to count down, so nothing warns you.",
  },
  date: {
    one: '1 item has no purchase date',
    many: 'items have no purchase date',
    why: 'Cover is measured from it, so the expiry can only be guessed.',
  },
  photo: {
    one: '1 item has no photo',
    many: 'items have no photo',
    why: 'Useful for proving condition, and for finding it in the list.',
  },
};

export function gapsFor(items: Item[], docs: Doc[]): Gap[] {
  const live = items.filter((i) => !i.deletedAt);
  const liveDocs = docs.filter((d) => !d.deletedAt);

  const withReceipt = new Set(liveDocs.filter((d) => d.kind === 'receipt').map((d) => d.itemId));

  const counts: Record<GapKind, number> = { receipt: 0, warranty: 0, date: 0, photo: 0 };

  for (const item of live) {
    if (!withReceipt.has(item.id)) counts.receipt++;
    // Warranty *length*, not the document: an item can have the paperwork
    // attached and still no term entered, and it's the term that drives every
    // countdown and every warning in the app.
    if (!hasTerm(item)) counts.warranty++;
    if (!item.purchaseDate) counts.date++;
    if (!item.thumbBlobId) counts.photo++;
  }

  return GAP_ORDER.filter((kind) => counts[kind] > 0).map((kind) => {
    const n = counts[kind];
    const copy = GAP_COPY[kind];
    return { kind, count: n, label: n === 1 ? copy.one : `${n} ${copy.many}`, why: copy.why };
  });
}

function hasTerm(item: Item): boolean {
  // Any policy at all counts, including a lifetime one — "no warranty length"
  // is the wrong thing to nag someone about on a couch whose frame is covered
  // forever.
  return coveragesOf(item).length > 0;
}

/** 0..1 share of items that are covered or ending soon, for the bar. */
export function coverShare(m: Metrics): number {
  const tracked = m.covered + m.endingSoon + m.expired;
  if (tracked === 0) return 0;
  return (m.covered + m.endingSoon) / tracked;
}
