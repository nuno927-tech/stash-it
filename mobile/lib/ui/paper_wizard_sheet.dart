/// Adding a document, one question at a time.
///
/// ── The same three cards, one to a screen ──────────────────────────────────
/// `paper_form_sheet.dart` shows What is it, Dates and How much warning
/// stacked. That is the right shape for EDITING, where somebody has arrived to
/// change one specific thing and needs to find it, and the wrong shape for the
/// first thirty seconds of owning the app.
///
/// So creating is those same three cards on three screens, in the order
/// somebody would answer them, and a fourth screen that offers the camera. They are not simplified copies —
/// `paper_cards.dart` draws both, so the thirteen tiles, the "Whose" box, the
/// pair of dates and the five warning choices here are the ones on the long
/// form, and always will be.
///
/// Editing still opens the full form.
///
/// ── The one refusal survives ───────────────────────────────────────────────
/// Everything this tab does is arithmetic on the printed expiry date, so a
/// document without one would sit in a list of things being watched, not being
/// watched. Saving without it takes you to the screen that has it.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/attachments.dart';
import '../logic/auto_advance.dart';
import '../logic/paper_form.dart';
import '../logic/papers.dart';
import 'doc_tiles.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'paper_cards.dart';
import 'paper_form_sheet.dart';
import 'save_paper.dart';
import 'scan_gate.dart';
import 'theme.dart';
import 'wizard_parts.dart';

/// Opens the step-by-step add. Resolves true when something was saved.
Future<bool?> showPaperWizard(BuildContext context,
    {required Repository repo}) {
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

/// The four screens, in the order somebody answers them.
///
/// What it is comes first because the tile answers the name as well as the
/// kind. The warning window is the last question about the document.
///
/// ── And then the one that is not a question ───────────────────────────────
/// The scan comes last and answers nothing. It used to be a dialog after the
/// save, which arrives when somebody has just finished and is putting the
/// phone down — the worst moment to hand them a camera. As the final screen
/// it is part of the same run of taps, skippable by pressing save, and the
/// document is in their hand either way.
enum _Step { what, dates, warning, scan }

class _Wizard extends StatefulWidget {
  const _Wizard({required this.repo});

  final Repository repo;

  @override
  State<_Wizard> createState() => _WizardState();
}

class _WizardState extends State<_Wizard> {
  final PaperDraft _draft = PaperDraft();

  /*
    Owned here, not built beside the field.

    A controller created in `build` is a new one on every keystroke, and one
    created beside an `await` is disposed while the sheet is still closing. This
    app has been bitten by the second; see ask_text.dart.
  */
  final TextEditingController _label = TextEditingController();

  final PageController _pages = PageController();
  _Step _at = _Step.what;

  /// Chosen on the last screen, written once the document has an id — the
  /// long form stages them the same way, for the same reason.
  final List<PendingDoc> _scans = [];

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

    /*
      It opens as a passport, named Passport.

      The draft's own default kind is passport and its label is empty, so
      without this the first screen would be a lit tile above a name the app
      could have written itself — and on this wizard the name is not even shown
      unless the kind is Other, which would leave the record nameless.

      Same line as the long form's `initState`, for the same reason.
    */
    _draft.label = kindLabel[_draft.kind]!;
    _label.text = _draft.label;

    /*
      ── Nothing takes focus on arrival ────────────────────────────────────

      The item wizard opens its keyboard, because its first question is a text
      field and nothing else on the screen can be tapped. This one is the
      opposite: the first question is thirteen tiles. A keyboard on arrival
      would cover the answer.
    */
  }

  @override
  void dispose() {
    _label.dispose();
    _pages.dispose();
    super.dispose();
  }

  bool get _named => _draft.label.trim().isNotEmpty;
  bool get _last => _at == _Step.values.last;

  /* ------------------------------------------------------------- moving on */

  void _go(_Step to) {
    FocusScope.of(context).unfocus();
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
    What "answered" means, per screen, in one place.

    These are the long form's own lists — see the `AutoAdvance` calls in
    `paper_form_sheet.dart` — because a wizard that advanced on a different rule
    from the form it mirrors would be two rules to keep in step.

    The whole card, optionals included: a screen that threw you forward the
    moment its most important answer arrived would skip the fields nobody had
    touched yet. See `cardFilled`. The cost is that a card with an optional box
    on it will rarely advance, and that is the right way round.
  */
  List<Object?> _answersFor(_Step step) => switch (step) {
        // The kind is never unset, so it is not listed. "Whose" is.
        _Step.what => [_draft.label, _draft.holder],
        _Step.dates => [
            _draft.expiresOn,
            _draft.issuedOn,
            _draft.authority,
            _draft.storedAt,
          ],
        /*
          Neither of the last two advances by itself.

          The warning window arrives already answered — every document has a
          lead time — so "complete" would fire the moment it was reached and
          throw somebody past the choice they were shown. And the scan step is
          last; there is nowhere to go.
        */
        _Step.warning || _Step.scan => const [null],
      };

  /*
    ── Answering the last question on a screen moves you on ─────────────────

    Moving the screen under somebody is one of the most unpleasant things an
    interface can do, so this fires as rarely as it can while still being
    useful. The guards are the item wizard's, for the same reasons:

      Every answer on the screen, not the important one.

      Once per screen — going back to change something must not throw you
      forward again.

      Never while the keyboard is up. A keyboard means somebody is still
      typing, and it is what stops a name box advancing mid-word.

      And arriving complete is not becoming complete, which is what `_arrived`
      is for — this wizard opens with a name already written, so without it the
      first screen would throw you past the tiles it exists to show.
  */
  void _advance(_Step from) {
    if (from != _at || _advanced.contains(from)) return;
    if (_last) return;
    if (!cardFilled(_answersFor(from))) return;
    if (MediaQuery.of(context).viewInsets.bottom > 0) return;

    _advanced.add(from);

    // A beat, so the tile somebody just pressed is seen to light up before the
    // screen it is on leaves.
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted && _at == from) _go(_Step.values[from.index + 1]);
    });
  }

  /*
    ── Out through the form, with everything so far ────────────────────────

    Somebody filing a drawer of certificates is served worse by three screens
    each than by one form, and somebody who wants a field this does not ask
    about cannot get there from here at all.

    The whole draft goes with them, not just the name: the kind has usually been
    tapped by the time anybody reaches for the way out, and an escape hatch that
    throws that away is one people use once.
  */
  Future<void> _theLongWay() async {
    final navigator = Navigator.of(context);
    final host = navigator.context;

    navigator.pop(false);

    if (!host.mounted) return;
    await showPaperForm(host, repo: widget.repo, starting: _draft);
  }

  /* ---------------------------------------------------------------- saving */

  Future<void> _save() async {
    final problem = whyNotSaveablePaper(_draft);
    if (problem != null) {
      feedback(Cue.error);
      setState(() => _problem = problem);

      /*
        Taken to the screen that can fix it.

        A refusal that names a field without showing it makes somebody hunt for
        a box they cannot picture — and here the box may be two screens behind
        them. There are two refusals: an empty name, which only happens on
        Other, and the expiry date.
      */
      _go(_named ? _Step.dates : _Step.what);
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    final outcome = await savePaperDraft(
      context,
      repo: widget.repo,
      draft: _draft,
      isNew: true,
      pending: _scans,
    );

    if (!mounted) return;

    switch (outcome) {
      case PaperNotSaved(:final message):
        setState(() {
          _problem = message;
          _saving = false;
        });

      case PaperSaved():
        /*
          Nothing follows the save any more.

          A dialog used to open here offering a scan, because the wizard had
          no room for one. It arrives at the moment somebody has finished and
          is putting the phone down, which is the worst moment to hand them a
          camera — so the offer became the fourth screen instead, and this is
          simply the end.
        */
        Navigator.of(context).pop(true);
    }
  }

  /* ----------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      ── Two thirds, and never behind the keyboard ───────────────────────────

      The padding goes INSIDE the sheet rather than under it: lifting the whole
      thing was the first attempt on the item wizard and it ran off the top of
      the screen. The sheet keeps its height, the contents move up by exactly
      what the keyboard takes, and every step scrolls in whatever is left. See
      the longer note there.
    */
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: screen * 0.72,
      child: SheetEntrance(
        child: SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: insets),
            child: Column(
              children: [
                WizardRail(steps: _Step.values.length, at: _at.index, c: c),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: _arrived,
                    children: [
                      _what(),
                      _dates(),
                      _warning(),
                      _scanStep(),
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
                  full form. After it, it is "Save now" — which needs a date as
                  well as a name here, because the date is the refusal.
                */
                WizardFooter(
                  c: c,
                  last: _last,
                  ready: _named,
                  saving: _saving,
                  onNext: _next,
                  // "Save document" on the scan screen rather than "Done":
                  // the step is optional and the button has to read as the way
                  // past it, not as a confirmation of something taken.
                  lastLabel: 'Save document',
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

    // Arriving complete is not becoming complete — see `_advance`.
    if (cardFilled(_answersFor(to))) _advanced.add(to);

    FocusScope.of(context).unfocus();
  }

  /* ------------------------------------------------------------- the steps */

  Widget _what() {
    _advance(_Step.what);

    return WizardAsk(
      question: 'What is it?',
      hint: 'Tap one. The name comes with it — you can change it later.',
      answer: PaperKindCard(
        // No heading on any of the three cards here. The question above each
        // one already says what is on it, so the heading was that question
        // repeated in smaller type one line below itself. The long form keeps
        // its headings — it stacks all three and needs them to tell the cards
        // apart.
        title: '',
        draft: _draft,
        label: _label,
        // The wizard's own auto-advance and its footer both read the name, so
        // they have to hear about a tap on a tile.
        onChanged: () => setState(() {}),
      ),
    );
  }

  Widget _dates() {
    _advance(_Step.dates);

    return WizardAsk(
      question: 'When does it expire?',
      hint: 'The printed date. Everything on this tab is worked out from it.',
      answer: PaperDatesCard(
        title: '',
        draft: _draft,
        onChanged: () => setState(() {}),
      ),
    );
  }

  Widget _warning() {
    return WizardAsk(
      question: 'How much warning?',
      hint: 'Before it runs out.',
      answer: PaperWarningCard(
        title: '',
        draft: _draft,
        onChanged: () => setState(() {}),
      ),
    );
  }

  /*
    ── The optional one ──────────────────────────────────────────────────────

    Everything before this is a question with a right answer. This one is an
    offer, and it has to look like one: no refusal, no red text, and the
    footer's button says "Save document" rather than "Done" so that walking
    past it is the obvious move.

    Why it earns a screen at all: a renewal office asks for the page, not for
    the date somebody typed in. The document is in their hand right now — it
    will not be in a week.
  */
  Widget _scanStep() {
    return WizardAsk(
      question: 'Photograph it?',
      hint: 'Optional. A renewal usually asks for the page itself.',
      answer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScanButton(
            // The screen has asked the question; the button is the answer.
            label: 'Camera or files',
            onTap: _scan,
          ),
          StagedScans(
            scans: _scans,
            onRemove: (scan) => setState(() => _scans.remove(scan)),
          ),
        ],
      ),
    );
  }

  /// The lock, the source and the picker — the long form's own routine.
  Future<void> _scan() async {
    final picked = await takeScan(context, label: _draft.label);
    if (picked.isEmpty || !mounted) return;

    setState(() => _scans.addAll(picked));
  }
}
