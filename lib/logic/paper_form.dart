/// What a half-filled document form means.
///
/// Pure, and separate from the widget, for the same reason as `item_form.dart`:
/// the rules are the interesting part.
///
/// ── One refusal, and it is different from the item form's ─────────────────
/// An item with no dates is still worth keeping — it is a thing you own, and
/// the app holds it. **A document with no expiry is not**, because the entire
/// Documents tab is a list of things that run out. A passport with no date on
/// it would sit in that list forever, never sorting, never warning, quietly
/// implying it was being watched.
library;

import '../models/paper.dart';
import 'papers.dart';

class PaperDraft {
  PaperDraft({
    this.id,
    this.kind = PaperKind.passport,
    this.label = '',
    this.holder = '',
    this.expiresOn = '',
    this.issuedOn = '',
    this.authority = '',
    this.storedAt = '',
    this.notes = '',
    this.leadDays,
    this.createdAt,
  });

  final String? id;
  PaperKind kind;
  String label;
  String holder;

  /// `YYYY-MM-DD`.
  String expiresOn;
  String issuedOn;

  String authority;
  String storedAt;
  String notes;

  /// Null means "use the default for its kind" — a passport wants eight
  /// months, a vehicle inspection wants one.
  int? leadDays;

  /// Carried, not edited. A draft that does not hold a field deletes it on
  /// save — see the note on `SubscriptionDraft.serviceId`.
  DateTime? createdAt;

  /// Tapping a different kind renames the box, unless somebody typed in it.
  ///
  /// A household has four passports and they get called "Nuno's passport".
  /// Correcting the tile must not throw that away — see `renameForKind`.
  void pickKind(PaperKind next) {
    label = renameForKind(next, label, kind);
    kind = next;
  }
}

String? whyNotSaveablePaper(PaperDraft d) {
  if (d.label.trim().isEmpty) {
    return 'Call it something — "Passport", or whose it is.';
  }

  /*
    THE REFUSAL. Everything this tab does is arithmetic on the printed date:
    the sort order, the amber circle, the "start now", the reminder. Without
    one there is nothing to compute and nothing to warn about, so the row
    would sit in a list of things being watched, not being watched.
  */
  if (d.expiresOn.trim().isEmpty) {
    return 'When does it expire? That is the whole point of this list.';
  }

  return null;
}

Paper toPaper(PaperDraft d, {required String propertyId}) {
  String? clean(String s) => s.trim().isEmpty ? null : s.trim();

  return Paper(
    id: d.id ?? '',
    propertyId: propertyId,
    kind: d.kind,
    label: d.label.trim(),
    holder: clean(d.holder),
    expiresOn: d.expiresOn.trim(),
    issuedOn: clean(d.issuedOn),
    leadDays: d.leadDays,
    authority: clean(d.authority),
    storedAt: clean(d.storedAt),
    notes: clean(d.notes),
    createdAt: d.createdAt,
  );
}

PaperDraft draftOfPaper(Paper p) => PaperDraft(
      id: p.id,
      kind: p.kind,
      label: p.label,
      holder: p.holder ?? '',
      expiresOn: p.expiresOn,
      issuedOn: p.issuedOn ?? '',
      authority: p.authority ?? '',
      storedAt: p.storedAt ?? '',
      notes: p.notes ?? '',
      leadDays: p.leadDays,
      createdAt: p.createdAt,
    );

/// How much runway this document will get, spelled out.
///
/// Shown under the lead-time picker because "240 days" means nothing and
/// "about eight months before it expires" means everything — and because a
/// passport defaulting to eight months looks like a mistake until you know it
/// is six months of required validity plus two of processing.
String leadExplanation(PaperDraft d) {
  final days = leadDaysFor(d.kind, d.leadDays);
  if (days == 0) return 'Tell me on the day it expires.';

  final months = (days / 30).round();
  final when = months <= 1 ? 'about a month' : 'about $months months';
  return 'Tell me $when before — that is when to start, not when it is too late.';
}
