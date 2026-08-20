/// One list of everything with a date on it, across all three kinds of record.
///
/// Translated from `src/lib/timeline.ts`.
///
/// ── Why this exists ───────────────────────────────────────────────────────
/// The dashboard used to carry three separate "next up" rows — the soonest
/// warranty, the soonest renewal, the soonest document — each sorted only
/// against its own kind and each in its own visual language. So a passport that
/// needed starting last week sat below an inspection that expires in a month,
/// purely because they were in different sections. Nobody thinks in sections.
/// The question is "what should I deal with", and only a merged list can
/// answer it.
///
/// ── Ranked by consequence, not by date ────────────────────────────────────
/// A strictly chronological list gets this wrong in a specific and expensive
/// way: Netflix charging $15 on Friday comes above a passport that already
/// needed starting, because Friday is sooner than "should have begun in June".
/// One of those is a direct debit and the other is a cancelled holiday.
///
/// So there are buckets, and dates only sort within them:
///
///   overdue  the date has passed and it still matters
///   now      it is inside the window where acting is the whole point
///   soon     within a week
///   later    everything else on the horizon
///
/// ── What is deliberately not in here ──────────────────────────────────────
/// LAPSED WARRANTIES. An expired warranty is not a thing you can act on — the
/// cover is gone, and the item is still yours. Putting every lapsed item at the
/// top of the list would bury the things that are still saveable under a pile
/// of things that aren't. The Items tab has a Lapsed filter for looking at them
/// on purpose.
///
/// A lapsed PASSPORT is a different matter and does appear, because an expired
/// document is a problem you still have to solve. The asymmetry is the point.
library;

import '../models/paper.dart';
import '../models/subscription.dart';
import '../models/types.dart';
import 'dates.dart';
import 'papers.dart';
import 'subscriptions.dart';
import 'warranty.dart';

enum TimelineKind { item, subscription, paper }

/// Ordering buckets. The order of the members is the sort key; the names are
/// the meaning.
///
/// An enum rather than the TypeScript's rank map, because Dart enums carry
/// `index` and comparing those is the same comparison the map was doing by
/// hand — with the compiler checking that every case is covered.
enum Urgency { overdue, now, soon, later }

class Entry {
  const Entry({
    required this.key,
    required this.kind,
    required this.id,
    required this.title,
    required this.detail,
    required this.urgency,
    required this.days,
    required this.flagged,
  });

  /// Unique across kinds — two records can share an id in different tables.
  final String key;
  final TimelineKind kind;
  final String id;
  final String title;

  /// The second line: what is happening and when.
  final String detail;
  final Urgency urgency;

  /// Days until the date this is about. Negative once it has passed.
  final int days;

  /// Whether to draw attention to the row.
  ///
  /// True for anything overdue or inside its window — the things the screen is
  /// for. Everything else is a list you are reading, not a thing shouting.
  final bool flagged;
}

/// How far ahead the list looks, per kind.
///
/// Subscriptions get a month, which on a list of nine monthly services is
/// roughly all of them — that is fine, because the list shows the nearest few
/// and the rest are behind "show more". Items use the app's own "ending soon"
/// definition rather than a second threshold invented here, so the dashboard
/// and the warranty colour always agree about what counts as soon.
const int _subHorizon = 30;
const int _paperHorizon = 30;

List<Entry> buildTimeline(
  List<Item> items,
  List<Subscription> subs,
  List<Paper> papers, [
  DateTime? now,
]) {
  final at = now ?? DateTime.now();
  final out = <Entry>[];

  /* ------------------------------------------------------------ warranties */

  for (final item in items) {
    // Only cover that is running out. See the note above on lapsed items.
    if (warrantyState(item, at) != WarrantyState.endingSoon) continue;
    final end = effectiveExpiry(item, at);
    if (end == null) continue;

    final days = daysUntil(end, at);
    out.add(Entry(
      key: 'item:${item.id}',
      kind: TimelineKind.item,
      id: item.id,
      title: item.name,
      detail: 'Warranty ends ${dayMonth(end)}',
      urgency: days <= 7 ? Urgency.soon : Urgency.later,
      days: days,
      flagged: false,
    ));
  }

  /* --------------------------------------------------------- subscriptions */

  for (final sub in subs) {
    final renews = nextRenewal(sub, at);
    final days = daysUntilRenewal(sub, at);
    if (renews == null || days == null || days > _subHorizon) continue;

    /*
      A reminder is what promotes a renewal out of the ordinary run of them.
      Without it every monthly service would sit in the same bucket and the one
      you asked to be told about would be indistinguishable from the eight you
      didn't. This is the only thing `remindDays` does, and it does more than
      the banner it replaced: it changes where the row sorts, rather than
      adding a second card saying the same thing further up the page.
    */
    final flagged = reminderDue(sub, at);
    out.add(Entry(
      key: 'sub:${sub.id}',
      kind: TimelineKind.subscription,
      id: sub.id,
      title: sub.name,
      detail: 'Renews ${dayMonth(renews)}',
      urgency: flagged
          ? Urgency.now
          : days <= 7
              ? Urgency.soon
              : Urgency.later,
      days: days,
      flagged: flagged,
    ));
  }

  /* -------------------------------------------------------------- documents */

  for (final paper in papers) {
    final state = paperState(paper, at);
    final end = expiryOf(paper);

    // An unreadable date cannot be placed on a timeline, and inventing a
    // position for it would put it somewhere confident and wrong.
    if (end == null) continue;

    if (state == PaperState.expired) {
      out.add(Entry(
        key: 'paper:${paper.id}',
        kind: TimelineKind.paper,
        id: paper.id,
        title: _named(paper),
        detail: 'Expired ${dayMonth(end)}',
        urgency: Urgency.overdue,
        days: daysUntilExpiry(paper, at) ?? 0,
        flagged: true,
      ));
      continue;
    }

    if (state == PaperState.renew) {
      out.add(Entry(
        key: 'paper:${paper.id}',
        kind: TimelineKind.paper,
        id: paper.id,
        title: _named(paper),
        detail: 'Start now · expires ${dayMonth(end)}',
        urgency: Urgency.now,
        days: daysUntilRenewBy(paper, at) ?? 0,
        flagged: true,
      ));
      continue;
    }

    // Still fine, but the day to begin is close enough to mention.
    final start = renewBy(paper);
    final left = daysUntilRenewBy(paper, at);
    if (start == null || left == null || left > _paperHorizon) continue;
    out.add(Entry(
      key: 'paper:${paper.id}',
      kind: TimelineKind.paper,
      id: paper.id,
      title: _named(paper),
      detail: 'Start ${dayMonth(start)}',
      urgency: left <= 7 ? Urgency.soon : Urgency.later,
      days: left,
      flagged: false,
    ));
  }

  return sortTimeline(out);
}

/// Bucket first, then soonest, then alphabetically.
///
/// The last one only decides ties, but it has to be there: without it two
/// renewals on the same day swap places between renders, and a list that
/// reorders itself while you look at it reads as broken.
List<Entry> sortTimeline(List<Entry> entries) {
  final out = [...entries];
  out.sort((a, b) {
    final bucket = a.urgency.index - b.urgency.index;
    if (bucket != 0) return bucket;
    if (a.days != b.days) return a.days - b.days;
    return a.title.compareTo(b.title);
  });
  return out;
}

/// How many need doing something about, for the count beside the heading.
int flaggedCount(List<Entry> entries) => entries.where((e) => e.flagged).length;

/// The right-hand column of a row.
///
/// Days rather than a date — the date is already on the line to the left, and
/// this column exists to be compared down the page.
///
/// THE 'NOW' CASE IS NOT A COUNTDOWN, and getting that wrong is easy. A
/// passport inside its lead time passed its renew-by months ago, so `days` is a
/// large negative number; printing it as "today" is a small lie and printing it
/// as "62 days late" is a bigger one, because the passport does not expire
/// until February and nothing is actually late. The window to act comfortably
/// is open, which is a state and not a duration.
String whenLabel(Urgency urgency, int days) {
  if (urgency == Urgency.overdue) return '${days.abs()} days late';
  if (urgency == Urgency.now) return 'now';
  if (days <= 0) return 'today';
  if (days == 1) return 'tomorrow';
  return '$days days';
}

/// The same thing, given a row.
String whenLabelFor(Entry e) => whenLabel(e.urgency, e.days);

/// "Nuno's passport" reads better than "Passport" in a mixed list.
String _named(Paper paper) {
  final who = paper.holder?.trim();
  return who != null && who.isNotEmpty ? '${paper.label} — $who' : paper.label;
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Aug 17".
///
/// ── A deliberate difference from the web app ──────────────────────────────
/// The TypeScript calls `toLocaleDateString(undefined, …)`, so the browser's
/// locale decides between "Aug 17" and "17 Aug". That is the right default on
/// the web and the wrong one to reproduce here with a hand-rolled table: this
/// is fixed American formatting, matching the language the rest of the app was
/// standardised on.
///
/// When phase 3 brings the UI it also brings `intl`, and this becomes
/// `DateFormat.MMMd()` — locale-aware for real, rather than a guess with a
/// month list in it. Until then, one format everywhere beats twelve.
String dayMonth(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/* --------------------------------------------------------------- the ring */

/// One count, split by what it is made of.
class KindSplit {
  const KindSplit(this.items, this.papers);
  final int items;
  final int papers;

  int get total => items + papers;
}

class DatedTally {
  const DatedTally({
    required this.inDate,
    required this.noDate,
    required this.percent,
    required this.items,
    required this.papers,
    required this.needsStartingBy,
    required this.lapsedBy,
    required this.noDateBy,
  });

  final int inDate;

  /// Records with nothing to count from. Not drawn, and not in the divisor.
  final int noDate;

  /// 0..100, whole.
  final int percent;

  /// Raw row counts, for "4 items · 4 documents" beside the ring.
  final int items;
  final int papers;

  /*
    The two action figures, split by kind — and the reason is a bug.

    Both counts span warranties and documents, but the chips beneath the ring
    opened the ITEMS list with a filter. Tap "2 action needed" on a house whose
    two are both passports and you land on an empty items screen: the number was
    right, the destination was wrong, and the app looked like it had lost them.

    A total cannot answer "where do these live", so it no longer has to — and
    unlike the TypeScript, which carried both the totals and the splits as
    separate fields that could drift apart, the totals here are derived.
  */
  final KindSplit needsStartingBy;
  final KindSplit lapsedBy;
  final KindSplit noDateBy;

  int get needsStarting => needsStartingBy.total;
  int get lapsed => lapsedBy.total;
}

/// What the ring counts.
///
/// ── Subscriptions are not in here, and it took drawing them to see why ────
/// A subscription cannot lapse. It renews, and then it renews again. Counting
/// nine of them as nine healthy units would have inflated "still in date" with
/// things that were never at risk of anything — the number would go up when you
/// added a service and down when you cancelled one, which is exactly backwards.
/// The ring counts what can actually run out: warranties and documents. The
/// signature is the proof — it does not take subscriptions.
///
/// ── Undated records are excluded from both the ring and the percentage ────
/// An item with no warranty length recorded is not a failure, it is a blank.
/// Including it as a fourth arc would mean the picture and the number disagree
/// — the green wedge would look like 70% next to a headline reading 77% — and
/// putting it in the divisor would mean the score DROPS when you add a record,
/// which punishes the one behaviour the app wants.
///
/// So it is counted, reported beside the ring, and left out of the maths.
DatedTally datedTally(List<Item> items, List<Paper> papers, [DateTime? now]) {
  final at = now ?? DateTime.now();

  var inDate = 0;
  var needStartItems = 0, needStartPapers = 0;
  var lapsedItems = 0, lapsedPapers = 0;
  var noDateItems = 0, noDatePapers = 0;

  for (final item in items) {
    switch (warrantyState(item, at)) {
      case WarrantyState.covered:
        inDate++;
        break;
      case WarrantyState.endingSoon:
        needStartItems++;
        break;
      case WarrantyState.expired:
        lapsedItems++;
        break;
      case WarrantyState.unknown:
        noDateItems++;
        break;
    }
  }

  for (final paper in papers) {
    if (expiryOf(paper) == null) {
      noDatePapers++;
      continue;
    }
    switch (paperState(paper, at)) {
      case PaperState.valid:
        inDate++;
        break;
      case PaperState.renew:
        needStartPapers++;
        break;
      case PaperState.expired:
        lapsedPapers++;
        break;
    }
  }

  final tracked =
      inDate + needStartItems + needStartPapers + lapsedItems + lapsedPapers;

  return DatedTally(
    inDate: inDate,
    noDate: noDateItems + noDatePapers,
    percent: tracked == 0 ? 0 : (inDate / tracked * 100).round(),
    items: items.length,
    papers: papers.length,
    needsStartingBy: KindSplit(needStartItems, needStartPapers),
    lapsedBy: KindSplit(lapsedItems, lapsedPapers),
    noDateBy: KindSplit(noDateItems, noDatePapers),
  );
}

/// Where tapping one of those counts should land.
///
/// `null` means nowhere — a zero has nothing to show, and a chip that navigates
/// to an empty screen is the bug this exists to fix.
///
/// When a count is made of one kind only, it goes to that kind's screen. When
/// it is made of both, items wins: it is the larger list on almost every
/// install, and the documents tab already sorts anything needing action to its
/// top, so the other half is one tap away and visible on arrival.
enum Destination { items, papers }

Destination? destinationFor(KindSplit split) {
  if (split.items > 0) return Destination.items;
  if (split.papers > 0) return Destination.papers;
  return null;
}
