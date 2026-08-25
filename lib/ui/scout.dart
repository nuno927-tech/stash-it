/// Scout, the mascot.
///
/// Ported from `src/components/Scout.tsx` and the `.rig` / `m-*` rules in
/// `src/styles/app.css`. The renders themselves are the PWA's files, copied
/// rather than redrawn — same alpha, same contact shadows — so the two apps
/// cannot drift apart by one of them being touched up.
///
/// ── Each pose means something, and that is why there are thirteen ─────────
/// Scout asleep on a card with nothing left to do says "you're finished" more
/// plainly than the sentence next to it does. The roster below is the same one
/// the PWA keeps in `SCOUT_POSES`, including where each pose belongs, because a
/// list that has to be updated in two places is a list that falls out of date
/// in one of them.
///
/// ── The motion rule, taken from the concept ───────────────────────────────
/// **Combine at most two primitives.** Float plus breathe reads alive; adding a
/// third reads seasick.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ScoutPose {
  /// Guarding the thing itself — the launch screen, and the install prompt.
  acorn,

  /// Hello. First run, and only first run.
  waving,

  /// Presenting your numbers. Beside the ring on the dashboard.
  report,

  /// Holding the paperwork. The items list.
  receipt,

  /// Filing the paper original. After a save, and in the tour.
  folder,

  /// Fishing receipts back out. The bin.
  bin,

  /// Glasses on, taking it down. The item form.
  clipboard,

  /// Holding up the month. Subscriptions.
  calendar,

  /// Both arms up. Not placed on a screen yet.
  dancing,

  /// At a control desk. Settings.
  settings,

  /// Ears up, something needs you.
  alert,

  /// Curled up, nothing does.
  resting,

  /// Feet up with a cold drink. Off duty.
  lounge,
}

/// What each pose is for. The album, and the only written-down record of the
/// cast — a pose that exists but is not listed is a pose everyone forgets.
const Map<ScoutPose, (String name, String where)> scoutRoster = {
  ScoutPose.acorn: ('On guard', 'The launch screen, and the invitation to install'),
  ScoutPose.waving: ('Hello', 'First run, and only first run'),
  ScoutPose.report: ('The field report', 'Beside the ring on the dashboard'),
  ScoutPose.receipt: ('Paperwork', 'The items list'),
  ScoutPose.folder: ('Filing day', 'After you save something, and in the tour'),
  ScoutPose.bin: ('Second thoughts', 'The bin, getting something back out'),
  ScoutPose.clipboard: ('Taking it down', 'Adding or editing an item'),
  ScoutPose.calendar: ('Minding the month', 'The subscriptions tab'),
  ScoutPose.dancing: ('Very pleased', 'Not on a screen yet'),
  ScoutPose.settings: ('At the desk', 'Settings'),
  ScoutPose.alert: ('Ears up', 'When something needs a minute, or needs confirming'),
  ScoutPose.resting: ('Off duty', 'When nothing does'),
  ScoutPose.lounge: ('Feet up', 'The one place he is off duty'),
};

enum ScoutMotion {
  /// Up nine pixels and back over 4.4 seconds, with the shadow shrinking as he
  /// rises. The shadow is what makes it read as height rather than as drift.
  float,

  /// A 1.4% squash and stretch about the feet, over 3.2 seconds. Almost
  /// invisible, which is the point — you notice its absence, not its presence.
  breathe,

  /// A double-take, not a jump.
  ///
  /// This was seven pixels and four degrees every 3.6 seconds, which on a card
  /// you are trying to read is a distraction rather than a bit of life — and
  /// the card only exists when something needs doing, so it is already asking
  /// for attention by being there. Half the movement, and less often.
  alert,

  /// Scales up from 0.7 once, on an overshooting curve. An entrance, not a loop.
  pop,
}

String _asset(ScoutPose pose) => 'assets/mascot/scout-${pose.name}.webp';

/// Scout at a given height, optionally moving.
///
/// `height` rather than width, because the poses have different aspect ratios —
/// he is wider holding a calendar than curled up asleep — and matching heights
/// is what keeps him the same size from screen to screen.
class Scout extends StatefulWidget {
  const Scout({
    required this.pose,
    required this.height,
    this.motion = const [],
    this.shadow = false,
    super.key,
  });

  final ScoutPose pose;
  final double height;

  /// At most two. See the note at the top of the file.
  final List<ScoutMotion> motion;

  /// A soft ellipse on the ground beneath him. Only worth it when he is
  /// floating or standing alone on an empty screen; under a small inline pose
  /// it reads as a smudge.
  final bool shadow;

  @override
  State<Scout> createState() => _ScoutState();
}

class _ScoutState extends State<Scout> with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4400),
  );
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final AnimationController _alert = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5400),
  );
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /*
    ── `didChangeDependencies`, not `initState` ──────────────────────────────

    Starting the animations needs `MediaQuery`, to honour the phone's
    reduced-motion setting — and reading an inherited widget in `initState` is
    an error, because the element is not yet attached to the tree that would
    answer. Flutter says so at length, and it said so on the home and settings
    screens, where Scout is built directly rather than inside a list.

    This callback runs immediately after `initState` and again whenever the
    thing it depends on changes, which is exactly the behaviour wanted here: a
    person turning reduced motion on in Android settings gets a Scout that
    stops moving, without reopening the app.
  */
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  @override
  void didUpdateWidget(Scout old) {
    super.didUpdateWidget(old);
    if (old.motion != widget.motion) _start();
  }

  void _start() {
    /*
      Reduced motion is honoured, and the whole point of honouring it is that
      the mascot still appears. Somebody who has asked their phone to stop
      things moving has not asked to be shown less; they have asked not to be
      made queasy. `pop` is excluded from the check on purpose — a single
      scale-in on appearance is not the kind of motion that causes trouble, and
      without it he materialises out of nothing.
    */
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    void loop(AnimationController c, ScoutMotion m) {
      if (widget.motion.contains(m) && !still) {
        c.repeat();
      } else {
        c.stop();
        c.value = 0;
      }
    }

    loop(_float, ScoutMotion.float);
    loop(_breathe, ScoutMotion.breathe);
    loop(_alert, ScoutMotion.alert);

    if (widget.motion.contains(ScoutMotion.pop)) {
      _pop.forward(from: 0);
    } else {
      _pop.value = 1;
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _breathe.dispose();
    _alert.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _asset(widget.pose),
      height: widget.height,
      fit: BoxFit.contain,
      // The renders are large; letting Flutter decode them at display size
      // keeps thirteen mascots from costing more memory than the database.
      cacheHeight: (widget.height * MediaQuery.of(context).devicePixelRatio).round(),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_float, _breathe, _alert, _pop]),
      builder: (context, _) {
        // 0 → 1 → 0 over the cycle, eased. The CSS is `ease-in-out` on a
        // 0/50/100 keyframe set, which is this.
        double wave(AnimationController c) =>
            Curves.easeInOut.transform((math.sin(c.value * 2 * math.pi - math.pi / 2) + 1) / 2);

        final lift = widget.motion.contains(ScoutMotion.float) ? -9.0 * wave(_float) : 0.0;

        final breath = widget.motion.contains(ScoutMotion.breathe) ? wave(_breathe) : 0.0;
        final sx = 1 + 0.014 * breath;
        final sy = 1 - 0.012 * breath;

        final (perkY, perkTurn) = _perk(_alert.value);

        final popped = widget.motion.contains(ScoutMotion.pop)
            ? Curves.easeOutBack.transform(_pop.value)
            : 1.0;

        Widget scout = Transform.translate(
          offset: Offset(0, lift + perkY),
          child: Transform.rotate(
            angle: perkTurn,
            // Squash and stretch is about the feet, not the middle — a
            // creature standing on the ground does not sink into it when it
            // breathes out.
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scaleX: sx,
              scaleY: sy,
              alignment: Alignment.bottomCenter,
              child: image,
            ),
          ),
        );

        if (popped != 1.0) {
          scout = Opacity(
            opacity: _pop.value.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.7 + 0.3 * popped, child: scout),
          );
        }

        if (!widget.shadow) return scout;

        /*
          The shadow does not move with him — it shrinks and fades as he rises,
          which is what makes the float read as height rather than as sliding
          around. Drawn behind, and outside the transform, for the same reason.
        */
        final rise = widget.motion.contains(ScoutMotion.float) ? wave(_float) : 0.0;

        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: -6,
              child: Opacity(
                opacity: 0.85 - 0.35 * rise,
                child: Container(
                  width: widget.height * 0.5 * (1 - 0.14 * rise),
                  height: 13,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x8C000000), Color(0x00000000)],
                      stops: [0.0, 0.7],
                    ),
                  ),
                ),
              ),
            ),
            scout,
          ],
        );
      },
    );
  }

  /// The double-take: still for 70% of the cycle, then three small movements.
  (double, double) _perk(double t) {
    if (!widget.motion.contains(ScoutMotion.alert)) return (0, 0);

    double at(double a, double b, double v) =>
        ((t - a) / (b - a)).clamp(0.0, 1.0) * v;

    if (t < 0.70) return (0, 0);
    if (t < 0.76) return (at(0.70, 0.76, -3), at(0.70, 0.76, -1.5 * math.pi / 180));
    if (t < 0.82) return (-3 + at(0.76, 0.82, 3), (-1.5 + at(0.76, 0.82, 2.5)) * math.pi / 180);
    if (t < 0.88) return (at(0.82, 0.88, -1.5), (1 - at(0.82, 0.88, 1)) * math.pi / 180);
    return (-1.5 + at(0.88, 1.0, 1.5), 0);
  }
}
