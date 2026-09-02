/// Adding a subscription, one question at a time.
///
/// ── The same three cards, one to a screen ──────────────────────────────────
/// `sub_form_sheet.dart` shows Service, Billing and Reminder stacked. That is
/// the right shape for EDITING, where somebody has arrived to change one
/// specific thing and needs to find it, and the wrong shape for the first
/// thirty seconds of owning the app: three cards of boxes is a form, and a form
/// is a thing people put off.
///
/// So creating is those same three cards on three screens, in the order
/// somebody would answer them. They are not simplified copies —
/// `sub_cards.dart` draws both, so the grid, the split toggle and the reminder
/// choices here are the ones on the long form, and always will be.
///
/// Editing still opens the full form.
///
/// ── Everything after the service is optional, almost ───────────────────────
/// "Save now" sits in the footer from the moment there is a name. The one
/// refusal the app makes survives: a subscription with no renewal date has no
/// next renewal, and every date in the app derives from that one — so saving
/// without it takes you to the screen that has it. See
/// `whyNotSaveableSubscription`.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/auto_advance.dart';
import '../logic/subscription_form.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'save_sub.dart';
import 'sub_cards.dart';
import 'sub_form_sheet.dart';
import 'theme.dart';
import 'wizard_parts.dart';

/// Opens the step-by-step add. Resolves true when something was saved.
Future<bool?> showSubWizard(BuildContext context, {required Repository repo}) {
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

/// The three questions, in the order somebody answers them.
///
/// Service first because it is the only required answer and the only one
/// anybody always knows. The reminder comes last because it is the only
/// question about the app rather than about the subscription.
enum _Step { service, billing, reminder }

class _Wizard extends StatefulWidget {
  const _Wizard({required this.repo});

  final Repository repo;

  @override
  State<_Wizard> createState() => _WizardState();
}

class _WizardState extends State<_Wizard> {
  final SubscriptionDraft _draft = SubscriptionDraft();

  /*
    Owned here, not built beside the field.

    A controller created in `build` is a new one on every keystroke, and one
    created beside an `await` is disposed while the sheet is still closing. This
    app has been bitten by the second; see ask_text.dart.
  */
  final TextEditingController _name = TextEditingController();

  final PageController _pages = PageController();
  _Step _at = _Step.service;

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

  /*
    ── Nothing takes focus on arrival ──────────────────────────────────────

    The item wizard opens its keyboard, because its first question is a text
    field and nothing else on the screen can be tapped. This one is the
    opposite: the first question is fifty logos, and the box underneath them is
    the way out for the gym. A keyboard on arrival would cover the answer.

    That is the same reason the box sits under the grid rather than over it —
    see the note in `SubServiceCard`.
  */

  @override
  void dispose() {
    _name.dispose();
    _pages.dispose();
    super.dispose();
  }

  bool get _named => _name.text.trim().isNotEmpty;
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

    Read by `_advance` from the step's own build and by `_arrived` on the way
    in. Two copies of this would let a screen advance on a rule the arrival
    check disagreed with, which is the sort of thing that shows up as a wizard
    that skips a question every third time.

    The lists are the long form's own — see the `AutoAdvance` calls in
    `sub_form_sheet.dart`. The whole card, optionals included: a screen that
    threw you forward the moment its most important answer arrived would skip
    three fields nobody had touched. See `cardFilled`.
  */
  List<Object?> _answersFor(_Step step) => switch (step) {
        _Step.service => [_draft.name],
        /*
          ── Billing never advances on its own ────────────────────────────────

          It did, on the same rule the long form scrolls by — renewal, amount
          and started — and it threw people past the split toggle, which sits
          under those three and is the last thing on the card.

          The rule cannot be fixed by adding the toggle to this list: a switch
          that is off reads as unanswered to `cardFilled`, so listing it would
          mean the screen only ever advanced for somebody who splits, which is
          the smaller half of everybody.

          And the toggle is not really the point. This screen has more on it
          than any other in the app — two dates, an amount, a cadence, and a
          branch that opens two more boxes — so "finished with it" is a
          judgement only the person holding the phone can make. Same call as
          the attachments screen on the item wizard, for the same reason.
        */
        _Step.billing => const [null],
        // The last screen never advances; there is nowhere to go.
        _Step.reminder => const [null],
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
      typing, and it is what stops the name box advancing mid-word.

      And arriving complete is not becoming complete, which is what `_arrived`
      is for.
  */
  void _advance(_Step from) {
    if (from != _at || _advanced.contains(from)) return;
    if (_last) return;
    if (!cardFilled(_answersFor(from))) return;
    if (MediaQuery.of(context).viewInsets.bottom > 0) return;

    _advanced.add(from);

    // A beat, so the logo somebody just pressed is seen to light up before the
    // screen it is on leaves.
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted && _at == from) _go(_Step.values[from.index + 1]);
    });
  }

  /*
    ── Out through the form, with the name ─────────────────────────────────

    Somebody adding eight services is served worse by three screens each than by
    one form, and somebody who wants a field this does not ask about cannot get
    there from here at all.

    The name goes with them. An escape hatch that throws away what was already
    typed is one people use once.
  */
  Future<void> _theLongWay() async {
    final navigator = Navigator.of(context);
    final host = navigator.context;

    navigator.pop(false);

    if (!host.mounted) return;
    await showSubForm(host, repo: widget.repo, startingName: _name.text.trim());
  }

  /* ---------------------------------------------------------------- saving */

  Future<void> _save() async {
    _draft.name = _name.text.trim();

    final problem = whyNotSaveableSubscription(_draft);
    if (problem != null) {
      feedback(Cue.error);
      setState(() => _problem = problem);

      /*
        Taken to the screen that can fix it.

        A refusal that names a field without showing it makes somebody hunt for
        a box they cannot picture — and here the box may be two screens behind
        them. There are only two refusals and they live on the first two
        screens, so an empty name goes back to the grid and everything else is
        the renewal date.
      */
      _go(_named ? _Step.billing : _Step.service);
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    final outcome = await saveSubDraft(
      context,
      repo: widget.repo,
      draft: _draft,
      isNew: true,
    );

    if (!mounted) return;

    switch (outcome) {
      case SubNotSaved(:final message):
        setState(() {
          _problem = message;
          _saving = false;
        });

      case SubSaved():
        Navigator.of(context).pop(true);
    }
  }

  /* ----------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      ── Two thirds, and never behind the keyboard ───────────────────────────

      Two thirds is the app's sheet, and two thirds anchored to the bottom edge
      is also exactly where the keyboard appears. The padding goes INSIDE the
      sheet rather than under it: lifting the whole thing was the first attempt
      on the item wizard and it ran off the top of the screen. The sheet keeps
      its height, the contents move up by exactly what the keyboard takes, and
      every step scrolls in whatever is left. See the longer note there.
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
                    // two screens later.
                    physics: _named
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: _arrived,
                    children: [
                      _service(),
                      _billing(),
                      _reminder(),
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
                  full form. After it, it is "Save now" — available from the
                  moment there is a name and a date, because nothing else is
                  required and making somebody walk to the end would be a wizard
                  pretending its questions are demands.

                  They never both apply: on the first screen there is nothing
                  saved to save, and after it the way out has already been
                  offered.
                */
                WizardFooter(
                  c: c,
                  last: _last,
                  ready: _named,
                  saving: _saving,
                  onNext: _next,
                  lastLabel: 'Save subscription',
                  quietLabel: _at == _Step.service
                      ? 'Use the full form instead'
                      : 'Save now',
                  onQuiet: _at == _Step.service
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

  Widget _service() {
    _advance(_Step.service);

    return WizardAsk(
      question: 'What service are you paying for?',
      hint: 'Tap one, or type anything we do not have a logo for.',
      answer: SubServiceCard(
        // No heading on any of the three cards here. The question above each
        // one already says what is on it, so the heading was that question
        // repeated in smaller type one line below itself. The long form keeps
        // its headings — it stacks all three and needs them to tell the cards
        // apart.
        title: '',
        draft: _draft,
        name: _name,
        // The wizard's own auto-advance and its footer both read the name, so
        // they have to hear about a tap on the grid.
        onChanged: () => setState(() {}),
      ),
    );
  }

  Widget _billing() {
    // No `_advance` here, deliberately — see the note in `_answersFor`.
    return WizardAsk(
      question: 'What does it cost?',
      hint: 'The next renewal is the one date everything else is worked out '
          'from.',
      answer: SubBillingCard(
        title: '',
        draft: _draft,
        onChanged: () => setState(() {}),
      ),
    );
  }

  Widget _reminder() {
    return WizardAsk(
      question: 'Remind me before it renews.',
      hint: 'Most do not need one — the money leaves either way.',
      answer: SubReminderCard(
        title: '',
        draft: _draft,
        onChanged: () => setState(() {}),
      ),
    );
  }
}
