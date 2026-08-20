/// Calendar arithmetic.
///
/// Translated from the date functions in `src/lib/subscriptions.ts` and
/// `src/lib/warranty.ts`, gathered here because every other logic file depends
/// on them and because this is where the app's most expensive bug lived.
///
/// ── Read this before changing anything below ──────────────────────────────
/// A day is not 86,400,000 milliseconds. Twice a year it is one hour more or
/// less, and every function here is written the long way round because of it.
/// The JavaScript version shipped `date.getTime() + DAY` once: a weekly
/// subscription anchored on a Monday started renewing on Sundays for the whole
/// winter half of the year, and a loop stepping a cursor forward a day at a
/// time stopped moving altogether and ran until its guard. Both were silent.
///
/// **Dart has the identical trap under a different name.**
/// `DateTime.add(Duration(days: 1))` adds 24 hours, not one day. Do not use it
/// for calendar work. The constructor is the answer: it normalises overflow —
/// day 32 of January is 1 February — and always resolves to real local
/// midnight, whatever the clocks did.
///
/// ── And one difference from JavaScript that will bite ─────────────────────
/// Dart months are 1-based. JavaScript's are 0-based. `new Date(y, 0, 1)` and
/// `DateTime(y, 1, 1)` are both January. Every construction translated from
/// the TypeScript has had one added, and this is the likeliest place in the
/// whole port for a silent off-by-one.
library;

/// Local midnight, so comparisons are about days rather than hours.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Add days by the calendar, never by duration.
///
/// See the note at the top of the file. `from.add(Duration(days: days))` is
/// the wrong answer and looks like the right one.
DateTime addDays(DateTime from, int days) =>
    DateTime(from.year, from.month, from.day + days);

/// Whole days between two dates.
///
/// Rounded, and not `difference().inDays`, which truncates. Across a clock
/// change the gap between two local midnights is 23 or 25 hours; `.inDays`
/// floors that to 0 or 1 and the countdown is wrong twice a year in opposite
/// directions. Dividing the milliseconds and rounding gives the calendar
/// answer, which is the one every screen means.
int daysBetween(DateTime from, DateTime to) =>
    (to.difference(from).inMilliseconds / Duration.millisecondsPerDay).round();

/// Whole days from `from` to `target`, both taken as calendar dates.
///
/// Negative once the target has passed. Both ends are normalised to local
/// midnight first so a target this afternoon and a target this morning are
/// both "today".
int daysUntil(DateTime target, [DateTime? from]) =>
    daysBetween(startOfDay(from ?? DateTime.now()), startOfDay(target));

/// Add months, clamping to the end of the target month.
///
/// A subscription anchored on the 31st renews on the 30th in April and the
/// 28th in February — which is what the card issuer does. Rolling forward into
/// the 1st of the next month instead would put the renewal in the wrong month
/// on the calendar and quietly shift every date after it.
///
/// `DateTime(y, m + 1, 0)` is the last day of month `m`: day zero of a month
/// is the last day of the one before it, in Dart as in JavaScript.
DateTime addMonthsClamped(DateTime from, int months) {
  final m = from.month + months;
  final lastDay = DateTime(from.year, m + 1, 0).day;
  return DateTime(from.year, m, from.day < lastDay ? from.day : lastDay);
}

/// Parse `YYYY-MM-DD` as a local calendar date, not UTC midnight.
///
/// Returns null rather than throwing, and rejects dates that do not exist:
/// `DateTime.parse` and the constructor both roll 2026-02-31 forward to March
/// without complaint, which turns a typo into a date the user never chose.
DateTime? parseDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso.trim());
  if (m == null) return null;

  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final da = int.parse(m.group(3)!);

  final d = DateTime(y, mo, da);
  return d.year == y && d.month == mo && d.day == da ? d : null;
}

/// `YYYY-MM-DD` from a local date.
String toIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
