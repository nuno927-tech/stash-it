# If Stash it were Flutter

A mock-up, not a plan of record. Written so the decision can be made against
real numbers and real code rather than an impression of how hard it might be.

Nothing in here is committed to. The app ships as a PWA today and that is not
in question.

---

## What actually transfers

Measured, not guessed:

| | lines | fate |
|---|---:|---|
| UI (`.tsx`) | 11,252 | rewritten as widgets |
| CSS | 5,693 | **deleted** — Flutter has no stylesheet |
| Pure logic (`lib/*.ts`, no browser) | 4,124 | translated, near line-for-line |
| Platform logic (db, backup, push, photo, lock) | ~4,800 | rewritten against packages |
| Tests | 7,026 / **1,250 assertions** | translated, near line-for-line |

The two big numbers are the honest ones: **seventeen thousand lines of UI and
CSS go in the bin**, and no amount of tooling changes that. Flutter does not
read HTML.

### The part that is better than it first looks

I said earlier that a rewrite would throw away the 1,250 assertions. Having
looked at them again, that is wrong and worth correcting.

The tests are not written against a framework. They are `check(label, boolean)`
over pure functions — no DOM, no React, no test runner beyond `node`. That maps
onto Dart's `test`/`expect` almost mechanically:

```ts
// test/subs.test.ts, today
check('a monthly anchored on the 31st clamps to February', 
  toISO(nextRenewal(sub({ anchorDate: '2026-01-31' }), new Date(2026, 1, 5))) === '2026-02-28');
```

```dart
// the same assertion, in Dart
test('a monthly anchored on the 31st clamps to February', () {
  expect(
    nextRenewal(sub(anchorDate: '2026-01-31'), DateTime(2026, 2, 5)),
    DateTime(2026, 2, 28),
  );
});
```

That matters more than the line count suggests. Those assertions are where the
DST bug, the clamped-month stepping and the timezone sweep bug are pinned. They
are the institutional memory of this app, and they survive the move.

---

## Package mapping

Everything the web platform gave for free has to be named explicitly.

| Today | Flutter |
|---|---|
| IndexedDB via Dexie | **Drift** (SQLite, typed queries, migrations) |
| `fflate` zip export | `archive` |
| Web Push + VAPID + Firebase sender | **`flutter_local_notifications`** — and the whole sender goes away |
| Service worker | nothing. There is no offline problem to solve |
| `navigator.share` | `share_plus` |
| Web Share Target | Android intent filter + iOS share extension — **works on iOS, which it never did** |
| `<input type=file capture>` | `image_picker` |
| WebAuthn passkey lock | `local_auth` |
| `navigator.vibrate` | `HapticFeedback` (built in) |
| CSS custom properties | `ThemeData` + a `ColorScheme` |
| `localStorage` / prefs | `shared_preferences` |

**The line that justifies the exercise:** `flutter_local_notifications`
schedules on the device. No server, no VAPID pair, no Firestore, no hourly
sweep, no IP address seen weekly, no $10/year. The privacy policy loses its
"two exceptions" section and keeps one.

---

## Structure

Deliberately the same shape, so the two can be read side by side:

```
lib/
  models/        item.dart, paper.dart, subscription.dart   ← src/db/types.ts
  data/          database.dart (Drift), repo.dart           ← src/db/
  logic/         warranty.dart, subscriptions.dart,
                 papers.dart, timeline.dart, search.dart,
                 nudges.dart, reminders.dart                ← src/lib/*.ts
  ui/
    screens/     home.dart, items.dart, subs.dart,
                 papers.dart, settings.dart                 ← src/screens/
    widgets/     scout.dart, item_row.dart, warranty_ring.dart,
                 swipe_row.dart, cover_list.dart            ← src/components/
  theme.dart                                                ← src/styles/tokens.css
test/            one file per logic file                    ← test/
```

---

## The code, translated

### Dates — the one that has already cost a bug

Today:

```ts
export function addDays(from: Date, days: number): Date {
  return new Date(from.getFullYear(), from.getMonth(), from.getDate() + days);
}
```

Dart:

```dart
/// Add days by the calendar, never by milliseconds.
///
/// A day is not 86,400,000 ms. Twice a year it is an hour more or less, and
/// adding a Duration on the morning the clocks go back lands at 23:00 the
/// SAME day. This is the same bug in Dart as it was in JavaScript —
/// `DateTime.add(Duration(days: 1))` is the trap, and the constructor is the
/// answer, because it normalises overflow and resolves to real local midnight.
DateTime addDays(DateTime from, int days) =>
    DateTime(from.year, from.month, from.day + days);
```

Worth noting: **the trap is identical in Dart.** `DateTime.add(Duration(days:
1))` is exactly `getTime() + DAY`. The comment has to move with the code.

### Clamped months

```dart
/// A subscription anchored on the 31st renews on the 30th in April and the
/// 28th in February — what the card issuer does. Rolling into the 1st of the
/// next month instead puts the renewal in the wrong month and shifts every
/// date after it.
DateTime addMonthsClamped(DateTime from, int months) {
  final m = from.month + months;
  final lastDay = DateTime(from.year, m + 1, 0).day;
  return DateTime(from.year, m, min(from.day, lastDay));
}
```

Dart's `DateTime` normalises month overflow the same way, so this is a direct
transliteration — `DateTime(2026, 13, 1)` is January 2027.

### A per-record lead time

```dart
/// A roof and a kettle do not deserve the same warning.
///
/// `??` and not `?:` — zero is a real answer, "tell me on the day", and only
/// null falls back. Dart's null-aware operator does the right thing here where
/// JavaScript's `||` did not.
int itemLeadDays(Item item, int globalWindow) => item.leadDays ?? globalWindow;
```

### The theme — 5,693 lines of CSS become about 60

```dart
/// The `--slate-*` names are roles, not colours: 900 is furthest from the
/// reader, 600 nearest, in both themes. Read as an elevation ramp.
class Tokens {
  static const slate900 = Color(0xFF0D0F12);
  static const slate800 = Color(0xFF15181D);
  static const slate700 = Color(0xFF1F242B);
  static const gold     = Color(0xFFF2B33D);
  static const moss     = Color(0xFF5FBF7E);
  static const ember    = Color(0xFFE05A44);
}

final darkTheme = ThemeData(
  colorScheme: const ColorScheme.dark(
    surface: Tokens.slate900,
    primary: Tokens.gold,
    error: Tokens.ember,
  ),
  textTheme: const TextTheme(
    // Bricolage Grotesque at weight 200, as the display face
    displayLarge: TextStyle(fontFamily: 'Bricolage', fontWeight: FontWeight.w200),
  ),
);
```

**What is lost:** the cascade. Every one of the `check-css` guards exists
because a stylesheet lets a rule reach somewhere it was not meant to — the
Scout height overridden by a presentational hint, the field pair pushed down
13px by a sibling rule, the hint tucked six pixels over an input. None of those
bugs is expressible in Flutter, because a widget's padding is a number passed
to that widget and nothing else can reach it.

`scripts/check-css.mjs` and its seven guards are deleted. That is a real gain
and it is easy to undersell.

### A widget, for the shape of it

The backup line, which today is a `<button class="backline">` plus 60 lines of
CSS:

```dart
/// One line about the only copy of everything. Quiet when it is good news and
/// one step louder when it is not — an alarm that is always on is furniture.
class BackupLine extends StatelessWidget {
  const BackupLine({super.key, required this.status, required this.onTap});

  final BackupStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Tokens.slate700,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(children: [
          _Dot(tone: s.tone),
          const SizedBox(width: 9),
          Expanded(child: Text(s.label, style: const TextStyle(fontSize: 12))),
          Text(s.tone == BackupTone.ok ? 'Back up' : 'Back up now',
              style: const TextStyle(fontSize: 11.5, color: Tokens.gold)),
        ]),
      ),
    );
  }
}
```

Longer than the JSX, shorter than JSX plus CSS, and the spacing is visible at
the point of use rather than three thousand lines away in a stylesheet.

---

## Phases

Each one ends somewhere you could stop.

**1 — The logic, headless.** `logic/` and `test/`, no UI at all. Translate the
4,124 pure lines and the 1,250 assertions. Nothing renders; everything is
proven. This is the phase that de-risks the rest, and if it goes badly you have
lost a week rather than a quarter.

**2 — Data.** Drift schema from `types.ts`, and a one-way importer that reads a
`.stashit` backup file. That importer is the migration path for every existing
user, and it must exist before anyone is asked to switch.

**3 — Read-only UI.** Dashboard, three lists, item detail. No forms. Enough to
open a real backup and see whether it looks like the app.

**4 — Forms and the rest.** Add, edit, delete, swipe, photos, share.

**5 — Reminders.** `flutter_local_notifications`, and the Firebase sender is
deleted rather than ported.

**6 — Ship.** Two stores, one codebase.

---

## What gets better

- **No server, no domain, no hosting.** Reminders schedule locally.
- **The privacy claim becomes absolute.** "Nothing leaves your phone", no asterisk.
- **iOS becomes real.** Share target, notifications and installability all work,
  none of which the PWA can do properly on an iPhone.
- **Whole classes of bug stop existing** — the cascade, service-worker
  handover, `beforeinstallprompt`, storage eviction.
- **Encryption gets easy.** SQLCipher on Drift, keyed from `local_auth`. The
  documents feature could finally hold a scan and a number.

## What gets worse

- **Seventeen thousand lines of working UI, deleted.**
- **A new language**, and the toolchain that comes with it.
- **Every fix waits on review.** No more deploy-and-it's-live.
- **No web version**, unless you keep both — and two codebases drift, which
  this repository has a whole test file about.
- **You need a Mac**, or a cloud one, from phase 6 onward.

---

## The honest summary

This is a two-to-three month project for one person, and it buys one thing that
matters — the server going away — plus several that are nice.

**Capacitor buys that same one thing in days**, and keeps the web version.

Flutter is the right answer if the app's future is "a proper mobile app on both
stores" and the web was always a means to an end. It is the wrong answer if the
web version is a product in its own right, because then you are maintaining two
of everything for one capability.

Worth revisiting once there are users and it is clear which of those is true.
Not worth deciding before.
