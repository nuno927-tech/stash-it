/// What a half-filled subscription form means.
///
/// ── One refusal, and it is the anchor date ────────────────────────────────
/// A subscription is two fields of arithmetic — a cadence and one real
/// renewal date — and **every other date in the app derives from that one**.
/// The next renewal, the calendar, the six-month chart, the reminder, the
/// "due this week" figure: all of them are `nextRenewal` walking forward from
/// the anchor.
///
/// Without it there is no next renewal, so the row would appear in a list
/// sorted by when things renew while having no answer to that question.
library;

import '../models/subscription.dart';
import 'format.dart';

class SubscriptionDraft {
  SubscriptionDraft({
    this.id,
    this.name = '',
    this.cadence = Cadence.monthly,
    this.anchorDate = '',
    this.amountText = '',
    this.currency = 'USD',
    this.notes = '',
    this.remindDays,
    this.serviceId,
    this.logoBlobId,
    this.startedDate,
    this.shared = false,
    this.payTo = '',
    this.payHow = '',
    this.createdAt,
  });

  final String? id;
  String name;
  Cadence cadence;

  /*
    ── Carried, not edited ─────────────────────────────────────────────────

    None of these four is on the form, and all four were being erased on save,
    because a draft that does not hold a field deletes it. `logoBlobId` was the
    expensive one: editing a subscription severed its logo and left the image
    in the database as an orphan.

    Same failure as `ItemDraft.photoBlobId` and `Doc.blobId` before it. The
    rule: **a form model must round-trip every field of the record, whether or
    not the form shows it.**
  */
  String? serviceId;
  String? logoBlobId;
  String? startedDate;
  DateTime? createdAt;

  /// One real renewal date, `YYYY-MM-DD`. Everything derives from it.
  String anchorDate;

  String amountText;
  String currency;
  String notes;

  /*
    ── Splitting ───────────────────────────────────────────────────────────

    `amountText` stays what **you** pay either way. Every total in the app is
    built from it, and a number that sometimes means the whole bill and
    sometimes half of it makes the monthly figure meaningless. These three
    only record the arrangement.
  */
  bool shared;
  String payTo;
  String payHow;

  /// 0, 1, 3 or 7. Null or zero means no reminder, and that is the default —
  /// nine monthly services would otherwise be nine notifications a month for
  /// money that leaves whether you are told or not.
  int? remindDays;
}

String? whyNotSaveableSubscription(SubscriptionDraft d) {
  if (d.name.trim().isEmpty) return 'What is it called?';

  if (d.anchorDate.trim().isEmpty) {
    return 'When does it next renew? Every other date is worked out from that one.';
  }

  return null;
}

Subscription toSubscription(SubscriptionDraft d, {required String propertyId}) {
  String? clean(String s) => s.trim().isEmpty ? null : s.trim();

  return Subscription(
    id: d.id ?? '',
    propertyId: propertyId,
    name: d.name.trim(),
    cadence: d.cadence,
    anchorDate: d.anchorDate.trim(),

    /*
      Zero is allowed and means zero.

      A free tier of something you still want to see renewing is a real case,
      and refusing it would push people into typing 0.01 to get past the form.
      It contributes nothing to the totals, which is correct.
    */
    amountCents: parseMoneyToCents(d.amountText) ?? 0,
    currency: d.currency,
    remindDays: d.remindDays,
    notes: clean(d.notes),
    serviceId: d.serviceId,
    logoBlobId: d.logoBlobId,
    startedDate: d.startedDate,

    /*
      Off means null, not false, and the two names go with it.

      A row that says `shared: false, payTo: 'Mum'` is a row remembering an
      arrangement somebody switched off — and it would come back the moment
      the toggle was flipped again, which looks like the app guessing. Null is
      "no arrangement", which is what off means.
    */
    shared: d.shared ? true : null,
    payTo: d.shared ? clean(d.payTo) : null,
    payHow: d.shared ? clean(d.payHow) : null,
    createdAt: d.createdAt,
  );
}

SubscriptionDraft draftOfSubscription(Subscription s) => SubscriptionDraft(
      id: s.id,
      name: s.name,
      cadence: s.cadence,
      anchorDate: s.anchorDate,
      amountText: s.amountCents == 0 ? '' : (s.amountCents / 100).toStringAsFixed(2),
      currency: s.currency,
      notes: s.notes ?? '',
      remindDays: s.remindDays,
      serviceId: s.serviceId,
      logoBlobId: s.logoBlobId,
      startedDate: s.startedDate,
      shared: s.shared ?? false,
      payTo: s.payTo ?? '',
      payHow: s.payHow ?? '',
      createdAt: s.createdAt,
    );
