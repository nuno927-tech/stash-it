/// The one thing this app ever asks to be paid for.
///
/// ── What it is not ────────────────────────────────────────────────────────
/// Not a trial that expires, not a subscription, not a feature held back.
/// Twenty things free, and every one of them is the whole app: the reminders
/// work, the backups work, the photographs work, nothing is watermarked and
/// nothing nags. The limit is a number, and the payment removes the number.
///
/// ── Why there is a list on it anyway ──────────────────────────────────────
/// This screen used to be one paragraph and a button, on the reasoning that
/// there is nothing to upsell because there is no better version. That is
/// true of the *features* and misses what somebody is actually deciding.
///
/// The question in front of them is not "which tier" — it is "is this app
/// worth eight pounds", and the answers to that are things the free version
/// already does and they may never have noticed: nothing is uploaded, there
/// is no account, there are no ads, and there is no server that could be
/// breached because there is no server. Those are the reasons to pay, and
/// leaving them unsaid on the one screen that asks for money is modesty at
/// the customer's expense.
///
/// The list is short and every line is checkable. No "military-grade" and no
/// promises about the future — this app cannot leak your data because it does
/// not have it, which is a fact about its architecture and not a policy that
/// can be revised.
///
/// ── Restore is not a footnote ─────────────────────────────────────────────
/// It sits directly under the buy button at the same size. Somebody on a new
/// phone reaches this screen by being told they are full, which is exactly the
/// moment a paid customer is most likely to pay twice. A "restore purchases"
/// link in grey at the bottom is how that happens.
library;

import 'package:flutter/material.dart';

import '../billing/billing.dart';
import '../db/repository.dart';
import '../logic/limits.dart';
import 'feedback.dart';
import 'pro_badge.dart';
import 'scout.dart';
import 'theme.dart';

/// Shows the offer. Resolves true when the app came back unlocked.
///
/// ── The same sheet answers two different questions ────────────────────────
/// Before buying it asks "is this worth it", and the six reasons below are the
/// argument. After buying, tapping the Pro card asks "what did I get", and the
/// same six lines are the answer — so the list is shared rather than written
/// twice and left to drift.
///
/// What [owned] changes is only what sits under them: a price and two buttons,
/// or a thank-you and a way out. Showing somebody a Buy button for a thing they
/// already own is the specific failure this exists to avoid.
Future<bool> showUnlock(
  BuildContext context, {
  required Repository repo,
  required Billing billing,

  /// How many things are saved, for the line that says where they are.
  required int count,

  /// True when this is a receipt rather than an offer.
  bool owned = false,
}) async {
  feedback(Cue.expand);

  final unlocked = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) =>
        _Unlock(repo: repo, billing: billing, count: count, owned: owned),
  );

  return unlocked ?? false;
}

class _Unlock extends StatefulWidget {
  const _Unlock({
    required this.repo,
    required this.billing,
    required this.count,
    required this.owned,
  });

  final Repository repo;
  final Billing billing;
  final int count;
  final bool owned;

  @override
  State<_Unlock> createState() => _UnlockState();
}

class _UnlockState extends State<_Unlock> {
  late Future<Offer> _offer = widget.billing.offer();

  bool _busy = false;
  String? _said;

  Future<void> _run(Future<BuyResult> Function() action,
      {required bool buying}) async {
    setState(() {
      _busy = true;
      _said = null;
    });

    final result = await action();
    if (!mounted) return;

    switch (result) {
      case BuyResult.unlocked:
        feedback(Cue.unlock);
        Navigator.of(context).pop(true);

      case BuyResult.cancelled:
        // Backing out is not an error and does not want a message. They know.
        setState(() => _busy = false);

      case BuyResult.nothingToRestore:
        setState(() {
          _busy = false;
          _said = buying
              ? 'That did not go through.'
              : "Nothing to restore on this account. If you paid with a "
                  'different Google account, sign in with that one and try again.';
        });

      case BuyResult.failed:
        setState(() {
          _busy = false;
          _said = 'The store is not answering. Try again in a moment.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return FractionallySizedBox(
      // Taller than it was, because there is a list on it now. Not full
      // height: the strip of app still showing is what says this is a sheet
      // somebody can back out of rather than a wall.
      heightFactor: 0.9,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
          children: [
            Center(
              child: Scout(
                pose: ScoutPose.acorn,
                // Smaller than the 150 it was. The mascot is the welcome, not
                // the argument, and the argument now needs the room.
                height: 112,
                motion: const [ScoutMotion.float, ScoutMotion.breathe],
                shadow: true,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Stash it Pro',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                    letterSpacing: -0.9,
                    height: 1.1,
                    color: c.text,
                  ),
                ),
                // Only once it is true. On the offer sheet this would be a
                // badge for something nobody has yet.
                if (widget.owned) ...[
                  const SizedBox(width: 10),
                  const ProBadge(scale: 1.15),
                ],
              ],
            ),
            const SizedBox(height: 8),

            Text(
              widget.owned
                  // No count, and no limit named. Saying "you have 34 of 20"
                  // to somebody who paid to stop being counted would be a
                  // strange thing to put in front of them.
                  ? 'Yours, on this Google account, for good. Here is what that '
                      'covers.'
                  // The number they are at, said back. Somebody who arrived
                  // here by being refused already knows they are full; somebody
                  // who came from Settings does not, and the same sentence
                  // serves both.
                  : 'You have ${widget.count} of $freeItemLimit. One payment '
                      'lifts the limit for good — and it is the only thing this '
                      'app will ever ask you to pay for.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 14,
                height: 1.55,
                color: c.muted,
              ),
            ),
            const SizedBox(height: 20),

            /*
              ── The list, and the order it is in ────────────────────────────

              Unlimited first, because it is the thing being bought. Then the
              shape of the payment, because "one payment" is the objection
              most people arrive with. Then the three privacy lines, which are
              the reason to want this app rather than a cheaper one — and
              which are equally true of the free version, said here because
              this is where somebody is deciding whether the thing is worth
              anything.

              Every line is a fact somebody could check by turning off the
              wifi. That is the test a claim on this screen has to pass.
            */
            const _Perk(
              icon: Icons.all_inclusive,
              title: 'Unlimited everything',
              body: 'Items, documents and subscriptions, as many as you like. '
                  'Photos, receipts and manuals with them.',
            ),
            const _Perk(
              icon: Icons.check_circle_outline,
              title: 'Paid once, yours for good',
              body: 'Not a subscription. No renewal, no expiry, and it comes '
                  'back on a new phone with the same Google account.',
            ),
            const _Perk(
              icon: Icons.phone_android_outlined,
              title: 'Everything stays on your phone',
              body: 'No account to make, no cloud to sign into. Nothing is '
                  'uploaded, so nothing can be sold or read.',
            ),
            const _Perk(
              icon: Icons.cloud_off_outlined,
              title: 'No servers, nothing to leak',
              body: 'There is no company database holding your receipts. '
                  'There is nothing to breach, because there is nothing there.',
            ),
            const _Perk(
              icon: Icons.lock_outline,
              title: 'Encrypted on the device',
              body: 'The database is encrypted with a key held in the phone\'s '
                  'own secure storage, and can be locked behind your '
                  'fingerprint.',
            ),
            const _Perk(
              icon: Icons.block_outlined,
              title: 'No ads, ever',
              body: 'Nothing to dismiss, nothing tracking you between apps, '
                  'and no reason for either — you paid instead.',
            ),
            const SizedBox(height: 20),

            /*
              Owned: a thank-you and a way out, and deliberately no store call
              at all. Asking Play for a price here would be work done to render
              a button nobody should be offered, and it would put "the store is
              not answering" in front of a paying customer on a plane.
            */
            if (widget.owned) ...[
              Text(
                'Thanks for supporting Scout and Stash it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: c.gold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.text,
                    side: BorderSide(color: c.line),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: c.text,
                    ),
                  ),
                ),
              ),
            ] else
              FutureBuilder<Offer>(
                future: _offer,
                builder: (context, snap) {
                  final offer = snap.data;

                  if (offer == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  /*
                  A store that is not answering gets a sentence, not a dead
                  button. Three different causes look identical from the app —
                  no connection, the product not set up, the account not on the
                  testers list — so it says what is observable and stops.
                */
                  if (!offer.available) {
                    return Column(
                      children: [
                        Text(
                          'The store is not answering right now, so there is '
                          'nothing to show you here. Everything you have saved '
                          'is fine — this only affects buying.',
                          textAlign: TextAlign.center,
                          style: hintStyle(c),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () =>
                              setState(() => _offer = widget.billing.offer()),
                          child: Text(
                            'Try again',
                            style:
                                TextStyle(fontFamily: fontBody, color: c.gold),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _run(widget.billing.buy, buying: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: c.gold,
                            foregroundColor: c.onGold,
                            disabledBackgroundColor: c.gold,
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                          ),
                          child: Text(
                            // The store's own price, localised. Never assembled
                            // here — see the note in billing.dart.
                            'Go Pro for ${offer.price}',
                            style: TextStyle(
                              fontFamily: fontDisplay,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: c.onGold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Same width, same shape, one step quieter. See the note
                      // at the top of the file on why this is not a link.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () =>
                                  _run(widget.billing.restore, buying: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.text,
                            side: BorderSide(color: c.line),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                          ),
                          child: Text(
                            'I already paid',
                            style: TextStyle(
                              fontFamily: fontBody,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: c.text,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],

            if (_said != null) ...[
              const SizedBox(height: 16),
              Text(_said!, textAlign: TextAlign.center, style: hintStyle(c)),
            ],

            const SizedBox(height: 18),

            /*
              What happens to the twenty they already have, said out loud.

              It is the first question somebody has when an app tells them they
              are full, and leaving it unanswered invites the worst guess.
              Nothing is hidden, nothing is deleted, nothing is held hostage —
              the only thing the limit stops is adding the twenty-first.
            */
            // Only on the offer. It answers "what happens to my twenty if I
            // don't pay", which is not a question anybody who has paid is
            // asking.
            if (!widget.owned)
              Text(
                'Everything you have saved stays exactly as it is either way. '
                'The limit only stops new ones.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 12,
                    height: 1.5,
                    color: c.muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// One reason, as an icon, a claim and a sentence backing it up.
///
/// Left-aligned in a centred sheet on purpose. A column of centred paragraphs
/// has a ragged left edge and gets skimmed as decoration; six lines starting
/// at the same x get read as a list, which is what this is.
class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Nudged down to sit on the title's baseline rather than its box.
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 19, color: c.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 12.5,
                    height: 1.45,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
