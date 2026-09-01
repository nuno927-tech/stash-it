/// Writing a subscription, once, for both screens that make one.
///
/// The same move as `save_item.dart`, for the same reason: the step-by-step
/// sheet arrived beside the long form and the save is not one insert. It is a
/// cap that can refuse halfway and offer a way through, a reminder schedule
/// that has to be rebuilt rather than added to, and a notification offer armed
/// on a condition this record has that no other record has — see below.
///
/// It reports what happened and leaves the consequences to the caller.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../billing/current.dart';
import '../db/repository.dart';
import '../logic/notify_offer.dart';
import '../logic/subscription_form.dart';
import '../notify/sync.dart';
import 'feedback.dart';
import 'unlock_sheet.dart';

/// What happened, said in a way the caller can act on.
sealed class SubOutcome {
  const SubOutcome();
}

/// It is in the database.
class SubSaved extends SubOutcome {
  const SubSaved();
}

/// It did not save, and this is the sentence to show.
class SubNotSaved extends SubOutcome {
  const SubNotSaved(this.message);

  final String message;
}

/// Writes a subscription.
///
/// Never throws. Anything unexpected comes back as [SubNotSaved] with a
/// sentence, because both callers are sheets that have to stay open and say
/// something rather than disappear.
Future<SubOutcome> saveSubDraft(
  BuildContext context, {
  required Repository repo,
  required SubscriptionDraft draft,
  required bool isNew,
}) async {
  try {
    final sub = toSubscription(draft, propertyId: repo.propertyId);

    if (isNew) {
      await repo.createSubscription(sub);
    } else {
      await repo.saveSubscription(sub);
    }

    unawaited(syncReminders(repo));

    // Not `save` — that is what a settings toggle gets. This is the app doing
    // the one thing it is for. See the note on `Cue.stashed`.
    feedback(Cue.stashed);

    /*
      The notification offer, only when a reminder was actually asked for.

      Every other save in the app offers on the strength of having a date. A
      subscription always has one and almost never wants waking for — see the
      note on `remindDays` — so offering on a date alone would be offering an
      empty schedule to somebody who just chose None two fields up.
    */
    if (draft.remindDays != null && draft.remindDays != 0) {
      if (datedSave(expiresOn: draft.anchorDate)) armNotifyOffer();
    }

    return const SubSaved();
  } on CapReached catch (e) {
    /*
      The wall, and the way through it, in the same moment.

      Handing back "you have too many" would leave every caller to work out what
      to do about it, and the answer is always the same: offer the unlock right
      here, because whatever they filled in is still sitting behind this sheet
      and unlocking means pressing save again with nothing retyped.
    */
    if (!context.mounted) return SubNotSaved(e.message);

    final unlocked = await showUnlock(
      context,
      repo: repo,
      billing: appBilling,
      count: e.count,
    );

    if (!unlocked || !context.mounted) return SubNotSaved(e.message);

    // Straight back into the save they were already trying to make.
    return saveSubDraft(context, repo: repo, draft: draft, isNew: isNew);
  } catch (e) {
    return SubNotSaved('That did not save: $e');
  }
}
