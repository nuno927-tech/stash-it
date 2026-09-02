/// Asking the launcher to put one of our widgets on the home screen.
///
/// ── Why this exists at all ─────────────────────────────────────────────────
/// The three widgets are the one part of this app that lives somewhere the app
/// cannot reach. Adding one means long-pressing an empty patch of home screen,
/// finding a picker that every launcher draws differently, and scrolling to S.
/// Nobody discovers that from inside an app, and Settings could only ever have
/// described it.
///
/// Android 8.0 added `requestPinAppWidget`. minSdk is 26, so it is there on
/// every phone this app runs on — but it is the LAUNCHER that implements it,
/// and a launcher is free not to. So [canPinWidgets] is asked first and the
/// card falls back to the sentence.
///
/// It is a request, not a grab: the launcher shows its own confirmation, and
/// somebody who says no gets nothing placed and no error worth reporting.
library;

import 'package:flutter/services.dart';

/// Rides the same channel as the incoming card and the Quick add tap — one
/// channel to the one activity, rather than three named after their errands.
const MethodChannel _channel = MethodChannel('app.stashit/incoming');

/// Which of the three.
///
/// The names are the strings the platform side switches on. Kept as an enum
/// here so a typo is a compile error rather than a button that does nothing.
enum PinnableWidget {
  ring('ring'),
  comingUp('comingUp'),
  quickAdd('quickAdd');

  const PinnableWidget(this.id);

  final String id;
}

/// Whether the launcher will take a request at all.
///
/// False everywhere the channel does not exist — the desktop test runs, and
/// iOS if it ever exists — rather than throwing, because "you cannot do that
/// here" is the honest answer in all three cases.
Future<bool> canPinWidgets() async {
  try {
    return await _channel.invokeMethod<bool>('canPin') ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// Asks the launcher to place [which].
///
/// Resolves true when the request was accepted — which means the launcher has
/// shown its dialog, NOT that somebody said yes to it. There is no way to learn
/// the answer without a callback intent, and nothing this app would do with it:
/// the widget draws itself from the mirror that is already written.
Future<bool> pinWidget(PinnableWidget which) async {
  try {
    return await _channel.invokeMethod<bool>('pin', which.id) ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
