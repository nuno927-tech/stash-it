/// A document that expires — a passport, a license, a lease.
///
/// Translated from the `Paper` half of `src/db/types.ts`.
///
/// ── What is deliberately NOT here ─────────────────────────────────────────
/// No scan, and no document number.
///
/// The web database is unencrypted by design and backups are plaintext zips
/// that leave the device the moment they are shared. A receipt for a kettle in
/// that file is fine; a passport scan is not, and a passport number sitting
/// next to a name is a better identity-theft package than the scan would be.
///
/// Flutter changes this calculus — SQLCipher on Drift, keyed from `local_auth`,
/// makes at-rest encryption straightforward in a way it never was on the web.
/// That is a decision to take deliberately when the storage layer arrives in
/// phase 2, not a field to add quietly because it became easier.
library;

/// The stored keys, and one of them is misspelled on purpose.
///
/// `licence` is British and the app says "Drivers license" — because that
/// string is written into every saved document and every backup ever exported,
/// so renaming it means a schema migration for a spelling. The KEY is frozen;
/// only the label people read is American. The port keeps the same freeze so
/// an imported backup from the web app lands on the same member.
enum PaperKind {
  passport,
  id,
  licence,
  visa,
  vehicle,
  insurance,
  lease,
  certification,
  membership,
  petlicence,
  petvaccine,
  voucher,
  other,
}

class Paper {
  const Paper({
    required this.id,
    required this.propertyId,
    required this.kind,
    required this.label,
    required this.expiresOn,
    this.holder,
    this.issuedOn,
    this.leadDays,
    this.authority,
    this.storedAt,
    this.notes,
    this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String propertyId;
  final PaperKind kind;

  /// What the user calls it. "Passport", or "Nuno's passport".
  final String label;

  /// Who it belongs to. The field people actually search a household by.
  final String? holder;

  /// The printed date, `YYYY-MM-DD`.
  final String expiresOn;
  final String? issuedOn;

  /// How much runway this one needs, in days.
  ///
  /// Null means "use the default for its kind". Zero is a real answer — tell
  /// me on the day — so only null falls back.
  final int? leadDays;

  /// Who issued it, and where the physical thing is kept.
  final String? authority;
  final String? storedAt;

  final String? notes;

  /// When it was first saved. See the note on `Subscription.createdAt` — the
  /// column existed and no model read it, so every edit wrote null over it.
  final DateTime? createdAt;

  final DateTime? deletedAt;
}
