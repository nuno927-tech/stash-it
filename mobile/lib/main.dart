/// Stash it, on a phone.
///
/// This file does three things and nothing else: open the encrypted database,
/// pick a theme, and hand off to the shell. Everything with a decision in it
/// lives under `logic/`, `db/` or `ui/`.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'billing/current.dart';
import 'billing/play_billing.dart';
import 'io/crash_log.dart';
import 'logic/crash_log.dart';
import 'db/open_flutter.dart';
import 'db/repository.dart';
import 'notify/sync.dart';
import 'ui/feedback.dart';
import 'ui/lock_gate.dart';
import 'ui/prefs_scope.dart';
import 'ui/settings_tab.dart' show appVersion;
import 'ui/shell.dart';
import 'ui/splash.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _catchEverything();

  /*
    The database is opened before the first frame, deliberately.

    Every screen reads from it immediately, and a splash that resolves into
    either an app or an error is easier to reason about than five screens each
    handling "the database is not ready yet". If `openEncrypted` throws —
    which it does, loudly, if SQLCipher failed to load — nothing renders and
    the crash names the reason.
  */
  final db = await openEncrypted();
  final repo = Repository(db);

  /*
    Preferences are read before the first frame too, and for a smaller but
    sharper reason: the theme. Painting dark and then switching to light a
    frame later is a flash on every launch for anybody who chose light, and it
    is the kind of thing that reads as the app being unsure of itself.
  */
  final prefs = PrefsController(repo);
  await prefs.load();

  /*
    ── The store, connected before the first frame ────────────────────────────

    Not awaited beyond construction: the connection itself is lazy and the
    paywall asks for a price when somebody opens it. What has to happen early
    is the purchase stream being listened to, because Play delivers a purchase
    that completed while the app was shut as an event on launch — and an
    unacknowledged purchase is refunded automatically after three days.

    Android only. Everywhere else `appBilling` stays `NoBilling`, which is the
    truthful answer rather than a stub that pretends.
  */
  if (Platform.isAndroid) {
    startBilling(PlayBilling(onUnlocked: repo.grantUnlock));
  }

  runApp(StashItApp(repo: repo, prefs: prefs));

  /*
    Rescheduling happens AFTER the first frame, and is deliberately not awaited.

    `horizonDays` is 60, so every pending notification was worked out at most
    two months ago and is re-derived on every launch — which means the schedule
    is never more than one app open out of date, and being a few hundred
    milliseconds late to fix it costs nothing. Blocking the splash on a plugin
    handshake, on the other hand, is how an app gets a reputation for being slow
    to open.
  */

  /*
    ── The sweep, which had never once run ────────────────────────────────

    `purgeExpiredDeletes` has existed since the repository was written, with a
    test proving it erases what is past thirty days, and nothing ever called
    it. Deleted records were accumulating in the database for ever: invisible,
    counted in no total, and carried into every backup.

    That is the same failure the bin screen was written to fix, one layer down
    — a green test on a function with no caller. On launch, before the
    reminders, because a swept record must not be scheduled.
  */
  unawaited(
    repo.purgeExpiredDeletes().then((_) => _wakeReminders(repo)),
  );

  // Three rising notes, once. See `Cue.launch` — it is the only cue in the set
  // allowed to have a shape, because it is heard at most once per launch.
  feedback(Cue.launch);
}

/*
  ── Writing down what nothing else would ────────────────────────────────────

  Two handlers, and between them they cover what escapes: one for errors thrown
  inside the widget machinery, one for asynchronous errors nothing awaited.

  Installed first, before the database is opened — the point is to catch the
  failure that stops the app starting, and a handler added after the thing that
  throws is a handler that was not there.

  ── `PlatformDispatcher.onError`, not `runZonedGuarded` ─────────────────────
  The zone version is the older advice and it interacts badly with the binding:
  `ensureInitialized` has already run in the root zone by the time a guarded
  zone could be entered, and a binding built in one zone with its errors
  delivered to another is a class of bug that shows up as reports arriving
  nowhere. The dispatcher hook has no such split.

  ── And neither one swallows anything ───────────────────────────────────────
  `FlutterError.onError`'s previous handler is still called, so a debug build
  still prints its console output and paints its red screen. This adds a
  record; a crash handler that quietly hides errors during development is how
  a release ships with three of them.
*/
void _catchEverything() {
  final wasFlutterError = FlutterError.onError;

  FlutterError.onError = (details) {
    unawaited(recordCrash(noteFor(
      error: details.exception,
      stack: details.stack,
      source: CrashSource.flutter,
      version: appVersion,
    )));

    wasFlutterError?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(recordCrash(noteFor(
      error: error,
      stack: stack,
      source: CrashSource.platform,
      version: appVersion,
    )));

    /*
      True: handled, and the app keeps running.

      False hands it on to the platform, which on Android ends the process. An
      unawaited future that failed — a plugin call, a file read — is rarely a
      reason to close somebody's app on them, and now that it is written down
      it is not a reason to lose it either.
    */
    return true;
  };
}

/*
  ── Asking for the notification permission, once ──────────────────────────

  Reminders are on by default, and on Android 13 and later "on" is not a thing
  the app can decide alone — the system has to be asked, and it only asks once
  per install.

  So the first launch asks, and the answer is written down whichever way it
  goes. Not asked again after that: `notifyAskedAt` is the record that the
  question has been put, and a prompt that returns is a prompt that gets
  dismissed by muscle memory rather than answered.

  After the first frame, deliberately. A permission dialog over a splash screen
  is a dialog about an app somebody has not seen yet.
*/
Future<void> _wakeReminders(Repository repo) async {
  final settings = await repo.settings();

  if (settings.notifyAskedAt == null && settings.notifyEnabled != false) {
    final granted = await notifications.ask();
    await repo.setNotify(enabled: granted);
  }

  await syncReminders(repo);
}

class StashItApp extends StatelessWidget {
  const StashItApp({required this.repo, required this.prefs, super.key});

  final Repository repo;
  final PrefsController prefs;

  @override
  Widget build(BuildContext context) {
    return PrefsScope(
      notifier: prefs,
      child: AnimatedBuilder(
        animation: prefs,
        builder: (context, _) => MaterialApp(
          title: 'Stash it',
          debugShowCheckedModeBanner: false,

          /*
            Both palettes are given, and `themeMode` chooses. Handing Flutter
            one resolved theme instead would make "match my device" a lie the
            moment the device changed its mind — at dusk, on a schedule, or
            because somebody turned on battery saver.
          */
          theme: stashTheme(dark: false),
          darkTheme: stashTheme(dark: true),
          themeMode: themeModeOf(prefs.theme),

          /*
            The gate is OUTSIDE the splash, and the nesting is the whole point.

            `Splash` paints its child underneath itself and fades to reveal it,
            so anything inside it is already built and already on screen. A
            lock in that position would be a picture of a lock over live
            records — visible the instant the fade finished, and captured by
            the task switcher's thumbnail regardless.

            Out here, `Shell` is not constructed until the gate opens, so there
            is nothing behind the lock to leak.
          */
          home: LockGate(
            repo: repo,
            child: Splash(child: Shell(repo: repo)),
          ),
        ),
      ),
    );
  }
}
