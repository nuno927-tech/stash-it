/// Every pose Scout has, in one scroll.
///
/// ── An easter egg that shows up in a menu is just a feature ───────────────
/// Reached by tapping the Settings heading ten times, which is the point: it
/// costs nothing, helps nobody, and is only ever found by somebody messing
/// about. The moment it has a row on the settings list it stops being a joke
/// and starts being a screen that has to justify itself.
///
/// Each pose gets a line in Scout's own voice and nothing else. It said where
/// each one appears in the app as well — useful to whoever is building it, and
/// beside the point to somebody who has just found a joke. `scoutRoster` in
/// scout.dart still holds that, for the compiler's readers.
library;

import 'package:flutter/material.dart';

import 'feedback.dart';
import 'scout.dart';
import 'theme.dart';

Future<void> showScoutAlbum(BuildContext context) {
  // The save cue: three rising notes. The one sound in the set with a shape to
  // it, for the one screen that is purely a reward.
  feedback(Cue.save);

  return showModalBottomSheet<void>(
    context: context,

    /*
      ── The root navigator, and why this one needs saying ────────────────────

      This is opened from the shell rather than from inside a screen, and the
      shell sits above the `Navigator` that the tabs push their routes onto. A
      sheet asked for from there resolves to whichever navigator happens to be
      nearest, which is not reliably the one drawing the screen — so the
      confetti appeared and the album did not.

      `useRootNavigator` says which one, rather than leaving it to the tree.
    */
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate700,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => const _Album(),
  );
}

/// Scout's line for each pose. His voice, not the app's — a squirrel admitting
/// he would lose a receipt in the garden is easier to read than a sentence
/// about claim requirements, which is the same reason the paper reminder works.
const Map<ScoutPose, String> _quips = {
  ScoutPose.acorn:
      'Buried this one in 2019. Dug it up on the first go. Do not ask me '
      'about the other four thousand.',
  ScoutPose.waving:
      'Hello. I have read your warranties. All of them. It was a quiet week.',
  ScoutPose.report:
      'Eighty-three per cent. I checked it twice, and then once more because '
      'I enjoy being right.',
  ScoutPose.receipt:
      'I can photograph this. I cannot make a shop reprint it in 2029. Guess '
      'which one they ask for.',
  ScoutPose.folder:
      'A drawer. Dry, findable, does not need digging up in February. '
      'Honestly, humans are ahead on this one.',
  ScoutPose.bin:
      'Thirty days. After that it is gone, and not even I know where — '
      'which for me is saying something.',
  ScoutPose.clipboard:
      'Glasses on. This is the part where I write down a model number you '
      'will never read and will one day desperately need.',
  ScoutPose.calendar:
      'Nine things renew this month. I am not judging you. I am holding a '
      'calendar in a way that judges you.',
  ScoutPose.dancing:
      'No screen has earned this. I have been warmed up since March.',
  ScoutPose.settings:
      'Every switch on this desk does something. I checked. Twice. One of '
      'them makes a noise and I am very proud of it.',
  ScoutPose.alert:
      'Ears up. Something expires soon and you were about to make a cup of tea.',
  ScoutPose.resting:
      'Nothing needs you. This is not me being lazy, it is me being the '
      'entire point of the app.',
  ScoutPose.lounge:
      'Everything is covered until August. I have earned this. Do not add '
      'a subscription.',
};

class _Album extends StatelessWidget {
  const _Album();

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final roster = scoutRoster.entries.toList();

    return FractionallySizedBox(
      heightFactor: 0.66,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 2, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You found Scout's album",
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      letterSpacing: -0.6,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                children: [
                  /*
                    The backstory, at the top.

                    It is the reason the mascot is a squirrel rather than a
                    mascot, and it has lived on the marketing site where the
                    people using the app never see it. This is the one screen
                    with room for it and nothing better to do.
                  */
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: c.washGoldSoft,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: c.washGoldLine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How Scout got the job',
                          style: TextStyle(
                            fontFamily: fontDisplay,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            height: 1.25,
                            letterSpacing: -0.3,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'The brief was simple: find something that is good at '
                          'remembering where it put things.\n\n'
                          'A squirrel stashes several thousand nuts in a season '
                          'and comes back for them months later, across a whole '
                          'garden, in the dark, under snow. No list. No '
                          'reminders. He just knows. Nobody else applied.\n\n'
                          'So Scout keeps the ledger: what is covered, what is '
                          'about to lapse, what is missing a receipt. He wears '
                          'the glasses for the paperwork and takes them off for '
                          'everything else.\n\n'
                          'And when there is nothing left to do, he falls asleep '
                          'on the card — which is the most honest thing an app '
                          'has ever told you.',
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 13,
                            height: 1.55,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  for (final entry in roster) ...[
                    _Row(pose: entry.key, name: entry.value.$1),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),

            Container(height: 1, color: c.line),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: FilledButton(
                onPressed: () {
                  feedback(Cue.tap);
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.onGold,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
                child: Text(
                  'Back to work',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: c.onGold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.pose, required this.name});

  final ScoutPose pose;
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        /*
          Breathing, not floating. Thirteen poses drifting up and down on one
          scroll is the seasick version of the motion rule — see the note at the
          top of scout.dart. One primitive each, the quietest one.
        */
        SizedBox(
          width: 130,
          child: Center(
            child: Scout(
              pose: pose,
              height: 124,
              motion: const [ScoutMotion.breathe],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '“${_quips[pose]}”',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 12.5,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                  color: c.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
