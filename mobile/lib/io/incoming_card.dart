/// The Dart end of the channel that hands over a tapped `.stashcard`.
///
/// ── Why any of this is needed ─────────────────────────────────────────────
/// The manifest claims the extension, so Android launches the app with the
/// file attached to the intent. Reading it is the problem: a card arriving
/// from a messaging app is a `content://` URI, which `dart:io` cannot open at
/// all — only the platform's ContentResolver can. So `MainActivity` copies the
/// bytes into the app's cache and this asks for the resulting path.
///
/// ── Asked for, not pushed ─────────────────────────────────────────────────
/// The shell asks on start and again on every resume, because a card can
/// arrive either way and Dart cannot tell which happened. `take` clears the
/// value on the native side, so asking twice about the same file gives it once
/// — otherwise the arrival screen would reopen every time somebody came back
/// to the app, on a card they had already dealt with.
///
/// `arrived` is the other direction, for a card tapped while the app is
/// already running: Android hands that to the live activity rather than
/// starting a new one, so nothing would prompt Dart to ask.
library;

import 'dart:io';

import 'package:flutter/services.dart';

import '../logic/bundle.dart';
import 'card_file.dart';

const MethodChannel _channel = MethodChannel('app.stashit/incoming');

/// The path of a card waiting to be opened, or null. Clears it as it reads.
///
/// Returns null on any platform without the channel — the desktop test runs,
/// and iOS if it ever exists — rather than throwing, because "no card was
/// tapped" is the honest answer everywhere the question cannot be asked.
Future<String?> takeIncomingCard() async {
  try {
    return await _channel.invokeMethod<String>('take');
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

/// Called when a card is tapped while the app is already open.
void onCardArrived(void Function(String path) handle) {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'arrived' && call.arguments is String) {
      handle(call.arguments as String);
    }
    return null;
  });
}

/// Reads a card from a path the channel gave us.
///
/// Throws `BundleError` with a sentence written for a person — including the
/// one that says a backup is not a card. The caller shows it as-is.
Future<ParsedBundle> readCardAt(String path) async {
  final bytes = await File(path).readAsBytes();
  return parseCardBytes(bytes);
}
