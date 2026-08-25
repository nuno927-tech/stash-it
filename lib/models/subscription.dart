/// A recurring charge — Netflix, Spotify, the gym.
///
/// Translated from the `Subscription` half of `src/db/types.ts`.
///
/// Its own type rather than a flag on Item, because it shares almost nothing
/// with one. An item has a room, a photo, coverage policies and documents; a
/// subscription has none of those and has a cadence, which no item has.
library;

enum Cadence { weekly, monthly, quarterly, yearly }

class Subscription {
  const Subscription({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.cadence,
    required this.anchorDate,
    required this.amountCents,
    required this.currency,
    this.serviceId,
    this.logoBlobId,
    this.startedDate,
    this.remindDays,
    this.notes,
    this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String propertyId;

  /// What it is called. Taken from the catalog, or typed.
  final String name;

  /// Catalog key when it is one of the known services.
  final String? serviceId;
  final String? logoBlobId;

  final Cadence cadence;

  /// One real renewal date, `YYYY-MM-DD`. Every other date derives from it.
  final String anchorDate;

  /// Integer minor units, like an item's price. Never a float.
  final int amountCents;
  final String currency;

  /// Optional: when the user first subscribed. Never used for arithmetic.
  final String? startedDate;

  /// 0, 1, 3 or 7. Zero — or null — means no reminder, and is the default.
  ///
  /// A renewal is not an event most people need waking for: the money leaves
  /// whether they know or not, and nine monthly services would mean nine
  /// notifications a month for nothing. This field is the user saying that
  /// this one is different.
  final int? remindDays;

  final String? notes;

  /// When it was first saved.
  ///
  /// The column has existed since the tables were written and no model ever
  /// read it, so `.replace()` on every edit wrote null back over it — a field
  /// that could only ever hold nothing. Here now for the same reason the item's
  /// is: a row that cannot say when it arrived cannot be ordered by age.
  final DateTime? createdAt;

  final DateTime? deletedAt;
}
