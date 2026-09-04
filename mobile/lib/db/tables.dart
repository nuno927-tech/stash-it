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

  /*
    ── One of these two, never both, never neither ──────────────────────────

    An attachment used to belong to an item and only an item, because only
    items had any. Documents now hold scans as well — a passport photographed
    rather than only its expiry date — and the row has to say which kind of
    record it hangs off.

    Two nullable columns rather than an `ownerKind` and an `ownerId`. A kind
    and an id are two fields that must agree, which is two chances to disagree
    and the exact shape this file objects to beside `Doc.isLocal`. Two ids
    cannot disagree: whichever is set IS the answer, and `Doc.owner` refuses a
    row where that is not exactly one of them.

    `itemId` became nullable in v8. Everything written before then has it set
    and `paperId` null, which is what the migration backfills to.
  */
  TextColumn get itemId => text().nullable()();
  TextColumn get paperId => text().nullable()();

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
  IntColumn get backupReminderDays =>
      integer().withDefault(const Constant(30))();

  /*
    ── The folder backups are written to, and how the last attempt went ──────

    `backupFolder` is a document tree URI Android handed over when somebody
    picked a folder, and it is the on switch: null means the app is not writing
    anything anywhere. A separate boolean would be a second way to say "off" and
    a state where the two disagree.

    `backupFolderLabel` is only for the screen. The URI is unreadable — a
    percent-encoded provider path — and the folder's real name has to be asked
    for across a process boundary, which is not something a settings page should
    do on every rebuild.

    `lastAutoBackupAt` is deliberately not `lastBackupAt`. That one means "the
    data left this phone somehow", including by somebody sharing a file by hand,
    and the dashboard's nudge reads it. This one means "the automatic one ran",
    and only the interval reads it.

    `lastAutoBackupError` is the sentence to show, or null when the last attempt
    was fine. A backup that quietly stopped working is worse than one that never
    started, because the app goes on looking as though it is protecting somebody.
  */
  TextColumn get backupFolder => text().nullable()();
  TextColumn get backupFolderLabel => text().nullable()();
  DateTimeColumn get lastAutoBackupAt => dateTime().nullable()();
  TextColumn get lastAutoBackupError => text().nullable()();

  BoolColumn get devModeEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get onboardedAt => dateTime().nullable()();

  /// When "Skip" said to ask again.
  ///
  /// Null means no reminder is pending, which is the state for somebody who
  /// took the tour and for somebody who has never been offered it. Only a
  /// deliberate skip sets it — see `tourDue`, which refuses to interrupt
  /// anybody who did not ask to be interrupted.
  DateTimeColumn get tourRemindAt => dateTime().nullable()();

  /*
    ── What the rating prompt is allowed to know ────────────────────────────

    Four fields, and every one of them is a fact the app already had a reason
    to hold. `installedAt` is when this stash began. `daysUsed` counts DAYS the
    app was opened, not launches — `usedOn` is the last one counted, and is the
    only reason the count cannot be inflated by an app that reopens itself.

    `reviewAskedAt` and `reviewAsks` are the record of having asked. Two, ever
    — see `logic/review.dart`, which holds the whole cadence and none of the
    storage.

    They are NOT in `settingsToJson`, so they do not travel in a backup. That
    file is a shared format the web app reads too, and none of this means
    anything there — and a restore onto a new handset genuinely is a new
    install, which starts its own fortnight rather than inheriting one.
  */
  DateTimeColumn get installedAt => dateTime().nullable()();
  IntColumn get daysUsed => integer().withDefault(const Constant(0))();
  DateTimeColumn get usedOn => dateTime().nullable()();
  DateTimeColumn get reviewAskedAt => dateTime().nullable()();
  IntColumn get reviewAsks => integer().withDefault(const Constant(0))();

  TextColumn get theme => text().nullable()();
  BoolColumn get sounds => boolean().nullable()();
  BoolColumn get haptics => boolean().nullable()();
  TextColumn get roomsView => text().nullable()();
  BoolColumn get biometricLock => boolean().nullable()();

  /// Whether the screen is pinned upright. Null means no opinion, which
  /// `prefsFrom` reads as on — see the note there.
  BoolColumn get lockPortrait => boolean().nullable()();

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
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _blobSizeIndex();
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
          if (from < 5) {
            // Nullable, and null is read as ON rather than off — the one
            // place in this file where "no opinion" does not resolve to
            // false. Portrait is what every existing install has been doing
            // since launch, so treating an old row as "unlocked" would turn
            // rotation on for everybody who upgrades, which is a change
            // nobody asked for dressed up as a default.
            await m.addColumn(settingsTable, settingsTable.lockPortrait);
          }
          if (from < 6) {
            // Null for everybody who already has the app, which is correct:
            // no reminder is pending for them. Whether they see the tour is
            // decided by `onboardedAt`, not by this.
            await m.addColumn(settingsTable, settingsTable.tourRemindAt);
          }
          if (from < 8) {
            /*
              Scans on documents.

              `paperId` is added and `itemId` is widened to nullable, which
              SQLite cannot do in place — the table is rebuilt. Every existing
              row keeps its `itemId` and gets a null `paperId`, which is
              exactly what it already meant.

              The blobs are untouched. This table holds references, not bytes,
              so a rebuild here moves kilobytes rather than the collection.
            */
            await m.addColumn(docs, docs.paperId);
            await m.alterTable(TableMigration(docs));
          }
          if (from < 9) {
            await _blobSizeIndex();
          }
          if (from < 10) {
            /*
              The rating prompt's memory.

              Nullable and zero-defaulted, so an existing install reads as "no
              install date known" — which `timeToAsk` treats as a reason not to
              ask rather than as a reason to. Somebody who upgrades starts the
              clock on their next launch, which is the honest reading: the app
              does not know how long they have had it.
            */
            await m.addColumn(settingsTable, settingsTable.installedAt);
            await m.addColumn(settingsTable, settingsTable.daysUsed);
            await m.addColumn(settingsTable, settingsTable.usedOn);
            await m.addColumn(settingsTable, settingsTable.reviewAskedAt);
            await m.addColumn(settingsTable, settingsTable.reviewAsks);
          }
          if (from < 7) {
            /*
              Automatic backups. Null on every existing install, which reads as
              off — and off is right: this grants an app permission to write
              into a folder on somebody's device, and that is not a thing to
              switch on for people while they were not looking.
            */
            await m.addColumn(settingsTable, settingsTable.backupFolder);
            await m.addColumn(settingsTable, settingsTable.backupFolderLabel);
            await m.addColumn(settingsTable, settingsTable.lastAutoBackupAt);
            await m.addColumn(settingsTable, settingsTable.lastAutoBackupError);
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

  /*
    ── An index on the size, and why it is worth one ─────────────────────────

    The Settings tab shows how much room the photographs take, which is
    `SELECT SUM(byte_length) FROM blobs`. That reads fast on paper and does
    not: `bytes` sits before `byte_length` in the row, and a photograph does
    not fit in one page, so reaching the column after it means walking that
    row's overflow pages — every one of which SQLCipher decrypts.

    On a collection with a couple of hundred photographs in it, adding up
    three-figure numbers meant decrypting the entire collection. Twice this
    screen has been made "faster" without that being the thing fixed.

    An index carrying the id and the size answers both questions from the
    index and never opens a row: the total on this screen, and the per-file
    sizes the claim sheet lists. Building it reads those two columns once, at
    upgrade — a real cost, paid once, instead of on every visit to the tab.
  */
  Future<void> _blobSizeIndex() => customStatement(
        'CREATE INDEX IF NOT EXISTS blobs_by_size ON blobs (id, byte_length)',
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
