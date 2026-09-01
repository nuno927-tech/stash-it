/// What the home screen widgets actually look like, drawn in Flutter.
///
/// ── Why a picture ──────────────────────────────────────────────────────────
/// A home screen widget is drawn by the LAUNCHER, from RemoteViews: a fixed
/// list of view classes, no custom drawing, no custom fonts below Android 8,
/// and no arcs at all. The ring is an arc. So the app draws its own face into
/// a PNG while it is running, and the launcher shows the picture.
///
/// The cost is honest and worth stating: a picture is only as fresh as the
/// last time the app ran. `widget_mirror.dart` says what is done about that.
///
/// ── No BuildContext, and no Theme ──────────────────────────────────────────
/// These are rendered off-screen, outside the app's widget tree, so there is
/// no `StashColors.of(context)` to call and no MediaQuery to read. The palette
/// arrives as an argument instead — which also means both faces can be drawn
/// on the same pass, dark and light, and the launcher picks. See
/// `stashColors()` in theme.dart.
///
/// Nothing here animates. A picture cannot.
library;

import 'package:flutter/material.dart';

import '../logic/widget_payload.dart';
import 'parts.dart';
import 'theme.dart';

/// The size the ring face is rendered at, in logical pixels.
///
/// Square, because the widget is square and a launcher scales the picture to
/// whatever cell it ends up in. Rendered at 3x — see `widget_mirror.dart` — so
/// it is still sharp when somebody stretches it.
const Size ringFaceSize = Size(160, 160);

/// The ring, as the home screen sees it.
///
/// The same dial as the dashboard's, painted by the same `RingPainter`, at a
/// size that survives being shrunk into a 2x2 cell. What it drops from the
/// dashboard version is everything that needs a second glance: the three
/// counts, the labels, Scout. A widget gets one look.
class RingFace extends StatelessWidget {
  const RingFace({
    required this.payload,
    required this.dark,
    super.key,
  });

  final WidgetPayload payload;

  /// Which palette, decided by the caller rather than by the phone — both are
  /// drawn every time and the launcher chooses at display.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = stashColors(dark: dark);

    /*
      Transparent, deliberately.

      The rounded surface behind this comes from @drawable/widget_background,
      which the launcher swaps for its night version by itself. Baking the
      background into the picture would mean a light card sitting on a dark
      home screen for as long as it took somebody to reopen the app.

      The ink cannot escape that — a picture's text colour is fixed when it is
      drawn — which is exactly why both faces are drawn and handed over.
    */
    return SizedBox.fromSize(
      size: ringFaceSize,
      child: CustomPaint(
        painter: RingPainter(
          covered: payload.inDate.toDouble(),
          soon: payload.needsAction.toDouble(),
          lapsed: payload.lapsed.toDouble(),
          track: c.slate600,
          error: c.ember,
          moss: c.moss,
          honey: c.honey,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /*
                The same proportions as the dashboard's — a big thin figure
                with the per cent sign dropped to a third and muted — scaled
                down for a face a fifth the size.

                FittedBox for the same reason it is there: "100%" is the case
                that overflows, and a household with everything in date is not
                an edge case.
              */
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${payload.percent}',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w200,
                        fontSize: 60,
                        letterSpacing: -2.7,
                        height: 1,
                        color: c.text,
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w200,
                        fontSize: 20,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'still in date',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                  color: c.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
