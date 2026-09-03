/// Dashboard figures.
///
/// Translated from `src/lib/dashboard.ts`.
///
/// Pure over lists the caller already has, so it is testable and cheap to
/// recompute on every change. Everything here answers a question someone would
/// actually ask about their own things — how much of it is still covered, what
/// lapses next, and which items would fail them at claim time.
library;

import '../models/types.dart';
import 'dates.dart';
import 'format.dart';
import 'warranty.dart';

class CurrencyTotal {
  const CurrencyTotal(this.currency, this.cents);
  final String currency;
  final int cents;
}

class NextToExpire {
  const NextToExpire(this.item, this.days);
  final Item item;
  final int days;
}

class Metrics {
  const Metrics({
    required this.total,
    required this.covered,
    required this.endingSoon,
    required this.expired,
    required this.untracked,
    required this.valueByCurrency,
    required this.documents,
    required this.missingPaperwork,
    required this.nextToExpire,
    required this.recent,
  });

  final int total;
  final int covered;
  final int endingSoon;
  final int expired;
  final int untracked;

  /// Totals per currency. **Never converted** — an offline app has no rates.
  final List<CurrencyTotal> valueByCurrency;

  final int documents;

  /// Items with no receipt and no warranty document attached.
  final int missingPaperwork;

  final NextToExpire? nextToExpire;

  /// Newest first, for the recent strip.
  final List<Item> recent;
}

/// The two kinds a claim will actually ask for. A manual is useful; it is not
/// evidence.
const Set<DocKind> _proof = {DocKind.receipt, DocKind.warranty};

Metrics metricsFor(List<Item> items, List<Doc> docs, [DateTime? now]) {
  final at = now ?? DateTime.now();

  final live = items.where((i) => i.deletedAt == null).toList();
  final liveDocs = docs.where((d) => d.deletedAt == null).toList();

  /*
    Attachments on DOCUMENTS are skipped here, and everywhere else that counts
    an item's paperwork.

    A passport scan is an attachment with no `itemId`, and a set built without
    this check would carry a null — which then matches no item and quietly
    inflates nothing, but does put a null in a set of ids. Filtering at the
    source is cheaper to read than wondering later what a null in there meant.
  */
  final withProof = {
    for (final d in liveDocs)
      if (_proof.contains(d.kind) && d.itemId != null) d.itemId!,
  };

  var covered = 0, endingSoon = 0, expired = 0, untracked = 0;
  NextToExpire? next;

  for (final item in live) {
    switch (warrantyState(item, at)) {
      case WarrantyState.covered:
        covered++;
        break;
      case WarrantyState.endingSoon:
        endingSoon++;
        break;
      case WarrantyState.expired:
        expired++;
        break;
      case WarrantyState.unknown:
        untracked++;
        break;
    }

    final end = effectiveExpiry(item, at);
    if (end != null) {
      final days = daysUntil(end, at);
      if (days >= 0 && (next == null || days < next.days)) {
        next = NextToExpire(item, days);
      }
    }
  }

  /*
    The value total is computed by calling `valueByCurrency` rather than being
    accumulated in the loop above.

    The TypeScript did both — an inline map here, and a standalone function
    lower down for the items list, which is where the figure eventually moved.
    Two implementations of one sum is one edit away from two answers.
  */
  return Metrics(
    total: live.length,
    covered: covered,
    endingSoon: endingSoon,
    expired: expired,
    untracked: untracked,
    valueByCurrency: valueByCurrency(live),
    documents: liveDocs.length,
    missingPaperwork: live.where((i) => !withProof.contains(i.id)).length,
    nextToExpire: next,
    recent: _recent(live),
  );
}

List<Item> _recent(List<Item> live) {
  final dated = [...live];
  dated.sort((a, b) {
    final at = a.createdAt;
    final bt = b.createdAt;
    // An item with no timestamp sinks rather than claiming to be newest.
    if (at == null && bt == null) return a.name.compareTo(b.name);
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  });
  return dated.take(3).toList();
}

/// What the collection is worth, per currency, largest first.
///
/// **Never converted.** An offline app has no exchange rates and inventing one
/// would produce a total that is confidently wrong and impossible to check — so
/// a mixed collection reports its biggest currency and says which.
List<CurrencyTotal> valueByCurrency(List<Item> items) {
  final totals = <String, int>{};
  for (final item in items) {
    final cents = item.purchasePriceCents;
    if (item.deletedAt != null || cents == null) continue;
    final c = item.currency ?? 'USD';
    totals[c] = (totals[c] ?? 0) + cents;
  }

  final out = [
    for (final e in totals.entries) CurrencyTotal(e.key, e.value),
  ];
  out.sort((a, b) {
    final byValue = b.cents.compareTo(a.cents);
    // Alphabetical on a tie, so two currencies that happen to match do not
    // swap places between rebuilds.
    return byValue != 0 ? byValue : a.currency.compareTo(b.currency);
  });
  return out;
}

/// "$12.4K" once the number gets long.
///
/// The exact figure belongs in a report; a line this size is read at a glance.
///
/// ── A divergence, and it is the same one as `dayMonth` ────────────────────
/// The TypeScript handed this to `Intl.NumberFormat`, which knows how every
/// locale abbreviates and where it puts the symbol. Dart's core library has no
/// equivalent, so this is a hand-rolled US-style abbreviation using the app's
/// own symbol table. `package:intl` replaces it in phase 3, at which point this
/// becomes locale-correct for real rather than correct-looking.
String shortMoney(CurrencyTotal total) {
  final symbol = currencySymbol(total.currency);
  final units = total.cents / 100;

  if (units.abs() >= 1000000) {
    return '$symbol${_trim(units / 1000000)}M';
  }
  if (units.abs() >= 10000) {
    return '$symbol${_trim(units / 1000)}K';
  }
  return '$symbol${_grouped(units.round())}';
}

/// One decimal, and not a trailing zero. "$12.4K", "$12K".
String _trim(double n) {
  final one = n.toStringAsFixed(1);
  return one.endsWith('.0') ? one.substring(0, one.length - 2) : one;
}

final RegExp _thousandsGap = RegExp(r'\B(?=(\d{3})+(?!\d))');

String _grouped(int n) {
  final negative = n < 0;
  final digits = n.abs().toString().replaceAll(_thousandsGap, ',');
  return negative ? '-$digits' : digits;
}

/* -------------------------------------------------------------------- gaps */

/// The things that are missing.
///
/// Ordered by **what it costs you to be missing it**, not by how many there
/// are. A receipt is the one thing a claim will actually ask for and the one
/// thing you cannot recreate later — a shop will not reissue a receipt from
/// 2023. A photo you can take this afternoon. Sorting by count would put the
/// cheap problem at the top on most people's data.
enum GapKind { receipt, warranty, date, photo }

class Gap {
  const Gap(this.kind, this.count, this.label, this.why);
  final GapKind kind;
  final int count;

  /// Second person, and specific: "3 items have no receipt".
  final String label;
  final String why;
}

class _GapCopy {
  const _GapCopy(this.one, this.many, this.why);
  final String one;
  final String many;
  final String why;
}

/// The order is the ranking. It is not alphabetical and it is not by count.
const List<GapKind> gapOrder = [
  GapKind.receipt,
  GapKind.warranty,
  GapKind.date,
  GapKind.photo,
];

const Map<GapKind, _GapCopy> _gapCopy = {
  GapKind.receipt: _GapCopy(
    '1 item has no receipt',
    'items have no receipt',
    "It's the first thing a claim asks for, and shops won't reissue one.",
  ),
  GapKind.warranty: _GapCopy(
    '1 item has no warranty length',
    'items have no warranty length',
    "Without it there's nothing to count down, so nothing warns you.",
  ),
  GapKind.date: _GapCopy(
    '1 item has no purchase date',
    'items have no purchase date',
    'Cover is measured from it, so the expiry can only be guessed.',
  ),
  GapKind.photo: _GapCopy(
    '1 item has no photo',
    'items have no photo',
    'Useful for proving condition, and for finding it in the list.',
  ),
};

List<Gap> gapsFor(List<Item> items, List<Doc> docs) {
  final live = items.where((i) => i.deletedAt == null).toList();
  final withReceipt = {
    for (final d in docs)
      if (d.deletedAt == null && d.kind == DocKind.receipt && d.itemId != null)
        d.itemId!,
  };

  final counts = {for (final k in GapKind.values) k: 0};

  for (final item in live) {
    if (!withReceipt.contains(item.id)) {
      counts[GapKind.receipt] = counts[GapKind.receipt]! + 1;
    }

    // Warranty *length*, not the document: an item can have the paperwork
    // attached and still no term entered, and it is the term that drives every
    // countdown and every warning in the app.
    if (!_hasTerm(item)) {
      counts[GapKind.warranty] = counts[GapKind.warranty]! + 1;
    }

    final bought = item.purchaseDate;
    if (bought == null || bought.isEmpty) {
      counts[GapKind.date] = counts[GapKind.date]! + 1;
    }
    if (item.thumbBlobId == null) {
      counts[GapKind.photo] = counts[GapKind.photo]! + 1;
    }
  }

  return [
    for (final kind in gapOrder)
      if (counts[kind]! > 0)
        Gap(
          kind,
          counts[kind]!,
          counts[kind] == 1
              ? _gapCopy[kind]!.one
              : '${counts[kind]} ${_gapCopy[kind]!.many}',
          _gapCopy[kind]!.why,
        ),
  ];
}

/// Any policy at all counts, including a lifetime one — "no warranty length"
/// is the wrong thing to nag someone about on a couch whose frame is covered
/// forever.
bool _hasTerm(Item item) => coveragesOf(item).isNotEmpty;

/// 0..1 share of items that are covered or ending soon, for the bar.
double coverShare(Metrics m) {
  final tracked = m.covered + m.endingSoon + m.expired;
  if (tracked == 0) return 0;
  return (m.covered + m.endingSoon) / tracked;
}
