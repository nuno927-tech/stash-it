/// Adding an item, one question at a time.
///
/// ── Why a second way in ────────────────────────────────────────────────────
/// `item_form_sheet.dart` shows every field at once: name, brand, model,
/// serial, retailer, room, date, price, cover, notes, receipts. That is the
/// right shape for EDITING, where somebody has arrived to change one specific
/// thing and needs to find it.
///
/// It is the wrong shape for the first thirty seconds of owning the app. A
/// dozen labelled boxes is a form, and a form is a thing people put off — which
/// is fatal for an app whose entire claim is that stashing something takes a
/// moment.
///
/// So creating is four questions, one screen each, in the order somebody would
/// actually answer them. Editing still opens the full form.
///
/// ── Everything after the name is optional, and it says so ─────────────────
/// Only the name is needed. Every other step carries a visible way past it, and
/// the button says "Save" rather than "Next" the moment there is a name to
/// save — so nobody has to reach the end to get out with something.
///
/// The one refusal the app allows itself is still here: a warranty term with no
/// purchase date is a number, not a countdown. See `whyNotSaveable`, which this
/// asks before saving exactly as the form does.
///
/// ── The batch case, which this is worse at ─────────────────────────────────
/// Somebody entering a drawerful of appliances on a Sunday is served better by
/// the form: four taps per item beats four screens per item. That is what "Add
/// the long way" at the bottom of the first step is for, and it carries the
/// name across so nothing typed is lost.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/dates.dart';
import '../logic/item_form.dart';
import '../models/types.dart';
import 'ask_text.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'item_form_sheet.dart';
import 'save_item.dart';
import 'stash_the_paper.dart';
import 'theme.dart';

/// Opens the step-by-step add. Resolves true when something was saved.
Future<bool?> showItemWizard(BuildContext context, {required Repository repo}) {
  feedback(Cue.expand);

  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => _Wizard(repo: repo),
  );
}

/// The four questions, in the order somebody answers them.
///
/// Name first because it is the only one that is required and the only one
/// somebody always knows. Cover last because it is the one people most often
/// have to go and look up, and a question you cannot answer is a better place
/// to stop than a question you can.
enum _Step { name, room, bought, cover }

class _Wizard extends StatefulWidget {
  const _Wizard({required this.repo});

  final Repository repo;

  @override
  State<_Wizard> createState() => _WizardState();
}

class _WizardState extends State<_Wizard> {
  final ItemDraft _draft = ItemDraft();

  /*
    Owned here, not built beside the field.

    A controller created in `build` is a new controller on every keystroke, and
    one created beside an `await` is disposed while the sheet is still closing.
    This app has been bitten by the second of those; see ask_text.dart.
  */
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  final PageController _pages = PageController();
  _Step _at = _Step.name;

  List<Room>? _rooms;
  bool _saving = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRooms());

    // The first question is a text field and there is nothing else on the
    // screen to tap. Waiting for a tap that has only one possible target is
    // the app asking somebody to confirm they meant to open it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _nameFocus.requestFocus());
  }

  Future<void> _loadRooms() async {
    final rooms = await widget.repo.rooms();
    if (mounted) setState(() => _rooms = rooms);
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _pages.dispose();
    super.dispose();
  }

  bool get _named => _name.text.trim().isNotEmpty;
  bool get _last => _at == _Step.cover;

  void _go(_Step to) {
    feedback(Cue.tap);
    _nameFocus.unfocus();
    _pages.animateToPage(
      to.index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_last) {
      unawaited(_save());
      return;
    }
    _go(_Step.values[_at.index + 1]);
  }

  /*
    ── Out through the form, with the name ─────────────────────────────────

    Somebody adding a drawerful of appliances is served worse by four screens
    per item than by one form with everything on it, and somebody who wants a
    field this does not ask about — a serial number, a price — cannot get there
    from here at all.

    The name goes with them. An escape hatch that throws away what was already
    typed is one people use once.
  */
  Future<void> _theLongWay() async {
    final navigator = Navigator.of(context);
    final host = navigator.context;

    navigator.pop(false);

    if (!host.mounted) return;
    await showItemForm(host, repo: widget.repo, startingName: _name.text.trim());
  }

  Future<void> _save() async {
    _draft.name = _name.text.trim();

    final problem = whyNotSaveable(_draft);
    if (problem != null) {
      feedback(Cue.error);
      setState(() => _problem = problem.message);

      // Taken to the step that can fix it. A refusal that names a field
      // without showing it makes somebody hunt for a box they cannot picture —
      // and on this sheet the box may be two screens back.
      _go(switch (problem.where) {
        Missing.name => _Step.name,
        Missing.purchaseDate => _Step.bought,
        _ => _at,
      });
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    final outcome = await saveItemDraft(
      context,
      repo: widget.repo,
      draft: _draft,
      isNew: true,
    );

    if (!mounted) return;

    switch (outcome) {
      case ItemNotSaved(:final message):
        setState(() {
          _problem = message;
          _saving = false;
        });

      case ItemSaved():
        // Closed before the receipt reminder, and the reminder shown from the
        // navigator's context rather than this one — see the same note in
        // item_form_sheet.dart, which this deliberately matches.
        final navigator = Navigator.of(context);
        final host = navigator.context;
        navigator.pop(true);
        if (host.mounted) await showStashThePaper(host);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      ── The sheet gives way to the keyboard ─────────────────────────────────

      Two thirds anchored to the bottom edge is exactly where the keyboard
      appears, so the first question — a text field — would be typed into from
      behind it. Lifting alone pushes the top off the screen, so the height
      gives way as well. Same fix as the tour's name step.
    */
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: insets),
      child: SizedBox(
        height: screen * 0.72 < screen - insets - 24
            ? screen * 0.72
            : screen - insets - 24,
        child: SheetEntrance(
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _Rail(at: _at, c: c),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    // Swipeable as well as tappable, but not past the name:
                    // a wizard that lets you skip the one required answer is a
                    // wizard that refuses to save four screens later.
                    physics: _named
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) {
                      setState(() => _at = _Step.values[i]);
                      if (_Step.values[i] == _Step.name) {
                        _nameFocus.requestFocus();
                      }
                    },
                    children: [
                      _Ask(
                        question: 'What is it?',
                        hint: 'Anything you would call it.',
                        child: _NameField(
                          controller: _name,
                          focus: _nameFocus,
                          onChanged: (_) => setState(() {}),
                          onDone: _named ? _next : null,
                        ),
                        footer: _Quiet(
                          label: 'Add the long way',
                          onTap: _theLongWay,
                        ),
                      ),
                      _Ask(
                        question: 'Where does it live?',
                        hint: 'So you can find it by room later.',
                        child: _Rooms(
                          rooms: _rooms,
                          chosen: _draft.roomId,
                          onPick: (id) => setState(() => _draft.roomId = id),
                          onNew: _newRoom,
                        ),
                      ),
                      _Ask(
                        question: 'When did you get it?',
                        hint: 'Every countdown is measured from this.',
                        child: _Bought(
                          date: _draft.purchaseDate,
                          onPick: (iso) =>
                              setState(() => _draft.purchaseDate = iso),
                        ),
                      ),
                      _Ask(
                        question: 'How long is it covered?',
                        hint: 'Skip it if you are not sure.',
                        child: _Cover(
                          chosen: _draft.coverages.isEmpty
                              ? null
                              : _draft.coverages.first,
                          onPick: _setCover,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_problem != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                    child: Text(
                      _problem!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 13,
                        color: c.ember,
                      ),
                    ),
                  ),
                _Footer(
                  c: c,
                  last: _last,
                  named: _named,
                  saving: _saving,
                  onNext: _next,
                  // Save is available from the moment there is a name, on
                  // every step. Nothing after the first question is required,
                  // so making somebody walk to the end to get out with an item
                  // would be a wizard pretending its questions are demands.
                  onSaveNow: _named && !_last && !_saving ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _newRoom() async {
    final name = await askText(context,
        title: 'New room', hint: 'Kitchen, garage, loft');
    if (name == null || name.trim().isEmpty || !mounted) return;

    final id = await widget.repo.createRoom(name.trim());
    if (!mounted) return;

    await _loadRooms();
    if (mounted) setState(() => _draft.roomId = id);
  }

  /// One cover, or none. The form handles several; this asks the common
  /// question and lets the form answer the uncommon one.
  void _setCover(CoverageDraft? cover) {
    setState(() {
      _draft.coverages
        ..clear()
        ..addAll([if (cover != null) cover]);
    });
  }
}

/// Four segments that fill as you go. Not a dot per step: a rail says how much
/// is left in a shape somebody reads without counting.
class _Rail extends StatelessWidget {
  const _Rail({required this.at, required this.c});

  final _Step at;
  final StashColors c;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 22),
        child: Row(
          children: [
            for (final step in _Step.values) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  height: 3,
                  decoration: BoxDecoration(
                    color: step.index <= at.index ? c.gold : c.slate600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (step != _Step.values.last) const SizedBox(width: 5),
            ],
          ],
        ),
      );
}

/// One question: the words, and whatever answers it.
class _Ask extends StatelessWidget {
  const _Ask({
    required this.question,
    required this.hint,
    required this.child,
    this.footer,
  });

  final String question;
  final String hint;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w800,
              fontSize: 27,
              height: 1.15,
              letterSpacing: -0.8,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 13.5,
              height: 1.5,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 26),
          child,
          if (footer != null) ...[
            const SizedBox(height: 26),
            Center(child: footer!),
          ],
        ],
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onDone,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return TextField(
      controller: controller,
      focusNode: focus,
      onChanged: onChanged,
      onSubmitted: (_) => onDone?.call(),
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w800,
        fontSize: 24,
        letterSpacing: -0.5,
        color: c.text,
      ),
      decoration: InputDecoration(
        hintText: 'Bosch dishwasher',
        hintStyle: TextStyle(
          fontFamily: fontDisplay,
          fontWeight: FontWeight.w800,
          fontSize: 24,
          letterSpacing: -0.5,
          color: c.slate600,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.only(bottom: 10),
        // A rule, not a box. The field is the only thing on the screen; a
        // filled rectangle round it would be drawing a border round the
        // whole page.
        border: UnderlineInputBorder(borderSide: BorderSide(color: c.line)),
        enabledBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: c.line)),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: c.gold, width: 2),
        ),
      ),
    );
  }
}

class _Rooms extends StatelessWidget {
  const _Rooms({
    required this.rooms,
    required this.chosen,
    required this.onPick,
    required this.onNew,
  });

  final List<Room>? rooms;
  final String? chosen;
  final ValueChanged<String?> onPick;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final all = rooms;
    if (all == null) return const SizedBox(height: 60);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final room in all)
          _Chip(
            label: room.name,
            on: chosen == room.id,
            // Tapping the lit one turns it off. Every answer here is
            // optional, so every answer has to be undoable without a second
            // control to undo it with.
            onTap: () => onPick(chosen == room.id ? null : room.id),
          ),
        _Chip(label: '+ New room', on: false, onTap: onNew),
      ],
    );
  }
}

class _Bought extends StatelessWidget {
  const _Bought({required this.date, required this.onPick});

  /// `YYYY-MM-DD`, or empty.
  final String date;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final today = startOfDay(DateTime.now());

    /*
      Four guesses and a date picker.

      "Today" is right for something bought on the way home, which is when
      somebody is most likely to be adding it. The others are the shapes people
      say out loud — "a few months back", "last year" — offered as a rough
      answer, because a rough purchase date makes the countdown roughly right
      and no date makes it nothing at all.
    */
    final guesses = <(String, DateTime)>[
      ('Today', today),
      ('Last month', addDays(today, -30)),
      ('6 months ago', addDays(today, -182)),
      ('A year ago', addDays(today, -365)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, when) in guesses)
              _Chip(
                label: label,
                on: date == toIsoDate(when),
                onTap: () => onPick(date == toIsoDate(when) ? '' : toIsoDate(when)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _Quiet(
          label: date.isEmpty ? 'Pick a date' : 'Bought $date · change',
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: parseDate(date) ?? today,
              firstDate: DateTime(1970),
              lastDate: addDays(today, 366),
            );
            if (picked != null) onPick(toIsoDate(picked));
          },
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.chosen, required this.onPick});

  final CoverageDraft? chosen;
  final ValueChanged<CoverageDraft?> onPick;

  @override
  Widget build(BuildContext context) {
    // The five answers that cover almost everything sold with a warranty.
    // Anything else is a reason to open the full form, where several policies
    // with providers and phone numbers are the point.
    final terms = <(String, CoverageUnit, String)>[
      ('1 year', CoverageUnit.years, '1'),
      ('2 years', CoverageUnit.years, '2'),
      ('3 years', CoverageUnit.years, '3'),
      ('5 years', CoverageUnit.years, '5'),
      ('Lifetime', CoverageUnit.lifetime, ''),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, unit, amount) in terms)
          _Chip(
            label: label,
            on: chosen != null &&
                chosen!.unit == unit &&
                chosen!.amountText == amount,
            onTap: () {
              final already = chosen != null &&
                  chosen!.unit == unit &&
                  chosen!.amountText == amount;

              onPick(already
                  ? null
                  : CoverageDraft(
                      label: 'Warranty',
                      unit: unit,
                      amountText: amount,
                    ));
            },
          ),
      ],
    );
  }
}

/// A pill answer. Lit when chosen, and tapping the lit one clears it.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Material(
      color: on ? c.gold : c.slate800,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: () {
          feedback(Cue.tap);
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: on ? c.gold : c.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: fontBody,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: on ? c.onGold : c.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// A way out that does not compete with the way on.
class _Quiet extends StatelessWidget {
  const _Quiet({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(fontFamily: fontBody, fontSize: 13, color: c.muted),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.c,
    required this.last,
    required this.named,
    required this.saving,
    required this.onNext,
    required this.onSaveNow,
  });

  final StashColors c;
  final bool last;
  final bool named;
  final bool saving;
  final VoidCallback onNext;
  final VoidCallback? onSaveNow;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 14),
        child: Row(
          children: [
            /*
              "Save now" rather than "Skip".

              Skip says the question was a step you got out of. Save says the
              thing exists, which is true from the moment it has a name — and
              it is the difference between a wizard you escape and a wizard you
              can stop using whenever you like.
            */
            if (onSaveNow != null)
              TextButton(
                onPressed: onSaveNow,
                child: Text(
                  'Save now',
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 13.5,
                    color: c.muted,
                  ),
                ),
              ),
            const Spacer(),
            FilledButton(
              onPressed: saving || !named ? null : onNext,
              style: FilledButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: c.onGold,
                disabledBackgroundColor: c.slate600,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
              child: Text(
                saving ? 'Saving' : (last ? 'Save item' : 'Next'),
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: named ? c.onGold : c.muted,
                ),
              ),
            ),
          ],
        ),
      );
}
