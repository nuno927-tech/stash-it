/// Rows in, models out.
///
/// ── Why the logic never sees a row ────────────────────────────────────────
/// Every function in `logic/` takes an `Item`, a `Paper`, a `Subscription` —
/// plain classes with no database in them. That is what let all 658 tests run
/// before there was a database at all, and it is worth keeping: the day a
/// query changes shape, nothing above this file has to.
///
/// So this is the only place that knows both, and it is deliberately dull.
///
/// ── The JSON columns read through the backup decoders ─────────────────────
/// `coveragesJson` and the two warranty columns hold exactly the shape a
/// backup file holds, and are read by exactly the functions that read a backup
/// — `readCoverage` and `readWarranty` from logic/bundle.dart. One shape, one
/// reader. A second implementation is how a restored record and a saved one
/// start disagreeing about what a lifetime policy is.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../logic/bundle.dart';
import '../models/paper.dart';
import '../models/settings.dart';
import '../models/subscription.dart';
import '../models/types.dart';
import 'tables.dart';

/* -------------------------------------------------------------- reading */

Item itemOf(ItemRow r) => Item(
      id: r.id,
      name: r.name,
      propertyId: r.propertyId,
      brand: r.brand,
      model: r.model,
      serial: r.serial,
      roomId: r.roomId,
      purchaseDate: r.purchaseDate,
      purchasePriceCents: r.purchasePriceCents,
      currency: r.currency,
      retailer: r.retailer,
      coverages: _coveragesOfJson(r.coveragesJson),
      warranty: _warrantyOfJson(r.warrantyJson),
      extendedWarranty: _warrantyOfJson(r.extendedWarrantyJson),
      leadDays: r.leadDays,
      notes: r.notes,
      thumbBlobId: r.thumbBlobId,
      photoBlobId: r.photoBlobId,
      createdAt: r.createdAt,
      deletedAt: r.deletedAt,
    );

Doc docOf(DocRow r) => Doc(
      id: r.id,
      itemId: r.itemId,
      kind: enumOf(r.kind, DocKind.values, DocKind.other),
      title: r.title,
      blobId: r.blobId,
      url: r.url,
      deletedAt: r.deletedAt,
    );

Room roomOf(RoomRow r) => Room(
      id: r.id,
      propertyId: r.propertyId,
      name: r.name,
      sortOrder: r.sortOrder,
      isSeed: r.isSeed,
      deletedAt: r.deletedAt,
    );

Subscription subscriptionOf(SubscriptionRow r) => Subscription(
      id: r.id,
      propertyId: r.propertyId,
      name: r.name,
      serviceId: r.serviceId,
      logoBlobId: r.logoBlobId,
      cadence: enumOf(r.cadence, Cadence.values, Cadence.monthly),
      anchorDate: r.anchorDate,
      amountCents: r.amountCents,
      currency: r.currency,
      startedDate: r.startedDate,
      remindDays: r.remindDays,
      notes: r.notes,
      createdAt: r.createdAt,
      deletedAt: r.deletedAt,
    );

Paper paperOf(PaperRow r) => Paper(
      id: r.id,
      propertyId: r.propertyId,
      // `licence` is the frozen key — see the note on the column.
      kind: enumOf(r.kind, PaperKind.values, PaperKind.other),
      label: r.label,
      holder: r.holder,
      expiresOn: r.expiresOn,
      issuedOn: r.issuedOn,
      leadDays: r.leadDays,
      authority: r.authority,
      storedAt: r.storedAt,
      notes: r.notes,
      createdAt: r.createdAt,
      deletedAt: r.deletedAt,
    );

Settings settingsOf(SettingsRow r) => Settings(
      reminderOffsetsDays: _intsOfJson(r.reminderOffsetsDaysJson),
      currency: r.currency,
      lastBackupAt: r.lastBackupAt,
      backupReminderDays: r.backupReminderDays,
      entitlements: Entitlements(
        proUnlock: r.proUnlock,
        reportUnlock: r.reportUnlock,
        source: r.entitlementSource,
        verifiedAt: r.entitlementVerifiedAt,
      ),
      devModeEnabled: r.devModeEnabled,
      displayName: r.displayName,
      onboardedAt: r.onboardedAt,
      theme: r.theme == null ? null : enumOf(r.theme, ThemeChoice.values, ThemeChoice.system),
      sounds: r.sounds,
      haptics: r.haptics,
      roomsView:
          r.roomsView == null ? null : enumOf(r.roomsView, RoomsView.values, RoomsView.collapsed),
      biometricLock: r.biometricLock,
      notifyEnabled: r.notifyEnabled,
      notifyAskedAt: r.notifyAskedAt,
    );

/* -------------------------------------------------------------- writing */

ItemsCompanion itemToRow(Item i, {DateTime? now}) => ItemsCompanion.insert(
      id: i.id,
      propertyId: i.propertyId,
      name: i.name,
      brand: Value(i.brand),
      model: Value(i.model),
      serial: Value(i.serial),
      roomId: Value(i.roomId),
      purchaseDate: Value(i.purchaseDate),
      purchasePriceCents: Value(i.purchasePriceCents),
      currency: Value(i.currency),
      retailer: Value(i.retailer),
      coveragesJson: Value(jsonEncode([for (final c in i.coverages) _coverageToJson(c)])),
      warrantyJson: Value(i.warranty == null ? null : jsonEncode(_warrantyToJson(i.warranty!))),
      extendedWarrantyJson: Value(
        i.extendedWarranty == null ? null : jsonEncode(_warrantyToJson(i.extendedWarranty!)),
      ),
      leadDays: Value(i.leadDays),
      notes: Value(i.notes),
      thumbBlobId: Value(i.thumbBlobId),
      photoBlobId: Value(i.photoBlobId),
      createdAt: Value(i.createdAt ?? now ?? DateTime.now()),
      updatedAt: Value(now ?? DateTime.now()),
      deletedAt: Value(i.deletedAt),
    );

DocsCompanion docToRow(Doc d) => DocsCompanion.insert(
      id: d.id,
      itemId: d.itemId,
      kind: Value(d.kind.name),
      title: Value(d.title),
      blobId: Value(d.blobId),
      url: Value(d.url),
      deletedAt: Value(d.deletedAt),
    );

RoomsCompanion roomToRow(Room r) => RoomsCompanion.insert(
      id: r.id,
      propertyId: r.propertyId,
      name: r.name,
      sortOrder: Value(r.sortOrder),
      isSeed: Value(r.isSeed),
      deletedAt: Value(r.deletedAt),
    );

SubscriptionsCompanion subscriptionToRow(Subscription s) => SubscriptionsCompanion.insert(
      id: s.id,
      propertyId: s.propertyId,
      name: s.name,
      serviceId: Value(s.serviceId),
      logoBlobId: Value(s.logoBlobId),
      cadence: s.cadence.name,
      anchorDate: s.anchorDate,
      amountCents: Value(s.amountCents),
      currency: Value(s.currency),
      startedDate: Value(s.startedDate),
      remindDays: Value(s.remindDays),
      notes: Value(s.notes),
      // Preserved rather than stamped, exactly as `itemToRow` does it. These
      // rows are written with `.replace()`, so a field this function forgets is
      // a field every edit sets back to null.
      createdAt: Value(s.createdAt ?? DateTime.now()),
      deletedAt: Value(s.deletedAt),
    );

PapersCompanion paperToRow(Paper p) => PapersCompanion.insert(
      id: p.id,
      propertyId: p.propertyId,
      kind: p.kind.name,
      label: p.label,
      holder: Value(p.holder),
      expiresOn: p.expiresOn,
      issuedOn: Value(p.issuedOn),
      leadDays: Value(p.leadDays),
      authority: Value(p.authority),
      storedAt: Value(p.storedAt),
      notes: Value(p.notes),
      createdAt: Value(p.createdAt ?? DateTime.now()),
      deletedAt: Value(p.deletedAt),
    );

/// Settings, minus the entitlements.
///
/// **The unlock is not written from a `Settings` object.** Everything else on
/// the row round-trips; a paid unlock is set by the billing code and by
/// nothing else, so there is no path from a restored file, a form, or a
/// developer toggle that goes through here.
SettingsTableCompanion settingsToRow(Settings s) => SettingsTableCompanion(
      id: const Value('singleton'),
      reminderOffsetsDaysJson: Value(jsonEncode(s.reminderOffsetsDays)),
      currency: Value(s.currency),
      lastBackupAt: Value(s.lastBackupAt),
      backupReminderDays: Value(s.backupReminderDays),
      devModeEnabled: Value(s.devModeEnabled),
      displayName: Value(s.displayName),
      onboardedAt: Value(s.onboardedAt),
      theme: Value(s.theme?.name),
      sounds: Value(s.sounds),
      haptics: Value(s.haptics),
      roomsView: Value(s.roomsView?.name),
      biometricLock: Value(s.biometricLock),
      /*
        `notifyEnabled` and `notifyAskedAt` are deliberately absent, for the
        same structural reason the entitlements are: this function is the only
        way a restore writes settings, so anything it cannot write is something
        a backup file cannot change.

        Without that, restoring a backup taken on another phone — or on this
        one before reminders existed — would silently switch notifications off
        and re-arm the offer dialog. Reminders belong to a handset and its
        notification tray, not to the records.

        They are written by `Repository.setNotify`, which touches these two
        columns and nothing else.
      */
    );

/* ----------------------------------------------------------------- json */

List<Coverage> _coveragesOfJson(String raw) {
  final decoded = _tryDecode(raw);
  if (decoded is! List) return const [];
  return [
    for (final c in decoded)
      if (c is Map) readCoverage(c.cast<String, dynamic>()),
  ];
}

Warranty? _warrantyOfJson(String? raw) {
  if (raw == null) return null;
  return readWarranty(_tryDecode(raw));
}

List<int> _intsOfJson(String raw) {
  final decoded = _tryDecode(raw);
  if (decoded is! List) return const [30];
  final out = [
    for (final v in decoded)
      if (intOf(v) != null) intOf(v)!,
  ];
  return out.isEmpty ? const [30] : out;
}

/// A column that will not parse is a corrupt row, not a crash.
///
/// The alternative is an exception thrown while building a list, which takes
/// out the whole screen over one bad record — and the record is recoverable
/// from a backup, while the screen is not recoverable at all.
Object? _tryDecode(String raw) {
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}

Map<String, Object?> _coverageToJson(Coverage c) => {
      'id': c.id,
      'label': c.label,
      'unit': c.unit.name,
      'amount': c.amount,
      if (c.covers != null) 'covers': c.covers,
      if (c.startsOn != null) 'startsOn': c.startsOn,
      if (c.provider != null) 'provider': c.provider,
      if (c.policyNumber != null) 'policyNumber': c.policyNumber,
      if (c.phone != null) 'phone': c.phone,
      if (c.url != null) 'url': c.url,
    };

Map<String, Object?> _warrantyToJson(Warranty w) => {
      'months': w.months,
      if (w.unit != null) 'unit': w.unit!.name,
      if (w.amount != null) 'amount': w.amount,
      if (w.startsOn != null) 'startsOn': w.startsOn,
      if (w.provider != null) 'provider': w.provider,
      if (w.policyNumber != null) 'policyNumber': w.policyNumber,
      if (w.phone != null) 'phone': w.phone,
      if (w.url != null) 'url': w.url,
    };
