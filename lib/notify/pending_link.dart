/// Where the app has been asked to go, waiting for something able to go there.
///
/// ── The gap this exists to bridge ─────────────────────────────────────────
/// A notification tap arrives at the plugin, which is a platform channel with
/// no `BuildContext` and no Navigator. It can arrive at two very different
/// moments:
///
///   While the app is running — the widget tree exists and could be told
///   directly, if the plugin had a way to reach it.
///
///   While the app is dead — the tap IS the launch. There is no tree yet, and
///   the answer has to sit somewhere until one is built. This is the half that
///   usually gets missed, and it is the common case: a reminder fires at nine
///   in the morning and gets tapped from a lock screen.
///
/// One notifier covers both. The plugin writes; the shell listens and clears
/// what it has acted on.
///
/// ── Why it is cleared by the reader, not the writer ───────────────────────
/// The shell sets it back to null once it has actually opened something.
/// Clearing on write would mean a link arriving half a second before the first
/// frame is a link nobody ever sees — which is precisely the cold-start case,
/// and precisely the one worth getting right.
library;

import 'package:flutter/foundation.dart';

import '../logic/deep_link.dart';

/// The link waiting to be handled, or null.
final ValueNotifier<DeepLink?> pendingLink = ValueNotifier<DeepLink?>(null);

/// Called from the notification plugin, on a tap.
///
/// Ignores anything it cannot read — a payload written by an older version and
/// held by the OS for sixty days across an update is a real case, and the
/// honest answer to a string this build does not understand is to open the app
/// normally rather than to guess.
void rememberLink(String? payload) {
  final link = parseLink(payload);
  if (link != null) pendingLink.value = link;
}
