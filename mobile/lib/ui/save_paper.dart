/// Writing a document, once, for both screens that make one.
///
/// The same move as `save_item.dart` and `save_sub.dart`, for the same reason:
/// the step-by-step sheet arrived beside the long form, and the save is a cap
/// that can refuse halfway and offer a way through, a reminder schedule that
/// has to be rebuilt rather than added to, and a notification offer.
///
/// It reports what happened and leaves the consequences to the caller.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../billing/current.dart';
import '../db/repository.dart';
import '../logic/notify_offer.dart';
import '../logic/paper_form.dart';
import '../notify/sync.dart';
import 'feedback.dart';
import 'unlock_sheet.dart';

/// What happened, said in a way the caller can act on.
sealed class PaperOutcome {
  const PaperOutcome();
}

/// It is in the database.
class PaperSaved extends PaperOutcome {
  const PaperSaved();
}

/// It did not save, and this is the sentence to show.
class PaperNotSaved extends PaperOutcome {
  const PaperNotSaved(this.message);

  final String message;
}

/// Writes a document.
///
/// Never throws. Anything unexpected comes back as [PaperNotSaved] with a
/// sentence, because both callers are sheets that have to stay open and say
/// something rather than disappear.
Future<PaperOutcome> savePaperDraft(
  BuildContext context, {
  required Repository repo,
  required PaperDraft draft,
  required bool isNew,
}) async {
  try {
    final paper = toPaper(draft, propertyId: repo.propertyId);

    if (isNew) {
      await repo.createPaper(paper);
    } else {
      await repo.savePaper(paper);
    }

    unawaited(syncReminders(repo));

    // Not `save` — that is what a settings toggle gets. This is the app doing
    // the one thing it is for. See the note on `Cue.stashed`.
    feedback(Cue.stashed);

    // A document always has an expiry — it is the one thing this form refuses
    // to save without — so a save here always earns the offer.
    if (datedSave(expiresOn: draft.expiresOn)) armNotifyOffer();

    return const PaperSaved();
  } on CapReached catch (e) {
    /*
      The wall, and the way through it, in the same moment.

      Handing back "you have too many" would leave every caller to work out what
      to do about it, and the answer is always the same: offer the unlock right
      here, because whatever they filled in is still sitting behind this sheet
      and unlocking means pressing save again with nothing retyped.
    */
    if (!context.mounted) return PaperNotSaved(e.message);

    final unlocked = await showUnlock(
      context,
      repo: repo,
      billing: appBilling,
      count: e.count,
    );

    if (!unlocked || !context.mounted) return PaperNotSaved(e.message);

    // Straight back into the save they were already trying to make.
    return savePaperDraft(context, repo: repo, draft: draft, isNew: isNew);
  } catch (e) {
    return PaperNotSaved('That did not save: $e');
  }
}
