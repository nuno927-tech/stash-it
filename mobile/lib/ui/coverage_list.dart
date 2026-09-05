/// The warranty control, drawn once and used twice.
///
/// ── Why it moved out of the form ───────────────────────────────────────────
/// It was a method on `item_form_sheet.dart`, which was fine while the form was
/// the only place an item got a policy. The step-by-step sheet asks the same
/// question, and "the same question" has to mean the same control: the same six
/// names, the same four units, the same presets, the same Additional details
/// disclosure, and the same "+ Add another policy".
///
/// Copied instead of moved, the two would have started identical and drifted
/// the first time either was touched — which is exactly what happened to the
/// widget palette three versions ago.
///
/// ── It owns which policies are expanded ────────────────────────────────────
/// `_detailed` is a set of indices, and it belongs here rather than to either
/// caller: it is a fact about this control's own state, not about the record
/// being edited. A policy that already has a provider or a policy number counts
/// as expanded whether or not anybody tapped it, so an edit never hides what is
/// already there.
library;

import 'package:flutter/material.dart';

import '../logic/item_form.dart';
import '../models/types.dart';
import 'ask_text.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'theme.dart';

/// Every policy on one item, and the way to add another.
class CoverageList extends StatefulWidget {
  const CoverageList({
    required this.coverages,
    required this.onChanged,
    super.key,
  });

  /// Edited in place. The draft is the single copy; this does not hold a second.
  final List<CoverageDraft> coverages;

  /// Called after every change, so the owner can rebuild anything that depends
  /// on it — the wizard's auto-advance reads the same list.
  final VoidCallback onChanged;

  @override
  State<CoverageList> createState() => _CoverageListState();
}

class _CoverageListState extends State<CoverageList> {
  /// Which policies have their "Additional details" open.
  final Set<int> _detailed = {};

  /*
    ── Three fields per policy, and the keys and nodes they need ────────────

    Keyed by the policy's index rather than held in a list, because a policy
    can be added at any time and the map only ever grows to the number of
    policies somebody actually opened the details on — usually one, often
    none.

    `_top` is a key on the first field's label, so opening the disclosure can
    scroll it to the top of the screen. The nodes are what make the key in the
    corner of the keyboard walk down the card rather than dismissing it.
  */
  final Map<int, GlobalKey> _top = {};
  final Map<int, FocusNode> _covers = {};
  final Map<int, FocusNode> _provider = {};
  final Map<int, FocusNode> _policy = {};

  GlobalKey _topKey(int i) => _top.putIfAbsent(i, GlobalKey.new);
  FocusNode _node(Map<int, FocusNode> of, int i) =>
      of.putIfAbsent(i, FocusNode.new);

  @override
  void dispose() {
    for (final node in [..._covers.values, ..._provider.values,
      ..._policy.values]) {
      node.dispose();
    }
    super.dispose();
  }

  void _changed(VoidCallback change) {
    setState(change);
    widget.onChanged();
  }

  /*
    ── Opening the details takes you to them ────────────────────────────────

    The disclosure sits low on a card that is already tall, so opening it used
    to reveal three fields below the fold and leave somebody looking at the
    button they had just pressed. They then scrolled, found the first field,
    and tapped it — three actions to answer a question the app had just asked.

    So the first field is brought to the top of the screen and given the
    keyboard. After the frame, because none of it exists to be scrolled to
    until the disclosure has been built.
  */
  void _openDetails(int i) {
    _changed(() => _detailed.add(i));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final at = _topKey(i).currentContext;
      if (at == null || !mounted) return;

      await Scrollable.ensureVisible(
        at,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        // Flush to the top: the three fields underneath are the point, and
        // every pixel above the first one is a pixel of them hidden by the
        // keyboard.
        alignment: 0,
      );

      if (mounted) _node(_covers, i).requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.coverages.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(height: 1, color: c.line),
            ),
          _one(context, c, i),
        ],
        const SizedBox(height: 10),

        /*
          A list, not two fixed slots.

          A couch has a lifetime frame, ten years on the cushions, five on the
          springs and one on the fabric. Two slots hold two of those and quietly
          lose the rest — and the one that matters is the shortest, because that
          is the one that will actually stop covering you.
        */
        FormPill(
          label: '+ Add another policy',
          onTap: () => _changed(() => widget.coverages.add(CoverageDraft(
                label: 'Warranty',
                unit: CoverageUnit.months,
                amountText: defaultTermText(CoverageUnit.months),
              ))),
        ),
      ],
    );
  }

  Widget _one(BuildContext context, StashColors c, int i) {
    final cov = widget.coverages[i];
    final custom = isCustomLabel(cov.label);
    final presets = coveragePresets[cov.unit]!;
    final lifetime = cov.unit == CoverageUnit.lifetime;
    final customTerm = isCustomTerm(cov.unit, cov.amountText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*
          No heading here.

          It read "Warranty" in 17pt directly above a row of buttons whose
          first button also read "Warranty" — the card is already titled
          "Warranty information", so the word appeared three times in four
          centimetres and named nothing the buttons did not.

          The remove button stays, on its own, and only when there is more
          than one policy to remove.
        */
        if (widget.coverages.length > 1)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => _changed(() {
                widget.coverages.removeAt(i);
                _detailed.remove(i);
              }),
              icon: Icon(Icons.close, size: 18, color: c.muted),
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove this policy',
            ),
          ),

        /*
          ── The name is chosen, not typed ─────────────────────────────────

          A free-text box asked people to invent the vocabulary and got back
          "warranty", "Warranty" and "3yr warr" for the same idea. Six buttons
          are the vocabulary; Custom is the way out, and it asks properly
          rather than leaving an empty field in front of everybody who did not
          need one.
        */
        /*
          Two and three, not three and two.

          The names are uneven — "Warranty" against "Extended warranty" — and
          the long ones need the width. Splitting after the first two puts the
          two longest on a row with half the bar each, which is what stops
          them wrapping to a second line and doubling the height of the whole
          control.

          One line each for the same reason. Two was most of why this card
          read as bloated.
        */
        SegRow<String?>(
          // Null when the name came from Custom, so neither row lights up
          // something the person did not choose.
          value: custom ? null : cov.label,
          options: [
            for (final name in coverageLabels.take(2)) (name, name),
          ],
          lines: 1,
          onPick: (v) => _changed(() => cov.label = v!),
        ),
        const SizedBox(height: 6),
        SegRow<String>(
          value: custom ? '' : cov.label,
          options: [
            for (final name in coverageLabels.skip(2)) (name, name),
            // Shows the custom name once there is one, so the row still says
            // what it is without a separate field repeating it back.
            ('', custom ? cov.label : 'Custom'),
          ],
          lines: 1,
          onPick: (v) async {
            if (v.isNotEmpty) {
              _changed(() => cov.label = v);
              return;
            }

            final name = await askText(
              context,
              title: 'Call it what it is',
              hint: 'Roof guarantee, screen cover',
              initial: custom ? cov.label : '',
            );
            if (name == null || name.trim().isEmpty) return;
            _changed(() => cov.label = name.trim());
          },
        ),
        /*
          A rule, because these are two different questions.

          Above it: what the policy is called. Below it: how long it runs.
          Four rows of near-identical buttons ran together as one control, and
          the only thing separating "Free service" from "Months" was that one
          happened to be a word and the other happened to be a unit.
        */
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(height: 1, color: c.line),
        ),
        SegRow<CoverageUnit>(
          value: cov.unit,
          options: [
            for (final unit in CoverageUnit.values)
              (unit, coverageUnitLabels[unit]!),
          ],
          // The length comes with it. See `termAfterUnitChange`: a number that
          // the new row cannot light up would otherwise sit there as "Custom".
          onPick: (v) => _changed(() {
            cov.amountText = termAfterUnitChange(v, cov.amountText);
            cov.unit = v;
          }),
        ),

        /*
          The quick numbers, and they are not round ones.

          14, 30, 90, 180 — 3, 6, 12, 18, 24 — 1, 2, 3, 5, 10. These are what
          is printed on warranties. A row of 10/20/30 would be tidy and would
          be a number nobody has to enter.
        */
        if (!lifetime) ...[
          const SizedBox(height: 12),
          // Wrap rather than Row. Six items whose widths depend on the numbers
          // in them ("180", "Custom", and whatever somebody typed) will
          // eventually not fit, and a Row's answer to that is a yellow
          // overflow bar across the form.
          // Full width, or `spaceBetween` has nothing to space against — a
          // Wrap sizes to its content inside a Column that aligns to the start.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 2,
              children: [
                for (final n in presets)
                  _Number(
                    label: '$n',
                    on: !customTerm && int.tryParse(cov.amountText.trim()) == n,
                    onTap: () => _changed(() => cov.amountText = '$n'),
                  ),
                _Number(
                  label: customTerm ? cov.amountText.trim() : 'Custom',
                  on: customTerm,
                  onTap: () async {
                    final typed = await askText(
                      context,
                      title: 'How long?',
                      hint:
                          'A number of ${coverageUnitLabels[cov.unit]!.toLowerCase()}',
                      initial: cov.amountText,
                      number: true,
                    );
                    if (typed == null) return;
                    _changed(() => cov.amountText = typed.trim());
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),

        /*
          The rest of a policy behind one press.

          Who underwrites it, a policy number, a phone number, what it actually
          covers — real fields that matter at claim time and that nobody has to
          hand while they are photographing a kettle. Shown open when there is
          already something in them, so an edit never hides what is there.
        */
        FormPill(
          label: 'Additional details',
          on: _detailed.contains(i) || _hasDetails(cov),
          onTap: () {
            // Closing is just a toggle. Opening is a journey — see
            // `_openDetails`.
            if (_detailed.contains(i)) {
              _changed(() => _detailed.remove(i));
            } else {
              _openDetails(i);
            }
          },
        ),
        if (_detailed.contains(i) || _hasDetails(cov)) ...[
          const SizedBox(height: 12),
          FieldLabel('What it covers', key: _topKey(i)),
          TextBox(
            initial: cov.covers,
            hint: 'Parts and labor, not accidental damage',
            onChanged: (v) => cov.covers = v,
            focus: _node(_covers, i),
            // Two more fields under this one, so the key in the corner walks
            // to them rather than putting the keyboard away — see the note on
            // `TextBox.action`.
            action: TextInputAction.next,
            onSubmitted: () => _node(_provider, i).requestFocus(),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Who covers it'),
                    TextBox(
                      initial: cov.provider,
                      hint: 'Optional',
                      onChanged: (v) => cov.provider = v,
                      focus: _node(_provider, i),
                      action: TextInputAction.next,
                      onSubmitted: () => _node(_policy, i).requestFocus(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Policy number'),
                    TextBox(
                      initial: cov.policyNumber,
                      hint: 'Optional',
                      onChanged: (v) => cov.policyNumber = v,
                      focus: _node(_policy, i),
                      // The tick, and it means what it says: this is the last
                      // field on the card, so finishing it IS finishing.
                      onSubmitted: () => _node(_policy, i).unfocus(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
  bool _hasDetails(CoverageDraft cov) =>
      cov.covers.trim().isNotEmpty ||
      cov.provider.trim().isNotEmpty ||
      cov.policyNumber.trim().isNotEmpty;
}


class _Number extends StatelessWidget {
  const _Number({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return GestureDetector(
      onTap: () {
        feedback(Cue.tap);
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: fontBody,
            fontSize: 15,
            fontWeight: on ? FontWeight.w800 : FontWeight.w500,
            color: on ? c.gold : c.muted,
          ),
        ),
      ),
    );
  }
}

class FormPill extends StatelessWidget {
  const FormPill({
    required this.label,
    required this.onTap,
    this.on = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          feedback(Cue.tap);
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: on ? c.washGold : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: on ? c.washGoldLine : c.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: on ? c.gold : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}
