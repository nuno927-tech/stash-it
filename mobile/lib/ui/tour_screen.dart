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

import '../io/backup_folder.dart';
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
                  repo: widget.repo,
                ),
              ),
            ),

            /*
              The dots say how much is left.

              A tour with no visible end is a tour people leave, because the
              only honest guess about its length is "more than this". A row of
              dots is a promise you can see — and it counts the script rather
              than a number written here, so adding a step cannot leave the
              promise saying something the tour does not honour.
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
    required this.repo,
  });

  final tour.TourStep step;

  /// For the one step that writes something. See `_FolderButton`.
  final Repository repo;

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
          /*
            ── The title leads, Scout answers, the detail follows ────────────

            Scout used to be first and the words came underneath him, which
            made every screen a picture with a caption. The picture is the
            charm and the title is the point, and on a screen somebody swipes
            through in eight seconds the point should not be the second thing
            they reach.

            So: the claim, then the drawing of Scout illustrating it, then the
            sentence that explains it. He sits between the two rather than
            above both, which also gives him the whole middle of the screen to
            be drawn in.
          */
          const SizedBox(height: 6),
          /*
            ── Gold, and not honey ───────────────────────────────────────────

            `c.gold` is the brand colour — the "it" in the wordmark, every
            button, every link. `c.honey` is a state: it means action needed,
            everywhere else in the app. A tour title is not a warning, and
            spending the warning colour on nine screens of introduction is how
            a colour stops meaning anything by the time it matters.

            Both are darkened in the light theme rather than being one hex
            value, so this holds its contrast on white as well — see the note
            at the top of the palette.
          */
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w800,
              /*
                Display size, not heading size.

                21 was a heading borrowed from a card. This is the first thing
                on a screen that holds one sentence under it — it is the
                headline of the whole app, and it should read like the
                wordmark rather than like a section label.

                The tracking tightens as it grows: Bricolage at 800 sets wide,
                and at this size the default spacing turns a three-word title
                into three separate words.
              */
              fontSize: 32,
              height: 1.12,
              letterSpacing: -1.1,
              color: c.gold,
            ),
          ),
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
            step.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontBody,
              // Up from 13.5, which was a caption size doing a paragraph's
              // job — these are two or three sentences somebody is meant to
              // actually read, not a note under a control.
              fontSize: 15.5,
              height: 1.55,
              color: c.muted,
            ),
          ),
          if (step.key == tour.folderStepKey) ...[
            const SizedBox(height: 18),
            _FolderButton(repo: repo),
          ],
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
/// The one control in the tour that changes anything.
///
/// ── Asking for a folder here, rather than only in Settings ────────────────
/// Automatic backups are the single thing in this app that protects somebody
/// who never opens Settings, and they cannot start until a folder is chosen.
/// A card in Settings serves the people who go looking; this serves everyone
/// else, at the one moment they are already being told why it matters.
///
/// ── It asks Android, and Android may say no ───────────────────────────────
/// The picker is a whole other app and it can be backed out of, which is not
/// a failure and is not treated as one. Nothing is written unless a folder
/// comes back, the step stays skippable either way, and the Next button is
/// never blocked on it — a tour that will not let you past a permission
/// dialog is a tour people uninstall rather than finish.
class _FolderButton extends StatefulWidget {
  const _FolderButton({required this.repo});

  final Repository repo;

  @override
  State<_FolderButton> createState() => _FolderButtonState();
}

class _FolderButtonState extends State<_FolderButton> {
  String? _chosen;
  bool _busy = false;

  Future<void> _pick() async {
    setState(() => _busy = true);

    try {
      final tree = await pickBackupFolder();
      if (tree == null || !mounted) return;

      final label = await folderLabel(tree);
      final settings = await widget.repo.settings();

      await widget.repo.saveSettings(settings.copyWith(
        backupFolder: tree,
        backupFolderLabel: label ?? 'the folder you chose',
        clearAutoBackupError: true,
      ));

      if (mounted) setState(() => _chosen = label ?? 'that folder');
    } catch (_) {
      // A picker that would not open, or a grant Android declined. Neither is
      // worth an error on an introduction — Settings offers it again.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    if (_chosen case final where?) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 17, color: c.moss),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Backing up to $where',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        FilledButton(
          onPressed: _busy ? null : cued(_pick),
          style: FilledButton.styleFrom(
            backgroundColor: c.gold,
            foregroundColor: c.onGold,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
            ),
          ),
          child: Text(
            'Choose a folder',
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: c.onGold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          // Said before the picker opens, not after. Somebody about to be
          // handed Android's folder chooser should know why.
          'Or skip it and set one up later in Settings.',
          style: TextStyle(fontFamily: fontBody, fontSize: 11.5, color: c.muted),
        ),
      ],
    );
  }
}

