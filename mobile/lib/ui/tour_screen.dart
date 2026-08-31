/// The tour, one screen at a time.
///
/// The script lives in `logic/tour.dart` and is read as prose there — a tour is
/// writing, and writing scattered through a widget tree stops being editable.
/// This is only the frame around it.
///
/// ── Eight steps, and it was nearly eleven ─────────────────────────────────
/// Documents, subscriptions and reminders all arrived after the script was
/// written, and the obvious move — a screen each, appended — would have made a
/// fourteen-tap introduction to an app whose whole pitch is that it is quick.
/// Two of the originals were folded into their neighbours instead.
///
/// **A tour is a budget. Every screen added has to displace one, or it is not
/// worth the tap it costs.**
library;

import 'package:flutter/material.dart';

import '../logic/tour.dart' as tour;
import '../db/repository.dart';
import 'feedback.dart';
import 'scout.dart';
import 'theme.dart';

/// Two thirds, like every other sheet — so the app stays visible above it and
/// the tour reads as a note about the thing behind it rather than a wall you
/// have to get through before you are allowed in.
/// ── It now records that it happened ──────────────────────────────────────
/// It used to take no repository and write nothing. Finishing it changed
/// nothing on disk, so `onboardedAt` stayed null forever and the app had no
/// way to know the tour had ever been seen — which is half of why it never
/// fired on launch and why it would have fired again on every launch if it
/// had.
///
/// [dismissible] is false when this is the first-launch showing: a tour that
/// vanishes on a stray tap outside it, before anything has been recorded, is
/// a tour somebody never sees again and never chose to skip.
Future<void> showTour(
  BuildContext context, {
  required Repository repo,
  bool dismissible = true,
}) {
  feedback(Cue.tap);

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: StashColors.of(context).slate700,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => _Tour(repo: repo),
  );
}

/// The script's poses are its own enum, so the two can be reordered
/// independently — `logic/tour.dart` has no business importing a widget.
const Map<tour.ScoutPose, ScoutPose> _poses = {
  tour.ScoutPose.waving: ScoutPose.waving,
  tour.ScoutPose.receipt: ScoutPose.receipt,
  tour.ScoutPose.folder: ScoutPose.folder,
  tour.ScoutPose.clipboard: ScoutPose.clipboard,
  tour.ScoutPose.calendar: ScoutPose.calendar,
  tour.ScoutPose.report: ScoutPose.report,
  tour.ScoutPose.alert: ScoutPose.alert,
  tour.ScoutPose.acorn: ScoutPose.acorn,
  tour.ScoutPose.lounge: ScoutPose.lounge,
};

class _Tour extends StatefulWidget {
  const _Tour({required this.repo});

  final Repository repo;

  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  final PageController _pages = PageController();
  final TextEditingController _name = TextEditingController();
  int _at = 0;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Finished. Records the date, and the name if one was typed.
  ///
  /// `onboardedAt` is what stops this reappearing on every launch, so it is
  /// written whether or not a name was given — reaching the end IS the
  /// completion, and the name is optional on its own step.
  Future<void> _done() async {
    final typed = _name.text.trim();
    final now = await widget.repo.settings();
    await widget.repo.saveSettings(now.copyWith(
      onboardedAt: DateTime.now(),
      displayName: typed.isEmpty ? now.displayName : typed,
    ));
  }

  /// Skipped. Comes back in three days, once.
  ///
  /// `onboardedAt` is deliberately NOT set: skipping is not finishing, and
  /// somebody who skipped should get one more offer rather than none.
  Future<void> _later() async {
    final now = await widget.repo.settings();
    await widget.repo.saveSettings(
      now.copyWith(tourRemindAt: tour.remindLater()),
    );
  }

  Future<void> _next() async {
    if (tour.isLastStep(_at)) {
      feedback(Cue.save);
      await _done();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    feedback(Cue.tap);
    _pages.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return FractionallySizedBox(
      heightFactor: 0.66,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: tour.tourSteps.length,
                // Swipeable as well as tappable. Somebody who has read one
                // screen and wants the next has two ways to say so, and the
                // gesture is the one they will try first on a phone.
                onPageChanged: (i) {
                  feedback(Cue.tap);
                  setState(() => _at = i);
                },
                itemBuilder: (context, i) => _Step(step: tour.stepAt(i), name: _name),
              ),
            ),

            /*
              The dots say how much is left.

              A tour with no visible end is a tour people leave, because the
              only honest guess about its length is "more than this". Eight
              dots is a promise you can see.
            */
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < tour.tourSteps.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _at ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _at ? c.gold : c.slate600,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  // Always available, never the loud one. A tour you cannot
                  // leave is a tour that gets remembered for that.
                  TextButton(
                    onPressed: () async {
                      feedback(Cue.collapse);
                      await _later();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(
                      tour.isLastStep(_at) ? '' : 'Skip',
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 13.5,
                        color: c.muted,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.gold,
                      foregroundColor: c.onGold,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                    child: Text(
                      tour.isLastStep(_at) ? 'Done' : 'Next',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: c.onGold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.step, required this.name});

  final tour.TourStep step;

  /// Shared with the sheet, so what is typed here survives a swipe back and
  /// forth and is still there to be saved on the last tap.
  final TextEditingController name;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final asks = step.key == tour.nameStepKey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Scout(
                pose: _poses[step.pose]!,
                // Smaller on the step that has a field under it, so the
                // keyboard does not push the whole thing off the sheet.
                height: asks ? 118 : 168,
                motion: const [ScoutMotion.float, ScoutMotion.breathe],
                shadow: true,
              ),
            ),
          ),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w800,
              fontSize: 21,
              height: 1.2,
              letterSpacing: -0.5,
              color: c.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 13.5,
              height: 1.5,
              color: c.muted,
            ),
          ),

          if (asks) ...[
            const SizedBox(height: 16),
            TextField(
              controller: name,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.words,
              // Done rather than next: this is the last step, and a keyboard
              // offering "next" on the final field suggests there is more.
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: c.text,
              ),
              decoration: InputDecoration(
                hintText: 'Scout',
                hintStyle: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: c.muted,
                ),
                filled: true,
                fillColor: c.field,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  borderSide: BorderSide(color: c.washGoldLine),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Optional',
              style: TextStyle(fontFamily: fontBody, fontSize: 11.5, color: c.muted),
            ),
          ],
        ],
      ),
    );
  }
}
