/// The entities. Translated from `src/db/types.ts`.
///
/// Plain classes with final fields rather than generated data classes — phase 1
/// has no database and no serialisation, so `freezed` and `json_serializable`
/// would be build steps earning nothing yet. Phase 2 introduces Drift, and
/// these grow the annotations then.
library;

/// The shape of the records, as this build understands them.
///
/// Bumped whenever a table or a field changes. A backup carries the version it
/// was written at, and `logic/bundle.dart` walks it forward — or refuses, if
/// the file came from a newer build than this one.
const int schemaVersion = 4;

enum WarrantyUnit { days, months, years }

/// `lifetime` never expires and never counts down. Stored as a unit rather
/// than as a 99-year term, so nothing has to pretend to know an end date.
enum CoverageUnit { days, months, years, lifetime }

/// One policy on one item.
///
/// A product rarely has "a warranty". A couch has a lifetime frame, ten years
/// on the cushions, five on the springs and one on the fabric. Two fixed slots
/// could hold two of those and quietly lost the rest.
class Coverage {
  const Coverage({
    required this.id,
    required this.label,
    required this.unit,
    required this.amount,
    this.covers,
    this.startsOn,
    this.provider,
    this.policyNumber,
    this.phone,
    this.url,
  });

  final String id;

  /// What it is for, in the user's words: "Fabric", "Frame", "Money back".
  /// Falls back to "Warranty" when blank — see `coverageLabel`.
  final String label;

  /// What it actually pays for. Free text on purpose: every manufacturer words
  /// this differently and a fixed list would force a wrong answer.
  final String? covers;

  final CoverageUnit unit;

  /// Ignored when the unit is `lifetime`.
  final int amount;

  /// Defaults to the item's purchase date when absent.
  final String? startsOn;
  final String? provider;
  final String? policyNumber;
  final String? phone;
  final String? url;
}

/// The pre-`coverages` shape, still read so older records keep their warranty.
///
/// A read-time fold rather than a migration: it cannot half-finish, cannot run
/// twice, and cannot corrupt a record that a future version understands better
/// — all three of which a database upgrade over every item can do.
class Warranty {
  const Warranty({
    required this.months,
    this.unit,
    this.amount,
    this.startsOn,
    this.provider,
    this.policyNumber,
    this.phone,
    this.url,
  });

  /// Kept for records written before units existed. When `unit` and `amount`
  /// are present they are the source of truth — read the term through
  /// `termOf` rather than touching either.
  final int months;

  final WarrantyUnit? unit;
  final int? amount;
  final String? startsOn;
  final String? provider;
  final String? policyNumber;
  final String? phone;
  final String? url;
}

/// A room, for grouping items and for searching by one.
class Room {
  const Room({
    required this.id,
    required this.propertyId,
    required this.name,
    this.sortOrder = 0,

    /// True until the user edits this row, so a future version can adjust
    /// untouched seed rooms without overwriting anyone's names.
    this.isSeed = false,
    this.deletedAt,
  });

  final String id;
  final String propertyId;
  final String name;
  final int sortOrder;
  final bool isSeed;
  final DateTime? deletedAt;
}

/// What a document is, which decides whether it counts as proof.
///
/// `receipt` and `warranty` are the two a claim will actually ask for — see
/// `metricsFor`. A manual or a photo is useful and is not evidence.
enum DocKind { receipt, manual, warranty, photo, other }

/// A file or a link attached to an item — a receipt, a manual, a certificate.
///
/// ── This was thin for one phase too many, and it cost real data ───────────
/// Phase 1 had no storage layer, so this held only what the logic needed:
/// whose it is, what kind, what it is called. `blobId` was left for "phase 2,
/// alongside the decision about where the bytes live on a phone".
///
/// Phase 2 arrived, the bytes went into the database, and **this class was not
/// revisited** — so `readDoc` silently dropped `blobId` out of every backup it
/// read and `docToRow` had none to write. A restore imported the documents and
/// imported the files, and connected nothing: 76 blobs sitting in the database
/// with not one row pointing at them, and 37 receipts that could never be
/// opened again.
///
/// Nothing reported it, because every layer was individually correct. The
/// backup file was fine, the blob importer was fine, the doc importer was fine
/// at what it claimed to do. The loss lived in a field that three of them had
/// agreed not to mention.
///
/// `linkStatus` and `lastCheckedAt` from the web schema are still not here,
/// and that is a real omission rather than this one repeated: they describe a
/// periodic check on remote URLs that this app does not perform.
class Doc {
  const Doc({
    required this.id,
    required this.itemId,
    this.kind = DocKind.other,
    this.title,
    this.blobId,
    this.url,
    this.deletedAt,
  });

  final String id;
  final String itemId;
  final DocKind kind;
  final String? title;

  /// The file, in the `blobs` table. Null for a document that is only a link.
  final String? blobId;

  /// A link, for a receipt that lives in somebody's email rather than here.
  final String? url;

  final DateTime? deletedAt;

  /// The web schema's `storageMode`, derived rather than stored.
  ///
  /// Two fields that must agree — a mode and a blob id — are two chances to
  /// disagree. There is exactly one question worth asking, and it is whether
  /// there are bytes.
  bool get isLocal => blobId != null;
}

class Item {
  const Item({
    required this.id,
    required this.name,
    required this.propertyId,
    this.brand,
    this.model,
    this.serial,
    this.roomId,
    this.purchaseDate,
    this.purchasePriceCents,
    this.currency,
    this.retailer,
    this.coverages = const [],
    this.warranty,
    this.extendedWarranty,
    this.leadDays,
    this.notes,
    this.thumbBlobId,
    this.photoBlobId,
    this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String propertyId;

  /// Kept separate from the name: these are the inputs to manual re-lookup.
  final String? brand;
  final String? model;
  final String? serial;
  final String? roomId;

  /// `YYYY-MM-DD`. Every countdown in the app is arithmetic on this.
  final String? purchaseDate;
  final int? purchasePriceCents;
  final String? currency;
  final String? retailer;

  /// Every policy, in the order they were entered. Read it through
  /// `coveragesOf`, which folds in the two legacy fields below.
  final List<Coverage> coverages;

  final Warranty? warranty;
  final Warranty? extendedWarranty;

  /// How much notice this item wants before its cover ends, in days.
  ///
  /// Null means "use the setting". Set, it overrides the global window for
  /// this item alone: a roof and a kettle do not deserve the same warning, and
  /// thirty days is useless for anything needing a quote and a tradesman.
  ///
  /// Zero is a real answer — tell me on the day — so only null falls back.
  final int? leadDays;

  final String? notes;
  final String? thumbBlobId;
  final String? photoBlobId;

  /// When this was added. Only the "recently added" strip reads it — every
  /// countdown in the app runs off `purchaseDate` instead, which is the date
  /// the user knows and this one is not.
  final DateTime? createdAt;

  final DateTime? deletedAt;
}
