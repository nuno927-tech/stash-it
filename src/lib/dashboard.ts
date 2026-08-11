/**
 * Dashboard figures.
 *
 * Pure over arrays the caller already has, so it's testable and cheap to
 * recompute on every change. Everything here answers a question someone would
 * actually ask about their own stuff — how much of it is still covered, what
 * lapses next, and which items would fail me at claim time.
 */

import type { Doc, Item } from '@/db/types';
import { daysUntil, effectiveExpiry, warrantyState } from './warranty';

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

/** 0..1 share of items that are covered or ending soon, for the bar. */
export function coverShare(m: Metrics): number {
  const tracked = m.covered + m.endingSoon + m.expired;
  if (tracked === 0) return 0;
  return (m.covered + m.endingSoon) / tracked;
}
