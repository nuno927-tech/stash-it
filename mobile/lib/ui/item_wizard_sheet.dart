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

import 'package:flutter/material.dart';
// `Uint8List` comes with this — services re-exports dart:typed_data — so
// importing it again is the analyzer's `unnecessary_import`. It arrived when
// the photograph did and stopped being needed when the price field brought
// `TextInputFormatter` in beside it.
import 'package:flutter/services.dart';

import '../db/repository.dart';
import '../logic/attachments.dart';
import '../logic/auto_advance.dart';
import '../logic/dates.dart';
import '../logic/format.dart';
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
import 'wizard_parts.dart';

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

  /*
    ── Enter goes to the price, not to the next screen ─────────────────────

    The keyboard's action key means "I have finished this field", and the next
    field is on the same screen. Sending it forward a page was the app deciding
    somebody had finished the SCREEN, which is a different claim and one it had
    no reason to make — the price is right there, unanswered.
  */
  final FocusNode _costFocus = FocusNode();

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

    /*
      ── One policy to start with ────────────────────────────────────────────

      The long form seeds this and the wizard did not, which is why the
      coverage screen arrived empty: `CoverageList` draws the policies it is
      given, and it was given none — so the names, the units and the lengths
      were all there in the control and there was simply nothing for them to
      belong to.

      A policy with no length is still blank as far as `realCoverages` is
      concerned, so seeding one does not save anything nobody asked for.
    */
    if (_draft.coverages.isEmpty) {
      _draft.coverages.add(CoverageDraft(
        label: 'Warranty',
        unit: CoverageUnit.months,
        amountText: defaultTermText(CoverageUnit.months),
      ));
    }

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
    _costFocus.dispose();
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

      And arriving complete is not the same as becoming complete. The coverage
      screen opens on a seeded policy that already has a name and a length, so
      without the check in `_arrived` it would throw you straight past the one
      question it exists to ask.

    The last two screens never advance: attachments can always take one more,
    and the warning window is the end.
  */
  /*
    What "answered" means, per screen, in one place.

    Read by `_advance` from the step's own build and by `_arrived` on the way
    in. Two copies of this would let a screen advance on a rule the arrival
    check disagreed with, which is the sort of thing that shows up as a wizard
    that skips a question every third time.
  */
  List<Object?> _answersFor(_Step step) => switch (step) {
        _Step.what => [_name.text, _photo, _draft.priceText],
        _Step.room => [_draft.roomId],
        _Step.bought => [_draft.purchaseDate],
        _Step.cover => [
            _cover?.label,
            // Lifetime has no length, so on that unit it is not a question.
            if (_cover?.unit != CoverageUnit.lifetime) _cover?.amountText,
          ],
        // Neither of these ever advances; see the note above.
        _Step.papers => const [null],
        _Step.warning => const [null],
      };

  void _advance(_Step from) {
    if (from != _at || _advanced.contains(from)) return;
    if (from == _Step.papers || _last) return;
    if (!cardFilled(_answersFor(from))) return;
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

  /// How many of the five extras have something in them.
  int get _extras => [
        _draft.brand,
        _draft.model,
        _draft.serial,
        _draft.retailer,
        _draft.notes,
      ].where((v) => v.trim().isNotEmpty).length;

  /// The five fields that are not questions.
  ///
  /// A sheet over a sheet, which the app otherwise avoids — but this is the one
  /// case it is right for: everything in it is optional, nothing in it changes
  /// what the screen underneath says, and closing it is the only way out
  /// anybody needs. There is no Cancel because there is nothing to cancel: the
  /// boxes write straight into the draft, exactly as they do on the long form.
  Future<void> _moreDetails() async {
    feedback(Cue.expand);

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: StashColors.of(context).slate900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (context) => SheetEntrance(child: _MoreSheet(draft: _draft)),
    );

    // The count on the button, and nothing else — none of these five is an
    // answer `cardFilled` looks at, so the screen will not advance because of
    // one.
    if (mounted) setState(() {});
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

    /*
      Two thirds, like every other sheet in the app.

      It went to 0.78 for one reason: the first screen asks three questions and
      the price sat under the fold. Raising the sheet was the wrong end of that
      problem — five screens got taller so that one would fit.

      The row that used to hold "Add the long way" on its own is what pays for
      it now. That link moved into the footer beside Next, so the first screen
      is a question, three answers and one row of buttons, and it fits.
    */
    return SizedBox(
      height: screen * 0.72,
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
                WizardRail(
                  steps: _Step.values.length,
                  at: _at.index,
                  c: c,
                ),
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
                      _coverage(),
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
                /*
                  ── One row, two jobs, and the left one changes ──────────────

                  On the first screen the quiet button is the way out into the
                  full form. Everywhere after it, it is "Save now" — which is
                  available from the moment there is a name, because nothing
                  after the first question is required and making somebody walk
                  to the end would be a wizard pretending its questions are
                  demands.

                  They never both apply: on the first screen there is nothing
                  saved to save, and after it the way out has already been
                  offered. So they share a slot rather than costing a row each.
                */
                WizardFooter(
                  c: c,
                  last: _last,
                  ready: _named,
                  saving: _saving,
                  onNext: _next,
                  lastLabel: 'Save item',
                  quietLabel: _at == _Step.what
                      ? 'Use the full form instead'
                      : 'Save now',
                  onQuiet: _at == _Step.what
                      ? _theLongWay
                      : (_named && !_last && !_saving ? _save : null),
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

    // Arriving complete is not becoming complete — see `_advance`. The
    // coverage screen opens on a seeded policy and would otherwise be skipped.
    if (cardFilled(_answersFor(to))) _advanced.add(to);

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
    _advance(_Step.what);

    return WizardAsk(
      question: 'What is it?',
      hint: 'A name is all this needs. The rest helps later.',
      /*
        ── The picture stands beside both fields ─────────────────────────────

        Name on top, cost under it, and the photograph to the left of the pair
        rather than beside one of them. A square lined up with only the cost box
        reads as belonging to the cost.

        Centred against the pair rather than stretched to it: stretching made it
        a tall rectangle, which reads as a panel. It is a picture, so it stays a
        square.
      */
      answer: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PhotoSquare(photo: _photo, onTap: _pickPhoto),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _NameField(
                  controller: _name,
                  focus: _nameFocus,
                  onChanged: (_) => setState(() {}),
                  // The next field, not the next screen. See `_costFocus`.
                  onDone: () => _costFocus.requestFocus(),
                ),
                const SizedBox(height: 20),
                /*
                  ── The extras share the cost label's row ────────────────────

                  Brand, model, serial, retailer and notes all belong on this
                  screen and none of them belongs ON it: five more boxes would
                  turn the one question people always answer into a form, which
                  is the thing this sheet exists to avoid.

                  So they live one tap away, behind a button that costs no
                  height — it sits in the space to the right of a label that was
                  empty anyway. The screen still fits without scrolling, which
                  it would not if this were a row of its own.

                  The count is on the button because a closed drawer with
                  something in it must not look like a closed drawer with
                  nothing in it.
                */
                Row(
                  children: [
                    const FieldLabel('What it cost'),
                    const Spacer(),
                    _MoreButton(count: _extras, onTap: _moreDetails),
                  ],
                ),
                _CostField(
                  focus: _costFocus,
                  initial: _draft.priceText,
                  currency: _draft.currency,
                  onChanged: (v) => setState(() => _draft.priceText = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _room() {
    _advance(_Step.room);

    final all = _rooms;

    return WizardAsk(
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
    _advance(_Step.bought);

    final chosen = parseDate(_draft.purchaseDate);
    final today = startOfDay(DateTime.now());

    return WizardAsk(
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
            /*
              ── Held to six week-rows ─────────────────────────────────────────

              `CalendarDatePicker` reserves room for six of them whatever month
              it is on, so February on a Sunday start left two empty rows of
              nothing at the bottom of the card. It also keeps a fixed
              sub-header for the month name and arrows.

              318 is the sub-header plus five rows, which every month reaches
              and only a handful exceed — and the widget scrolls a month that
              needs the sixth rather than clipping it. Trading two rows of
              permanent whitespace for a rare scroll is the right way round.
            */
            child: SizedBox(
              height: 318,
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


  Widget _coverage() {
    _advance(_Step.cover);

    return WizardAsk(
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
      answer: SheetCard(
        title: 'Warranty information',
        children: [
          CoverageList(
            coverages: _draft.coverages,
            // The wizard's own auto-advance reads this list, so it has to hear
            // about a change made inside a control that owns its own state.
            onChanged: () => setState(() {}),
          ),
        ],
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
    return WizardAsk(
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
    return WizardAsk(
      question: 'How much warning?',
      hint: 'Before the cover runs out.',
      answer: SheetCard(
        title: 'How much warning',
        children: [
          SegRow<int?>(
            value: _draft.leadDays,
            options: [
              for (final choice in itemLeadChoices) (choice.days, choice.label),
            ],
            lines: 1,
            onPick: (v) => setState(() => _draft.leadDays = v),
          ),
          const SizedBox(height: 12),
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

  /// What the keyboard's action key does. Always the next field on this
  /// screen, never the next screen.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return TextField(
      controller: controller,
      focusNode: focus,
      onChanged: onChanged,
      onSubmitted: (_) => onDone(),
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

/// What it cost, on a rule rather than in a bubble.
///
/// ── Why not `MoneyBox` ─────────────────────────────────────────────────────
/// `MoneyBox` draws itself inside a `WhiteField`, which is `StashColors.field`
/// — and in the light theme `field` is #F4F2ED, which is EXACTLY `slate900`,
/// the sheet's own background. On the long form that is invisible by design,
/// because every field there sits inside a card. Here there is no card, so the
/// bubble was genuinely there and genuinely could not be seen.
///
/// A rule rather than a fill fixes it in both themes at once, and matches the
/// name field directly above — which is the other reason: two boxes of
/// different kinds, one over the other, on a screen with two questions on it.
///
/// The currency symbol sits inside the field as a prefix, the way `MoneyBox`
/// puts it, and the same formatter runs as you type. Correcting a field after
/// the fact makes people wonder whether they typed it wrong.
class _CostField extends StatelessWidget {
  const _CostField({
    required this.focus,
    required this.initial,
    required this.currency,
    required this.onChanged,
  });

  /// Owned by the sheet, so the name field's Enter key can reach it.
  final FocusNode focus;

  final String initial;
  final String currency;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    final style = TextStyle(fontFamily: fontBody, fontSize: 18, color: c.text);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, right: 6),
          child: Text(
            currencySymbol(currency),
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 18,
              color: c.muted,
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            focusNode: focus,
            initialValue: initial,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            /*
              Done, not next.

              This is the last field on the screen, and a keyboard offering
              "next" on the last one suggests there is another. Pressing it puts
              the keyboard away, which is also what lets the screen advance on
              its own — see the keyboard guard in `_advance`.
            */
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => focus.unfocus(),
            style: style,
            cursorColor: c.gold,
            inputFormatters: [
              TextInputFormatter.withFunction((old, now) {
                final formatted = formatMoneyInput(now.text, currency);
                return TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }),
            ],
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                fontFamily: fontBody,
                fontSize: 18,
                color: c.slate600,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.only(bottom: 10),
              border:
                  UnderlineInputBorder(borderSide: BorderSide(color: c.line)),
              enabledBorder:
                  UnderlineInputBorder(borderSide: BorderSide(color: c.line)),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: c.gold, width: 2),
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// The photograph, or the invitation to take one.
class _PhotoSquare extends StatelessWidget {
  const _PhotoSquare({required this.photo, required this.onTap});

  final Uint8List? photo;
  final VoidCallback onTap;

  /// Square, and it has to stay square.
  ///
  /// It was briefly sized by the row instead — width fixed, height stretched to
  /// the two fields beside it — and came out a tall rectangle, which reads as a
  /// panel rather than as a picture.
  static const double _side = 96;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _side,
        height: _side,
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

/// The way into the five extras, sized to fit beside a label.
///
/// Not a `TextButton`: Material's minimum tap height is 48, which is more than
/// the whole label row is, and the point of putting it here was that it costs
/// no height. 36 with a wide enough target either side is the compromise.
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.count, required this.onTap});

  /// How many of the five have something in them. Zero says nothing.
  final int count;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      // Matches `FieldLabel`, so the two sit on the same line.
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.pill),
          onTap: () {
            feedback(Cue.tap);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, size: 15, color: c.gold),
                const SizedBox(width: 6),
                Text(
                  count == 0 ? 'More details' : 'More details ($count)',
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: c.gold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand, model, serial, retailer and notes — the long form's own five, in the
/// same order and with the same hints.
///
/// Every one of them is optional and none of them is a question, which is why
/// they are not a step: a wizard screen asks something, and "would you like to
/// type a serial number" is not a thing anybody wants asked.
class _MoreSheet extends StatefulWidget {
  const _MoreSheet({required this.draft});

  final ItemDraft draft;

  @override
  State<_MoreSheet> createState() => _MoreSheetState();
}

class _MoreSheetState extends State<_MoreSheet> {
  /*
    Five boxes, four handoffs.

    The keyboard's corner key is a tick left alone, and a tick on the first of
    five boxes means reaching past the keyboard four times. See `TextBox.action`
    — the same chain the split fields and the document dates now use.
  */
  final FocusNode _brand = FocusNode();
  final FocusNode _model = FocusNode();
  final FocusNode _serial = FocusNode();
  final FocusNode _retailer = FocusNode();
  final FocusNode _notes = FocusNode();

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _serial.dispose();
    _retailer.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;

    final draft = widget.draft;

    return SizedBox(
      height: screen * 0.72,
      child: SafeArea(
        top: false,
        // The keyboard moves the contents up inside the sheet rather than
        // lifting the sheet off the bottom of the screen — the same note as on
        // the wizard itself.
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: insets),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  children: [
                    SheetCard(
                      title: 'More details',
                      children: [
                        const FieldLabel('Brand'),
                        TextBox(
                          initial: draft.brand,
                          focus: _brand,
                          hint: 'Optional',
                          action: TextInputAction.next,
                          onSubmitted: _model.requestFocus,
                          onChanged: (v) => draft.brand = v,
                        ),
                        const SizedBox(height: 12),
                        const FieldLabel('Model'),
                        TextBox(
                          initial: draft.model,
                          focus: _model,
                          hint: 'Optional',
                          action: TextInputAction.next,
                          onSubmitted: _serial.requestFocus,
                          onChanged: (v) => draft.model = v,
                        ),
                        const SizedBox(height: 12),
                        /*
                          Serial sits with the rest rather than on the wizard's
                          face, but it is the field people come back for —
                          somebody making a claim is reading it off a plate with
                          a torch, and the search matches on any four characters
                          of it. See logic/search.dart.
                        */
                        const FieldLabel('Serial number'),
                        TextBox(
                          initial: draft.serial,
                          focus: _serial,
                          hint: 'Optional',
                          action: TextInputAction.next,
                          onSubmitted: _retailer.requestFocus,
                          onChanged: (v) => draft.serial = v,
                        ),
                        const SizedBox(height: 12),
                        const FieldLabel('Retailer'),
                        TextBox(
                          initial: draft.retailer,
                          focus: _retailer,
                          hint: 'Optional',
                          action: TextInputAction.next,
                          onSubmitted: _notes.requestFocus,
                          onChanged: (v) => draft.retailer = v,
                        ),
                        const SizedBox(height: 12),
                        const FieldLabel('Notes'),
                        TextBox(
                          initial: draft.notes,
                          focus: _notes,
                          hint: 'Optional',
                          lines: 4,
                          onChanged: (v) => draft.notes = v,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Row(
                  children: [
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: c.gold,
                        foregroundColor: c.onGold,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          fontFamily: fontDisplay,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: c.onGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
