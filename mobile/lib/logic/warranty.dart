/// What is covered, for how much longer, and what colour that is.
///
/// Translated from `src/lib/warranty.ts`.
library;

import '../models/types.dart';
import 'dates.dart';
import 'format.dart';

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
    return DatedCoverage(
        coverage, end, end == null ? null : daysUntil(end, at));
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

/* ------------------------------------------------- the countdown, in parts */

/// The number and its unit, kept apart.
///
/// Apart because the row draws them at very different sizes — 27px of the
/// display face for the figure, 10.5px for the words under it — and a single
/// string like "142 days left" would either wrap on a phone or force the number
/// down to the size of the label.
class WarrantyParts {
  const WarrantyParts(this.value, this.unit, [this.which]);

  final String value;
  final String unit;

  /// Which policy the number belongs to, or null when there is only one. On
  /// the overwhelming majority of items the name would just be the word
  /// "Warranty" under every figure in the list.
  final String? which;
}

/// True when the end is close enough that days are the useful unit.
///
/// Six months. Past that "142 days" is a number nobody converts; inside it,
/// months round away the thing you actually want to know.
bool inFinalStretch(DateTime end, [DateTime? now]) =>
    !end.isAfter(addMonthsClamped(startOfDay(now ?? DateTime.now()), 6));

String _sinceLabel(int daysAgo) {
  if (daysAgo < 31) return '$daysAgo ${daysAgo == 1 ? 'day' : 'days'} ago';
  final months = (daysAgo / 30.44).floor();
  if (months < 12) return '$months ${months == 1 ? 'month' : 'months'} ago';
  final years = (months / 12).floor();
  return '$years ${years == 1 ? 'year' : 'years'} ago';
}

/// The countdown for one named policy.
///
/// A term entered in days counts down in days for its whole life, however long
/// that is. Somebody who typed 90 days is watching a 90-day clock, and showing
/// them "2 months" on day one answers a question they did not ask.
WarrantyParts coverageParts(DatedCoverage d, [DateTime? now]) {
  if (d.end == null) return const WarrantyParts('Lifetime', 'no end date');

  return countdownParts(
    d.daysLeft!,
    // A term entered in days counts down in days for its whole life — see
    // above — and everything else switches to days near the end.
    inDays: d.coverage.unit == CoverageUnit.days || inFinalStretch(d.end!, now),
  );
}

/*
  ── One countdown vocabulary, for everything that expires ───────────────────

  Warranties and documents both count down to a date, and both used to do it
  their own way — the items list said "142 days left" and "8 months left", and
  the documents list showed the kind of document instead of a number at all.

  Pulled out here so the two screens cannot disagree about what a number means.
  A passport eleven months out and a warranty eleven months out should read
  identically, because they are the same fact about two different things.

  Whether days are still the useful unit is the CALLER'S call, because it is a
  calendar question — see `inFinalStretch` — and this only has a count.
*/
WarrantyParts countdownParts(
  int days, {
  bool inDays = false,
  String endedWord = 'Ended',
  String lastDayWord = 'last day',
}) {
  if (days < 0) return WarrantyParts(endedWord, _sinceLabel(-days));
  if (days == 0) return WarrantyParts('Today', lastDayWord);

  if (inDays) {
    return WarrantyParts(grouped(days), days == 1 ? 'day left' : 'days left');
  }

  final months = (days / 30.44).floor();
  if (months < 12) return WarrantyParts('$months', 'months left');

  final years = (months / 12).floor();
  final rem = months % 12;
  return WarrantyParts(rem != 0 ? '${years}y ${rem}m' : '${years}y', 'left');
}

/// The item's own countdown: the policy that will lapse first.
WarrantyParts warrantyParts(Item item, [DateTime? now]) {
  final all = coveragesOf(item);
  final next = nextToLapse(item, now);

  if (next == null) {
    if (hasLifetime(item)) {
      return const WarrantyParts('Lifetime', 'no end date');
    }

    final last = _lastLapsed(item, now);
    if (last == null) {
      return WarrantyParts('—', all.isEmpty ? 'no warranty' : 'no start date');
    }
    return WarrantyParts(
      'Ended',
      _sinceLabel(-last.daysLeft!),
      all.length > 1 ? coverageLabel(last.coverage) : null,
    );
  }

  final parts = coverageParts(next, now);
  return WarrantyParts(
    parts.value,
    parts.unit,
    all.length > 1 ? coverageLabel(next.coverage) : null,
  );
}

/* ------------------------------------------------------------- the rings */

/// How much of one policy's term is left, 0..1, for its arc.
double coverageProgress(DatedCoverage d, Item item) {
  // Lifetime is a full circle, because it never empties.
  if (d.end == null) return 1;

  final startsOn = d.coverage.startsOn ?? item.purchaseDate;
  final start = startsOn == null ? null : parseDate(startsOn);
  if (start == null) return 0;

  final total = daysUntil(d.end!, start);
  if (total <= 0) return 0;
  return (d.daysLeft! / total).clamp(0.0, 1.0);
}

class CoverageArc {
  const CoverageArc(this.progress, this.state);
  final double progress;
  final WarrantyState state;
}

/// One arc per policy, soonest to lapse outermost.
///
/// The caller draws only the first few, which is why the order matters: the
/// ones that get dropped are the ones furthest from mattering.
List<CoverageArc> coverageArcs(Item item, [DateTime? now]) {
  final schedule = coverageSchedule(item, now);

  // Still one ring, drawn as an empty track. A row with no ring at all reads as
  // a different kind of row rather than as an item with nothing recorded.
  if (schedule.isEmpty) {
    return const [CoverageArc(0, WarrantyState.unknown)];
  }

  return [
    for (final d in schedule)
      CoverageArc(coverageProgress(d, item), coverageState(d, item)),
  ];
}

/// The cover line under an item's name: which policy ends first.
///
/// Only for items with more than one — on everything else the row keeps showing
/// the model and the year, which is more useful than the word "Warranty"
/// repeated down the page.
///
/// How many there are is drawn on the ring rather than said here. Saying both
/// put a number in two places on one row, and the count was the less useful
/// half: knowing it is the fabric tells you what to do.
String? coverSummary(Item item, [DateTime? now]) {
  final all = coveragesOf(item);
  if (all.length < 2) return null;

  final next = nextToLapse(item, now);
  if (next != null) return '${coverageLabel(next.coverage)} ends first';
  if (hasLifetime(item)) return 'Covered for life';
  return 'Every policy has ended';
}
