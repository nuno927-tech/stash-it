/// The database, as tables.
///
/// Replaces the Dexie schema in `src/db/db.ts`.
///
/// ── Why the shapes are not quite the models ───────────────────────────────
/// IndexedDB stored whole objects, so an item carried its coverage list inside
/// it. SQLite stores columns. Most fields map straight across; the two that do
/// not are called out where they appear.
///
/// ── Encrypted at rest ─────────────────────────────────────────────────────
/// The file this describes is opened through SQLCipher on a phone — see
/// `open.dart`. Nothing in *this* file knows or cares: the tables, the queries
/// and the migrations are identical either way, which is the point of putting
/// the decision in the opener.
///
/// **That decision is why the blobs are in here.** Photographs on disk beside
/// an encrypted database would leave the passport image in plaintext and the
/// row describing it encrypted, which is the wrong way round. They cost a
/// little more to read and they are covered by the same key as everything
/// else.
library;

import 'package:drift/drift.dart';

part 'tables.g.dart';

/// Everything you own, one row each.
@DataClassName('ItemRow')
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get propertyId => text()();
  TextColumn get name => text()();

  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get serial => text().nullable()();
  TextColumn get roomId => text().nullable()();

  /// `YYYY-MM-DD`, kept as text.
  ///
  /// A purchase date is a calendar date, not a moment — 15 January is 15
  /// January in every timezone the phone is ever carried through. Storing it
  /// as an instant would make it shift when someone flies, and every countdown
  /// in the app is measured from it.
  TextColumn get purchaseDate => text().nullable()();

  IntColumn get purchasePriceCents => integer().nullable()();
  TextColumn get currency => text().nullable()();
  TextColumn get retailer => text().nullable()();

  /*
    Coverage policies, as JSON, and this is the one place the port keeps a
    document inside a row.

    A child table is the textbook answer and would buy nothing here. Nothing in
    the app ever asks a question about coverages across items — every read
    starts from an item and calls `coveragesOf`, which needs all of them at
    once. A join on every list render, to reassemble a list that is always
    wanted whole, is cost without a use.

    The decoders in logic/bundle.dart already read exactly this shape, so the
    backup importer and the database read coverage through the same code.
  */
  TextColumn get coveragesJson => text().withDefault(const Constant('[]'))();

  /// The two pre-`coverages` fields, still stored so older records keep their
  /// warranty. Read through `coveragesOf`, never directly.
  TextColumn get warrantyJson => text().nullable()();
  TextColumn get extendedWarrantyJson => text().nullable()();

  /// How much notice this item wants. Null means "use the setting"; zero is a
  /// real answer meaning "tell me on the day".
  IntColumn get leadDays => integer().nullable()();

  TextColumn get notes => text().nullable()();
  TextColumn get thumbBlobId => text().nullable()();
  TextColumn get photoBlobId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// Set rather than deleted. The bin is a thirty-day recovery window, and it
  /// only works because nothing is actually removed until the sweep runs.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Files and links attached to an item.
@DataClassName('DocRow')
class Docs extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();

  /// Stored as the enum's name, not its index.
  ///
  /// An index is a number whose meaning depends on the order of a list in the
  /// source — reorder the enum and every row in the database changes meaning
  /// silently. The name survives reordering, and it is also what the backup
  /// format uses, so one string means one thing everywhere.
  TextColumn get kind => text().withDefault(const Constant('other'))();

  TextColumn get title => text().nullable()();
  TextColumn get blobId => text().nullable()();
  TextColumn get url => text().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RoomRow')
class Rooms extends Table {
  TextColumn get id => text()();
  TextColumn get propertyId => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSeed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SubscriptionRow')
class Subscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get propertyId => text()();
  TextColumn get name => text()();

  TextColumn get serviceId => text().nullable()();
  TextColumn get logoBlobId => text().nullable()();

  /// The enum's name — see the note on `Docs.kind`.
  TextColumn get cadence => text()();

  /// One real renewal date, `YYYY-MM-DD`. Every other date derives from it.
  TextColumn get anchorDate => text()();

  IntColumn get amountCents => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();

  TextColumn get startedDate => text().nullable()();

  /*
    ── Splitting, and what it deliberately does not do ─────────────────────

    `amountCents` above stays what **you** pay, whether this is on or off.
    Every total in the app is built from it — the monthly figure, the six
    month chart, the running costs panel — and a number that sometimes means
    the whole bill and sometimes half of it makes all three meaningless.

    These three only record the arrangement: that it is split, who the money
    goes to, and how it gets to them. Nothing does arithmetic on them.
  */
  BoolColumn get shared => boolean().nullable()();
  TextColumn get payTo => text().nullable()();
  TextColumn get payHow => text().nullable()();

  /// 0, 1, 3 or 7. Null or zero means no reminder, and is the default.
  IntColumn get remindDays => integer().nullable()();

  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Documents that expire — passports, licenses, leases.
@DataClassName('PaperRow')
class Papers extends Table {
  TextColumn get id => text()();
  TextColumn get propertyId => text()();

  /// The enum's name, and one of those names is misspelled on purpose:
  /// `licence` is British, the label people read is American, and the key is
  /// frozen because it is written into every record ever saved. See the note
  /// on `PaperKind`.
  TextColumn get kind => text()();

  TextColumn get label => text()();
  TextColumn get holder => text().nullable()();

  TextColumn get expiresOn => text()();
  TextColumn get issuedOn => text().nullable()();

  IntColumn get leadDays => integer().nullable()();
  TextColumn get authority => text().nullable()();
  TextColumn get storedAt => text().nullable()();
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /*
    NO SCAN AND NO DOCUMENT NUMBER, and their absence is a decision rather than
    an oversight — the same one the web app made.

    Encrypting the database changes what is *possible* here, which is why the
    question came up again in phase 2. It does not change what is *wise*: a
    backup is still a plaintext zip the moment it is shared, and a passport
    number sitting next to a name is a better identity-theft package than the
    scan would be. Adding either means solving backup encryption first, and
    that is a feature with a lost-passphrase story attached.
  */
}

/// The properties a household has. One, for almost everybody.
@DataClassName('PropertyRow')
class Properties extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Photographs, receipts and PDFs.
///
/// In the database on purpose — see the note at the top of the file.
@DataClassName('BlobRow')
class Blobs extends Table {
  TextColumn get id => text()();
  BlobColumn get bytes => blob()();
  TextColumn get mime => text()();
  IntColumn get byteLength => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The one settings row.
///
/// A table with a single row rather than a key-value store, because every
/// field has a type and a default and a key-value store throws both away.
@DataClassName('SettingsRow')
class SettingsTable extends Table {
  @override
  String get tableName => 'settings';

  /// Always `singleton`. A primary key with one legal value is how a table
  /// says "there is one of these".
  TextColumn get id => text().withDefault(const Constant('singleton'))();

  /// A JSON list of ints. One number is read and always has been, but the
  /// column keeps the shape the backup format uses so a restore is a copy.
  TextColumn get reminderOffsetsDaysJson =>
      text().withDefault(const Constant('[30]'))();

  TextColumn get currency => text().withDefault(const Constant('USD'))();
  DateTimeColumn get lastBackupAt => dateTime().nullable()();
  IntColumn get backupReminderDays => integer().withDefault(const Constant(30))();

  BoolColumn get devModeEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get onboardedAt => dateTime().nullable()();

  TextColumn get theme => text().nullable()();
  BoolColumn get sounds => boolean().nullable()();
  BoolColumn get haptics => boolean().nullable()();
  TextColumn get roomsView => text().nullable()();
  BoolColumn get biometricLock => boolean().nullable()();

  /*
    ── Reminders, and why these are two columns rather than one ─────────────

    `notifyEnabled` is the switch. `notifyAskedAt` is whether the question has
    ever been put — and off-because-declined has to be distinguishable from
    off-because-never-asked, or the offer dialog reappears forever. See
    `shouldOffer` in logic/notify_offer.dart, which reads both.

    Neither is written by a restore. A backup carries dates and names, not this
    phone's relationship with its own notification tray.
  */
  BoolColumn get notifyEnabled => boolean().nullable()();
  DateTimeColumn get notifyAskedAt => dateTime().nullable()();

  /// The hour a reminder lands, 0–23 local. Null means the default — nine in
  /// the morning, which is `defaultSendHour` and not repeated here.
  IntColumn get reminderHour => integer().nullable()();

  /*
    Entitlements live here and are the one thing a restore must never write.
    See `_settingsOf` in logic/bundle.dart: the backup decoder does not read
    the field at all, so there is no path from a file anyone can edit to a paid
    unlock.
  */
  BoolColumn get proUnlock => boolean().withDefault(const Constant(false))();
  BoolColumn get reportUnlock => boolean().withDefault(const Constant(false))();
  TextColumn get entitlementSource => text().nullable()();
  DateTimeColumn get entitlementVerifiedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Items,
    Docs,
    Rooms,
    Subscriptions,
    Papers,
    Properties,
    Blobs,
    SettingsTable,
  ],
)
class StashDatabase extends _$StashDatabase {
  StashDatabase(super.e);

  /// ── Not the same number as the backup's schema version ──────────────────
  /// That one describes the *records*, and is written into every export; this
  /// one describes the *tables*, and never leaves the phone. They start apart
  /// and will drift further — adding an index bumps this and not that.
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },

        /*
          ── The first migration, and the rule it sets ──────────────────────

          There is already a phone with real data on it, restored from a v0.67
          backup, so from here on a schema change has to be additive and has to
          be tested against a database that predates it — see
          `test/migration_test.dart`.

          Adding a nullable column is the safe shape: every existing row gets
          null, and null already means "no opinion" everywhere preferences are
          read. Nobody who upgrades finds notifications silently switched on,
          and nobody finds the offer dialog silently marked as already asked.
        */
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(settingsTable, settingsTable.notifyEnabled);
            await m.addColumn(settingsTable, settingsTable.notifyAskedAt);
          }
          if (from < 3) {
            await m.addColumn(settingsTable, settingsTable.reminderHour);
          }
          if (from < 4) {
            // Splitting. Nullable, like everything added since v1: null means
            // "no opinion", which is what every subscription written before
            // today actually had.
            await m.addColumn(subscriptions, subscriptions.shared);
            await m.addColumn(subscriptions, subscriptions.payTo);
            await m.addColumn(subscriptions, subscriptions.payHow);
          }
        },
        beforeOpen: (details) async {
          // Foreign keys are off by default in SQLite — every time, per
          // connection, not once per file. There are none declared yet;
          // turning them on now means the first one added actually does
          // something rather than being quietly ignored.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// A new install needs a property to hang everything off, and a settings row
  /// to read preferences from. Both are invisible; their absence is not.
  Future<void> _seed() async {
    await into(properties).insert(
      PropertiesCompanion.insert(
        id: 'default',
        name: 'Home',
        createdAt: Value(DateTime.now()),
      ),
    );
    await into(settingsTable).insert(const SettingsTableCompanion());
  }
}
