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

import 'dart:math' as math;

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

  /*
    ── Held here, not in the step ──────────────────────────────────────────

    The step that asks for a name is a `_Step`, and `_Step` is rebuilt every
    time the PageView scrolls. A focus node created there would be a new node
    on every frame of the swipe, which is the quiet version of the controller
    bug this app has already been bitten by: focus would be requested on an
    object that is thrown away before the keyboard finishes opening.

    It lives beside the controller it belongs with, for the same reason that
    one does.
  */
  final FocusNode _nameFocus = FocusNode();

  int _at = 0;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _nameFocus.dispose();
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

    /*
      ── Making room for the keyboard ────────────────────────────────────────

      This was a flat two thirds of the screen, anchored to the bottom. That is
      right for eight of the nine steps and wrong for the one with a field in
      it: a sheet pinned to the bottom edge is exactly where the keyboard
      appears, so the field somebody just tapped ended up behind it.

      Two things fix it together, and neither works alone.

      The padding lifts the whole sheet clear of the keyboard. On its own that
      pushes the top of the sheet off the screen, because two thirds plus a
      keyboard is more than a screen.

      So the height gives way as well: still two thirds when there is nothing
      in the way, and never more than the space actually left. `24` is a margin
      so the sheet does not meet the status bar.

      Animated because the keyboard is — an instant jump next to a sliding
      keyboard reads as a glitch rather than as the same movement.
    */
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: insets),
      child: SizedBox(
        height: math.min(screen * 0.66, screen - insets - 24),
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

                  /*
                    ── The keyboard opens itself on the last step ────────────

                    Somebody who has swiped through eight screens and arrived
                    at a single field should not then have to tap it. The step
                    exists to be answered, and the extra tap is the one that
                    makes an optional field feel like a form.

                    Driven from here rather than by `autofocus` on the field,
                    because a PageView builds the page either side of the one
                    you are on: autofocus would fire while the name step was
                    still off-screen, opening the keyboard a screen early.

                    And unfocused on the way out, or swiping back leaves the
                    keyboard up over a step that has nothing to type into.
                  */
                  if (tour.stepAt(i).key == tour.nameStepKey) {
                    _nameFocus.requestFocus();
                  } else {
                    _nameFocus.unfocus();
                  }
                },
                itemBuilder: (context, i) => _Step(
                  step: tour.stepAt(i),
                  name: _name,
                  focus: _nameFocus,
                ),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
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
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.step,
    required this.name,
    required this.focus,
  });

  final tour.TourStep step;

  /// Shared with the sheet, so what is typed here survives a swipe back and
  /// forth and is still there to be saved on the last tap.
  final TextEditingController name;

  /// Owned by the sheet, not by this — see the note there.
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final asks = step.key == tour.nameStepKey;
    final typing = asks && MediaQuery.viewInsetsOf(context).bottom > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Scout(
                pose: _poses[step.pose]!,
                /*
                  Smaller on the step that has a field under it, and smaller
                  again once the keyboard is actually up.

                  He is not dropped entirely while typing, though there is
                  room to. The whole point of this step is that it is Scout
                  asking your name — losing him mid-answer turns a greeting
                  into a form field.
                */
                height: typing ? 64 : (asks ? 118 : 168),
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
              focusNode: focus,
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
              style: TextStyle(
                  fontFamily: fontBody, fontSize: 11.5, color: c.muted),
            ),
          ],
        ],
      ),
    );
  }
}
