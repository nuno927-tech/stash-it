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
import '../logic/attachments.dart';
import '../logic/notify_offer.dart';
import '../logic/paper_form.dart';
import '../models/types.dart';
import '../notify/sync.dart';
import 'feedback.dart';
import 'unlock_sheet.dart';

/// What happened, said in a way the caller can act on.
sealed class PaperOutcome {
  const PaperOutcome();
}

/// It is in the database.
class PaperSaved extends PaperOutcome {
  const PaperSaved(this.paperId);

  /// The row it went into, so a caller can attach something to it.
  ///
  /// The wizard offers a scan after the save rather than asking for one
  /// mid-flow, and an offer needs something to attach to. For an edit this is
  /// the id it already had.
  final String paperId;
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

  /// Scans chosen but not yet written. Staged for the same reason an item's
  /// are — a new document has no id to point at until it is saved. See
  /// `PendingDoc`.
  List<PendingDoc> pending = const [],
}) async {
  try {
    final paper = toPaper(draft, propertyId: repo.propertyId);

    final paperId = isNew ? await repo.createPaper(paper) : paper.id;
    if (!isNew) await repo.savePaper(paper);

    /*
      Written after the document exists, and only then.

      The bytes go into the blobs table and the row that points at them goes
      into docs — the same two steps an item's attachments take, against
      `paperId` instead of `itemId`.
    */
    for (final scan in pending) {
      await _writeScan(repo, scan, paperId);
    }

    unawaited(syncReminders(repo));

    // Not `save` — that is what a settings toggle gets. This is the app doing
    // the one thing it is for. See the note on `Cue.stashed`.
    feedback(Cue.stashed);

    // A document always has an expiry — it is the one thing this form refuses
    // to save without — so a save here always earns the offer.
    if (datedSave(expiresOn: draft.expiresOn)) armNotifyOffer();

    return PaperSaved(paperId);
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

/// One staged scan, written against the document it belongs to.
///
/// The twin of `_write` in save_item.dart, and deliberately a twin rather than
/// a shared function taking a `DocOwner`: the two differ by one named
/// argument, and a shared version would be a switch on the owner wrapping two
/// lines that are already clear.
Future<void> _writeScan(
  Repository repo,
  PendingDoc scan,
  String paperId,
) async {
  String? blobId;

  if (scan.bytes != null) {
    blobId = newId();
    await repo.putBlob(
      blobId,
      scan.bytes!,
      scan.mime ?? 'application/octet-stream',
    );
  }

  await repo.createDoc(Doc.onPaper(
    id: '',
    paper: paperId,
    kind: scan.kind,
    title: scan.title,
    blobId: blobId,
    url: scan.url,
  ));
}
