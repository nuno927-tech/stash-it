/// Adding an item, one question at a time.
///
/// ── Why a second way in ────────────────────────────────────────────────────
/// `item_form_sheet.dart` shows every field at once. That is the right shape
/// for EDITING, where somebody has arrived to change one specific thing and
/// needs to find it, and the wrong shape for the first thirty seconds of owning
/// the app: a dozen labelled boxes is a form, and a form is a thing people put
/// off.
///
/// So creating is six questions, one screen each, in the order somebody would
/// answer them. Editing still opens the full form.
///
/// ── Everything after the name is optional ──────────────────────────────────
/// Only the name is needed. "Save now" sits in the footer from the moment there
/// is one, on every step, so nobody has to reach the end to get out with
/// something.
///
/// The one refusal the app allows itself survives: a warranty term with no
/// purchase date is a number, not a countdown. See `whyNotSaveable`.
///
/// ── It moves on by itself ──────────────────────────────────────────────────
/// A screen whose questions are all answered advances on its own, using the
/// same rule the long form scrolls by — see `cardFilled`, and the note on
/// `_advance` for the three guards that stop it firing while somebody is still
/// working.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/attachments.dart';
import '../logic/auto_advance.dart';
import '../logic/dates.dart';
import '../logic/item_form.dart';
import '../logic/prefs.dart';
import '../models/types.dart';
import 'ask_text.dart';
import 'coverage_list.dart';
import 'doc_tiles.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'item_form_sheet.dart';
import 'pick_doc.dart';
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

/// The six questions, in the order somebody answers them.
///
/// What it is comes first because it is the only required answer and the only
/// one anybody always knows. The warning window comes last because it is the
/// only question about the app rather than about the thing.
enum _Step { what, room, bought, cover, papers, warning }

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

    A controller created in `build` is a new one on every keystroke, and one
    created beside an `await` is disposed while the sheet is still closing. This
    app has been bitten by the second; see ask_text.dart.
  */
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  final PageController _pages = PageController();
  _Step _at = _Step.what;

  Uint8List? _photo;
  final List<PendingDoc> _pending = [];

  List<Room>? _rooms;
  bool _saving = false;
  String? _problem;

  /*
    ── Which steps have already thrown you forward ─────────────────────────

    Once per step, on the false-to-true edge. Somebody who completes a screen,
    swipes back to change an answer and completes it again should not be thrown
    forward a second time — see the same rule in `ui/auto_advance.dart`, which
    this is the paged version of.
  */
  final Set<_Step> _advanced = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadRooms());

    // Two weeks by default, as on the long form: the shortest useful notice.
    _draft.leadDays = itemLeadChoices.first.days;

    // The first question is a text field and nothing else on the screen can be
    // tapped. Waiting for a tap with only one possible target is the app asking
    // somebody to confirm they meant to open it.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _nameFocus.requestFocus());
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
  bool get _last => _at == _Step.values.last;

  CoverageDraft? get _cover =>
      _draft.coverages.isEmpty ? null : _draft.coverages.first;

  /* ------------------------------------------------------------- moving on */

  void _go(_Step to) {
    _nameFocus.unfocus();
    _pages.animateToPage(
      to.index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    feedback(Cue.tap);
    if (_last) {
      unawaited(_save());
      return;
    }
    _go(_Step.values[_at.index + 1]);
  }

  /*
    ── Answering the last question on a screen moves you on ─────────────────

    Moving the screen under somebody is one of the most unpleasant things an
    interface can do, so this fires as rarely as it can while still being
    useful. Three guards, each earned:

      Every answer on the screen, not the important one. `cardFilled` takes the
      whole inventory, so a screen with an optional price on it will simply not
      advance until the price is there. A convenience that fires rarely is
      strictly better than one that fires while you are still working.

      Once per screen. Going back to change something must not throw you
      forward again.

      Never while the keyboard is up. A keyboard means somebody is still
      typing, and it is also what stops the name field advancing mid-word.

    The last two screens never advance: attachments can always take one more,
    and the warning window is the end.
  */
  void _advance(_Step from, List<Object?> answers) {
    if (from != _at || _advanced.contains(from)) return;
    if (from == _Step.papers || _last) return;
    if (!cardFilled(answers)) return;
    if (MediaQuery.of(context).viewInsets.bottom > 0) return;

    _advanced.add(from);

    // A beat, so the chip somebody just pressed is seen to light up before the
    // screen it is on leaves.
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted && _at == from) _go(_Step.values[from.index + 1]);
    });
  }

  /*
    ── Out through the form, with the name ─────────────────────────────────

    Somebody adding a drawerful of appliances is served worse by six screens per
    item than by one form, and somebody who wants a field this does not ask
    about — a serial number, a retailer — cannot get there from here at all.

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

  /* --------------------------------------------------------------- answers */

  Future<void> _pickPhoto() async {
    final source = await askPickSource(
      context,
      title: 'Take or upload photo',
      canRemove: _photo != null,
      removeLabel: 'Remove the photo',
      removeNote: 'The item keeps everything else',
    );
    if (source == null || !mounted) return;

    if (source == PickSource.remove) {
      setState(() => _photo = null);
      return;
    }

    final picked = await pickDocs(DocKind.photo, source);

    // Only a picture. The file picker will happily return a PDF, and a PDF as
    // an item's thumbnail is a grey box on every row it appears on.
    final images =
        picked.where((d) => isImage(d.mime) && d.bytes != null).toList();
    if (images.isEmpty || !mounted) return;

    setState(() => _photo = images.first.bytes);
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

  Future<void> _attach(DocKind kind) async {
    // The tile said what kind of thing this is; this asks where it comes from.
    final source = await askPickSource(
      context,
      title: 'Add a ${docKindLabels[kind]!.toLowerCase()}',
    );
    if (source == null || source == PickSource.remove || !mounted) return;

    final picked = await pickDocs(kind, source);
    if (picked.isEmpty || !mounted) return;

    // Nothing to point at yet, so they are held and written by `saveItemDraft`.
    setState(() => _pending.addAll(picked));
  }

  Future<void> _attachLink() async {
    final doc = await askForLink(context);
    if (doc == null || !mounted) return;
    setState(() => _pending.add(doc));
  }

  /* ---------------------------------------------------------------- saving */

  Future<void> _save() async {
    _draft.name = _name.text.trim();

    final problem = whyNotSaveable(_draft);
    if (problem != null) {
      feedback(Cue.error);
      setState(() => _problem = problem.message);

      // Taken to the screen that can fix it. A refusal that names a field
      // without showing it makes somebody hunt for a box they cannot picture —
      // and here the box may be three screens behind them.
      _go(switch (problem.where) {
        Missing.name => _Step.what,
        Missing.purchaseDate => _Step.bought,
        Missing.term => _Step.cover,
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
      photo: _photo,
      pending: _pending,
    );

    if (!mounted) return;

    switch (outcome) {
      case ItemNotSaved(:final message):
        setState(() {
          _problem = message;
          _saving = false;
        });

      case ItemSaved(:final attached):
        // Closed before the receipt reminder, and the reminder shown from the
        // navigator's context rather than this one — the same note as in
        // item_form_sheet.dart, which this deliberately matches.
        final navigator = Navigator.of(context);
        final host = navigator.context;
        navigator.pop(true);

        if (!attached && host.mounted) await showStashThePaper(host);
    }
  }

  /* ----------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      ── Two thirds, and never behind the keyboard ───────────────────────────

      Two thirds is the app's sheet, and two thirds anchored to the bottom edge
      is also exactly where the keyboard appears — so the first question would
      be typed into from behind it.

      Lifting alone does not fix that: two thirds plus a keyboard is more than a
      screen, so the top would go off the top. The height gives way as well, to
      whatever is genuinely left, and every step scrolls inside whatever it
      gets. Between them nothing is ever covered.
    */
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: screen * 0.66,
      child: SheetEntrance(
        child: SafeArea(
          top: false,
          /*
            The padding is INSIDE the sheet, not under it.

            Lifting the whole sheet by the keyboard was the first attempt, and
            it traded one problem for another: two thirds plus a keyboard is
            more than a screen, so the top ran off the top and the sheet no
            longer looked like the app's other sheets.

            A modal sheet is anchored to the bottom and the keyboard simply
            covers it. So the sheet keeps its two thirds and the CONTENTS move
            up inside it by exactly what the keyboard takes — the footer lands
            just above the keys, the question stays visible, and every step
            scrolls in whatever is left between them.
          */
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: insets),
            child: Column(
              children: [
                _Rail(at: _at, c: c),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    // Swipeable, but not past the one required answer: a wizard
                    // that lets you skip the name is one that refuses to save
                    // five screens later.
                    physics: _named
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: _arrived,
                    children: [
                      _what(c),
                      _room(),
                      _bought(c),
                      _coverage(c),
                      _papers(c),
                      _warning(c),
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
                  // Save is available from the moment there is a name, on every
                  // step. Nothing after the first question is required, so
                  // making somebody walk to the end would be a wizard
                  // pretending its questions are demands.
                  onSaveNow: _named && !_last && !_saving ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _arrived(int i) {
    final to = _Step.values[i];
    setState(() => _at = to);

    if (to == _Step.what) {
      _nameFocus.requestFocus();
      return;
    }

    _nameFocus.unfocus();

    /*
      Nothing to open on arrival any more.

      The calendar used to be a dialog and this opened it. It is on the card
      now, so arriving at that step IS arriving at the calendar — which is the
      version that has no Cancel to leave somebody staring at an empty screen.
    */
  }

  /* ------------------------------------------------------------- the steps */

  Widget _what(StashColors c) {
    // Name, photograph and price. All three, because `cardFilled` takes the
    // whole screen — see `_advance`.
    _advance(_Step.what, [_name.text, _photo, _draft.priceText]);

    return _Ask(
      question: 'What is it?',
      hint: 'A name is all this needs. The rest helps later.',
      footer: _Quiet(label: 'Add the long way', onTap: _theLongWay),
      answer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NameField(
            controller: _name,
            focus: _nameFocus,
            onChanged: (_) => setState(() {}),
            onDone: _named ? _next : null,
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PhotoSquare(photo: _photo, onTap: _pickPhoto),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('What it cost'),
                    // No WhiteField around it: `MoneyBox` draws its own, and
                    // one inside another in the same flat colour reads as no
                    // bubble at all — which is exactly how it looked.
                    MoneyBox(
                      initial: _draft.priceText,
                      currency: _draft.currency,
                      onChanged: (v) => setState(() => _draft.priceText = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _room() {
    _advance(_Step.room, [_draft.roomId]);

    final all = _rooms;

    return _Ask(
      question: 'Where does it live?',
      hint: 'So you can find it by room later.',
      answer: all == null
          ? const SizedBox(height: 60)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in all)
                  _Chip(
                    label: r.name,
                    on: _draft.roomId == r.id,
                    // Tapping the lit one clears it. Every answer here is
                    // optional, so every answer has to be undoable without a
                    // second control to undo it with.
                    onTap: () => setState(() => _draft.roomId =
                        _draft.roomId == r.id ? null : r.id),
                  ),
                _Chip(label: '+ New room', on: false, onTap: _newRoom),
              ],
            ),
    );
  }

  Widget _bought(StashColors c) {
    _advance(_Step.bought, [_draft.purchaseDate]);

    final chosen = parseDate(_draft.purchaseDate);
    final today = startOfDay(DateTime.now());

    return _Ask(
      question: 'When did you get it?',
      hint: 'Every countdown is measured from this.',
      answer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /*
            ── The calendar is on the card, not over it ────────────────────────

            It used to open `showDatePicker`, which is a dialog on top of a
            sheet: two floating layers, the sheet dimmed behind its own
            question, and a Cancel that leaves somebody looking at a screen
            with nothing on it.

            There is only one question here and a whole screen for it, so the
            calendar simply IS the screen. `CalendarDatePicker` is the same
            widget the dialog wraps, without the dialog.
          */
          Container(
            decoration: BoxDecoration(
              color: c.slate800,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.line),
            ),
            child: CalendarDatePicker(
              // Opens on what was chosen, or on today for a first visit.
              initialDate: chosen ?? today,
              firstDate: DateTime(1970),
              // A year ahead, for something ordered and not yet arrived.
              lastDate: addDays(today, 366),
              onDateChanged: (picked) =>
                  setState(() => _draft.purchaseDate = toIsoDate(picked)),
            ),
          ),
          if (chosen != null) ...[
            const SizedBox(height: 10),
            Center(
              child: _Quiet(
                label: 'Clear',
                onTap: () => setState(() => _draft.purchaseDate = ''),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _coverage(StashColors c) {
    final cover = _cover;

    _advance(_Step.cover, [
      cover?.label,
      // Lifetime has no length, so on that unit the length is not a question.
      if (cover?.unit != CoverageUnit.lifetime) cover?.amountText,
    ]);

    return _Ask(
      question: "What's the coverage and how long?",
      hint: 'Skip it if you are not sure — you can add it later.',
      /*
        ── The same control the long form draws ──────────────────────────────

        Not a simplified version of it. The same six names and Custom, the same
        four units, the same presets that are printed on real warranties, the
        same Additional details disclosure, and the same "+ Add another policy"
        — because a couch has a lifetime frame, ten years on the cushions, five
        on the springs and one on the fabric.

        Shared rather than copied. Two versions of this would have started
        identical and drifted the first time either was touched, which is what
        happened to the widget palette three versions ago and took a while to
        notice.
      */
      answer: CoverageList(
        coverages: _draft.coverages,
        // The wizard's own auto-advance reads this list, so it has to hear
        // about a change made inside a control that owns its own state.
        onChanged: () => setState(() {}),
      ),
    );
  }


  Widget _papers(StashColors c) {
    /*
      No auto-advance here, deliberately.

      Every other screen has an end — one room, one date, one term. This one can
      always take another receipt, so "finished" is a judgement only the person
      holding the phone can make.
    */
    return _Ask(
      question: 'Anything to keep with it?',
      hint: 'A receipt, a manual, a photo of the serial plate.',
      answer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DocTiles(onPick: _attach, onLink: _attachLink),
          if (_pending.isNotEmpty) ...[
            const SizedBox(height: 18),
            for (final doc in _pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 16, color: c.moss),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: fontBody,
                          fontSize: 13.5,
                          color: c.text,
                        ),
                      ),
                    ),
                    // Staged, not written — so removing one is forgetting it
                    // rather than deleting anything.
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: c.muted),
                      onPressed: () => setState(() => _pending.remove(doc)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _warning(StashColors c) {
    return _Ask(
      question: 'How much warning?',
      hint: 'Before the cover runs out.',
      answer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegRow<int?>(
            value: _draft.leadDays,
            options: [
              for (final choice in itemLeadChoices) (choice.days, choice.label),
            ],
            lines: 1,
            onPick: (v) => setState(() => _draft.leadDays = v),
          ),
          const SizedBox(height: 14),
          Text(
            'Turns the item amber on the dashboard, and sends a notification if '
            'you have them on.',
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 13,
              height: 1.45,
              color: c.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Segments that fill as you go. Not a dot per step: a rail says how much is
/// left in a shape somebody reads without counting.
class _Rail extends StatelessWidget {
  const _Rail({required this.at, required this.c});

  final _Step at;
  final StashColors c;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
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
    required this.answer,
    this.footer,
  });

  final String question;
  final String hint;

  /// Whatever answers it — a field, or a row of chips.
  ///
  /// Named `answer` rather than `child` on purpose: this one sits between the
  /// question and the way past it, and a name that says what it holds is worth
  /// more than one that says where it goes.
  final Widget answer;

  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    // Scrolls, because a step can be taller than what the keyboard leaves.
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
              fontSize: 25,
              height: 1.15,
              letterSpacing: -0.7,
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
          const SizedBox(height: 24),
          answer,
          if (footer != null) ...[
            const SizedBox(height: 22),
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
        fontSize: 23,
        letterSpacing: -0.5,
        color: c.text,
      ),
      decoration: InputDecoration(
        hintText: 'Bosch dishwasher',
        hintStyle: TextStyle(
          fontFamily: fontDisplay,
          fontWeight: FontWeight.w800,
          fontSize: 23,
          letterSpacing: -0.5,
          color: c.slate600,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.only(bottom: 10),
        // A rule, not a box. This is the only thing on the screen; a filled
        // rectangle round it would be a border round the whole page.
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

/// The photograph, or the invitation to take one.
class _PhotoSquare extends StatelessWidget {
  const _PhotoSquare({required this.photo, required this.onTap});

  final Uint8List? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: c.field,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: photo == null ? c.line : c.gold),
          image: photo == null
              ? null
              : DecorationImage(image: MemoryImage(photo!), fit: BoxFit.cover),
        ),
        child: photo != null
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 22, color: c.muted),
                  const SizedBox(height: 6),
                  Text(
                    'Photo',
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11.5,
                      color: c.muted,
                    ),
                  ),
                ],
              ),
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: on ? c.gold : c.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: fontBody,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
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
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
        child: Row(
          children: [
            /*
              "Save now" rather than "Skip".

              Skip says the question was a step you got out of. Save says the
              thing exists, which is true from the moment it has a name — the
              difference between a wizard you escape and one you can stop using
              whenever you like.
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
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
