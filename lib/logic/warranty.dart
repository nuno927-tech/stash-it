/// What is covered, for how much longer, and what colour that is.
///
/// Translated from `src/lib/warranty.ts`.
library;

import '../models/types.dart';
import 'dates.dart';

enum WarrantyState { covered, endingSoon, expired, unknown }

const String defaultCoverageLabel = 'Warranty';
const int defaultEndingSoonDays = 30;

/// How close to the end counts as "ending soon", in days.
///
/// A library-level value with a setter, rather than an argument threaded
/// through every caller. In the TypeScript that decision was about avoiding a
/// fifteen-file signature change; the same reasoning holds here, and the same
/// warning applies — it is global state, tests must put it back.
int _endingSoon = defaultEndingSoonDays;

void setEndingSoonDays(int days) {
  _endingSoon = days.clamp(1, 365);
}

int getEndingSoonDays() => _endingSoon;

/// How much notice THIS item wants, which is not always the global answer.
///
/// An override rather than a second reminder. The alternative — the global
/// warning at thirty days plus the item's own at six months — is two
/// notifications about one warranty and a dashboard that agrees with neither.
/// Every surface asks `warrantyState`, so overriding the lead here moves the
/// ring, the timeline, the list filter and the notification together.
///
/// `??` and not `||`: zero is a real answer, "tell me on the day", and only
/// null falls back. Dart's null-aware operator does the right thing here where
/// JavaScript's truthiness did not.
int itemLeadDays(Item item) => item.leadDays ?? _endingSoon;

/// The term as the user expressed it.
class WarrantyTerm {
  const WarrantyTerm(this.unit, this.amount);
  final WarrantyUnit unit;
  final int amount;
}

/// Records written before units existed only have `months`, and read back as
/// months — which is what they meant.
WarrantyTerm? termOf(Warranty? w) {
  if (w == null) return null;
  final unit = w.unit;
  final amount = w.amount;
  if (unit != null && amount != null && amount > 0) {
    return WarrantyTerm(unit, amount);
  }
  if (w.months > 0) return WarrantyTerm(WarrantyUnit.months, w.months);
  return null;
}

/// Months equivalent, for the legacy field and for sorting by length.
int termToMonths(WarrantyTerm term) {
  switch (term.unit) {
    case WarrantyUnit.years:
      return term.amount * 12;
    case WarrantyUnit.months:
      return term.amount;
    case WarrantyUnit.days:
      final m = (term.amount / 30.44).round();
      return m < 1 ? 1 : m;
  }
}

/// Every policy on an item, oldest field first.
///
/// A read-time fold rather than a migration — see the note on `Warranty`.
List<Coverage> coveragesOf(Item item) {
  if (item.coverages.isNotEmpty) return item.coverages;

  final out = <Coverage>[];
  void legacy(Warranty? w, String id, String label) {
    final term = termOf(w);
    if (term == null || w == null) return;
    out.add(Coverage(
      id: id,
      label: label,
      unit: switch (term.unit) {
        WarrantyUnit.days => CoverageUnit.days,
        WarrantyUnit.months => CoverageUnit.months,
        WarrantyUnit.years => CoverageUnit.years,
      },
      amount: term.amount,
      startsOn: w.startsOn,
      provider: w.provider,
      policyNumber: w.policyNumber,
      phone: w.phone,
      url: w.url,
    ));
  }

  legacy(item.warranty, 'legacy-base', defaultCoverageLabel);
  legacy(item.extendedWarranty, 'legacy-extended', 'Extended warranty');
  return out;
}

bool isLifetime(Coverage c) => c.unit == CoverageUnit.lifetime;

/// When a policy runs out. Null for lifetime, and for a term with no start.
///
/// Days are exact. Months and years use calendar arithmetic, so a term bought
/// on the 31st ends on the 31st rather than drifting by the length of
/// whichever months it passed through.
DateTime? coverageEnd(Coverage c, String? purchaseDate) {
  if (isLifetime(c)) return null;

  final start = c.startsOn ?? purchaseDate;
  if (start == null || c.amount <= 0) return null;

  final from = parseDate(start);
  if (from == null) return null;

  if (c.unit == CoverageUnit.days) return addDays(from, c.amount);
  return addMonthsClamped(
    from,
    c.unit == CoverageUnit.years ? c.amount * 12 : c.amount,
  );
}

class DatedCoverage {
  const DatedCoverage(this.coverage, this.end, this.daysLeft);
  final Coverage coverage;

  /// Null only for lifetime.
  final DateTime? end;

  /// Null for lifetime; negative once it has lapsed.
  final int? daysLeft;
}

/// Every policy with its end date worked out, soonest first, lifetime last.
///
/// This ordering is the whole feature. A couch with a lifetime frame and
/// twelve months on the fabric is not "covered for life" in any sense the
/// owner cares about — the thing that will go wrong and stop being covered is
/// the fabric, and it is three months away.
List<DatedCoverage> coverageSchedule(Item item, [DateTime? now]) {
  final at = now ?? DateTime.now();

  final dated = coveragesOf(item).map((coverage) {
    final end = coverageEnd(coverage, item.purchaseDate);
    return DatedCoverage(coverage, end, end == null ? null : daysUntil(end, at));
  }).toList();

  dated.sort((a, b) {
    // Lifetime has no date to sort by and belongs at the bottom either way.
    if (a.end == null && b.end == null) return 0;
    if (a.end == null) return 1;
    if (b.end == null) return -1;
    return a.end!.compareTo(b.end!);
  });

  return dated;
}

/// The policy the countdown belongs to: the next one still running that will
/// lapse. The number, the colour, the ring and the "expiring" filter all
/// follow this one.
DatedCoverage? nextToLapse(Item item, [DateTime? now]) {
  for (final d in coverageSchedule(item, now)) {
    final left = d.daysLeft;
    if (left != null && left >= 0) return d;
  }
  return null;
}

bool hasLifetime(Item item) => coveragesOf(item).any(isLifetime);

/// The last dated policy to have lapsed, for "ended 4 months ago".
DatedCoverage? _lastLapsed(Item item, [DateTime? now]) {
  DatedCoverage? last;
  for (final d in coverageSchedule(item, now)) {
    final left = d.daysLeft;
    if (left != null && left < 0) last = d;
  }
  return last;
}

/// What a policy is called, never blank.
String coverageLabel(Coverage c) =>
    c.label.trim().isEmpty ? defaultCoverageLabel : c.label.trim();

/// When the item's cover next changes — the soonest policy still running.
///
/// This used to be the *longest* of the two warranties, on the reasoning that
/// extended cover supersedes the base policy. With a real list that reasoning
/// inverts: reporting the furthest date away is how you tell someone their
/// couch is fine for life on the morning the fabric cover ends.
DateTime? effectiveExpiry(Item item, [DateTime? now]) {
  final next = nextToLapse(item, now);
  if (next != null) return next.end;

  // Nothing running. The last thing to lapse is the honest answer; an item
  // with only a lifetime policy has no date at all, which is also honest.
  return _lastLapsed(item, now)?.end;
}

/// The colour the item earns.
WarrantyState warrantyState(Item item, [DateTime? now]) {
  if (coveragesOf(item).isEmpty) return WarrantyState.unknown;

  final next = nextToLapse(item, now);
  if (next != null) {
    return next.daysLeft! <= itemLeadDays(item)
        ? WarrantyState.endingSoon
        : WarrantyState.covered;
  }

  // Every dated policy has run out. A lifetime policy means the item is still
  // covered for something, so it must not be painted as expired.
  if (hasLifetime(item)) return WarrantyState.covered;

  // A term with no purchase date to run from isn't expired, it's unanswered.
  return _lastLapsed(item, now) != null
      ? WarrantyState.expired
      : WarrantyState.unknown;
}

/// The colour a single policy earns, on the same scale as the item's.
///
/// Takes the item so one row of coverage cannot read "covered" while the item
/// it belongs to reads "ending soon" — which is what happened the moment the
/// lead stopped being one number for everything.
WarrantyState coverageState(DatedCoverage d, [Item? item]) {
  if (d.end == null) return WarrantyState.covered;
  if (d.daysLeft! < 0) return WarrantyState.expired;
  final lead = item != null ? itemLeadDays(item) : _endingSoon;
  return d.daysLeft! <= lead ? WarrantyState.endingSoon : WarrantyState.covered;
}
