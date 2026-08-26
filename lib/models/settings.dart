/// The one settings row.
///
/// Translated from the `Settings` half of `src/db/types.ts` — the parts of it
/// that phase 1 logic actually reads. Themes, the biometric lock and the
/// entitlements arrive in phase 2 with the storage layer and in phase 6 with
/// billing; adding fields now that nothing reads is how a model starts lying
/// about what the app does.
///
/// ── What is gone rather than deferred ─────────────────────────────────────
/// `pushEnabled`, `pushEndpoint`, `pushSyncedAt` and `pushWakes`. All four
/// described a device's relationship with a push server, and were stripped
/// from every backup because an endpoint belongs to one browser on one phone
/// and means nothing anywhere else. There is no push server here — see the
/// note at the top of `logic/reminders.dart` — so there is nothing to record.
///
/// ── One deliberate type change ────────────────────────────────────────────
/// Timestamps are `DateTime?`, not ISO strings.
///
/// The TypeScript stored them as strings and every reader called `new Date()`
/// on one, so every reader had to handle a string that would not parse — and
/// the web test suite has a case for exactly that, asserting that garbage is
/// treated as "never backed up". **That case cannot be written here**, because
/// the field will not hold garbage. The parsing moves to one place, the backup
/// importer in phase 2, which is the only place a string ever arrives from
/// outside.
library;

/// What has been paid for.
///
/// `proUnlock` lifts the item cap and turns on reminders that arrive while the
/// app is closed. `source` records which store said so, because a receipt from
/// Play means nothing to the App Store and the app has to be able to tell a
/// user why their purchase is not showing on a second device.
class Entitlements {
  const Entitlements({
    this.proUnlock = false,
    this.reportUnlock = false,
    this.source,
    this.verifiedAt,
  });

  final bool proUnlock;
  final bool reportUnlock;
  final String? source;
  final DateTime? verifiedAt;
}

enum ThemeChoice { system, light, dark }

/// How the Items list opens: rooms shut, or everything on show.
enum RoomsView { collapsed, expanded }

class Settings {
  const Settings({
    this.reminderOffsetsDays = const [30],
    this.currency = 'USD',
    this.lastBackupAt,
    this.backupReminderDays = 30,
    this.entitlements = const Entitlements(),
    this.devModeEnabled = false,
    this.displayName,
    this.onboardedAt,
    this.theme,
    this.sounds,
    this.haptics,
    this.roomsView,
    this.biometricLock,
    this.notifyEnabled,
    this.notifyAskedAt,
    this.reminderHour,
  });

  final Entitlements entitlements;

  /*
    Preferences, all nullable.

    Null is not "off" — it is "this record was written before the preference
    existed, and has no opinion". Read them through `prefsFrom` in
    logic/prefs.dart, which supplies the defaults, rather than touching them
    directly. That is deliberately cheaper than a schema migration: an older
    build reading a newer record simply ignores what it does not recognise.
  */
  final ThemeChoice? theme;
  final bool? sounds;
  final bool? haptics;
  final RoomsView? roomsView;

  /// Ask for a fingerprint or face check before the app opens.
  final bool? biometricLock;

  /// Whether reminders should arrive while the app is shut.
  ///
  /// Null is not false. It means the question has never been put, which is what
  /// `notifyAskedAt` records separately — off-because-declined and
  /// off-because-never-asked have to be told apart, or the offer returns every
  /// time somebody saves something with a date on it.
  final bool? notifyEnabled;

  /// When the offer was made, either way. Null means never.
  final DateTime? notifyAskedAt;

  /// What time of day a reminder arrives, 0–23 local.
  ///
  /// Null is the default rather than midnight — see `defaultSendHour`. Stored
  /// as an hour and not a `TimeOfDay` because nothing in the app needs a
  /// minute, and offering one would invite somebody to set 09:07 and then
  /// wonder why an inexact alarm did not honour it.
  final int? reminderHour;

  /// How much notice to give before cover ends. A list because the web schema
  /// allowed several offsets; only the first is read, and always has been.
  /// Read it through `endingSoonDays`, which clamps it.
  final List<int> reminderOffsetsDays;

  final String currency;

  /// When a backup was last exported. Null means never.
  final DateTime? lastBackupAt;

  /// How often to ask for one. **Zero means never**, and must not be read as
  /// "every zero days".
  final int backupReminderDays;

  final bool devModeEnabled;

  /// What the greeting calls you. Empty means asked and declined, which is a
  /// different state from null, meaning not yet asked.
  final String? displayName;

  /// Set once the welcome has been answered, either way.
  final DateTime? onboardedAt;

  Settings copyWith({
    List<int>? reminderOffsetsDays,
    String? currency,
    DateTime? lastBackupAt,
    int? backupReminderDays,
    Entitlements? entitlements,
    bool? devModeEnabled,
    String? displayName,
    DateTime? onboardedAt,
    ThemeChoice? theme,
    bool? sounds,
    bool? haptics,
    RoomsView? roomsView,
    bool? biometricLock,
    bool? notifyEnabled,
    DateTime? notifyAskedAt,
    int? reminderHour,
  }) =>
      Settings(
        reminderOffsetsDays: reminderOffsetsDays ?? this.reminderOffsetsDays,
        currency: currency ?? this.currency,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
        backupReminderDays: backupReminderDays ?? this.backupReminderDays,
        entitlements: entitlements ?? this.entitlements,
        devModeEnabled: devModeEnabled ?? this.devModeEnabled,
        displayName: displayName ?? this.displayName,
        onboardedAt: onboardedAt ?? this.onboardedAt,
        theme: theme ?? this.theme,
        sounds: sounds ?? this.sounds,
        haptics: haptics ?? this.haptics,
        roomsView: roomsView ?? this.roomsView,
        biometricLock: biometricLock ?? this.biometricLock,
        notifyEnabled: notifyEnabled ?? this.notifyEnabled,
        notifyAskedAt: notifyAskedAt ?? this.notifyAskedAt,
        reminderHour: reminderHour ?? this.reminderHour,
      );
}
