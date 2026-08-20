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

class Settings {
  const Settings({
    this.reminderOffsetsDays = const [30],
    this.currency = 'USD',
    this.lastBackupAt,
    this.backupReminderDays = 30,
    this.donateMonthly = false,
    this.donateLastAt,
    this.devModeEnabled = false,
    this.displayName,
    this.onboardedAt,
  });

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

  /// The tip jar. Venmo cannot schedule a payment from a link, so "monthly"
  /// was only ever a reminder the app gives itself.
  final bool donateMonthly;
  final DateTime? donateLastAt;

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
    bool? donateMonthly,
    DateTime? donateLastAt,
    bool? devModeEnabled,
    String? displayName,
    DateTime? onboardedAt,
  }) =>
      Settings(
        reminderOffsetsDays: reminderOffsetsDays ?? this.reminderOffsetsDays,
        currency: currency ?? this.currency,
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
        backupReminderDays: backupReminderDays ?? this.backupReminderDays,
        donateMonthly: donateMonthly ?? this.donateMonthly,
        donateLastAt: donateLastAt ?? this.donateLastAt,
        devModeEnabled: devModeEnabled ?? this.devModeEnabled,
        displayName: displayName ?? this.displayName,
        onboardedAt: onboardedAt ?? this.onboardedAt,
      );
}
