/// Turning records back into the JSON a `.stashit` holds.
///
/// The mirror of the decoders in `bundle.dart`, and deliberately written as
/// its mirror: every field that is read has a line here, in the same order, so
/// the two can be compared side by side.
///
/// ── The property worth having, and the test that proves it ────────────────
/// **Write then read gives back what you started with.** That is one test
/// (`bundle_roundtrip_test.dart`) and it is worth more than any number of
/// assertions about individual fields, because it fails the moment an encoder
/// and its decoder stop agreeing — which is the only way this file can be
/// wrong.
///
/// ── What is deliberately not written ──────────────────────────────────────
/// Entitlements. The decoder does not read them; this does not write them.
/// Both halves, so neither an old file nor a new one is a route to a paid
/// unlock.
///
/// The biometric flag and anything about push, for the same reason they were
/// never read: they describe one handset, and a backup is a thing you carry to
/// another.
library;

import '../models/paper.dart';
import '../models/settings.dart';
import '../models/subscription.dart';
import '../models/types.dart';

/// Drops nulls, so a bundle does not carry a field for every value nobody set.
Map<String, Object?> _tidy(Map<String, Object?> m) {
  m.removeWhere((_, v) => v == null);
  return m;
}

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

Map<String, Object?> itemToJson(Item i) => _tidy({
      'id': i.id,
      'propertyId': i.propertyId,
      'name': i.name,
      'brand': i.brand,
      'model': i.model,
      'serial': i.serial,
      'roomId': i.roomId,
      'purchaseDate': i.purchaseDate,
      'purchasePriceCents': i.purchasePriceCents,
      'currency': i.currency,
      'retailer': i.retailer,
      'coverages': [for (final c in i.coverages) coverageToJson(c)],
      'warranty': i.warranty == null ? null : warrantyToJson(i.warranty!),
      'extendedWarranty':
          i.extendedWarranty == null ? null : warrantyToJson(i.extendedWarranty!),
      'leadDays': i.leadDays,
      'notes': i.notes,
      'thumbBlobId': i.thumbBlobId,
      'photoBlobId': i.photoBlobId,
      'createdAt': _iso(i.createdAt),
      'deletedAt': _iso(i.deletedAt),
    });

Map<String, Object?> coverageToJson(Coverage c) => _tidy({
      'id': c.id,
      'label': c.label,
      'unit': c.unit.name,
      'amount': c.amount,
      'covers': c.covers,
      'startsOn': c.startsOn,
      'provider': c.provider,
      'policyNumber': c.policyNumber,
      'phone': c.phone,
      'url': c.url,
    });

Map<String, Object?> warrantyToJson(Warranty w) => _tidy({
      'months': w.months,
      'unit': w.unit?.name,
      'amount': w.amount,
      'startsOn': w.startsOn,
      'provider': w.provider,
      'policyNumber': w.policyNumber,
      'phone': w.phone,
      'url': w.url,
    });

Map<String, Object?> docToJson(Doc d) => _tidy({
      'id': d.id,
      'itemId': d.itemId,
      'kind': d.kind.name,
      'title': d.title,
      // Both halves of the round trip, or a backup made by this app ships the
      // files and loses every reference to them. See the note on `Doc`.
      'blobId': d.blobId,
      'url': d.url,
      // Derived rather than stored, but written out because the web app reads
      // this key and would treat its absence as a linked document.
      'storageMode': d.isLocal ? 'local' : 'linked',
      'deletedAt': _iso(d.deletedAt),
    });

Map<String, Object?> roomToJson(Room r) => _tidy({
      'id': r.id,
      'propertyId': r.propertyId,
      'name': r.name,
      'sortOrder': r.sortOrder,
      'isSeed': r.isSeed,
      'deletedAt': _iso(r.deletedAt),
    });

Map<String, Object?> subscriptionToJson(Subscription s) => _tidy({
      'id': s.id,
      'propertyId': s.propertyId,
      'name': s.name,
      'serviceId': s.serviceId,
      'logoBlobId': s.logoBlobId,
      'cadence': s.cadence.name,
      'anchorDate': s.anchorDate,
      'amountCents': s.amountCents,
      'currency': s.currency,
      'startedDate': s.startedDate,
      'remindDays': s.remindDays,
      'notes': s.notes,
      'createdAt': _iso(s.createdAt),
      'deletedAt': _iso(s.deletedAt),
    });

Map<String, Object?> paperToJson(Paper p) => _tidy({
      'id': p.id,
      'propertyId': p.propertyId,

      // The frozen key, spelled as it is stored. Writing the American label
      // here would make every backup unreadable by every other build.
      'kind': p.kind.name,

      'label': p.label,
      'holder': p.holder,
      'expiresOn': p.expiresOn,
      'issuedOn': p.issuedOn,
      'leadDays': p.leadDays,
      'authority': p.authority,
      'storedAt': p.storedAt,
      'notes': p.notes,
      'createdAt': _iso(p.createdAt),
      'deletedAt': _iso(p.deletedAt),
    });

/// Settings, **minus the entitlements**.
///
/// `_settingsOf` in bundle.dart does not read them. This does not write them.
/// A guarantee that only holds on one side of a round trip is not a guarantee.
Map<String, Object?> settingsToJson(Settings s) => _tidy({
      'reminderOffsetsDays': s.reminderOffsetsDays,
      'currency': s.currency,
      'lastBackupAt': _iso(s.lastBackupAt),
      'backupReminderDays': s.backupReminderDays,
      'devModeEnabled': s.devModeEnabled,
      'displayName': s.displayName,
      'onboardedAt': _iso(s.onboardedAt),
      'theme': s.theme?.name,
      'sounds': s.sounds,
      'haptics': s.haptics,
      'roomsView': s.roomsView?.name,
    });

/// What a blob file is called inside the zip.
///
/// The reader takes the id from the name and the mime from the extension, so
/// an unknown type has to become something — `.bin` reads back as
/// `application/octet-stream`, which is what it already was.
const Map<String, String> extensionOfMime = {
  'image/webp': 'webp',
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/heic': 'heic',
  'image/gif': 'gif',
  'application/pdf': 'pdf',
};

String blobPath(String id, String mime) =>
    'blobs/$id.${extensionOfMime[mime] ?? 'bin'}';
