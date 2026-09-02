/// Reading a `.stashit` backup.
///
/// Translated from the read half of `src/lib/backup.ts`.
///
/// The format is a zip named `stash-it-backup-YYYY-MM-DD.stashit` holding one
/// JSON file per table plus the raw blobs. JSON rather than a database dump on
/// purpose — someone with a broken install and a stuck restore can open the
/// file and read their own data.
///
/// ── This is the file where the untrusted strings arrive ───────────────────
/// Everywhere else in the port, a date is a `DateTime` and a lead time is an
/// `int`, so several checks the TypeScript needed became impossible to write
/// and were deleted with a note pointing here. **Here is where they come
/// back**, because a backup is a text file: it can have been hand-edited,
/// truncated by a mail client, or written by a version that spelled things
/// differently. Every decoder below returns null or a default rather than
/// throwing, and the ones that give up say so.
///
/// ── Two rules that are easy and expensive to get wrong ────────────────────
///  - **Entitlements never come back.** A backup file must not be a way to
///    hand someone a paid unlock, so the field is not read at all — not read
///    and ignored, not read.
///  - **Soft-deleted rows are kept.** A restore has to be able to undo an
///    accidental delete, so the bin travels with everything else.
///
/// ── What this file deliberately does not do ───────────────────────────────
/// Unzip, and hash. Both need packages, and phase 1 runs on `dart test` with
/// nothing installed. They arrive as arguments instead, which is also the
/// right shape: it makes the whole parser testable without a zip file.
library;

import 'dart:convert';

import '../models/paper.dart';
import '../models/settings.dart';
import '../models/subscription.dart';
import '../models/types.dart';

const String backupFormat = 'stash-it-backup';
const int backupFormatVersion = 1;

/*
  ── A shared card is a different file, and that is a safety decision ────────

  A card holds a handful of records somebody sent you. A backup holds
  everything you own, and restoring one REPLACES the database — that is what a
  restore is for.

  If both were `.stashit` with the same format string, one mis-tap on a file
  in a text message could wipe a stranger's entire stash. The failure is
  silent, instant and total, and the person who caused it did nothing more
  careless than tap the wrong attachment.

  So they are two formats with two extensions, and each reader refuses the
  other by name — the check below is the whole guard. The message points at
  the right door rather than just saying no, because somebody holding a file
  they cannot open is a person who will keep tapping it.
*/
const String cardFormat = 'stash-it-card';
const int cardFormatVersion = 1;

/// Anything wrong with the file, phrased for the person holding it.
///
/// One exception type rather than several, because every one of these ends up
/// in the same place — a line of text under a file picker — and a caller that
/// has to switch on the failure to write that line is a caller doing the
/// message's job for it.
class BundleError implements Exception {
  const BundleError(this.message);
  final String message;

  @override
  String toString() => message;
}

class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.sha256,
    required this.encrypted,
    required this.itemCount,
    required this.docCount,
    required this.blobCount,
  });

  final int formatVersion;
  final int schemaVersion;
  final String appVersion;

  /// When it was written. Null if the file did not say, or said nonsense.
  final DateTime? exportedAt;

  /// Over the concatenated JSON payloads, in `tableOrder`.
  final String sha256;
  final bool encrypted;

  final int itemCount;
  final int docCount;
  final int blobCount;
}

class BundleData {
  const BundleData({
    this.items = const [],
    this.docs = const [],
    this.rooms = const [],
    this.subscriptions = const [],
    this.papers = const [],
    this.settings,
    this.properties = const [],
    this.maintenance = const [],
  });

  final List<Item> items;
  final List<Doc> docs;
  final List<Room> rooms;
  final List<Subscription> subscriptions;
  final List<Paper> papers;
  final Settings? settings;

  /*
    Two tables carried through as raw maps rather than decoded.

    `Property` and `MaintenanceEntry` have no model in the port yet. Decoding
    them into nothing would be pointless; **dropping them would be data loss**,
    and silent data loss during a restore is the worst bug this file could
    have. So they are kept exactly as they were read and handed on, ready for
    the day their models exist.
  */
  final List<Map<String, dynamic>> properties;
  final List<Map<String, dynamic>> maintenance;

  BundleData copyWith({
    List<Item>? items,
    List<Doc>? docs,
    List<Room>? rooms,
    List<Subscription>? subscriptions,
    List<Paper>? papers,
    Settings? settings,
    List<Map<String, dynamic>>? properties,
    List<Map<String, dynamic>>? maintenance,
  }) =>
      BundleData(
        items: items ?? this.items,
        docs: docs ?? this.docs,
        rooms: rooms ?? this.rooms,
        subscriptions: subscriptions ?? this.subscriptions,
        papers: papers ?? this.papers,
        settings: settings ?? this.settings,
        properties: properties ?? this.properties,
        maintenance: maintenance ?? this.maintenance,
      );
}

class BundleBlob {
  const BundleBlob(this.bytes, this.mime);
  final List<int> bytes;
  final String mime;
}

class ParsedBundle {
  const ParsedBundle(this.manifest, this.data, this.blobs);
  final BackupManifest manifest;
  final BundleData data;
  final Map<String, BundleBlob> blobs;
}

/// Fixed order — **the checksum depends on it**.
///
/// New tables go on the end, never in the middle. A bundle written before a
/// table existed simply has no file for it, and a missing entry contributes
/// zero bytes to the concatenation — so appending leaves every older backup's
/// checksum exactly as it was. Inserting one anywhere else would invalidate
/// every backup ever written.
const List<String> tableOrder = [
  'items',
  'docs',
  'properties',
  'rooms',
  'maintenance',
  'settings',
  'subscriptions',
  'papers',
];

const Map<String, String> _mimeOfExtension = {
  'webp': 'image/webp',
  'jpg': 'image/jpeg',
  'png': 'image/png',
  'heic': 'image/heic',
  'gif': 'image/gif',
  'pdf': 'application/pdf',
};

/// The exact bytes the checksum is taken over.
///
/// Split out so the export side and this side cannot drift: whatever hashes
/// this list is hashing the same thing the writer did, in the same order.
List<int> checksumInput(Map<String, List<int>> entries) => [
      for (final table in tableOrder)
        ...(entries['$table.json'] ?? const <int>[]),
    ];

/// Reads an already-unzipped bundle.
///
/// `entries` is path → bytes, exactly as they came out of the zip.
/// `sha256Hex` is injected: see the note at the top of the file.
ParsedBundle parseBundle(
  Map<String, List<int>> entries, {
  required String Function(List<int> bytes) sha256Hex,

  /// Which of the two file types the caller is willing to accept. The restore
  /// path takes the default; the import path passes [cardFormat]. Neither can
  /// be handed the other by accident — see the note beside `cardFormat`.
  String format = backupFormat,
}) {
  Object? read(String name) {
    final raw = entries[name];
    if (raw == null) return null;
    try {
      return jsonDecode(utf8.decode(raw));
    } on FormatException {
      throw BundleError(
        'That backup is damaged — $name could not be read as text.',
      );
    }
  }

  /*
    A file with no manifest, or a manifest that is not an object, gets the same
    sentence as one claiming the wrong format — phrased for whichever door the
    caller knocked on. "Not a Stash it file" would be true and useless: the
    person is holding it because they were trying to restore a backup, or to
    add a card, and the answer has to name the thing they were trying to do.
  */
  final wanted = format == cardFormat ? 'card' : 'backup';

  final manifestJson = read('manifest.json');
  if (manifestJson is! Map) {
    throw BundleError('That file is not a Stash it $wanted.');
  }

  final found = manifestJson['format'];
  if (found != format) {
    throw BundleError(switch ((found, format)) {
      // The two dangerous confusions, each pointed at the right door.
      (cardFormat, backupFormat) => 'That is a shared card, not a backup. '
          'Open it from Items to add what is in it to your stash — restoring '
          'it would replace everything you have.',
      (backupFormat, cardFormat) => 'That is a full backup, not a shared card. '
          'Restore it from Settings if you meant to replace what is here.',
      _ => 'That file is not a Stash it $wanted.',
    });
  }

  final manifest = _readManifest(manifestJson.cast<String, dynamic>());

  if (manifest.encrypted) {
    throw const BundleError(
      'This backup is encrypted. Passphrase restore is not built yet.',
    );
  }

  final ceiling =
      format == cardFormat ? cardFormatVersion : backupFormatVersion;
  if (manifest.formatVersion > ceiling) {
    throw BundleError(
      'This $wanted uses format v${manifest.formatVersion}, newer than this '
      'app understands. Update Stash it and try again.',
    );
  }

  /*
    A newer schema is refused rather than read on a best-effort basis.

    Reading it would mean silently discarding every field this build has never
    heard of — and then writing the result back over the database, which turns
    "restore my backup" into "delete the parts of my data this version is too
    old to know about". Refusing is recoverable; that is not.
  */
  if (manifest.schemaVersion > schemaVersion) {
    throw BundleError(
      'This backup was written by a newer version of Stash it (schema '
      'v${manifest.schemaVersion}). Update the app first — reading it now '
      'would lose data.',
    );
  }

  // Checksum over the same bytes, in the same order, as the export wrote them.
  if (sha256Hex(checksumInput(entries)) != manifest.sha256) {
    throw const BundleError(
      'This backup is damaged — its contents do not match its checksum.',
    );
  }

  final blobs = <String, BundleBlob>{};
  for (final entry in entries.entries) {
    if (!entry.key.startsWith('blobs/')) continue;
    final base = entry.key.substring('blobs/'.length);
    final dot = base.lastIndexOf('.');
    final id = dot == -1 ? base : base.substring(0, dot);
    final ext = dot == -1 ? 'bin' : base.substring(dot + 1);
    blobs[id] = BundleBlob(
      entry.value,
      _mimeOfExtension[ext.toLowerCase()] ?? 'application/octet-stream',
    );
  }

  final data = BundleData(
    items: _rows(read('items.json')).map(readItem).toList(),
    docs: _rows(read('docs.json')).map(readDoc).toList(),
    rooms: _rows(read('rooms.json')).map(readRoom).toList(),
    subscriptions:
        _rows(read('subscriptions.json')).map(readSubscription).toList(),
    papers: _rows(read('papers.json')).map(readPaper).toList(),
    settings: _settingsOf(read('settings.json')),
    properties: _rows(read('properties.json')),
    maintenance: _rows(read('maintenance.json')),
  );

  return ParsedBundle(
      manifest, migrateBundle(data, manifest.schemaVersion), blobs);
}

BackupManifest _readManifest(Map<String, dynamic> m) {
  final counts = m['counts'];
  final c = counts is Map
      ? counts.cast<String, dynamic>()
      : const <String, dynamic>{};

  return BackupManifest(
    // A missing format version means the very first one. A missing schema
    // version means the same, and both are only reachable from a hand-edited
    // file — but guessing "1" is safe, because the migration chain starts
    // there and every step is idempotent in what it adds.
    formatVersion: intOf(m['formatVersion']) ?? 1,
    schemaVersion: intOf(m['schemaVersion']) ?? 1,
    appVersion: stringOf(m['appVersion']) ?? 'unknown',
    exportedAt: dateOf(m['exportedAt']),
    sha256: stringOf(m['sha256']) ?? '',
    encrypted: m['encrypted'] == true,
    itemCount: intOf(c['items']) ?? 0,
    docCount: intOf(c['docs']) ?? 0,
    blobCount: intOf(c['blobs']) ?? 0,
  );
}

List<Map<String, dynamic>> _rows(Object? json) {
  if (json is! List) return const [];
  return [
    for (final row in json)
      if (row is Map) row.cast<String, dynamic>(),
  ];
}

/* ------------------------------------------------------- the field readers */

/// A JSON value that should be a string, or null.
///
/// Empty and whitespace-only both read as null. A backup that has been through
/// a form somewhere can carry `""` where it means "not set", and the rest of
/// the app tests for null.
String? stringOf(Object? v) {
  if (v is! String) return null;
  final trimmed = v.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// A JSON value that should be a whole number, or null.
///
/// **Accepts a double that is a whole number**, because JSON has one number
/// type and a value written as `30` can come back as `30.0`. Rejects `30.5`,
/// infinities and NaN — this is exactly the case `endingSoonDays` used to
/// guard against and can no longer express.
int? intOf(Object? v) {
  if (v is int) return v;
  if (v is double) {
    if (!v.isFinite || v != v.roundToDouble()) return null;
    return v.toInt();
  }
  if (v is String) return int.tryParse(v.trim());
  return null;
}

bool? boolOf(Object? v) {
  if (v is bool) return v;
  // Some exports wrote 0/1. Nothing else counts — "false" as a string is a bug
  // somewhere upstream, and guessing at it would hide the bug.
  if (v is int) return v != 0;
  return null;
}

/// An ISO timestamp, or null.
///
/// **This is the check the type system removed.** `lastBackupAt: 'not a date'`
/// was a real test in the web suite; here it is impossible to construct on a
/// `Settings`, and possible on every line of a backup file.
DateTime? dateOf(Object? v) {
  final s = stringOf(v);
  if (s == null) return null;
  return DateTime.tryParse(s);
}

final RegExp _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// A `YYYY-MM-DD` date kept as a string, because that is how the models hold
/// it — a purchase date is a calendar date and never a moment.
///
/// Anything that is not exactly that shape is dropped. A half-typed date is
/// worse than a missing one: it is the input to every countdown in the app.
String? isoDateOf(Object? v) {
  final s = stringOf(v);
  if (s == null || !_isoDate.hasMatch(s)) return null;
  // Rejects 2026-02-31, which the shape alone would allow.
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  return '${parsed.year.toString().padLeft(4, '0')}'
              '-${parsed.month.toString().padLeft(2, '0')}'
              '-${parsed.day.toString().padLeft(2, '0')}' ==
          s
      ? s
      : null;
}

/// Looks a value up in an enum by name, falling back rather than throwing.
///
/// **Unknown values are the normal case, not the error case.** A backup from a
/// newer build can name a document kind or a paper kind this one has never
/// heard of, and the honest answer is "other" — the record is still worth
/// keeping, and the field can be corrected in a form.
T enumOf<T extends Enum>(Object? v, List<T> values, T fallback) {
  final name = stringOf(v)?.toLowerCase();
  if (name == null) return fallback;
  for (final e in values) {
    if (e.name.toLowerCase() == name) return e;
  }
  return fallback;
}

/* ---------------------------------------------------------- the decoders */

Item readItem(Map<String, dynamic> j) => Item(
      id: stringOf(j['id']) ?? '',
      name: stringOf(j['name']) ?? '',
      propertyId: stringOf(j['propertyId']) ?? '',
      brand: stringOf(j['brand']),
      model: stringOf(j['model']),
      serial: stringOf(j['serial']),
      roomId: stringOf(j['roomId']),
      purchaseDate: isoDateOf(j['purchaseDate']),
      purchasePriceCents: intOf(j['purchasePriceCents']),
      currency: stringOf(j['currency']),
      retailer: stringOf(j['retailer']),
      coverages: [
        for (final c in _rows(j['coverages'])) readCoverage(c),
      ],
      warranty: readWarranty(j['warranty']),
      extendedWarranty: readWarranty(j['extendedWarranty']),
      leadDays: intOf(j['leadDays']),
      notes: stringOf(j['notes']),
      thumbBlobId: stringOf(j['thumbBlobId']),
      photoBlobId: stringOf(j['photoBlobId']),
      createdAt: dateOf(j['createdAt']),
      deletedAt: dateOf(j['deletedAt']),
    );

Coverage readCoverage(Map<String, dynamic> j) => Coverage(
      id: stringOf(j['id']) ?? '',
      label: stringOf(j['label']) ?? '',
      unit: enumOf(j['unit'], CoverageUnit.values, CoverageUnit.months),
      amount: intOf(j['amount']) ?? 0,
      covers: stringOf(j['covers']),
      startsOn: isoDateOf(j['startsOn']),
      provider: stringOf(j['provider']),
      policyNumber: stringOf(j['policyNumber']),
      phone: stringOf(j['phone']),
      url: stringOf(j['url']),
    );

Warranty? readWarranty(Object? v) {
  if (v is! Map) return null;
  final j = v.cast<String, dynamic>();
  return Warranty(
    months: intOf(j['months']) ?? 0,
    unit: stringOf(j['unit']) == null
        ? null
        : enumOf(j['unit'], WarrantyUnit.values, WarrantyUnit.months),
    amount: intOf(j['amount']),
    startsOn: isoDateOf(j['startsOn']),
    provider: stringOf(j['provider']),
    policyNumber: stringOf(j['policyNumber']),
    phone: stringOf(j['phone']),
    url: stringOf(j['url']),
  );
}

/// ── `blobId` is the whole reason a document is worth restoring ────────────
/// Without it a restored receipt is a row with a name on it, and the file it
/// names is in the same database, unreachable. This function dropped it for
/// one release; see the note on `Doc`.
Doc readDoc(Map<String, dynamic> j) => Doc(
      id: stringOf(j['id']) ?? '',
      itemId: stringOf(j['itemId']) ?? '',
      kind: enumOf(j['kind'], DocKind.values, DocKind.other),
      title: stringOf(j['title']),
      blobId: stringOf(j['blobId']),
      url: stringOf(j['url']),
      deletedAt: dateOf(j['deletedAt']),
    );

Room readRoom(Map<String, dynamic> j) => Room(
      id: stringOf(j['id']) ?? '',
      propertyId: stringOf(j['propertyId']) ?? '',
      name: stringOf(j['name']) ?? '',
      sortOrder: intOf(j['sortOrder']) ?? 0,
      isSeed: boolOf(j['isSeed']) ?? false,
      deletedAt: dateOf(j['deletedAt']),
    );

Subscription readSubscription(Map<String, dynamic> j) => Subscription(
      id: stringOf(j['id']) ?? '',
      propertyId: stringOf(j['propertyId']) ?? '',
      name: stringOf(j['name']) ?? '',
      serviceId: stringOf(j['serviceId']),
      logoBlobId: stringOf(j['logoBlobId']),
      cadence: enumOf(j['cadence'], Cadence.values, Cadence.monthly),
      anchorDate: isoDateOf(j['anchorDate']) ?? '',
      amountCents: intOf(j['amountCents']) ?? 0,
      currency: stringOf(j['currency']) ?? 'USD',
      startedDate: isoDateOf(j['startedDate']),
      shared: boolOf(j['shared']),
      payTo: stringOf(j['payTo']),
      payHow: stringOf(j['payHow']),
      remindDays: intOf(j['remindDays']),
      notes: stringOf(j['notes']),
      createdAt: dateOf(j['createdAt']),
      deletedAt: dateOf(j['deletedAt']),
    );

Paper readPaper(Map<String, dynamic> j) => Paper(
      id: stringOf(j['id']) ?? '',
      propertyId: stringOf(j['propertyId']) ?? '',

      /*
        `licence` is the frozen key, spelled British, and it is written into
        every document ever saved. The label people read is American. Renaming
        the key would mean a migration for a spelling, so the enum member keeps
        the old name and this lookup finds it — which is the entire reason the
        member is spelled that way. See the note on `PaperKind`.
      */
      kind: enumOf(j['kind'], PaperKind.values, PaperKind.other),
      label: stringOf(j['label']) ?? '',
      holder: stringOf(j['holder']),
      expiresOn: isoDateOf(j['expiresOn']) ?? '',
      issuedOn: isoDateOf(j['issuedOn']),
      leadDays: intOf(j['leadDays']),
      authority: stringOf(j['authority']),
      storedAt: stringOf(j['storedAt']),
      notes: stringOf(j['notes']),
      createdAt: dateOf(j['createdAt']),
      deletedAt: dateOf(j['deletedAt']),
    );

Settings? _settingsOf(Object? v) {
  if (v is! Map) return null;
  final j = v.cast<String, dynamic>();

  /*
    ENTITLEMENTS ARE NOT READ.

    Not read and discarded — not read. A backup file must not be a way to hand
    someone a paid unlock, and the surest way to guarantee that is for the
    field never to be looked at. The same goes for the biometric credential and
    the push endpoint in older files: both describe one handset, and restoring
    either onto a new one leaves it waiting on something that was never set up
    for it.
  */
  final offsets = [
    for (final o in (j['reminderOffsetsDays'] is List
        ? j['reminderOffsetsDays'] as List
        : const []))
      if (intOf(o) != null) intOf(o)!,
  ];

  return Settings(
    reminderOffsetsDays: offsets.isEmpty ? const [30] : offsets,
    currency: stringOf(j['currency']) ?? 'USD',
    lastBackupAt: dateOf(j['lastBackupAt']),
    backupReminderDays: intOf(j['backupReminderDays']) ?? 30,
    devModeEnabled: boolOf(j['devModeEnabled']) ?? false,
    displayName:
        j['displayName'] is String ? (j['displayName'] as String).trim() : null,
    onboardedAt: dateOf(j['onboardedAt']),
    tourRemindAt: dateOf(j['tourRemindAt']),
    theme: j['theme'] == null
        ? null
        : enumOf(j['theme'], ThemeChoice.values, ThemeChoice.system),
    sounds: boolOf(j['sounds']),
    haptics: boolOf(j['haptics']),
    lockPortrait: boolOf(j['lockPortrait']),
    roomsView: j['roomsView'] == null
        ? null
        : enumOf(j['roomsView'], RoomsView.values, RoomsView.collapsed),
    biometricLock: null,

    /*
      ── The backup folder does not travel either ──────────────────────────

      It is a document tree URI: a grant made by one Android install, to one
      app install, over one folder. Restored onto a new phone it names a folder
      this app has no permission for — and the failure would be the worst kind,
      because the Settings card would show a folder and a cadence and the app
      would go on looking as though somebody's data was being protected.

      Left null, so a restored phone asks for a folder again. One extra tap
      against a silent, invisible failure to back up at all.
    */
  );
}

/* -------------------------------------------------------------- migration */

/// Walks a bundle forward to the current schema.
///
/// ── Why every step restamps records it did not change ─────────────────────
/// v2 → v3 and v3 → v4 both only added a table. No existing record changes
/// shape — and every record is still restamped, because a version field
/// answers "does this match the current shape", not "which migration last
/// touched it". A record left behind is indistinguishable from one that
/// genuinely needs upgrading.
///
/// **The port cannot restamp anything, and that is a difference worth
/// naming.** The Dart models carry no `schemaVersion` field: a decoded record
/// is by definition current, because the decoder is this build's. The version
/// lives on the file rather than on the row. So the steps below are about
/// tables appearing and fields disappearing, and nothing else.
BundleData migrateBundle(BundleData data, int fromVersion) {
  var out = data;
  for (var v = fromVersion; v < schemaVersion; v++) {
    final step = _migrations[v];
    if (step == null) {
      throw BundleError("This backup can't be upgraded from schema v$v.");
    }
    out = step(out);
  }
  return out;
}

final Map<int, BundleData Function(BundleData)> _migrations = {
  /*
    v1 → v2: `category` was dropped from Item.

    Nothing to do. The field is simply not in the decoder, so it was discarded
    the moment the row was read — which is the whole benefit of decoding into
    a typed model instead of spreading an untyped object around.
  */
  1: (data) => data,

  // v2 → v3: subscriptions arrived. A bundle written before the table existed
  // has no subscriptions.json, and `_rows` already made that an empty list.
  2: (data) => data,

  // v3 → v4: documents arrived, same shape of step.
  3: (data) => data,
};
