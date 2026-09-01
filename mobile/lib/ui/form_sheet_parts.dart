/// The pieces the three add sheets are built from.
///
/// ── Why these moved out of the sheets ─────────────────────────────────────
/// Items, subscriptions and documents each grew a private `_Card`, `_Label`,
/// `_Field`, `_Box`, `_DateBox` and `_Seg` — six widgets, three times, nearly
/// but not exactly identical. Three copies of a thing is three places for a
/// fix to be applied twice, and the bug below proves it: the box-in-a-box was
/// wrong in all three and would have been fixed in one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/format.dart';
import 'feedback.dart';
import 'theme.dart';

/*
  ── How far up a sheet opens ────────────────────────────────────────────────

  These forms were two thirds, which is the right size for a question and the
  wrong size for five cards of answers — the first thing you saw was a third of
  a form and a scrollbar.

  They stop just under the tab heading instead. Not the very top: the strip of
  app still showing is what says the screen underneath is waiting rather than
  gone, and it is the thing that makes the sheet dismissible-looking. The
  heading is also the one part of the screen behind that still says where you
  are.

  Computed rather than guessed at 0.9, because the status bar is 24 logical
  pixels on some phones and 48 on others, and a fixed fraction puts the sheet
  over the heading on exactly the devices with the tallest cutouts.
*/
double sheetTop(BuildContext context) {
  final media = MediaQuery.of(context);

  // The heading block: `TabTitle` is 2 + text + 4, and the text is the display
  // face at headlineSmall. 58 covers it at every text scale the app allows.
  final below = media.padding.top + 58;

  return (1 - below / media.size.height).clamp(0.5, 0.96);
}

/*
  ── The content arrives just after the sheet does ───────────────────────────

  A modal sheet already slides up; that is Flutter's route transition and it
  moves the whole panel as one rigid object. Everything inside is therefore
  already in its final position when the panel is still travelling, which
  reads as a printed card being pushed onto the screen.

  This gives the contents a shorter, later, smaller move of their own — 14
  pixels over 320ms, starting once the panel is most of the way up. The panel
  arrives and then settles, which is what a physical thing does.

  Deliberately small. A sheet whose contents visibly fly in is a sheet you
  wait for, and these are forms people open dozens of times.
*/
class SheetEntrance extends StatefulWidget {
  const SheetEntrance({required this.child, super.key});

  final Widget child;

  @override
  State<SheetEntrance> createState() => _SheetEntranceState();
}

class _SheetEntranceState extends State<SheetEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  late final Animation<double> _t =
      CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);

  /*
    Held and cancelled — and I wrote this as a bare `Future.delayed` first,
    three versions after fixing exactly that in `Shell` and `Splash`.

    A bare delay is a timer nobody owns. The `if (mounted)` inside guards the
    work and never the timer, so a sheet dismissed inside the first 90ms
    leaves one running against a dead State, and Flutter's test binding fails
    the whole test with "A Timer is still pending".
  */
  Timer? _begin;

  @override
  void initState() {
    super.initState();
    // Started a beat late on purpose: the route's own slide owns the first
    // 90ms, and two things moving at once is one thing moving badly.
    _begin = Timer(const Duration(milliseconds: 90), () {
      if (mounted) _in.forward();
    });
  }

  @override
  void dispose() {
    _begin?.cancel();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;

    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}

/// A titled card, with an optional control or a mascot in the corner.
class SheetCard extends StatelessWidget {
  const SheetCard({
    required this.title,
    required this.children,
    this.action,
    this.trailing,
    super.key,
  });

  final String title;
  final List<Widget> children;

  /// A control on the title row — "New room".
  final Widget? action;

  /// Something that is not a control and must not be laid out like one:
  /// Scout, or the document's own mark.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      // No border. The fill is one step brighter than the sheet behind it and
      // does the whole job — see the note on `StashColors.card`.
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: c.text,
                    ),
                  ),
                ),
              ),
              if (action != null) action!,
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    // Uppercased here rather than at every call site, so the eighty labels in
    // the three sheets read as sentence case in the source and as annotations
    // on the screen. See `fieldLabelStyle`.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: fieldLabelStyle(c)),
    );
  }
}

/// The white shape every input sits in. **One box, and only one.**
class WhiteField extends StatelessWidget {
  const WhiteField({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: child,
    );
  }
}

/*
  ── The box inside the box ──────────────────────────────────────────────────

  Every field on these sheets was drawing two: the white `WhiteField` above,
  and inside it a second filled, outlined rectangle in the card's own colour.

  It was not in any of this code. `theme.dart` sets an `inputDecorationTheme`
  with `filled: true` and an `OutlineInputBorder` on `enabledBorder` and
  `focusedBorder` — written for the old full-screen forms, where a Material
  text field on a bare page needed an edge of its own.

  And `border: InputBorder.none` does not switch it off. `border` is only the
  fallback for states that have no border of their own, so a theme that sets
  `enabledBorder` wins over a decoration that sets `border` — which is exactly
  the shape of bug that looks like it cannot be happening, because the code
  plainly says there is no border.

  Every state has to be cleared by name, which is what this does.
*/
InputDecoration bareInput(
    {String? hint, TextStyle? hintStyle, EdgeInsets? padding}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: hintStyle,
    filled: false,
    isDense: true,
    contentPadding: padding ?? const EdgeInsets.symmetric(vertical: 14),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );
}

/// The same, but filled — for the small sheets that ask one question on their
/// own background rather than inside a white field.
InputDecoration sunkenInput({String? hint, required Color fill}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: fill,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
      borderSide: BorderSide.none,
    ),
  );
}

class TextBox extends StatelessWidget {
  const TextBox({
    required this.initial,
    required this.onChanged,
    this.controller,
    this.focus,
    this.hint,
    this.lines = 1,
    this.keyboard,
    this.format,
    this.autofocus = false,
    this.big = false,
    this.action,
    this.onSubmitted,
    super.key,
  });

  /// Ignored when a `controller` is given.
  final String initial;

  /// For the two fields the form rewrites itself — the item's name and the
  /// document's. A `TextFormField` will not notice a changed `initialValue`.
  final TextEditingController? controller;

  final ValueChanged<String> onChanged;
  final String? hint;
  final int lines;
  final TextInputType? keyboard;

  /// Formats as you type rather than on blur. Correcting a field after the
  /// fact makes people wonder whether they typed it wrong.
  final String Function(String)? format;

  final bool autofocus;

  /// The one field on a form that is the point of it — the product name, the
  /// service.
  final bool big;

  /*
    ── The key in the corner of the keyboard ───────────────────────────────

    Left alone it is a tick, and a tick means "finished" — it puts the keyboard
    away and nothing else. On a card with two boxes one under the other that is
    a dead end: the second field is right there, and somebody who has just
    finished the first has to reach past the keyboard to tap it.

    So a field with another field under it asks for `TextInputAction.next` and
    sends `onSubmitted` to that field's focus node. The last one keeps the tick,
    which is honest — there IS nothing after it.

    Never "next the screen". The action key means "I have finished this field",
    which is a smaller claim than having finished the card.
  */
  final FocusNode? focus;
  final TextInputAction? action;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    // 17, not 15. The label above is now 11 and tracked out, so the value has
    // room to be the thing you see — see the note on the scale in theme.dart.
    final size = big ? 21.0 : 17.0;

    final decoration = bareInput(
      hint: hint,
      hintStyle:
          TextStyle(fontFamily: fontBody, fontSize: size, color: c.muted),
      padding: EdgeInsets.symmetric(vertical: lines > 1 ? 2 : 14),
    );

    final style =
        TextStyle(fontFamily: fontBody, fontSize: size, color: c.text);

    final formatters = format == null
        ? null
        : [
            TextInputFormatter.withFunction((old, now) {
              final formatted = format!(now.text);
              return TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }),
          ];

    return WhiteField(
      padding:
          EdgeInsets.symmetric(horizontal: 14, vertical: lines > 1 ? 10 : 2),
      child: controller != null
          ? TextField(
              controller: controller,
              focusNode: focus,
              autofocus: autofocus,
              maxLines: lines,
              keyboardType: keyboard,
              textInputAction: action,
              onSubmitted:
                  onSubmitted == null ? null : (_) => onSubmitted!.call(),
              style: style,
              cursorColor: c.gold,
              decoration: decoration,
              inputFormatters: formatters,
              onChanged: onChanged,
            )
          : TextFormField(
              initialValue: initial,
              focusNode: focus,
              autofocus: autofocus,
              maxLines: lines,
              keyboardType: keyboard,
              textInputAction: action,
              onFieldSubmitted:
                  onSubmitted == null ? null : (_) => onSubmitted!.call(),
              style: style,
              cursorColor: c.gold,
              decoration: decoration,
              inputFormatters: formatters,
              onChanged: onChanged,
            ),
    );
  }
}

/// The amount, with the currency symbol inside the box rather than beside it.
class MoneyBox extends StatelessWidget {
  const MoneyBox({
    required this.initial,
    required this.currency,
    required this.onChanged,
    this.hint = '12.99',
    super.key,
  });

  final String initial;

  /// The currency itself, not just its symbol — the formatter needs it too. A
  /// box showing £ and rounding to two decimals because it was told "USD" is
  /// wrong in every zero-decimal currency there is.
  final String currency;

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return WhiteField(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Text(
            currencySymbol(currency),
            style:
                TextStyle(fontFamily: fontBody, fontSize: 15, color: c.muted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              initialValue: initial,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style:
                  TextStyle(fontFamily: fontBody, fontSize: 17, color: c.text),
              cursorColor: c.gold,
              decoration: bareInput(
                hint: hint,
                hintStyle: TextStyle(
                    fontFamily: fontBody, fontSize: 17, color: c.muted),
              ),
              inputFormatters: [
                TextInputFormatter.withFunction((old, now) {
                  final formatted = formatMoneyInput(now.text, currency);
                  return TextEditingValue(
                    text: formatted,
                    selection:
                        TextSelection.collapsed(offset: formatted.length),
                  );
                }),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class DateBox extends StatelessWidget {
  const DateBox({
    required this.value,
    required this.onTap,
    this.hint = 'Pick one',
    super.key,
  });

  final String value;
  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: WhiteField(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? hint : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: value.isEmpty ? fontBody : fontMono,
                  fontSize: value.isEmpty ? 15 : 16,
                  color: value.isEmpty ? c.muted : c.text,
                ),
              ),
            ),
            Icon(Icons.calendar_today_outlined, size: 17, color: c.muted),
          ],
        ),
      ),
    );
  }
}

/// A row of choices in one pill, one of them lit.
class SegRow<T> extends StatelessWidget {
  const SegRow({
    required this.value,
    required this.options,
    required this.onPick,
    this.lines = 2,
    super.key,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onPick;

  /// How many lines a label may wrap to. Two for the warranty names, one for
  /// anything that is meant to read as a scale.
  final int lines;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      /*
        ── The lit one fills the bar, and why this needs IntrinsicHeight ──────

        Every segment is the same WIDTH because of `Expanded`, and used to be
        its own HEIGHT: a container sizes to its content, so a one-line label
        made a short pill inside a bar whose height came from a two-line one
        elsewhere in the row. The lit pill floated with a gap above and below.

        `stretch` fixes that and cannot be used alone. A Row asked to stretch
        its children must know its own height first, and inside a scroll view —
        which is every screen this appears on — the height it is offered is
        INFINITE. The row takes it, and the result is not an overflow stripe
        but a blank page. Two of these went blank before I understood that.

        `IntrinsicHeight` measures the tallest child and hands the row that,
        which is exactly the height stretch needs.
      */
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (key, label) in options)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    feedback(Cue.tap);
                    onPick(key);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
                    decoration: BoxDecoration(
                      color: key == value ? c.slate600 : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: lines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 12.5,
                        fontWeight:
                            key == value ? FontWeight.w700 : FontWeight.w500,
                        color: key == value ? c.text : c.muted,
                      ),
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

/// The gold button pinned to the bottom of a sheet, with the one refusal the
/// form makes said above it.
class SheetFooter extends StatelessWidget {
  const SheetFooter({
    required this.label,
    required this.problem,
    required this.onSave,
    super.key,
  });

  final String label;

  /// Why this cannot be saved yet, or null. Said before the button is pressed
  /// rather than after.
  final String? problem;

  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        14 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: c.slate900,
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (problem != null) ...[
            Text(
              problem!,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontFamily: fontBody, fontSize: 13, color: c.muted),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: c.onGold,
                disabledBackgroundColor: c.gold,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: c.onGold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
