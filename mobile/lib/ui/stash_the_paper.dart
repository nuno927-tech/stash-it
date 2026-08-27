/// The one part of the job the app cannot do for you.
///
/// Ported from `StashThePaper.tsx`.
///
/// Everything else here is a copy: the photo, the dates, the export. **The
/// paper original is the only artefact that exists once**, and a phone in a
/// puddle does not take it with it. Retailers and manufacturers vary on whether
/// a photograph is enough — plenty accept one, some still want the physical
/// receipt, and you find out which on the day the thing breaks.
///
/// ── Shown after every save, not once ──────────────────────────────────────
/// It was tempting to fire it three times and stop, on the grounds that people
/// learn. But **the habit is per receipt, not per person**: knowing you should
/// file the paper is no use on the eleventh purchase if the paper for it is in
/// a carrier bag.
///
/// Which is also why it is this short. Something read a few hundred times gets
/// one line, and the line is Scout's rather than the app's — a squirrel
/// admitting he would lose it in the garden is easier to hear for the hundredth
/// time than a sentence about claim requirements.
library;

import 'package:flutter/material.dart';

import 'feedback.dart';
import 'scout.dart';
import 'theme.dart';

/// Scout's line. The tour makes the same point at more length.
const String stashThePaperTitle = 'Now stash the paper';
const String stashThePaperBody =
    "I've got the photo. You keep the original — one folder, somewhere dry. "
    "I'd bury it, but drawers are easier to find again.";

/// Slides up over two thirds of the screen, and stays until dismissed.
///
/// ── Two thirds, and why not a small toast ─────────────────────────────────
/// A toast is something you can miss, and this is the one instruction in the
/// app that has to land — the app cannot file a receipt for you. A sheet that
/// takes most of the screen and needs a tap to leave is the difference between
/// telling somebody and being sure they heard.
///
/// Not full height either: the list underneath stays visible at the top, so it
/// reads as a note about what just happened rather than as a new screen the
/// save has navigated to.
Future<void> showStashThePaper(BuildContext context) {
  feedback(Cue.save);

  return showModalBottomSheet<void>(
    context: context,
    // Dismissible by dragging as well as by the button. The button is the
    // instruction; the drag is for the second hundred times.
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate700,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => const _Sheet(),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet();

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
              // Filing day. The pose is the message — he is putting the paper
              // somewhere, which is the whole instruction.
              const Expanded(
                child: Center(
                  child: Scout(
                    pose: ScoutPose.folder,
                    height: 210,
                    motion: [ScoutMotion.float, ScoutMotion.pop],
                    shadow: true,
                  ),
                ),
              ),

              Text(
                stashThePaperTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  letterSpacing: -0.6,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                stashThePaperBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 14,
                  height: 1.45,
                  color: c.muted,
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    feedback(Cue.tap);
                    Navigator.of(context).pop();
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
                    'Will do',
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: c.onGold,
                    ),
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
