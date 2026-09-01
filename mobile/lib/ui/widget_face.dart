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
/// ── And no Image.asset ─────────────────────────────────────────────────────
/// Scout is a `ui.Image`, handed in already decoded, rather than an
/// `Image.asset`. An asset resolves asynchronously: it starts loading, the
/// widget builds without it, and a frame later it appears. That is invisible
/// on screen and fatal here, because the render captures the FIRST frame — the
/// one with a hole where the mascot goes. Decoding before the render is the
/// only way to be sure he is in the picture.
///
/// Nothing here animates. A picture cannot.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/widget_payload.dart';
import 'parts.dart';
import 'theme.dart';

/// The size the ring face is rendered at, in logical pixels.
///
/// Four cells by three: the wordmark, the dial, Scout beside it and four
/// figures underneath is the dashboard's own card, and it does not fit in a
/// square. Rendered at 3x — see `widget_mirror.dart` — so it survives being
/// stretched.
const Size ringFaceSize = Size(300, 200);

/// The mascot's asset, decoded once by the mirror and handed to every face.
const String scoutWidgetAsset = 'assets/mascot/scout-report.webp';

/// The dashboard card, as the home screen sees it.
///
/// Deliberately the same composition as the top of the Home tab: wordmark,
/// dial, Scout, four figures. Somebody who taps this widget arrives at a screen
/// that looks like what they just tapped, which is the whole job of a widget —
/// anything rearranged for the smaller space would make the app feel like a
/// different app.
class RingFace extends StatelessWidget {
  const RingFace({
    required this.payload,
    required this.dark,
    this.scout,
    super.key,
  });

  final WidgetPayload payload;

  /// Which palette, decided by the caller rather than by the phone — both are
  /// drawn every time and the launcher chooses at display.
  final bool dark;

  /// Already decoded. Null draws the face without him rather than failing:
  /// a missing mascot is a worse widget, not a broken one.
  final ui.Image? scout;

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Wordmark(c: c),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: Center(child: _Dial(payload: payload, c: c))),
                  if (scout != null)
                    /*
                      Presenting your numbers, exactly as he does on the
                      dashboard. He is sized by height and lets his own width
                      follow, because a mascot squashed to fit a box is worse
                      than no mascot.
                    */
                    RawImage(
                      image: scout,
                      height: 104,
                      width: 104 * scout!.width / scout!.height,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _Figures(payload: payload, c: c),
          ],
        ),
      ),
    );
  }
}

/// "Stash" in the text colour, "it" in gold — the app's masthead, small.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.c});

  final StashColors c;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Stash '),
            TextSpan(text: 'it', style: TextStyle(color: c.gold)),
          ],
        ),
        style: TextStyle(
          fontFamily: fontDisplay,
          fontWeight: FontWeight.w800,
          fontSize: 19,
          letterSpacing: -0.5,
          height: 1,
          color: c.text,
        ),
      );
}

/// The dial and the one number inside it.
class _Dial extends StatelessWidget {
  const _Dial({required this.payload, required this.c});

  final WidgetPayload payload;
  final StashColors c;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 104,
        width: 104,
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
                  with the per cent sign dropped to a third and muted.

                  FittedBox for the reason it is there too: "100%" is the case
                  that overflows, and a household with everything in date is
                  not an edge case.
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
                          fontSize: 44,
                          letterSpacing: -2,
                          height: 1,
                          color: c.text,
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          fontFamily: fontDisplay,
                          fontWeight: FontWeight.w200,
                          fontSize: 15,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'still in date',
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 9,
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

/// The four counts, in the dashboard's own order and colours.
class _Figures extends StatelessWidget {
  const _Figures({required this.payload, required this.c});

  final WidgetPayload payload;
  final StashColors c;

  @override
  Widget build(BuildContext context) {
    /*
      Four, not three, and "no date" is gold rather than a fourth traffic-light
      colour — the same reasoning as the dashboard, written down there: it is
      not good, not urgent, just unanswerable, and honey is already spoken for
      one column to the left.
    */
    final figures = <(int, String, Color)>[
      (payload.inDate, 'in date', c.moss),
      (payload.needsAction, 'action needed', c.honey),
      (payload.lapsed, 'lapsed', c.ember),
      (payload.noDate, 'no date', c.gold),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (count, label, tone) in figures)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w300,
                    fontSize: 20,
                    height: 1,
                    // A zero is not news. Muting it stops four columns of
                    // colour shouting at somebody whose stash is fine.
                    color: count == 0 ? c.muted : tone,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 9,
                    fontWeight: FontWeight.w300,
                    height: 1,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
