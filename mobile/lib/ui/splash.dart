/// The first thing you see.
///
/// ── Why the app draws its own rather than leaving it to Android ───────────
/// Android 12 and later put the launcher icon in a small circle in the middle
/// of a coloured screen, and there is no way to make that anything else — it is
/// a fixed size, masked to a circle, with no room for a wordmark. Scout ends up
/// as a thumbnail of a squirrel, which is a worse introduction than none.
///
/// So the system splash is painted the app's own background colour and left to
/// hold that colour for the few hundred milliseconds before Flutter is running,
/// and this takes over from it: same background, so the handover is invisible,
/// and then Scout arrives at a size worth looking at.
///
/// ── And why it does not wait for anything ─────────────────────────────────
/// The database is already open by the time this is built — `main` awaits it
/// before the first frame. So this is not a loading screen and must not pretend
/// to be one: no spinner, no progress, no artificial delay beyond the length of
/// its own animation. It is a title card, and it leaves.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'parts.dart';
import 'scout.dart';
import 'theme.dart';

/// How long the splash owns the screen, hold plus fade.
///
/// Exported because something has to happen AFTER it — the tour, on a first
/// launch — and the alternative is a second number somewhere else that has to
/// be kept in step with these two by hand.
const Duration splashHold = Duration(milliseconds: 1100);
const Duration splashFade = Duration(milliseconds: 420);
const Duration splashTotal = Duration(milliseconds: 1520);

class Splash extends StatefulWidget {
  const Splash({required this.child, super.key});

  /// The app, revealed underneath.
  final Widget child;

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: splashFade,
  );

  bool _gone = false;

  @override
  void initState() {
    super.initState();

    /*
      1.1 seconds, then fade.

      Long enough for the pop to finish and be read as a thing arriving rather
      than a flash; short enough that it is not in the way. The whole point of
      this app is speed of entry — somebody opens it to check one date — and a
      title card that outstays that is a tax on every single launch.
    */
    _leave = Timer(splashHold, () {
      if (!mounted) return;
      _out.forward().then((_) {
        if (mounted) setState(() => _gone = true);
      });
    });
  }

  /*
    Held so it can be cancelled, which it was not.

    An uncancelled timer outlives the widget: the `if (!mounted)` inside guards
    the work but not the timer itself, so a shell disposed inside the first
    1.1 seconds left one running with a reference to a dead State.

    Nothing ever caught it, and the reason is luck rather than design — the
    widget tests wind the clock 1,200ms, past the 1,100 this waits, so it had
    always fired by teardown. The identical bug in `Shell._maybeTour` waits
    1,760ms and failed ten tests immediately. Same mistake, different number.
  */
  Timer? _leave;

  @override
  void dispose() {
    _leave?.cancel();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;

    final c = StashColors.of(context);
    final height = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _out,
          builder: (context, _) => IgnorePointer(
            ignoring: _out.value > 0,
            child: Opacity(
              opacity: 1 - _out.value,
              child: ColoredBox(
                // `slate800`, the same surface the app itself sits on — so the
                // splash does not leave, it dissolves.
                color: c.slate800,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // On guard, holding the acorn. Half the screen, because
                      // the whole reason to draw this rather than let Android
                      // do it is that Android's version is too small to read.
                      Scout(
                        pose: ScoutPose.acorn,
                        height: height * 0.5,
                        motion: const [ScoutMotion.float, ScoutMotion.pop],
                        shadow: true,
                      ),
                      SizedBox(height: height * 0.06),
                      const Wordmark(fontSize: 42),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
