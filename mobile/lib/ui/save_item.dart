/// Writing an item, once, for every screen that makes one.
///
/// ── Why this is not in the form ────────────────────────────────────────────
/// It was, and it was the only place an item could be created. Then a second
/// way to add one arrived — the step-by-step sheet — and the choice was to
/// copy a hundred lines or to move them.
///
/// Copying would have been worse than it sounds. This is not one insert: it is
/// a photograph written before the record so its id can go on it, an id that
/// only exists after the insert so the staged documents have something to
/// point at, a cap that can refuse the whole thing halfway, a reminder
/// schedule that has to be rebuilt rather than added to, and a notification
/// offer armed on a specific condition. Every one of those is a thing to get
/// wrong twice.
///
/// ── It returns an outcome; it does not drive the screen ────────────────────
/// The two callers need different things afterwards — one pops a sheet and
/// suggests filing the receipt, the other has its own ending — so this reports
/// what happened and leaves the consequences to them. The one exception is the
/// cap: unlocking is offered from here because the alternative is handing back
/// "you have too many" and making each caller rediscover what to do about it.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../billing/current.dart';
import '../db/repository.dart';
import '../logic/attachments.dart';
import '../logic/item_form.dart';
import '../logic/notify_offer.dart';
import '../models/types.dart';
import '../notify/sync.dart';
import 'feedback.dart';
import 'unlock_sheet.dart';

/// What happened, said in a way the caller can act on.
sealed class SaveOutcome {
  const SaveOutcome();
}

/// It is in the database.
class ItemSaved extends SaveOutcome {
  const ItemSaved({required this.id, required this.attached});

  final String id;

  /// Whether any document went in with it.
  ///
  /// The caller uses this to decide whether to suggest filing the receipt:
  /// being told to go and file the receipt immediately after filing the
  /// receipt is the kind of nagging that gets an app's advice ignored.
  final bool attached;
}

/// It did not save, and this is the sentence to show.
class ItemNotSaved extends SaveOutcome {
  const ItemNotSaved(this.message);

  final String message;
}

/// Writes an item and everything that hangs off it.
///
/// Never throws. Anything unexpected comes back as [ItemNotSaved] with a
/// sentence, because both callers are sheets that have to stay open and say
/// something rather than disappear.
Future<SaveOutcome> saveItemDraft(
  BuildContext context, {
  required Repository repo,
  required ItemDraft draft,
  required bool isNew,
  Uint8List? photo,
  List<PendingDoc> pending = const [],
  DateTime? createdAt,
}) async {
  try {
    // The item's picture, written first so its id can go on the record.
    if (photo != null) {
      final id = newId();
      await repo.putBlob(id, photo, 'image/jpeg');
      draft.photoBlobId = id;
      draft.thumbBlobId = id;
    }

    final item = toItem(draft, propertyId: repo.propertyId, createdAt: createdAt);

    /*
      The id comes back from the insert, it is not on the draft.

      `toItem` leaves `id` empty for something new and the repository mints
      one — so writing the staged documents against `item.id` would file every
      one of them against an item called "", which is not an error anywhere:
      the insert succeeds, and the receipt simply never appears on anything.
    */
    final String itemId;
    if (isNew) {
      itemId = await repo.createItem(item);
    } else {
      await repo.saveItem(item);
      itemId = item.id;
    }

    // And now there is something for the staged documents to point at.
    for (final doc in pending) {
      await _write(repo, doc, itemId);
    }

    /*
      A saved item can move a reminder in either direction — adding cover
      creates one, deleting the purchase date removes one — so the schedule is
      rebuilt rather than added to. Not awaited: a form should close on the
      save, not on the notification tray.
    */
    unawaited(syncReminders(repo));

    if (datedSave(
      purchaseDate: draft.purchaseDate,
      hasCover: draft.realCoverages.any((c) => c.hasTerm),
    )) {
      armNotifyOffer();
    }

    // Not `save` — that is what a settings toggle gets. This is the app doing
    // the one thing it is for. See the note on `Cue.stashed`.
    feedback(Cue.stashed);

    return ItemSaved(id: itemId, attached: pending.isNotEmpty);
  } on CapReached catch (e) {
    /*
      The wall, and the way through it, in the same moment.

      Handing back "you have too many" would leave every caller to work out
      what to do about it, and the answer is always the same: offer the unlock
      right here, because whatever they filled in is still sitting behind this
      sheet and unlocking means pressing save again with nothing retyped.
    */
    if (!context.mounted) return ItemNotSaved(e.message);

    final unlocked = await showUnlock(
      context,
      repo: repo,
      billing: appBilling,
      count: e.count,
    );

    if (!unlocked || !context.mounted) return ItemNotSaved(e.message);

    // Straight back into the save they were already trying to make.
    return saveItemDraft(
      context,
      repo: repo,
      draft: draft,
      isNew: isNew,
      /*
        Not the photo again.

        It was written to blobs before the cap refused, and the draft is
        carrying its id now. Passing it back in would write a second copy of
        the same picture and point the item at that one, leaving the first
        orphaned in the database for ever.
      */
      pending: pending,
      createdAt: createdAt,
    );
  } catch (e) {
    return ItemNotSaved('That did not save: $e');
  }
}

/// One staged document, onto an item that now exists.
Future<void> _write(Repository repo, PendingDoc doc, String itemId) async {
  String? blobId;

  if (doc.bytes != null) {
    blobId = newId();
    await repo.putBlob(
      blobId,
      doc.bytes!,
      doc.mime ?? 'application/octet-stream',
    );
  }

  await repo.createDoc(Doc(
    id: '',
    itemId: itemId,
    kind: doc.kind,
    title: doc.title,
    blobId: blobId,
    url: doc.url,
  ));
}
