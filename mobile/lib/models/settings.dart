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
    this.backupFolder,
    this.backupFolderLabel,
    this.lastAutoBackupAt,
    this.lastAutoBackupError,
    this.entitlements = const Entitlements(),
    this.devModeEnabled = false,
    this.displayName,
    this.onboardedAt,
    this.tourRemindAt,
    this.theme,
    this.sounds,
    this.haptics,
    this.roomsView,
    this.biometricLock,
    this.lockPortrait,
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

  /// Pin the screen upright.
  ///
  /// The one preference where null resolves to **true** rather than false —
  /// see `defaultPrefs`. Portrait is what the app has always done, so a record
  /// written before this existed had that behaviour and should keep it.
  final bool? lockPortrait;

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
  ///
  /// The same number decides how often the automatic backup runs. One interval,
  /// not two: somebody who wants a copy every fortnight wants to be nagged
  /// every fortnight if it did not happen, and two settings that mean almost
  /// the same thing is how a settings page stops being read.
  final int backupReminderDays;

  /// The folder automatic backups are written to, as a document tree URI.
  ///
  /// **Null is off.** See the note on the column — a separate switch would be a
  /// second way to say the same thing and a state where the two disagree.
  final String? backupFolder;

  /// What to call that folder on screen. For the screen only.
  final String? backupFolderLabel;

  /// When the automatic backup last ran. Not `lastBackupAt`, which means the
  /// data left the phone by any route including by hand.
  final DateTime? lastAutoBackupAt;

  /// Why the last automatic backup did not work, or null when it did.
  ///
  /// Kept as the sentence rather than a code. There is one place it is shown
  /// and no logic reads it, so a code would be a translation table with one
  /// customer.
  final String? lastAutoBackupError;

  final bool devModeEnabled;

  /// What the greeting calls you. Empty means asked and declined, which is a
  /// different state from null, meaning not yet asked.
  final String? displayName;

  /// Set once the welcome has been answered, either way.
  final DateTime? onboardedAt;

  /// When "Skip" on the tour said to ask again. Null means nothing is pending.
  final DateTime? tourRemindAt;

  Settings copyWith({
    List<int>? reminderOffsetsDays,
    String? currency,
    DateTime? lastBackupAt,
    int? backupReminderDays,
    String? backupFolder,
    String? backupFolderLabel,
    DateTime? lastAutoBackupAt,
    String? lastAutoBackupError,
    /*
      ── Four fields that have to be settable to null ────────────────────────

      `copyWith` reads a null argument as "leave it alone", which is right for
      everything else here and wrong for these: turning automatic backups off
      means CLEARING the folder, and recording a successful run means CLEARING
      the error. Both are impossible to say through a nullable parameter.

      So each takes an explicit flag. Ugly, and the alternative is a sentinel
      value or a wrapper type — both of which are the same ugliness spread over
      more of the file.
    */
    bool clearBackupFolder = false,
    bool clearAutoBackupError = false,
    Entitlements? entitlements,
    bool? devModeEnabled,
    String? displayName,
    DateTime? onboardedAt,
    DateTime? tourRemindAt,
    ThemeChoice? theme,
    bool? sounds,
    bool? haptics,
    RoomsView? roomsView,
    bool? biometricLock,
    bool? lockPortrait,
    bool? notifyEnabled,
    DateTime? notifyAskedAt,
    int? reminderHour,
  }) =>
      Settings(
        reminderOffsetsDays: reminderOffsetsDays ?? this.reminderOffsetsDays,
        currency: currency ?? this.currency,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
        backupReminderDays: backupReminderDays ?? this.backupReminderDays,
        backupFolder:
            clearBackupFolder ? null : (backupFolder ?? this.backupFolder),
        backupFolderLabel: clearBackupFolder
            ? null
            : (backupFolderLabel ?? this.backupFolderLabel),
        lastAutoBackupAt: lastAutoBackupAt ?? this.lastAutoBackupAt,
        lastAutoBackupError: clearAutoBackupError
            ? null
            : (lastAutoBackupError ?? this.lastAutoBackupError),
        entitlements: entitlements ?? this.entitlements,
        devModeEnabled: devModeEnabled ?? this.devModeEnabled,
        displayName: displayName ?? this.displayName,
        onboardedAt: onboardedAt ?? this.onboardedAt,
        tourRemindAt: tourRemindAt ?? this.tourRemindAt,
        theme: theme ?? this.theme,
        sounds: sounds ?? this.sounds,
        haptics: haptics ?? this.haptics,
        roomsView: roomsView ?? this.roomsView,
        biometricLock: biometricLock ?? this.biometricLock,
        lockPortrait: lockPortrait ?? this.lockPortrait,
        notifyEnabled: notifyEnabled ?? this.notifyEnabled,
        notifyAskedAt: notifyAskedAt ?? this.notifyAskedAt,
        reminderHour: reminderHour ?? this.reminderHour,
      );
}
