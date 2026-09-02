/// The "Stash it" button, and the menu that unfolds from it.
///
/// Ported from `BottomNav.tsx` and the `.fab` / `.addstack` / `.addchoice`
/// rules in app.css.
///
/// ── A pill with words on it, not a circle with a plus ─────────────────────
/// A floating `+` means "add" only to somebody who already knows the app. This
/// says **Stash it** — the app's own name used as a verb, which is the whole
/// idea the product is built on — and that is worth more than the eighty pixels
/// a circle would save.
///
/// ── A menu, not a dialog ──────────────────────────────────────────────────
/// A dialog asking "product or subscription?" is a screen you have to read and
/// then dismiss. This unfolds in place, above the thumb that opened it, and
/// closes by tapping anywhere else.
///
/// A list rather than three hard-coded buttons: the reason for making the
/// button expand at all is that a fourth kind is plausible. Adding one should
/// be a line in `_kinds` and nothing else.
///
/// ── The curve is the point ────────────────────────────────────────────────
/// `cubic-bezier(.34, 1.56, .64, 1)` — Flutter's `Curves.easeOutBack` — passes
/// its target and comes back, which is what makes it read as a thing with mass
/// arriving rather than a box being switched on. **Going away uses a plain ease
/// at half the duration**, because an overshoot on the way out reads as
/// indecision.
library;

import 'package:flutter/material.dart';

import '../billing/current.dart';
import '../db/repository.dart';
import '../logic/limits.dart';
import 'feedback.dart';
import 'item_wizard_sheet.dart';
import 'sub_wizard_sheet.dart';
import 'paper_wizard_sheet.dart';
import 'theme.dart';
import 'unlock_sheet.dart';

enum AddKind { item, subscription, paper }

const List<(AddKind, IconData, String, String)> _kinds = [
  (AddKind.item, Icons.work_outline, 'Product', 'Something you own'),
  (
    AddKind.subscription,
    Icons.calendar_today_outlined,
    'Subscription',
    'Something you pay for'
  ),
  (
    AddKind.paper,
    Icons.description_outlined,
    'Document',
    'Something that expires'
  ),
];

class StashItButton extends StatefulWidget {
  const StashItButton({required this.repo, this.onDone, super.key});

  final Repository repo;

  /// Called after a form closes, whatever happened in it — the tab underneath
  /// has to rebuild whether something was saved, edited or deleted.
  final VoidCallback? onDone;

  @override
  State<StashItButton> createState() => _StashItButtonState();
}

class _StashItButtonState extends State<StashItButton>
    with SingleTickerProviderStateMixin {
  /*
    One controller for the whole menu, with the stagger applied per row by
    slicing the same 0..1 value. Three controllers would drift.

    Opening is longer than closing on purpose — 360ms out, 180ms back. A menu
    that takes as long to put away as it took to open feels reluctant.
  */
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    reverseDuration: const Duration(milliseconds: 180),
  );

  bool get _open => _c.value > 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /*
    ── Full, and the button says so before it is pressed ───────────────────

    The cap used to be enforced at the point of saving: the fan opened, the
    form opened, somebody filled in a kettle, and only on Save did the app say
    there was no room. That is the worst possible moment to find out — the
    work is done and the answer is no.

    Dimming the button moves the news to before the effort. The button still
    works, because a dead control invites the question "why will this not
    work" rather than answering it; it just goes somewhere else.
  */
  bool _full = false;

  Future<void> _readRoom() async {
    final settings = await widget.repo.settings();
    final count = await widget.repo.cappedCount();
    if (!mounted) return;

    final now = !canAddItem(count, settings.entitlements);
    if (now != _full) setState(() => _full = now);
  }

  /// Straight to the offer, with the count already in it.
  Future<void> _offer() async {
    feedback(Cue.tap);
    final count = await widget.repo.cappedCount();
    if (!mounted) return;

    final unlocked = await showUnlock(
      context,
      repo: widget.repo,
      billing: appBilling,
      count: count,
    );
    if (unlocked) {
      await _readRoom();
      widget.onDone?.call();
    }
  }

  void _toggle() {
    // Full: the fan never opens. Three choices of thing you cannot add is a
    // worse answer than one clear reason why.
    if (_full) {
      _offer();
      return;
    }

    feedback(_open ? Cue.collapse : Cue.expand);
    if (_open) {
      _c.reverse();
    } else {
      _c.forward();
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _readRoom();
  }

  void _close() {
    if (!_open) return;
    feedback(Cue.collapse);
    _c.reverse();
    setState(() {});
  }

  Future<void> _pick(AddKind kind) async {
    feedback(Cue.tap);
    _c.reverse();
    setState(() {});

    /*
      All three are sheets now.

      Every question this app asks is asked over the screen you were on. The
      three add forms were the last places taking the whole screen, and the
      thing they were hiding behind themselves was the list somebody had just
      been looking at.
    */
    switch (kind) {
      case AddKind.item:
        await showItemWizard(context, repo: widget.repo);
      case AddKind.subscription:
        await showSubWizard(context, repo: widget.repo);
      case AddKind.paper:
        await showPaperWizard(context, repo: widget.repo);
    }

    widget.onDone?.call();
    await _readRoom();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;

        /*
          A full-size stack rather than a floating button.

          `Scaffold.floatingActionButton` sizes itself to its child and sits in
          its own slot, so a scrim inside it can only ever dim the eighty pixels
          the button occupies. This fills the body instead and places the pill
          in the corner itself, which is the only way the dimming can reach the
          rest of the screen.
        */
        return Stack(
          alignment: Alignment.bottomRight,
          children: [
            /*
              ── The scrim, which is what makes this a menu ──────────────────

              Without it these are three buttons that happened to appear near
              each other. With it the rest of the screen is visibly out of play,
              and the gesture has an undo: anywhere else puts it away.

              Sized to the whole window rather than to this widget, and ignored
              entirely when closed so it cannot swallow taps meant for the list
              underneath.
            */
            if (t > 0)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: t < 0.05,
                  child: GestureDetector(
                    onTap: _close,
                    child: Container(
                        color:
                            const Color(0xFF06080C).withValues(alpha: 0.5 * t)),
                  ),
                ),
              ),

            // Above the tab bar, which is 74 tall plus whatever the phone's
            // gesture area adds. The button belongs to the app, not to the
            // screen, so it clears the nav rather than sitting inside it.
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                90 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < _kinds.length; i++) ...[
                    _choice(i, t, still, c),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 6),
                  _pill(c, t),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// One choice, sprung from under the button.
  ///
  /// The one nearest the button moves first, so the stack unfolds upward from
  /// where you tapped rather than arriving as a block. Reversed on the way out,
  /// for the same reason.
  Widget _choice(int i, double t, bool still, StashColors c) {
    final (kind, icon, label, note) = _kinds[i];

    // 45ms between rows opening, 30ms closing, expressed as a slice of the
    // controller rather than as a timer — one clock, three offsets.
    final last = _kinds.length - 1;
    final delay = (_c.status == AnimationStatus.reverse ? i : last - i) * 0.12;
    final slice = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);

    // Somebody who has asked their phone for less movement gets the menu
    // without the spring, not without the menu.
    final eased =
        still ? (slice > 0 ? 1.0 : 0.0) : Curves.easeOutBack.transform(slice);

    if (slice == 0) return const SizedBox.shrink();

    return Opacity(
      // Opacity resolves in a sixth of the time the movement takes, so the row
      // is readable while it is still settling rather than fading in after it.
      opacity: (slice * 4).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 52 * (1 - eased)),
        child: Transform.scale(
          scale: 0.86 + 0.14 * eased,
          // From the corner nearest the button, which is where it came from.
          alignment: const Alignment(0.8, 1),
          child: Material(
            color: c.slate700,
            borderRadius: BorderRadius.circular(Radii.pill),
            elevation: 8,
            shadowColor: const Color(0x99000000),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.pill),
              onTap: () => _pick(kind),
              child: Container(
                padding: const EdgeInsets.fromLTRB(11, 9, 16, 9),
                decoration: BoxDecoration(
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.washGold,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Icon(icon, size: 17, color: c.gold),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          note,
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The button itself, which becomes the close control while the menu is open.
  ///
  /// It goes quiet rather than staying gold: the choices are the thing to look
  /// at now, and a gold pill under three cream ones would still be the loudest
  /// object on the screen. The plus turns forty-five degrees into a cross,
  /// which is the same shape saying the opposite thing.
  Widget _pill(StashColors c, double t) {
    /*
      Dimmed rather than greyed out.

      A disabled-looking control says "this is broken or not for you"; a
      quieter gold says "this still does something, and it is not the usual
      thing". The plus stays a plus for the same reason — turning it into a
      lock would make the button about the paywall rather than about adding.
    */
    final gold = _full ? Color.lerp(c.gold, c.slate600, 0.45)! : c.gold;
    final ink = _full ? c.muted : c.onGold;

    return Material(
      color: Color.lerp(gold, c.slate600, t),
      borderRadius: BorderRadius.circular(Radii.pill),
      elevation: (_full ? 2 : 6) * (1 - t) + 2,
      // A coloured object lit from behind throws its own colour; a grey shadow
      // under a gold pill on a dark background just reads as dirt.
      // No glow when there is no room. The halo is what makes this the loudest
      // thing on the screen, and it should not be shouting an invitation it
      // cannot honour.
      shadowColor: gold.withValues(alpha: (_full ? 0.15 : 0.6) * (1 - t)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 24, 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: t * 0.785398, // 45°, into a cross
                child: Icon(
                  Icons.add,
                  size: 24,
                  color: Color.lerp(ink, c.text, t),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Stash it',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  letterSpacing: -0.3,
                  color: Color.lerp(ink, c.text, t),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
