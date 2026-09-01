/// What a subscription costs and when it renews next.
///
/// Translated from `src/lib/subscriptions.ts`.
///
/// All of it is arithmetic on two fields — a cadence and an anchor date — and
/// all of it is here rather than in a screen, because every one of these
/// calculations has an off-by-one in it somewhere and a wrong renewal date is
/// indistinguishable from a right one until the money leaves.
///
/// ── Why an anchor and not a day number ────────────────────────────────────
/// "Which day of the month does it renew" is the obvious model and it can only
/// describe monthly plans. A yearly plan stored as a day-of-month becomes a
/// monthly charge, and the dashboard total is then wrong by a factor of twelve
/// — quietly, and in the flattering direction.
library;

import '../models/subscription.dart';
import 'dates.dart';

/// How many months one period spans. Weekly is handled separately.
const Map<Cadence, int> _monthsPer = {
  Cadence.monthly: 1,
  Cadence.quarterly: 3,
  Cadence.yearly: 12,
};

/// Periods in a year, for normalising to a monthly figure.
const Map<Cadence, double> _perYear = {
  Cadence.weekly: 365.25 / 7,
  Cadence.monthly: 12,
  Cadence.quarterly: 4,
  Cadence.yearly: 1,
};

const Map<Cadence, String> cadenceLabel = {
  Cadence.weekly: 'Weekly',
  Cadence.monthly: 'Monthly',
  Cadence.quarterly: 'Quarterly',
  Cadence.yearly: 'Yearly',
};

/// "a month" / "a year" — for "$12.99 a month".
const Map<Cadence, String> cadencePer = {
  Cadence.weekly: 'a week',
  Cadence.monthly: 'a month',
  Cadence.quarterly: 'a quarter',
  Cadence.yearly: 'a year',
};

/// The next time this renews, on or after `now`.
///
/// Stepping period by period rather than computing a count, because clamped
/// months do not divide: an anchor on the 31st visits the 28th of February and
/// must come back to the 31st in March, which only works if each step is taken
/// from the ORIGINAL anchor rather than from the previous result.
DateTime? nextRenewal(Subscription sub, [DateTime? now]) {
  final anchor = parseDate(sub.anchorDate);
  if (anchor == null) return null;

  final today = startOfDay(now ?? DateTime.now());
  if (!anchor.isBefore(today)) return anchor;

  if (sub.cadence == Cadence.weekly) {
    // Counted in days and stepped by the calendar. Done in milliseconds this
    // silently moved every weekly renewal one day earlier for the winter half
    // of the year — see the note at the top of dates.dart.
    final weeks = (daysBetween(anchor, today) / 7).ceil();
    return addDays(anchor, weeks * 7);
  }

  final step = _monthsPer[sub.cadence]!;

  // Start from a floor estimate and walk, so a clamped month cannot strand us.
  final months = (today.year - anchor.year) * 12 + (today.month - anchor.month);
  var periods = months ~/ step;
  if (periods < 0) periods = 0;

  for (var guard = 0; guard < 500; guard++) {
    final at = addMonthsClamped(anchor, periods * step);
    if (!at.isBefore(today)) return at;
    periods++;
  }
  return null;
}

/// Whole days until the next renewal. 0 means today.
int? daysUntilRenewal(Subscription sub, [DateTime? now]) {
  final at = nextRenewal(sub, now);
  if (at == null) return null;
  return daysBetween(startOfDay(now ?? DateTime.now()), at);
}

/// What this costs per month, in cents.
///
/// Yearly divided by twelve, weekly multiplied by 52.18 — the point of the
/// figure is comparison and a monthly total, so a weekly plan has to be
/// expressed as its true monthly average rather than four weeks, which
/// undercounts by about 8%.
int monthlyCents(Subscription sub) {
  if (sub.amountCents <= 0) return 0;
  return (sub.amountCents * _perYear[sub.cadence]! / 12).round();
}

int totalMonthlyCents(List<Subscription> subs) =>
    subs.fold(0, (sum, s) => sum + monthlyCents(s));

/// Yearly spend, from the same normalisation.
int totalYearlyCents(List<Subscription> subs) => subs.fold(
      0,
      (sum, s) => sum + (s.amountCents * _perYear[s.cadence]!).round(),
    );

/// The single largest recurring charge, normalised to a month.
Subscription? biggest(List<Subscription> subs) {
  if (subs.isEmpty) return null;
  final sorted = [...subs]..sort((a, b) => monthlyCents(b) - monthlyCents(a));
  return sorted.first;
}

class DueWithin {
  const DueWithin(this.count, this.cents);
  final int count;
  final int cents;
}

/// What actually leaves your account in the next `days`.
///
/// Not a normalised figure — the real charges, on their real dates. The
/// monthly total answers "what is this costing me", which is a question about
/// the year; this answers "what is about to happen", which is a question about
/// Thursday.
DueWithin dueWithin(List<Subscription> subs, int days, [DateTime? now]) {
  var count = 0;
  var cents = 0;
  for (final s in subs) {
    final left = daysUntilRenewal(s, now);
    if (left == null || left < 0 || left > days) continue;
    count++;
    cents += s.amountCents;
  }
  return DueWithin(count, cents);
}

/// The monthly total, per day.
///
/// The same money said in the unit people actually feel. "$94 a month" is a
/// line on a statement; "about $3 a day" is a coffee, and it is the framing
/// that makes somebody look at the list.
double dailyCents(List<Subscription> subs) =>
    ((totalYearlyCents(subs) / 365.25) * 100).round() / 100;

/* --------------------------------------------------------------- reminders */

/// Days before renewal a reminder can be set for. `0` means none.
const List<int> remindChoices = [0, 1, 3, 7];

/// Whether this subscription wants to be mentioned right now.
///
/// "Right now" means the next time the app is opened, because on the web that
/// was the only moment it could say anything: there was no server and nothing
/// ran while the app was closed. Every word around this setting was written to
/// be honest about that.
///
/// **This is one of the promises the port can finally keep.** A native app has
/// a real scheduler, so in phase 5 this becomes a notification that arrives
/// whether the app is open or not. The predicate does not change — what
/// changes is that something other than a screen render can ask it.
///
/// `remindDays` null or 0 both mean no reminder, which is the default: nine
/// monthly services would otherwise be nine notifications a month for money
/// that leaves whether you are told or not.
bool reminderDue(Subscription sub, [DateTime? now]) {
  final want = sub.remindDays;
  if (want == null || want == 0) return false;
  final days = daysUntilRenewal(sub, now);
  if (days == null) return false;
  return days >= 0 && days <= want;
}

/// Everything that wants mentioning, soonest first.
List<Subscription> dueReminders(List<Subscription> subs, [DateTime? now]) {
  final out = subs.where((s) => reminderDue(s, now)).toList();
  out.sort((a, b) =>
      (daysUntilRenewal(a, now) ?? 0) - (daysUntilRenewal(b, now) ?? 0));
  return out;
}

/// Every renewal between two dates, inclusive.
///
/// Steps by asking `nextRenewal` again from the day after each hit rather than
/// doing its own arithmetic, so the end-of-month clamping is applied in
/// exactly one place. A weekly plan returns four or five dates in a month; a
/// yearly one returns nothing at all in eleven months of twelve, which is the
/// entire point of drawing this.
List<DateTime> renewalsBetween(Subscription sub, DateTime from, DateTime to) {
  final out = <DateTime>[];
  final last = startOfDay(to);
  var cursor = startOfDay(from);

  // 400 is a year and a half of weekly renewals — far past any window this is
  // called with, and a hard stop if a cadence ever fails to advance.
  for (var guard = 0; guard < 400; guard++) {
    final at = nextRenewal(sub, cursor);
    if (at == null || at.isAfter(last)) break;
    out.add(at);
    cursor = addDays(at, 1);
  }
  return out;
}

class MonthSpend {
  const MonthSpend(this.year, this.month, this.cents, this.count);
  final int year;

  /// 1-12. **The TypeScript stores 0-11**, because JavaScript months are
  /// zero-based; this is one of the deliberate differences in the port, and
  /// anything reading both has to know it.
  final int month;

  /// Real money, at real prices, on the days it actually leaves.
  final int cents;
  final int count;
}

/// What each of the next `months` calendar months actually costs.
///
/// A monthly total is an average, and an average hides the only thing about
/// subscription spending that ever surprises anybody: it is not level. Three
/// annual plans that happen to renew in January make January cost four times
/// what October does, and no amount of staring at "$94 a month" will tell you
/// that.
///
/// Whole months, including the part of this one already spent. A first bar
/// showing only what is left would be a different measurement from the five
/// beside it, which is the one thing a bar chart must never do.
List<MonthSpend> spendByMonth(List<Subscription> subs, int months,
    [DateTime? now]) {
  final at = now ?? DateTime.now();
  final out = <MonthSpend>[];

  for (var i = 0; i < months; i++) {
    final first = DateTime(at.year, at.month + i, 1);
    // Day zero of the next month is the last day of this one.
    final last = DateTime(first.year, first.month + 1, 0);

    var cents = 0;
    var count = 0;
    for (final s in subs) {
      final hits = renewalsBetween(s, first, last);
      count += hits.length;
      cents += hits.length * s.amountCents;
    }

    out.add(MonthSpend(first.year, first.month, cents, count));
  }

  return out;
}

/// The most expensive month in a run, or null if they are all empty.
MonthSpend? heaviest(List<MonthSpend> spend) {
  MonthSpend? top;
  for (final m in spend) {
    if (m.cents > 0 && (top == null || m.cents > top.cents)) top = m;
  }
  return top;
}
