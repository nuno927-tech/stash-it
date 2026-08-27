/// Documents that expire, and when to start doing something about them.
///
/// Translated from `src/lib/papers.ts`.
///
/// ── The idea the whole feature turns on ───────────────────────────────────
/// A passport tells you it expires in February. It does not tell you that most
/// countries want six months of validity on it, or that renewal takes eight
/// weeks. The date that matters is not the printed one — it is the printed one
/// minus however long the job takes, and that is what this file computes and
/// what every screen sorts by.
library;

import '../models/paper.dart';
import 'dates.dart';

/// What each kind is called on screen. American, deliberately — see the note
/// on `PaperKind` for why the stored key is not.
const Map<PaperKind, String> kindLabel = {
  PaperKind.passport: 'Passport',
  PaperKind.id: 'ID card',
  PaperKind.licence: 'Drivers license',
  PaperKind.visa: 'Visa or permit',
  PaperKind.vehicle: 'Vehicle',
  PaperKind.insurance: 'Insurance',
  PaperKind.lease: 'Lease',
  PaperKind.certification: 'Certification',
  PaperKind.membership: 'Membership',
  PaperKind.petlicence: 'Pet license',
  PaperKind.petvaccine: 'Pet vaccination',
  PaperKind.voucher: 'Gift card',
  PaperKind.other: 'Other',
};

/// How much runway each kind needs, in days.
///
/// A passport is 240 — six months of validity most countries require, plus
/// about two months of processing. A lease is 90, and that is the notice
/// period rather than the paperwork: the date that matters is the last day you
/// can give notice, not the day the tenancy ends.
const Map<PaperKind, int> defaultLeadDays = {
  PaperKind.passport: 240,
  PaperKind.id: 90,
  PaperKind.licence: 60,
  PaperKind.visa: 120,
  PaperKind.vehicle: 30,
  PaperKind.insurance: 30,
  PaperKind.lease: 90,
  PaperKind.certification: 90,
  PaperKind.membership: 30,
  PaperKind.petlicence: 30,
  PaperKind.petvaccine: 30,
  PaperKind.voucher: 30,
  PaperKind.other: 30,
};

/// Three states, and the middle one is the point.
///
/// `expired` — the printed date has passed. The document is not valid.
/// `renew`   — still valid, but inside its lead time. The state the feature
///             exists to surface, and the only one you can act on usefully:
///             there is still time, and there will not be for long.
/// `valid`   — nothing to do.
enum PaperState { valid, renew, expired }

/// Zero is a real answer — "tell me on the day" — so only null falls back.
int leadDaysFor(PaperKind kind, int? leadDays) =>
    leadDays ?? defaultLeadDays[kind]!;

/// The printed date, or null if it cannot be read.
DateTime? expiryOf(Paper paper) => parseDate(paper.expiresOn);

/// The date this actually needs dealing with: expiry minus its lead time.
///
/// This is the date the app counts down to, and the one the list sorts by.
DateTime? renewBy(Paper paper) {
  final end = expiryOf(paper);
  return end == null ? null : addDays(end, -leadDaysFor(paper.kind, paper.leadDays));
}

/// Days until the printed date. Negative once it has passed.
int? daysUntilExpiry(Paper paper, [DateTime? now]) {
  final end = expiryOf(paper);
  return end == null ? null : daysUntil(end, now);
}

/// Days until it needs starting. Negative means it needed starting already.
int? daysUntilRenewBy(Paper paper, [DateTime? now]) {
  final at = renewBy(paper);
  return at == null ? null : daysUntil(at, now);
}

PaperState paperState(Paper paper, [DateTime? now]) {
  final left = daysUntilExpiry(paper, now);

  // An unreadable date is not an expired document. Saying "expired" about a
  // record whose date failed to parse would be inventing bad news.
  if (left == null) return PaperState.valid;
  if (left < 0) return PaperState.expired;

  return (daysUntilRenewBy(paper, now) ?? 1) <= 0
      ? PaperState.renew
      : PaperState.valid;
}

/// What the name field should say after the user taps a kind.
///
/// Two rules, and the second is the one that matters:
///
///  - "Other" fills nothing. It is the one tile that carries no name, so it is
///    the one case where the user genuinely has to say what this is.
///
///  - ANYTHING THEY TYPED THEMSELVES SURVIVES. A household has four passports
///    and they get called "Nuno's passport" and "Leo's passport". Someone who
///    typed that and then corrected the tile must not have their words thrown
///    away by the correction. The test is whether the box still holds the
///    previous tile's name — if it does, nobody has an opinion yet and it is
///    ours to overwrite.
String renameForKind(PaperKind next, String current, PaperKind was) {
  final typed = current.trim();
  final untouched = typed.isEmpty || typed == kindLabel[was];
  if (!untouched) return current;
  return next == PaperKind.other ? '' : kindLabel[next]!;
}

/// Soonest to need doing first, by renew-by rather than by expiry.
///
/// Those two orders genuinely differ: a passport expiring in nine months needs
/// starting before a driving license expiring in four, because one needs eight
/// months of runway and the other needs two. Sorting by the printed date puts
/// them the wrong way round, which is the exact mistake this file exists to
/// prevent.
List<Paper> sortPapers(List<Paper> papers, [DateTime? now]) {
  final out = [...papers];
  out.sort((a, b) {
    final da = daysUntilRenewBy(a, now);
    final db = daysUntilRenewBy(b, now);
    if (da == null && db == null) return a.label.compareTo(b.label);
    if (da == null) return 1;
    if (db == null) return -1;
    if (da != db) return da - db;
    return a.label.compareTo(b.label);
  });
  return out;
}

/// Everything past its renew-by date, worst first. Expired counts.
List<Paper> needsRenewing(List<Paper> papers, [DateTime? now]) => sortPapers(
      papers.where((p) => paperState(p, now) != PaperState.valid).toList(),
      now,
    );

/// The next one that will need starting, ignoring those already overdue.
Paper? nextUp(List<Paper> papers, [DateTime? now]) {
  for (final p in sortPapers(papers, now)) {
    if (paperState(p, now) == PaperState.valid) return p;
  }
  return null;
}

/// Everyone named on a document, for a household list. Empty when nobody
/// filled the field in, which is the common case and should cost nothing.
List<String> holders(List<Paper> papers) {
  final seen = <String>{};
  for (final p in papers) {
    final who = p.holder?.trim();
    if (who != null && who.isNotEmpty) seen.add(who);
  }
  final out = seen.toList()..sort();
  return out;
}
