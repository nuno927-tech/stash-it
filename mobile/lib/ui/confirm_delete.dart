/// Deleting something, and the question worth asking first.
///
/// Ported from `ConfirmDelete.tsx`.
///
/// ── Why it is a sheet and not a dialog under the button ───────────────────
/// This used to be a block that appeared in the page underneath the delete
/// button — which sits at the very bottom of a form, so the question opened
/// below the fold. You tapped Delete, nothing visibly happened, and the
/// explanation of what you were agreeing to was off-screen. **A confirmation
/// you have to go looking for is not a confirmation.**
///
/// ── The reassurance leads, because it is the true part ────────────────────
/// Nothing goes anywhere for thirty days, and the slot comes back immediately.
/// Both are worth stating plainly: people hesitate over deleting when they are
/// at a limit, which is exactly the moment the slot returning is the thing they
/// wanted to know.
library;

import 'package:flutter/material.dart';

import '../logic/limits.dart';
import 'feedback.dart';
import 'scout.dart';
import 'theme.dart';

/// Asks, and answers true only on a deliberate Delete.
///
/// **There is no close button.** Every way out of this sheet that is not the
/// Delete button is a cancel — the back gesture, a tap on the scrim, a drag
/// downward, and the Keep it button. An X in the corner would be a fifth way to
/// do what four things already do, sitting next to the one control that
/// destroys something.
Future<bool> confirmDelete(
  BuildContext context, {
  required String name,

  /// No thirty-day bin behind this one, so the sheet must not promise a
  /// recovery window that does not exist.
  bool permanent = false,
}) async {
  feedback(Cue.tap);

  final answer = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate700,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => _Sheet(name: name, permanent: permanent),
  );

  return answer ?? false;
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.name, required this.permanent});

  final String name;
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return FractionallySizedBox(
      heightFactor: 0.66,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            children: [
              // Ears up. The pose that means something needs a decision, and
              // the same one the dashboard uses when something needs a minute.
              const Expanded(
                child: Center(
                  child: Scout(
                    pose: ScoutPose.alert,
                    height: 190,
                    motion: [ScoutMotion.alert, ScoutMotion.pop],
                    shadow: true,
                  ),
                ),
              ),

              Text(
                'Delete $name?',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 23,
                  letterSpacing: -0.6,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 10),

              // Naming the place, not just the policy. This said "it goes to
              // the bin for 30 days" for months while there was no bin anywhere
              // in the app — a promise nobody could check and nobody could use.
              Text(
                permanent
                    ? 'This one goes now — there is no bin behind it. You can '
                        'add it again in a moment.'
                    : 'It waits $purgeAfterDays days under Recently deleted, at '
                        'the bottom of the Items list.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 14,
                  height: 1.45,
                  color: c.muted,
                ),
              ),

              const SizedBox(height: 22),

              /*
                ── Keep it is the loud one ────────────────────────────────────

                The destructive option has to be chosen, never landed on by
                momentum — so the filled gold button is the one that does
                nothing, and Delete is an outline in the error colour underneath
                it. That is the opposite of the usual arrangement, and it is
                deliberate: the usual arrangement optimises for the answer the
                app wants, and this app does not want either answer.
              */
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    feedback(Cue.tap);
                    Navigator.of(context).pop(false);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: c.gold,
                    foregroundColor: c.onGold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                  child: Text(
                    'Keep it',
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: c.onGold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    feedback(Cue.delete);
                    Navigator.of(context).pop(true);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.ember,
                    side: BorderSide(color: c.ember.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Delete',
                        style: TextStyle(
                          fontFamily: fontBody,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: c.ember,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        permanent
                            ? 'Gone for good, right now.'
                            : 'Recoverable for $purgeAfterDays days, then gone for good.',
                        style: TextStyle(
                          fontFamily: fontBody,
                          fontSize: 11,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
