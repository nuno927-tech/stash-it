/// What the two long jobs look like while they run, and when they finish.
///
/// ── Why a sheet and not a spinner in the button ───────────────────────────
/// Making a backup takes seconds on a real collection, and until now the only
/// sign of it was a disabled button. The app looked crashed — which was the
/// literal report — because nothing moved and nothing said why.
///
/// A modal sheet is the honest shape for it: the work cannot be interrupted
/// halfway and leave anything sensible behind, so the screen should say so by
/// being modal rather than by looking available and ignoring taps.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../logic/backup_progress.dart';
import 'acorn_progress.dart';
import 'confetti.dart';
import 'feedback.dart';
import 'scout.dart';
import 'theme.dart';

/// Runs [job] behind a sheet that cannot be dismissed, feeding it a watcher.
///
/// Returns whatever the job returned, or rethrows — the caller still owns the
/// error message, because it knows what was being attempted.
Future<T> runWithAcorns<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(BackupWatcher onStep) job,
}) async {
  final progress = ValueNotifier<BackupProgress>(
    const BackupProgress(BackupStage.reading),
  );

  // Shown without awaiting: the sheet has to be on screen while the work runs,
  // not after it.
  final shown = showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: StashColors.of(context).slate800,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => _Working(title: title, progress: progress),
  );

  try {
    return await job((step) => progress.value = step);
  } finally {
    /*
      Closed from here rather than by the sheet noticing it is finished.

      The sheet has no way to know whether the job threw, and a sheet that
      dismisses itself on reaching 100% would sit at 100% for ever when
      something failed at 99. The owner of the future closes it, in a `finally`
      so a failure closes it too.
    */
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    await shown;
    progress.dispose();
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.title, required this.progress});

  final String title;
  final ValueListenable<BackupProgress> progress;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return PopScope(
      // Not cancellable. Half a backup is not a backup, and half a restore is
      // worse than none — the transaction would roll back and the person would
      // be left guessing which they had.
      canPop: false,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Scout(
                pose: ScoutPose.acorn,
                height: 120,
                motion: [ScoutMotion.breathe],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 22),
              ValueListenableBuilder<BackupProgress>(
                valueListenable: progress,
                builder: (context, step, _) => AcornProgress(progress: step),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------- and after */

/// The screen a restore lands on.
///
/// ── Why a restore earns a moment and a backup does not ───────────────────
/// A backup ends with the share sheet — the phone's own confirmation that
/// something real was produced, and a line in Settings saying what. Nothing
/// more is needed.
///
/// A restore ends with the app silently holding different data. Everything the
/// person owns has just been replaced, and the only evidence was a line of
/// grey text. That is the one moment in this app worth stopping for: the cue,
/// the buzz, Scout, and the numbers said out loud.
Future<void> showRestoreDone(
  BuildContext context, {
  required int items,
  required int papers,
  required int subscriptions,
  required int files,
}) async {
  // Sound and haptics together — `Cue.stashed` is the app's "that worked"
  // voice, the same one a saved item plays.
  feedback(Cue.stashed);

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate800,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => _RestoreDone(
      items: items,
      papers: papers,
      subscriptions: subscriptions,
      files: files,
    ),
  );
}

class _RestoreDone extends StatefulWidget {
  const _RestoreDone({
    required this.items,
    required this.papers,
    required this.subscriptions,
    required this.files,
  });

  final int items;
  final int papers;
  final int subscriptions;
  final int files;

  @override
  State<_RestoreDone> createState() => _RestoreDoneState();
}

class _RestoreDoneState extends State<_RestoreDone> {
  @override
  void initState() {
    super.initState();
    // After the frame, so the sheet is on screen to drop it onto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) dropConfetti(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    final lines = <(int, String, String)>[
      (widget.items, 'item', 'items'),
      (widget.papers, 'document', 'documents'),
      (widget.subscriptions, 'subscription', 'subscriptions'),
      (widget.files, 'file', 'files'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Scout(
                // Filing the paper original — the pose a save already uses, so
                // "it is put away" reads the same wherever it happens.
                pose: ScoutPose.folder,
                height: 150,
                motion: [ScoutMotion.breathe],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Everything is back',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w800,
                fontSize: 24,
                letterSpacing: -0.5,
                color: c.text,
              ),
            ),
            const SizedBox(height: 18),

            /*
              The counts, one per line, in the display face.

              A restore is the one action whose result nobody can check by
              looking — the lists behind this sheet look the same whether four
              items arrived or forty. So the numbers are the receipt, and a
              kind that restored nothing says zero rather than being left out:
              a missing line reads as "it worked" when it means "there were
              none of those".
            */
            for (final (n, one, many) in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        '$n',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: fontDisplay,
                          fontWeight: FontWeight.w800,
                          fontSize: 21,
                          letterSpacing: -0.6,
                          color: n == 0 ? c.muted : c.gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      n == 1 ? one : many,
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 14,
                        color: n == 0 ? c.muted : c.text,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: c.onGold,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
              child: Text(
                'Good',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  color: c.onGold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
