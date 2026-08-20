/// User preferences, and the lists of choices behind them.
///
/// Translated from `src/lib/prefs.ts`, minus `setPref`, which was a Dexie
/// write and belongs with the storage layer in phase 2.
///
/// These live on the settings singleton as optional fields, read through
/// `prefsFrom` so a record written before they existed still answers every
/// question. That is deliberately cheaper than a schema migration: no index
/// changes, and an older build reading a newer record simply ignores what it
/// does not recognise.
library;

import '../models/settings.dart';

class Prefs {
  const Prefs({
    required this.theme,
    required this.sounds,
    required this.haptics,
    required this.roomsView,
    required this.biometricLock,
    required this.displayName,
  });

  final ThemeChoice theme;
  final bool sounds;
  final bool haptics;
  final RoomsView roomsView;

  /// Ask for a fingerprint or face check before the app opens.
  final bool biometricLock;

  /// What the greeting calls you. Empty is a valid answer.
  final String displayName;
}

const Prefs defaultPrefs = Prefs(
  theme: ThemeChoice.system,

  /*
    Sound on by default.

    The usual reasoning — an app that chirps unasked gets silenced at the OS
    level — is sound for an app that pings at you. It does not describe this
    one: the cues are a tick on tap, a short tone on save, and a chime at
    launch, all of them responses to something the user just did. And they are
    already governed by the phone's own switch, since a device on silent plays
    nothing regardless of what is set here.

    Off by default also meant almost nobody heard them. A feature that has to
    be discovered in Settings before it can be experienced is a feature most
    people never know exists.
  */
  sounds: true,
  haptics: true,

  // Collapsed: with a dozen rooms the expanded list is a long scroll, and the
  // question people arrive with is usually "what's in the garage".
  roomsView: RoomsView.collapsed,

  // Off until asked for. Switching it on costs an enrolment prompt, and a lock
  // nobody chose is a lock they will be surprised by at the worst moment.
  biometricLock: false,
  displayName: '',
);

Prefs prefsFrom(Settings? settings) => Prefs(
      theme: settings?.theme ?? defaultPrefs.theme,
      sounds: settings?.sounds ?? defaultPrefs.sounds,
      haptics: settings?.haptics ?? defaultPrefs.haptics,
      roomsView: settings?.roomsView ?? defaultPrefs.roomsView,
      biometricLock: settings?.biometricLock ?? defaultPrefs.biometricLock,
      displayName: settings?.displayName ?? defaultPrefs.displayName,
    );

/// Resolves `system` against the device.
ThemeChoice resolveTheme(ThemeChoice choice, bool prefersDark) {
  if (choice != ThemeChoice.system) return choice;
  return prefersDark ? ThemeChoice.dark : ThemeChoice.light;
}

/* ----------------------------------------------------------- the choices */

class Choice {
  const Choice(this.days, this.label);

  /// Null is a real option on the item form — see `itemLeadChoices`.
  final int? days;
  final String label;
}

/// The global "warn me before cover ends" list.
const List<Choice> reminderChoices = [
  Choice(7, '1 week'),
  Choice(14, '2 weeks'),
  Choice(30, '1 month'),
  Choice(60, '2 months'),
  Choice(90, '3 months'),
];

/// Per-item notice, on the item's own form.
///
/// Longer than the global list on purpose, and longer than a subscription's by
/// a mile. A renewal is a payment you might want to cancel this week; a
/// warranty on something installed is a job — a quote, a tradesman, a date in a
/// diary — and thirty days does not cover any of it. A roof wants a year.
///
/// **Null is the first option and the default: follow the setting.** It has to
/// be a real, selectable choice rather than an absence, or there is no way back
/// once someone has picked a number.
const List<Choice> itemLeadChoices = [
  Choice(null, 'Default'),
  Choice(14, '2 weeks'),
  Choice(30, '1 month'),
  Choice(90, '3 months'),
  Choice(182, '6 months'),
  Choice(365, '1 year'),
];

/// How often to ask for a backup. Zero is never, and is a real answer.
const List<Choice> backupReminderChoices = [
  Choice(7, 'Weekly'),
  Choice(30, 'Monthly'),
  Choice(90, 'Quarterly'),
  Choice(0, 'Never'),
];

/// The currencies worth putting in a picker; everything else can be typed.
const List<String> currencies = [
  'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'NZD', 'JPY', //
  'INR', 'BRL', 'MXN', 'ZAR', 'CHF', 'SEK',
];
