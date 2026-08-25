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
import 'db/tables.dart';
import 'notify/sync.dart';
import 'ui/shell.dart';

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
  runApp(StashItApp(db: db));

  /*
    Rescheduling happens AFTER the first frame, and is deliberately not awaited.

    `horizonDays` is 60, so every pending notification was worked out at most
    two months ago and is re-derived on every launch — which means the schedule
    is never more than one app open out of date, and being a few hundred
    milliseconds late to fix it costs nothing. Blocking the splash on a plugin
    handshake, on the other hand, is how an app gets a reputation for being slow
    to open.
  */
  unawaited(syncReminders(Repository(db)));
}

class StashItApp extends StatelessWidget {
  const StashItApp({required this.db, super.key});

  final StashDatabase db;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stash it',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          // The gold from the web app, which is the one piece of the old
          // design worth carrying across before the rest is drawn.
          seedColor: const Color(0xFFF2B33D),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Shell(repo: Repository(db)),
    );
  }
}
