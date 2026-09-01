/// The small pieces every tab uses.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/timeline.dart';
import '../logic/warranty.dart';
import 'feedback.dart';
import 'scout.dart';
import 'theme.dart';

/// One number with a word under it, as `.coverstat` draws it.
///
/// ── The number is LIGHT, not bold ─────────────────────────────────────────
/// 24px of the display face at weight 200. That looks backwards for a figure
/// somebody is meant to read first, and it is the reason the row works: four
/// bold numbers in a row compete with each other and with the ring above them,
/// and the eye lands nowhere. Thin and large reads as a quantity; heavy and
/// large reads as a warning, which only one of these is.
///
/// The colour lives in the dot beside the label rather than in the digits, for
/// the same reason.
/*
  ── A figure that counts up to itself ───────────────────────────────────────

  Only when it is a number, and `count` is how a caller says so. The four on
  the dashboard sit beside a ring that sweeps; arriving fully formed next to
  it made them look like a different screen's furniture.

  `value` stays for everything that is not countable — a total in pounds, a
  short word — because counting "£46.5K" up is not a thing anybody wants.
*/
/*
  ── The dashboard's opening, and it plays once ──────────────────────────────

  The ring sweeps and the four figures count up from zero. That is an opening
  title: it earns its keep the first time somebody sees the screen, and after
  that it is a delay between tapping Home and reading a number.

  It was replaying on every visit to the tab, because the tab is rebuilt from
  scratch each time — `AnimatedSwitcher` disposes the old one, so `initState`
  ran again and the tween started from zero again. Somebody stepping Home →
  Items → Home watched the same 850ms performance twice.

  So: one flag, for the life of the process. First view animates; every view
  after it draws the finished numbers immediately. A cold start resets it,
  which is the right grain — "the first time you open the app" is exactly what
  a process-lifetime flag means.

  It is flipped from a post-frame callback rather than the moment the ring
  starts, because the figures are built AFTER the ring in the same frame and
  would otherwise read a flag the ring had already spent. Post-frame runs once
  the whole frame is laid out, so everything in it sees the same answer.

  A number CHANGING is a different event and still animates — see the note on
  `didUpdateWidget`. This governs the arrival, not the updates.
*/
bool _introPlayed = false;

/// Whether the dashboard's opening animation is still owed.
bool get dashboardIntroDue => !_introPlayed;

/*
  ── And it waits for the splash to get out of the way ───────────────────────

  `Splash` draws the app UNDERNEATH itself from the first frame and fades off
  after 1.5 seconds, which is deliberate — it means the dashboard is warm and
  finished by the time anybody sees it. It also meant the opening animation
  played, in full, behind an opaque title card, and the flag above was spent
  before the app was visible. The ring and the four figures simply appeared,
  already at their final values, every single launch.

  So the intro waits for this. It starts TRUE, so anything not wrapped in a
  splash — a test, a deep link straight into a tab — animates normally rather
  than silently never animating, which is the failure mode that would go
  unnoticed for another sixty versions.
*/
final ValueNotifier<bool> appRevealed = ValueNotifier<bool>(true);

/// The sweep, and the count, and they are one duration on purpose.
///
/// The arc and the figures beneath it describe the same tally. Two durations
/// would have them land at different moments, which reads as one chasing the
/// other rather than as a single picture assembling.
const Duration dashboardSweep = Duration(milliseconds: 1100);

class Figure extends StatelessWidget {
  const Figure({
    required this.value,
    required this.label,
    this.count,
    this.onTap,
    this.tone,
    super.key,
  });

  final String value;
  final String label;

  /// When set, the figure counts up to this instead of drawing [value].
  final int? count;

  /// Null when there is nothing to show. A figure that navigates to an empty
  /// screen is worse than one that does not respond.
  final VoidCallback? onTap;

  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              feedback(Cue.tap);
              onTap!();
            },
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Counted(
              value: value,
              count: count,
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w200,
                fontSize: 28,
                letterSpacing: -0.84,
                height: 1,
                color: c.text,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (tone != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: tone, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: c.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The row those figures sit in: equal columns, with a rule above.
///
/// A grid rather than a `Wrap`, because four equal columns is what makes them
/// scan as one measurement broken into parts. Wrapped, they read as four
/// separate facts that happen to be near each other — which is how the port had
/// them, and why they stopped looking like the PWA's.
/// The number, arriving.
///
/// `TweenAnimationBuilder` rather than a controller: there is no state to
/// keep beyond the number itself, and when the number changes it animates
/// from wherever it had got to — the same rule the ring follows, for the same
/// reason. Adding one item should nudge a figure, not replay it from zero.
class _Counted extends StatelessWidget {
  const _Counted(
      {required this.value, required this.count, required this.style});

  final String value;
  final int? count;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (count == null ||
        !dashboardIntroDue ||
        MediaQuery.of(context).disableAnimations) {
      return Text(count?.toString() ?? value, style: style);
    }

    /*
      Behind the splash this draws the finished number and does not move. The
      tween is not started and then hidden — it is not built at all, so when
      the splash lifts the builder mounts fresh and counts from zero. Nobody
      sees the still frame, because something opaque was over it.
    */
    return ValueListenableBuilder<bool>(
      valueListenable: appRevealed,
      builder: (context, revealed, _) => revealed
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: count!.toDouble()),
              duration: dashboardSweep,
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text('${v.round()}', style: style),
            )
          : Text('${count!}', style: style),
    );
  }
}

class FigureRow extends StatelessWidget {
  const FigureRow(this.figures, {super.key});

  final List<Widget> figures;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: StashColors.of(context).slate600)),
      ),
      child: Row(
        children: [for (final f in figures) Expanded(child: f)],
      ),
    );
  }
}

/// A heading, in sentence case rather than shouted.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A card with a shadow under it.
///
/// Material's `Card` takes one elevation and derives a single shadow from it;
/// this needs two layers at different blurs — see `cardShadow` for why. So the
/// box is built rather than themed, and `clip` is offered because the recent
/// strip puts a photograph against the rounded corner.
class StashCard extends StatelessWidget {
  const StashCard({required this.child, this.clip = false, super.key});

  final Widget child;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(Radii.lg);

    /*
      No border.

      It used to carry a hairline as well as a fill and a shadow — three
      devices saying "this is a raised surface", which is two more than the
      idea needs. The fill is `card` now, one step brighter than the page, and
      the shadow seats it. See the note on `StashColors.card`.
    */
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: radius,
        boxShadow: cardShadow(c, dark: dark),
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: child,
    );
  }
}

/// The heading at the top of a tab.
///
/// ── Every screen says what it is ──────────────────────────────────────────
/// The PWA gives each tab an `.apphead` with the screen's name in the display
/// face, and the port had none of them: five screens that opened straight into
/// a list. On a phone that is a real loss rather than a cosmetic one — the
/// bottom bar shows five icons and a small label, and after a swipe between
/// tabs the only thing telling you where you landed is the content.
///
/// Home is the exception and takes the wordmark instead, because a masthead
/// saying "Home" would be the app introducing itself as a navigation state.
class TabTitle extends StatelessWidget {
  const TabTitle(this.title, {this.pose, this.trailing, this.onTap, super.key});

  final String title;

  /// The Settings heading is the dev-mode tap target — ten taps on the word
  /// "Settings". A title that does something when tapped is invisible to
  /// anybody not looking for it, which is the whole point of an easter egg.
  final VoidCallback? onTap;

  /// Scout, small, at the right-hand end. The PWA gives every tab head one —
  /// `.subshead`, `.masthead` — doing the job that screen is for.
  final ScoutPose? pose;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Right at the top. It had 14 above it, which on a screen whose first
      // real content is a one-line figure left the heading floating.
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                title,
                // The same style as the wordmark, deliberately. These are all
                // mastheads — the app naming the screen you are on — and a
                // heading that changes face between tabs reads as two apps.
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          if (pose != null)
            Scout(pose: pose!, height: 74, motion: const [ScoutMotion.breathe]),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// "Stash **it**" — the masthead, with the second word in gold.
///
/// One widget rather than a string, because the colour change mid-phrase is
/// the wordmark. Written as `it` in gold everywhere it appears, including the
/// PWA's `.apptitle span`.
class Wordmark extends StatelessWidget {
  const Wordmark({this.fontSize = 42, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    /*
      ── `Text.rich`, not `RichText`, and this was a real bug ────────────────

      Both draw a styled span. Only `Text` applies the device's text scale —
      `RichText` renders at exactly the size it is given and ignores the
      Accessibility → Font size setting entirely.

      So the wordmark and the tab headings were both nominally 34, and on any
      phone whose font size is not at the default they came out different: the
      headings scaled with the setting and the masthead did not. On a device set
      below default, "Stash it" is visibly the larger of the two — which is what
      this was reported as.

      Nothing else here changed. Same 34, same weight, same style object.
    */
    final base =
        Theme.of(context).textTheme.headlineSmall!.copyWith(fontSize: fontSize);

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Stash '),
          TextSpan(
            text: 'it',
            style: TextStyle(color: StashColors.of(context).gold),
          ),
        ],
      ),
      style: base,
    );
  }
}

/// What an empty list should say, which is never nothing.
class Blank extends StatelessWidget {
  const Blank(this.message, {this.pose, this.poseHeight = 170, super.key});

  final String message;

  /*
    ── Scout stands on the empty screens, and this is not decoration ─────────

    An empty list is the least informative thing an app can show, and it is
    also the first thing a new user sees on four of the five tabs. The PWA puts
    a pose on every one of them for that reason — floating, with a shadow, so
    the screen has a subject rather than a paragraph in the middle of nothing.

    Which pose is not arbitrary either: the one holding a receipt on Items,
    the one holding up a month on Subscriptions, the one with a clipboard on
    Documents. He is doing the job the screen is for.
  */
  final ScoutPose? pose;
  final double poseHeight;

  @override
  Widget build(BuildContext context) {
    /*
      ── Scout shrinks rather than overflowing ────────────────────────────────

      An empty state is the one screen whose height is entirely out of its own
      control: a search that found nothing on a small phone in landscape gets a
      couple of hundred pixels, and a 180-tall mascot plus four lines of text
      does not fit in it. Flutter's answer to that is a yellow-and-black bar,
      which is a worse empty state than no mascot at all.

      So the pose is measured against what it has been given, and the whole
      thing scrolls if even the shrunken version is too tall. He disappears
      entirely below about 130 pixels — at that point he would be a thumbnail
      competing with the sentence, and the sentence is the part that has to be
      read.
    */
    return LayoutBuilder(
      builder: (context, box) {
        final room = box.maxHeight;
        final showPose = pose != null && room > 200;
        final height = showPose ? poseHeight.clamp(90.0, room * 0.45) : 0.0;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: room.isFinite ? room : 0),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showPose) ...[
                      Scout(
                        pose: pose!,
                        height: height,
                        motion: const [ScoutMotion.float],
                        shadow: true,
                      ),
                      const SizedBox(height: 28),
                    ],
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The colour a warranty state earns. Green, amber, red, grey.
Color toneOf(WarrantyState state, BuildContext context) => switch (state) {
      WarrantyState.covered => const Color(0xFF5FBF7E),
      WarrantyState.endingSoon => const Color(0xFFF2B33D),
      WarrantyState.expired => Theme.of(context).colorScheme.error,
      WarrantyState.unknown => Theme.of(context).disabledColor,
    };

/// A row from the merged timeline.
class TimelineTile extends StatelessWidget {
  const TimelineTile({required this.entry, super.key});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        entry.flagged ? Icons.error_outline : Icons.schedule,
        color: entry.flagged ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(entry.title),
      subtitle: Text(entry.detail),
      trailing: Text(
        whenLabelFor(entry),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

/// The ring: how much of what can run out still has not.
///
/// ── What it counts, and what it leaves out ────────────────────────────────
/// Warranties and documents. **Not subscriptions** — a subscription cannot
/// lapse, it renews, so counting nine of them as nine healthy units would make
/// the score rise when you take on a service and fall when you cancel one.
///
/// Undated records are not drawn and not in the divisor either. Including them
/// would mean the score DROPS when you add a record with a date missing, which
/// punishes the one behaviour the app wants.
/*
  ── The ring draws itself, rather than appearing already drawn ──────────────

  It used to be a StatelessWidget painting the final arc on its first frame:
  the dashboard's headline number was simply there, complete, before anybody
  had focused on it.

  A ring is a proportion, and a proportion is easier to read as it arrives —
  the eye follows the sweep and lands on where it stopped. Counting the
  percentage up alongside it means the number and the arc are saying the same
  thing at the same moment rather than one confirming the other afterwards.

  ── And it animates BETWEEN values, not just up from nothing ────────────────

  The obvious version sweeps from zero whenever it is built, which is right on
  first open and wrong every time after: adding one item to a household of
  twenty-five would replay the whole thing to move the arc by a degree.

  So the tween is from what is currently drawn to what has just arrived. On
  the first build that happens to be zero, which is the opening sweep; on an
  edit it is a short correction, which is what an edit is.
*/
class Ring extends StatefulWidget {
  const Ring({
    required this.inDate,
    required this.needsStarting,
    required this.lapsed,
    required this.percent,
    super.key,
  });

  final int inDate;
  final int needsStarting;
  final int lapsed;
  final int percent;

  @override
  State<Ring> createState() => _RingState();
}

class _RingState extends State<Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: dashboardSweep);

  late final CurvedAnimation _curve =
      CurvedAnimation(parent: _sweep, curve: Curves.easeOutCubic);

  // What was on screen when the last change arrived. Zero to begin with, which
  // is what makes the first appearance a full sweep.
  double _fromIn = 0, _fromSoon = 0, _fromLapsed = 0, _fromPercent = 0;

  @override
  void initState() {
    super.initState();

    /*
      Second and later visits open on the finished ring rather than sweeping to
      it again — see `dashboardIntroDue`. The controller is parked at 1 rather
      than skipped, so `didUpdateWidget` below still has a sensible `_curve
      .value` to interpolate from when a count actually changes.
    */
    if (!dashboardIntroDue) {
      _sweep.value = 1;
      _fromIn = widget.inDate.toDouble();
      _fromSoon = widget.needsStarting.toDouble();
      _fromLapsed = widget.lapsed.toDouble();
      _fromPercent = widget.percent.toDouble();
      return;
    }

    if (appRevealed.value) {
      _begin();
    } else {
      appRevealed.addListener(_onRevealed);
    }
  }

  void _onRevealed() {
    if (!appRevealed.value || !mounted) return;
    appRevealed.removeListener(_onRevealed);
    _begin();
  }

  void _begin() {
    _sweep.forward();
    /*
      Burned after the frame, not now. The four figures are built below this
      ring and listen to the same signal, so they are still mid-rebuild when
      this runs — spending the flag here would have the ring sweep while the
      numbers snapped, which is the half-animation that reads as a glitch.
    */
    WidgetsBinding.instance.addPostFrameCallback((_) => _introPlayed = true);
  }

  @override
  void didUpdateWidget(Ring old) {
    super.didUpdateWidget(old);
    if (old.inDate == widget.inDate &&
        old.needsStarting == widget.needsStarting &&
        old.lapsed == widget.lapsed &&
        old.percent == widget.percent) {
      return;
    }

    // Start the next run from whatever is drawn right now rather than from the
    // last target — a change arriving mid-sweep would otherwise jump back.
    final t = _curve.value;
    _fromIn = _fromIn + (old.inDate - _fromIn) * t;
    _fromSoon = _fromSoon + (old.needsStarting - _fromSoon) * t;
    _fromLapsed = _fromLapsed + (old.lapsed - _fromLapsed) * t;
    _fromPercent = _fromPercent + (old.percent - _fromPercent) * t;

    _sweep.forward(from: 0);
  }

  @override
  void dispose() {
    appRevealed.removeListener(_onRevealed);
    _curve.dispose();
    _sweep.dispose();
    super.dispose();
  }

  double _at(double from, num to, double t) => from + (to - from) * t;

  @override
  Widget build(BuildContext context) {
    /*
      ── The OS setting wins ─────────────────────────────────────────────────

      "Remove animations" in Android's accessibility settings is not a taste
      preference — people turn it on for motion sickness, for vestibular
      disorders, and because a phone that moves less is a phone that is easier
      to follow. A sweeping arc is exactly the sort of thing it means.

      Checked in `build` rather than at construction so it takes effect the
      moment the setting changes, without needing the screen reopened.
    */
    if (MediaQuery.of(context).disableAnimations) {
      return _RingFace(
        inDate: widget.inDate.toDouble(),
        needsStarting: widget.needsStarting.toDouble(),
        lapsed: widget.lapsed.toDouble(),
        percent: widget.percent,
      );
    }

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) => _RingFace(
        inDate: _at(_fromIn, widget.inDate, _curve.value),
        needsStarting: _at(_fromSoon, widget.needsStarting, _curve.value),
        lapsed: _at(_fromLapsed, widget.lapsed, _curve.value),
        percent: _at(_fromPercent, widget.percent, _curve.value).round(),
      ),
    );
  }
}

class _RingFace extends StatelessWidget {
  const _RingFace({
    required this.inDate,
    required this.needsStarting,
    required this.lapsed,
    required this.percent,
  });

  final double inDate;
  final double needsStarting;
  final double lapsed;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return SizedBox(
      // 176, the PWA's number. Smaller than the 208 it was drawn at when it
      // stood alone — a big ring and a mascot worth looking at do not both fit
      // across a phone, and a mascot too small to read is just clutter.
      height: 176,
      width: 176,
      child: CustomPaint(
        painter: _RingPainter(
          covered: inDate,
          soon: needsStarting,
          lapsed: lapsed,
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
                ── Big, and thin ─────────────────────────────────────────────

                52px of the display face at weight 200. The number is the
                headline of the whole screen and it has a 168px circle to sit
                in; anything smaller leaves the ring looking like a frame round
                an empty space.

                Thin rather than bold for the same reason the counts below are:
                weight would make it shout, and 83% is not news. The per cent
                sign is dropped to a third of the size and baseline-aligned,
                because "83" is the number and "%" is its unit.
              */
              /*
                Scaled to fit, and the case that needs it is the good one.

                "100%" at 52px is 168.05 pixels wide inside a 168 pixel ring —
                over by a twentieth of a pixel, which Flutter reports as an
                overflow with a striped bar across the number. A household with
                everything in date is not an edge case, and shrinking the type
                by a hair is a better answer than making the ring bigger for
                everybody else.
              */
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$percent',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w200,
                        fontSize: 82,
                        letterSpacing: -3.7,
                        height: 1,
                        color: c.text,
                      ),
                    ),
                    // The unit is not the number: same weight, a third the
                    // size, and muted — so the figure keeps the eye and the
                    // sign only qualifies it.
                    Text(
                      '%',
                      style: TextStyle(
                        // Held at a third of the figure, as it was — the sign
                        // is the unit, and growing the two together would make
                        // "%" a second number rather than a qualifier.
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w200,
                        fontSize: 27,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'still in date',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 12,
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

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.covered,
    required this.soon,
    required this.lapsed,
    required this.track,
    required this.error,
    required this.moss,
    required this.honey,
  });

  final double covered;
  final double soon;
  final double lapsed;
  final Color track;
  final Color error;

  /// Taken from the theme rather than written here. The light palette darkens
  /// every state colour to hold contrast on white — a ring painted with the
  /// dark theme's moss would be a bright green line on a pale card.
  final Color moss;
  final Color honey;

  @override
  void paint(Canvas canvas, Size size) {
    /*
      ── Six on a hundred and seventy-six, which is the PWA's ring exactly ──

      It was 16, which at a tenth of the diameter is a doughnut chart. Six is a
      line drawn round the number rather than a band competing with it, and the
      number is the point.

      The colours read better thin too. A 16px wedge of amber is a block of
      amber; a 6px one is a mark on a dial, which is what a one-item share of
      thirty-two actually is.
    */
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final circle = Rect.fromCircle(center: rect.center, radius: radius);

    canvas.drawArc(
      circle,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    final total = covered + soon + lapsed;
    if (total == 0) return;

    /*
      ── Round caps, and a gap cut to make room for them ────────────────────

      A round cap adds half a stroke at each end, so three arcs drawn back to
      back overlap and the joins turn into lumps. Each sweep gives up five
      pixels of arc length to compensate.

      Five, not three: at this weight a 3px gap read as a break in the ring
      rather than as a division of it.
    */
    const gapPx = 5.0;
    final circumference = 2 * math.pi * radius;
    final gap = (gapPx / circumference) * 2 * math.pi;

    // Green, then amber, then red — worst last, so the eye lands on it as the
    // arc closes rather than meeting it first.
    var start = -math.pi / 2;
    for (final wedge in [(covered, moss), (soon, honey), (lapsed, error)]) {
      final sweep = (wedge.$1 / total) * math.pi * 2;
      if (wedge.$1 == 0) {
        start += sweep;
        continue;
      }

      canvas.drawArc(
        circle,
        start,
        // Never below zero: a single item out of thirty is a sweep narrower
        // than the gap, and a negative sweep draws the arc backwards round the
        // whole ring.
        math.max(0.0001, sweep - gap),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = wedge.$2,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.covered != covered || old.soon != soon || old.lapsed != lapsed;
}

/// The header a list wears while rows are being chosen to send.
///
/// ── One bar, three tabs ────────────────────────────────────────────────────
/// Items, Documents and Subscriptions all offer the same gesture and the same
/// outcome, so they get literally the same widget rather than three that look
/// alike. Three copies is how "2 chosen" ends up saying "2 selected" on one
/// screen after somebody edits the wording on the other two.
class PickingBar extends StatelessWidget {
  const PickingBar({
    required this.count,
    required this.onCancel,
    required this.onSend,
    super.key,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: c.slate800,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Stop choosing',
            icon: Icon(Icons.close, size: 20, color: c.muted),
            onPressed: onCancel,
          ),
          Expanded(
            child: Text(
              // The number, because it is the only thing that changed since
              // the last tap and the only thing worth reading here.
              count == 0 ? 'Nothing chosen' : '$count chosen',
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: count == 0 ? c.muted : c.text,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onSend,
            icon: const Icon(Icons.ios_share, size: 17),
            label: const Text('Send'),
            style: FilledButton.styleFrom(
              backgroundColor: c.gold,
              foregroundColor: c.onGold,
              disabledBackgroundColor: c.slate700,
              disabledForegroundColor: c.muted,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
