/// The one time reminders are offered.
///
/// The rules are in `logic/notify_offer.dart` and are tested there. This is the
/// dialog, and the wording — which is most of the decision.
///
/// ── Why it appears over the list rather than over the form ────────────────
/// The form has already closed by the time this runs, and that ordering is
/// deliberate. A dialog that lands on top of the thing somebody just filled in
/// reads as "there is a problem with what you typed"; one that lands after it
/// has visibly saved reads as what it is — an offer about the next thing.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/notify_offer.dart';
import '../notify/sync.dart';

/// Called by each tab after a form closes. Does nothing unless the save that
/// just happened armed it.
Future<void> maybeOfferNotifications(
    BuildContext context, Repository repo) async {
  if (!notifyOfferArmed()) return;
  clearNotifyOffer();

  final settings = await repo.settings();

  final offer = shouldOffer(
    OfferInput(
      asked: settings.notifyAskedAt != null,
      enabled: settings.notifyEnabled == true,
      dated: true,
      /*
        Always `ready` here, and the reason is worth writing down.

        On Android 13+ the OS reports notifications as disabled until the
        permission prompt has been answered — so asking it *before* asking the
        person cannot tell "never been asked" from "said no", and reading it as
        denied would mean the offer never appears on a fresh install. Our own
        `notifyAskedAt` is the record of whether the question has been put, and
        it is checked one line above. The OS gets asked when they say yes.
      */
      verdict: NotifyVerdict.ready,
    ),
  );

  if (!offer || !context.mounted) return;

  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Want a heads-up?'),
      /*
        Three sentences, and each is doing a job.

        The first says what arrives, because "enable notifications" tells
        somebody nothing about what they are agreeing to receive. The second is
        the privacy claim, stated plainly and only because it is now literally
        true — there is no server to send anything to. The third makes declining
        safe: the app is not broken without this, and copy that implies
        otherwise is how people end up resenting a prompt they said yes to.
      */
      content: const Text(
        'Stash it can remind you when a warranty is running out or a document '
        'needs renewing — a day or two before it matters, not after.\n\n'
        'The reminders are set on this phone and never leave it. There is no '
        'account and nothing to send.\n\n'
        'You can change this in Settings whenever you like.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes, remind me'),
        ),
      ],
    ),
  );

  // The date is written whichever way they answered — that is what makes this
  // ask-once rather than ask-until-yes. See the note in logic/notify_offer.dart.
  var enabled = false;
  if (yes == true) {
    // And only now does the OS get asked. Somebody who taps "Yes, remind me"
    // and then denies the system prompt has said no twice; the switch reflects
    // the second answer, not the first.
    enabled = await notifications.ask();
  }

  await repo.setNotify(enabled: enabled);
  await syncReminders(repo);

  if (yes == true && !enabled && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Android is holding notifications for Stash it. You can turn them '
          'on in the phone\'s app settings.',
        ),
      ),
    );
  }
}
