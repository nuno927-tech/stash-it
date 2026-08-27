# Stash it — the Flutter port

Phase 1 of the plan in `../Stash it/docs/flutter.md`: **the logic, headless.**
No UI, no database, no Flutter. Pure Dart functions and the assertions that
pin them.

This phase exists to de-risk the rest. If the arithmetic ports cleanly and the
tests go green, the remaining phases are work; if it does not, a week has been
spent rather than a quarter.

---

## Running it

Phase 1 needs **only the Dart SDK**, which ships inside Flutter. No emulator,
no Android Studio, no device.

```bash
cd "C:\Stash it APK"
dart pub get
dart test
```

If you have Flutter installed, `dart` is already on your path.

---

## The rules of this port

**1. Every function is a translation of a named function, not a rewrite.**
Each file says which TypeScript file it came from. When the two disagree, the
TypeScript is right until somebody decides otherwise on purpose.

**2. The comments come across with the code.** They are not decoration. Most
of them exist because something went wrong once — the DST bug, the clamped
month, the four field-pair reports — and a comment left behind in the old
language is a bug rediscovered in the new one.

**3. Every assertion comes across too.** The originals are
`check(label, boolean)` over pure functions, so they map onto `test`/`expect`
almost mechanically. Those 1,250 assertions are the institutional memory of
this app; the port is only trustworthy if they come with it.

**4. Nothing is verified until you run it.** See below.

---

## What is NOT verified

The Dart in this folder has never been compiled or executed. The environment
it was written in has no Dart SDK and no network route to one, so there was no
way to run `dart test` before handing it over.

Everything in `../Stash it` was written against 42 suites, a type check and a
build, and none of it shipped red. **This folder has had none of that.** Treat
the first `dart test` run as the real review — expect syntax errors and
missing imports, and send them back rather than working around them.

---

## Traps found on the way across

Two, both in the first file, and both the same shape as bugs this app has
already paid for once.

**`DateTime.add(Duration(days: 1))` is the JavaScript `+ 86400000` bug,
renamed.** A day is not always 24 hours. On the morning the clocks go back,
adding a day-Duration lands at 23:00 the same day. The answer in Dart is the
same as in JavaScript: build a new `DateTime` from year, month and day, and
let the constructor normalise. See `lib/logic/dates.dart`.

**`difference().inDays` truncates.** Across a clock change the gap between two
local midnights is 23 or 25 hours, and `.inDays` floors that to 0 or 1 — so
"days until this expires" would be wrong twice a year, in opposite directions.
Divide the milliseconds and round, exactly as the TypeScript does.

**And one difference to watch: Dart months are 1-based, JavaScript's are
0-based.** `new Date(y, 0, 1)` is January; `DateTime(y, 1, 1)` is January.
Every translated date construction has had one subtracted or added, and that
is the single most likely place for a silent off-by-one.

---

## Layout

```
lib/
  models/     ← src/db/types.ts, split by entity
  logic/      ← src/lib/*.ts, one file each
test/         ← one suite per logic file
```

Files arrive in dependency order. Nothing here imports `package:flutter`.

---

## What is deliberately not being ported

Some of the web app is scaffolding holding up a browser. It has no counterpart
here, and listing it is as much a part of the port as the translation is —
otherwise these come back one at a time as "missing features".

**`backstack.ts` — the Android back gesture.** The whole module, and it was the
single most jarring thing about the PWA on a phone. The app navigates by state
rather than by URL, so as far as the browser is concerned every screen is the
same page: the back swipe found nothing to go back to and left the app, from
the item detail, from the add form, from a full-screen photo. The fix was a
hand-rolled stack of handlers, one global `popstate` listener, and careful
bookkeeping so the browser's history depth and ours never disagreed.

Flutter's `Navigator` **is** that stack. Pushing a route gives the gesture
something to pop, and `PopScope` intercepts when a screen needs to ask first.
The bug and its 108 lines of fix both disappear.

**The push server.** `push.ts`, `pushSync.ts`, `pushClient.ts`, the Firebase
function, VAPID keys, the Firestore row per device, the weekly sync and the
service worker that received a deliberately empty push. All of it existed
because a browser cannot wake itself. `logic/reminders.dart` keeps the part
that was ever the feature — which days earn a wake, and what a lock screen is
allowed to say — and the OS does the rest. See the notes at the top of that
file.

**`ownsItsSwipe` and `inHorizontalScroller`.** Two DOM tree-walks that decided
whether a horizontal drag belonged to the shell or to something inside it,
because a browser delivers one touch to everything at once. Flutter's gesture
arena resolves that natively.

**`nudgeClass`.** Built a CSS class list, and existed because
`class="nudge warranty"` collided with an unrelated `.warranty` rule and pushed
one card's buttons off the screen. There is no global style namespace to
collide in.

**`sessionStorage` in `devmode.ts`.** A Flutter process is the session.

**The tip jar.** Dropped on request, not for technical reasons.

### And one thing that had to be rewritten rather than dropped

The tour's `notify` step told people that "the only thing that leaves this
phone is a delivery address and the days something is due". True of web push;
false here, where nothing leaves at all. Left alone it would have been the
port's most visible untruth, on the one screen written to earn trust.
`test/tour_test.dart` now fails if that phrasing returns.
