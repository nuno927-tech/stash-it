/// Stash it, on a phone.
///
/// This file does three things and nothing else: open the encrypted database,
/// pick a theme, and hand off to the shell. Everything with a decision in it
/// lives under `logic/`, `db/` or `ui/`.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'db/open_flutter.dart';
import 'db/repository.dart';
import 'notify/sync.dart';
import 'ui/feedback.dart';
import 'ui/prefs_scope.dart';
import 'ui/shell.dart';
import 'ui/splash.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

          home: Splash(child: Shell(repo: repo)),
        ),
      ),
    );
  }
}
