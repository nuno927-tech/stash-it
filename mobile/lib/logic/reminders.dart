/// Reminders that arrive while the app is closed.
///
/// Translated from `src/lib/push.ts` — and this is the file where the port
/// stops being a translation and starts being a simplification.
///
/// ── What the web version had to build, and why ────────────────────────────
/// A browser cannot wake itself. To notify anyone about anything, the web app
/// needed a server that knew WHEN to wake the phone and WHERE to send the ping
/// — so it needed VAPID keys, a Firebase function, a Firestore row per device,
/// a weekly sync, and a service worker to receive a push that deliberately
/// carried no payload. The notification text was composed on the device, parked
/// in Cache Storage, and read back by the worker, precisely so that the words
/// never crossed a network.
///
/// That whole apparatus exists to protect one property: **breach the server and
/// you have a set of push endpoints and a set of dates — not one item name,
/// price, passport or photograph.**
///
/// ── What a native app needs instead ───────────────────────────────────────
/// A scheduler. `flutter_local_notifications` hands the OS a list of local
/// instants and the text to show at each one, and the OS wakes the app. There
/// is no server, no key, no endpoint, no sync and no worker.
///
/// So the property the web design worked hard for becomes true by construction:
/// **nothing leaves the device, because there is nowhere for it to go.** Roughly
/// 250 lines of TypeScript across push.ts, pushSync.ts, pushClient.ts and the
/// Firebase function have no counterpart here, and the settings copy explaining
/// the tradeoff has nothing left to explain.
///
/// ── What survives, and it is the part that was always the point ───────────
/// Which days earn a wake, and what is said on them. That logic is unchanged
/// and is what this file is. See the note on `compose` — the reason a
/// notification says "Passport — Nuno" and not "Passport expires 11 Feb" is
/// about lock screens, not about servers, so it survives the move intact.
///
/// ── And one new constraint the web never had ──────────────────────────────
/// iOS will hold **64** pending local notifications per app and silently drops
/// the rest. See `maxPending`.
library;

import '../models/paper.dart';
import '../models/subscription.dart';
import '../models/types.dart';
import 'dates.dart';
import 'papers.dart';
import 'timeline.dart' show dayMonth;
import 'subscriptions.dart';
import 'deep_link.dart';
import 'warranty.dart';

/// What a notification says, collapsed and expanded.
class Note {
  const Note(this.title, this.body, [String? detail]) : _detail = detail;

  final String title;

  /// The one line a collapsed notification shows.
  final String body;

  final String? _detail;

  /*
    ── The expanded body ───────────────────────────────────────────────────

    Android shows a collapsed notification as one truncated line and expands
    it when somebody pulls it down. Those are two different jobs and they were
    being done by the same string.

    Collapsed has to survive being cut off mid-word on a lock screen, so it
    stays short. Expanded is where the detail goes — every record on the day
    with what is actually happening to it — because somebody who pulled the
    notification down has asked for exactly that.

    Falls back to the body, so a Note built without one still expands to
    something rather than to nothing.
  */
  String get detail => _detail ?? body;
}

/// One record wanting attention, and why.
class Due {
  const Due(this.label, this.why, this.link);

  /// "Passport — Nuno", "Bosch dishwasher".
  final String label;

  /// "expires Feb 11", "cover ends Mar 4", "renews Sep 1".
  ///
  /// Lower case and verb-first so it reads as a continuation of the label
  /// rather than as a sentence of its own: "Passport — Nuno · expires Feb 11".
  final String why;

  final DeepLink link;
}

/// One day the phone should be woken, and what to say when it is.
class Wake {
  const Wake(this.on, this.title, this.body,
      [this.payload = 'home', String? detail])
      : detail = detail ?? body;

  Wake.fromNote(this.on, Note note, [this.payload = 'home'])
      : title = note.title,
        body = note.body,
        detail = note.detail;

  /*
    ── Where the tap goes ────────────────────────────────────────────────────

    A notification that opens the app on whatever screen you last left has
    wasted the one moment it had — somebody tapped it because of the thing it
    named. See `logic/deep_link.dart` for the format.

    Defaulted rather than required so the sixty-odd existing constructions in
    the tests keep saying what they were written to say. A wake with no
    opinion about where to land goes to the dashboard, which is the same
    behaviour they had before this field existed.
  */
  final String payload;

  /// `YYYY-MM-DD`, local. Day granularity on purpose: the hour you did
  /// something is itself information, and nothing here needs it. The delivery
  /// hour is applied later, by `wakeTimes`.
  final String on;

  final String title;

  /// The one line a collapsed notification shows.
  final String body;

  /// Every record on the day, one per line, for the expanded view. See `Note`.
  final String detail;
}

/// How far ahead a schedule is worked out.
///
/// On the web this was how much one sync covered. Here it is how far ahead the
/// OS is handed instants — the app reschedules on every launch, so anything
/// beyond this is re-derived long before it matters.
const int horizonDays = 60;

/// The most notifications to leave pending with the OS.
///
/// **iOS caps this at 64 per app and drops the rest without telling you.**
/// Android has no documented hard limit but is not generous either. Sixty days
/// of a busy household is a handful of dates, so this only ever bites on a bug
/// — and truncating to the NEAREST ones is the right behaviour regardless: a
/// reminder eight weeks out is not urgent, and the schedule is rebuilt every
/// time the app opens.
///
/// The web version capped at 40 for a different reason — a long list of
/// instants uploaded to a server is a fingerprint. That reason is gone. This
/// one is a platform limit, which is why the number changed with it.
const int maxPending = 64;

/// Every date in the next `horizon` days on which something starts needing
/// you, with the sentence to show.
///
/// ── What earns a wake, and what does not ──────────────────────────────────
/// A DOCUMENT wakes you on its renew-by date: the day it stops being "fine"
/// and starts being "start now". Not its expiry — by then the point has gone,
/// which is the mistake the whole documents feature exists to avoid.
///
/// A WARRANTY wakes you the day it enters its ending-soon window, which is the
/// same threshold the ring and the list already use. One notification per
/// warranty, at the moment there is still time to act on it.
///
/// A SUBSCRIPTION wakes you ONLY IF YOU ASKED. A renewal is not an event you
/// need waking for — the money leaves whether you know or not, and nine
/// monthly services would mean nine notifications a month for nothing.
/// `remindDays` is the user saying this one is different.
List<Wake> reminderSchedule(
  List<Item> items,
  List<Subscription> subs,
  List<Paper> papers, [
  DateTime? now,
  int horizon = horizonDays,
]) {
  final at = now ?? DateTime.now();
  final today = startOfDay(at);
  final last = addDays(today, horizon);

  final byDay = <String, List<Due>>{};

  void add(DateTime? when, Due due) {
    if (when == null) return;
    final day = startOfDay(when);
    // Today counts — something crossing its threshold this morning is exactly
    // what a reminder is for. Yesterday does not: the moment has gone and the
    // dashboard is already carrying it.
    if (day.isBefore(today) || day.isAfter(last)) return;
    byDay.putIfAbsent(toIsoDate(day), () => []).add(due);
  }

  for (final paper in papers) {
    final expiry = expiryOf(paper);
    if (expiry == null) continue;
    add(
      renewBy(paper),
      Due(
        _named(paper),
        'expires ${dayMonth(expiry)}',
        DeepLink(LinkKind.paper, paper.id),
      ),
    );
  }

  for (final item in items) {
    final end = effectiveExpiry(item, at);
    if (end == null) continue;
    // The day the countdown turns amber, not the day the cover ends — and this
    // item's own lead if it was given one, so the reminder lands on the same
    // day the dashboard changes colour.
    add(
      addDays(end, -itemLeadDays(item)),
      Due(
        item.name,
        'cover ends ${dayMonth(end)}',
        DeepLink(LinkKind.item, item.id),
      ),
    );
  }

  for (final sub in subs) {
    final ask = sub.remindDays;
    if (ask == null || ask == 0) continue;
    final renews = nextRenewal(sub, at);
    if (renews == null) continue;
    add(
      addDays(renews, -ask),
      Due(
        sub.name,
        // The amount as well as the date. A renewal is the one reminder where
        // the number is the reason somebody would act on it — "renews Sep 1"
        // invites a shrug where "renews Sep 1 · 12.99" invites a decision.
        'renews ${dayMonth(renews)} · ${(sub.amountCents / 100).toStringAsFixed(2)}',
        DeepLink(LinkKind.sub, sub.id),
      ),
    );
  }

  final days = byDay.keys.toList()..sort();

  return [
    for (final on in days)
      Wake.fromNote(
        on,
        compose(byDay[on]!),
        /*
          One record on the day means the tap can open that record. Several
          means there is no single right answer — and picking the
          alphabetically first would be arbitrary in a way somebody would
          notice, because the notification named it first for a reason that
          has nothing to do with which one they care about.

          A busy day goes to the dashboard, which is already sorted
          soonest-first and is exactly the list the notification summarised.
        */
        encodeLink(byDay[on]!.length == 1
            ? byDay[on]!.single.link
            : const DeepLink.home()),
      ),
  ];
}

/// What the notification says.
///
/// ── Detail, and where it is safe to put it ────────────────────────────────
///
/// This used to say names and nothing else — "Passport — Nuno" and then
/// "Needs a look in Stash it." The reasoning was a lock screen a stranger can
/// read over your shoulder, and that reasoning was sound about the lock
/// screen and wrong about everything else: it also stripped the detail from
/// the notification shade on an unlocked phone, where nobody but the owner is
/// looking, and left a reminder that says something needs doing without
/// saying what or when.
///
/// So there are two bodies now.
///
/// **Collapsed** is one line that will be truncated, and gets the same
/// treatment as before: a name, or a count and two names. Short enough to
/// survive being cut off.
///
/// **Expanded** is what somebody sees after pulling the notification down —
/// every record on the day with its date, one per line. Pulling it down is a
/// deliberate act by whoever is holding the phone.
///
/// The lock screen is handled where it actually lives, which is not here:
/// `reschedule` marks these `NotificationVisibility.private`, so Android
/// redacts them on a locked phone and shows them in full once it is unlocked.
/// That is the setting that was always the right answer to the original
/// worry, and writing vaguer text was standing in for it.
///
/// Two named and the rest counted in the collapsed line, because a lock screen
/// truncates and a list of five names truncates to three names and an ellipsis
/// — which is a worse version of saying "and 3 more" on purpose.
Note compose(List<Due> due) {
  final sorted = [...due]..sort((a, b) => a.label.compareTo(b.label));

  if (sorted.isEmpty) {
    return const Note('Stash it', 'Needs a look in Stash it.');
  }

  // One line per record, for the expanded view. Same order as the collapsed
  // line, so the two read as the same list rather than as two lists.
  final lines = [for (final d in sorted) '${d.label} · ${d.why}'].join('\n');

  if (sorted.length == 1) {
    final only = sorted.single;
    return Note(only.label, _sentence(only.why), lines);
  }

  final names = [for (final d in sorted) d.label];
  final rest = names.length - 2;
  final listed = names.length == 2
      ? '${names[0]} and ${names[1]}'
      : '${names[0]}, ${names[1]} and $rest more';

  return Note('${names.length} things need you', listed, lines);
}

/// "expires Feb 11" becomes "Expires Feb 11." — the reason on its own line
/// wants to read as a sentence, where the same words after a name do not.
String _sentence(String why) => '${why[0].toUpperCase()}${why.substring(1)}.';

/// The dates alone, for showing someone what their schedule looks like.
///
/// On the web this was the only thing that was ever uploaded, and the test
/// suite asserted at length that it carried no names. Here it feeds a settings
/// screen and nothing else — but the assertion is worth keeping, because a
/// function that starts leaking names into a "just the dates" list is a
/// function whose name has stopped being true.
List<String> wakeDates(List<Wake> schedule) => [for (final w in schedule) w.on];

/// When a reminder should land, local. Nine in the morning unless asked.
const int defaultSendHour = 9;

/// The schedule as local instants, which is what the OS scheduler wants.
///
/// ── The web version's hardest paragraph, now deleted ──────────────────────
/// On the web these numbers were uploaded, and the note here ran to fifteen
/// lines explaining why a server had to be told roughly which band of the earth
/// you live in: a date alone fires at a fixed hour UTC, and a fixed hour UTC is
/// the middle of the night for most of the planet. It was a real privacy cost,
/// accepted because a reminder arriving at 3am is a reminder you switch off.
///
/// **That cost is simply gone.** These instants are handed to the operating
/// system on the same device that computed them. Nobody learns your offset,
/// because nobody is told anything.
///
/// Built through the `DateTime` constructor rather than by adding hours, so the
/// result is right across a clock change instead of an hour out twice a year.
List<DateTime> wakeTimes(List<Wake> schedule, [int hour = defaultSendHour]) {
  final out = <DateTime>[];
  for (final w in schedule) {
    final day = parseDate(w.on);
    if (day == null) continue;
    out.add(DateTime(day.year, day.month, day.day, hour));
  }
  out.sort();
  return out;
}

/// The schedule trimmed to what the OS will actually hold, soonest first.
List<Wake> pending(List<Wake> schedule) {
  final out = [...schedule]..sort((a, b) => a.on.compareTo(b.on));
  return out.length <= maxPending ? out : out.sublist(0, maxPending);
}

/// Whatever should be said today, or null on a day with nothing on it.
Wake? noteFor(List<Wake> schedule, [DateTime? now]) {
  final today = toIsoDate(startOfDay(now ?? DateTime.now()));
  for (final w in schedule) {
    if (w.on == today) return w;
  }
  return null;
}

/// "Nuno's passport" reads better than "Passport" on a lock screen.
String _named(Paper paper) {
  final who = paper.holder?.trim();
  return who != null && who.isNotEmpty ? '${paper.label} — $who' : paper.label;
}
