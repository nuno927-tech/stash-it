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
import 'subscriptions.dart';
import 'warranty.dart';

/// The two lines of a notification.
class Note {
  const Note(this.title, this.body);
  final String title;
  final String body;
}

/// One day the phone should be woken, and what to say when it is.
class Wake {
  const Wake(this.on, this.title, this.body);

  Wake.fromNote(this.on, Note note)
      : title = note.title,
        body = note.body;

  /// `YYYY-MM-DD`, local. Day granularity on purpose: the hour you did
  /// something is itself information, and nothing here needs it. The delivery
  /// hour is applied later, by `wakeTimes`.
  final String on;

  final String title;
  final String body;
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

  final byDay = <String, List<String>>{};

  void add(DateTime? when, String label) {
    if (when == null) return;
    final day = startOfDay(when);
    // Today counts — something crossing its threshold this morning is exactly
    // what a reminder is for. Yesterday does not: the moment has gone and the
    // dashboard is already carrying it.
    if (day.isBefore(today) || day.isAfter(last)) return;
    byDay.putIfAbsent(toIsoDate(day), () => []).add(label);
  }

  for (final paper in papers) {
    if (expiryOf(paper) == null) continue;
    add(renewBy(paper), _named(paper));
  }

  for (final item in items) {
    final end = effectiveExpiry(item, at);
    if (end == null) continue;
    // The day the countdown turns amber, not the day the cover ends — and this
    // item's own lead if it was given one, so the reminder lands on the same
    // day the dashboard changes colour.
    add(addDays(end, -itemLeadDays(item)), item.name);
  }

  for (final sub in subs) {
    final ask = sub.remindDays;
    if (ask == null || ask == 0) continue;
    final renews = nextRenewal(sub, at);
    if (renews == null) continue;
    add(addDays(renews, -ask), sub.name);
  }

  final days = byDay.keys.toList()..sort();
  return [for (final on in days) Wake.fromNote(on, compose(byDay[on]!))];
}

/// What the notification says.
///
/// NAMES, NOT DETAIL. "Passport — Nuno" is enough to know what it's about and
/// costs nothing on a lock screen a stranger can read; "Passport expires 11
/// Feb, renew now" is the same information broadcast to anyone glancing at the
/// phone on a table. Everything else is one tap away in an app that can ask for
/// a fingerprint first.
///
/// Two named and the rest counted, because a lock screen truncates and a list
/// of five names truncates to three names and an ellipsis — which is a worse
/// version of saying "and 3 more" on purpose.
Note compose(List<String> labels) {
  final names = [...labels]..sort();

  if (names.isEmpty) return const Note('Stash it', 'Needs a look in Stash it.');
  if (names.length == 1) return Note(names.first, 'Needs a look in Stash it.');

  final rest = names.length - 2;
  final listed = names.length == 2
      ? '${names[0]} and ${names[1]}'
      : '${names[0]}, ${names[1]} and $rest more';

  return Note('${names.length} things need you', listed);
}

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
