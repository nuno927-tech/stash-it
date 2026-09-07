/// The three cards a subscription is made of, drawn once for both ways in.
///
/// ── Why they moved out of the form ─────────────────────────────────────────
/// `sub_form_sheet.dart` was the only place a subscription could be made, so
/// the cards lived inside it. Then the step-by-step sheet arrived and needed
/// the same three — the same grid of fifty-odd logos, the same cadence row, the
/// same split toggle, the same reminder choices.
///
/// Copying them would have started identical and drifted the first time either
/// side was touched. That is exactly what nearly happened to the warranty
/// control before `CoverageList` was pulled out, and this is the same move for
/// the same reason: **one card, two screens.**
///
/// ── They own nothing ───────────────────────────────────────────────────────
/// Each takes the draft and a callback, mutates the draft in place and calls
/// back so whoever owns the screen can rebuild. The name field's controller is
/// passed in rather than made here, because both callers need to write to it —
/// the form to seed an edit, the wizard to hand the name to the long way out.
library;

import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/services.dart';
import '../logic/subscription_form.dart';
import '../logic/subscriptions.dart';
import '../models/subscription.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'service_mark.dart';
import 'theme.dart';

/* ---------------------------------------------------------------- service */

/*
  ── Two numbers the grid's arithmetic rests on ──────────────────────────────

  `_tileHeight` is a mark at 38, seven of gap, two lines at 10.5 and ten of
  padding top and bottom — measured rather than guessed, and fixed so that
  every row is the same height whatever the names in it are.

  `_roomForEverythingElse` is what the sheet spends on the question, the hint,
  the name box, the rail and the footer. It only has to be roughly right: it
  decides between two rows and three, and being ten pixels out never changes
  that answer.
*/
const double _tileHeight = 92;
const double _roomForEverythingElse = 250;

/// Which service this is: the grid, or whatever you type instead.
///
/// ── The grid is the field ─────────────────────────────────────────────────
/// The old form opened on an empty "Call it" box, which asked somebody to type
/// "Netflix" — a word the app already knows, spelled a way it could then never
/// match against its own logo list. The grid answers the name, the logo and the
/// service id in one tap, and the text field underneath is for the gym.
class SubServiceCard extends StatelessWidget {
  const SubServiceCard({
    required this.draft,
    required this.name,
    required this.onChanged,
    this.title = 'Service',
    this.oneScreen = false,
    this.nameFocus,
    this.onPicked,
    super.key,
  });

  final SubscriptionDraft draft;

  /// Owned by the caller. Choosing off the grid writes into it, and typing in
  /// it unpicks whatever was chosen.
  final TextEditingController name;

  /// "Something changed" — the caller rebuilds.
  final VoidCallback onChanged;

  /// The heading on the card. Both screens use the same words, so the wizard's
  /// question and the card underneath it never disagree about what is on it.
  final String title;

  /*
    ── Wizard shape, or form shape ──────────────────────────────────────────

    On the wizard this card IS the screen and it has to fit on one, with the
    keyboard up: the box goes first and takes the cursor, and the grid gets
    whatever height is left, showing whole rows and scrolling to the rest.

    On the long form it is the first of three stacked cards. Nothing there
    should take the keyboard on arrival — somebody is reading down a form —
    and a bounded, scrolling grid inside a scrolling form is two scrollers
    fighting over the same drag.
  */
  final bool oneScreen;

  /// Owned by the caller, so the wizard can put the cursor here as the step
  /// arrives. Null on the form, which takes no focus on its own.
  final FocusNode? nameFocus;

  /*
    ── Chosen off the grid, which is different from changed ─────────────────

    `onChanged` fires on every keystroke as well, and the wizard treats those
    two very differently: typing means somebody is still working, tapping a
    logo means they have finished the question. Only the tap is worth acting
    on, so only the tap gets its own callback.
  */
  final VoidCallback? onPicked;

  /// Picking one off the grid answers three questions at once.
  void _choose(ServiceDef service) {
    feedback(Cue.tap);
    draft.serviceId = service.id;
    draft.name = service.name;
    name.text = service.name;
    onChanged();
    onPicked?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      The grid narrows as you type.

      Not a dropdown and not an autocomplete list: the whole point of a logo is
      that it is recognised faster than it is read, so the answer to "which one"
      is a picture rather than a row of text. Typing filters it, and typing
      something not on the list is itself a valid answer — the field keeps
      whatever was typed and the mark falls back to initials.
    */
    final matches = searchServices(draft.name);

    /*
      Built as two pieces so the order can change.

      The wizard needs the box first and the form needs it last — see
      `oneScreen` — and a list that is assembled in one order and then reversed
      by conditionals is a list nobody can read.
    */
    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        /*
          ── Once one is chosen, the grid goes ────────────────────────────────

          The grid filters on whatever is in the name box, and choosing a
          service puts its name in that box — so after a tap the fifty-seven
          tiles collapsed to exactly one, sitting small and left-aligned where
          the grid had been, with the large centred mark below it. Two icons for
          one answer, and the little one looked like a leftover.

          It is a leftover. A grid is for choosing between things; once the
          choice is made there is nothing left to choose between, so what
          belongs here is the answer and a way to change it.
        */
        if (serviceFor(draft.serviceId) case final chosen?) ...[
          Center(
            child: Column(
              children: [
                ServiceMark(serviceId: chosen.id, name: chosen.name, size: 64),
                const SizedBox(height: 10),
                Text(
                  chosen.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    feedback(Cue.collapse);
                    // Both, because the grid filters on the name. Clearing only
                    // the id would bring back a grid of one.
                    draft.serviceId = null;
                    draft.name = '';
                    name.clear();
                    onChanged();
                  },
                  child: Text(
                    'Choose a different one',
                    style: TextStyle(
                        fontFamily: fontBody, fontSize: 13, color: c.muted),
                  ),
                ),
              ],
            ),
          ),
        ] else if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Not one we know. That is fine — it saves under whatever you '
              'called it, with its initials for a mark.',
              style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 13,
                  height: 1.45,
                  color: c.muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              const gap = 8.0;
              // Five across, as the PWA has it. At four the tiles are large
              // enough to look like buttons rather than a palette; at six the
              // names wrap to three lines.
              final width = (box.maxWidth - gap * 4) / 5;

              final grid = Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final service in matches)
                    SizedBox(
                      width: width,
                      // Fixed, so a row is a known height. A `Wrap` sizes each
                      // row to its tallest child, and "Nintendo Switch Online"
                      // on two lines beside "Hulu" on one made the rows
                      // different heights — which makes "how many rows fit"
                      // unanswerable.
                      height: _tileHeight,
                      child: _ServiceTile(
                        service: service,
                        onTap: () => _choose(service),
                      ),
                    ),
                ],
              );

              if (!oneScreen) return grid;

              /*
                ── Whole rows, and the rest below the fold ──────────────────

                With the keyboard up there is room for two or three rows of
                fifty-seven tiles. Showing a strip of a fourth would be the
                card saying "there is more" in the least useful way there is —
                half a picture, cut through the middle.

                So the box is a whole number of rows and the remainder scrolls.
                The floor is one row: a grid of nothing is worse than a grid
                that is obviously short.
              */
              const pitch = _tileHeight + gap;

              /*
                Measured against the SHEET, not the screen. The wizard is
                seventy-two per cent of the display and the keyboard comes out
                of that, so the screen's own height would answer a question
                nobody is asking.
              */
              final room = MediaQuery.sizeOf(context).height * 0.72 -
                  MediaQuery.viewInsetsOf(context).bottom -
                  _roomForEverythingElse;

              /*
                Two at the least, four at the most.

                One row is a strip, not a grid, and on a short phone with the
                keyboard up the arithmetic would land there — the step scrolls,
                so a second row half below the fold is better than a first row
                alone above it. Four is where a grid stops being scannable and
                starts being a page.
              */
              final rows = (room / pitch).floor().clamp(2, 4);

              return SizedBox(
                height: rows * pitch - gap,
                child: SingleChildScrollView(child: grid),
              );
            },
          ),
      ],
    );

    /*
      ── Under the grid on the form, over it on the wizard ──────────────────

      On the long form it belongs underneath: somebody scanning three stacked
      cards is almost certainly going to tap one of the fifty pictures, and a
      text box above them reads as the app asking for typing it does not need.
      There it is what it looks like — the way out for the gym, the window
      cleaner and the one service we have no logo for.

      On the wizard the screen has one question and the box takes the cursor as
      it opens, so it has to be the thing at the top. A field with the keyboard
      under it and the grid above it would push the grid off the screen the
      moment anybody arrived.

      The same field the item wizard uses for a product name — `NameField`,
      which is where that style lives. These two screens are one swipe apart in
      the same sheet and both ask what a thing is called.
    */
    final box = NameField(
      controller: name,
      focus: nameFocus,
      hint: 'Netflix, Spotify, the gym...',
      onChanged: (v) {
        draft.name = v;

        // Typing over a chosen service unpicks it. Otherwise a subscription
        // called "Netflix account" keeps Netflix's id, and the id is what the
        // rest of the app trusts.
        final picked = serviceFor(draft.serviceId);
        if (picked != null && picked.name != v) draft.serviceId = null;

        onChanged();
      },
    );

    return SheetCard(
      title: title,
      children: [
        if (oneScreen) ...[box, const SizedBox(height: 14)],
        grid,
        if (!oneScreen) ...[const SizedBox(height: 14), box],
      ],
    );
  }
}

/* ---------------------------------------------------------------- billing */

/// How often, how much, since when, and who it is split with.
class SubBillingCard extends StatefulWidget {
  const SubBillingCard({
    required this.draft,
    required this.onChanged,
    this.title = 'Billing',
    super.key,
  });

  final SubscriptionDraft draft;
  final VoidCallback onChanged;
  final String title;

  @override
  State<SubBillingCard> createState() => _SubBillingCardState();
}

class _SubBillingCardState extends State<SubBillingCard> {
  /*
    ── Owned here, so the action key has somewhere to go ────────────────────

    Two focus nodes for the two split fields. They have to belong to a State:
    a `FocusNode` built in `build` is a new one on every keystroke, which is
    the same trap as a controller built there.
  */
  final FocusNode _payTo = FocusNode();
  final FocusNode _payHow = FocusNode();

  /// The amount, so the calendar can hand the number pad straight to it.
  final FocusNode _amount = FocusNode();

  /// On the split fields, so turning the toggle on can bring them up the
  /// screen rather than revealing them under the keyboard.
  final GlobalKey _splitTop = GlobalKey();

  /// On the amount, for the same reason: the calendar hands it the keyboard,
  /// and a field with a keyboard over it is a field nobody can see.
  final GlobalKey _amountTop = GlobalKey();

  @override
  void dispose() {
    _payTo.dispose();
    _payHow.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool anchor}) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(
        anchor ? widget.draft.anchorDate : (widget.draft.startedDate ?? ''));

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      /*
        The next renewal is allowed to be in the future and the start is not.

        They are the two halves of the same arithmetic — `nextRenewal` walks
        forward from the anchor — and a "started" date after today would mean a
        subscription that has not begun paying for a renewal that already has.
      */
      lastDate: anchor ? DateTime(now.year + 12) : now,
    );

    if (picked == null) return;
    feedback(Cue.tap);

    final iso = '${picked.year.toString().padLeft(4, '0')}'
        '-${picked.month.toString().padLeft(2, '0')}'
        '-${picked.day.toString().padLeft(2, '0')}';

    if (anchor) {
      widget.draft.anchorDate = iso;
    } else {
      widget.draft.startedDate = iso;
    }
    widget.onChanged();

    /*
      ── The renewal hands over to the amount ────────────────────────────────

      They sit side by side and they are one thought: when it renews and what
      it costs. Pressing OK on the calendar used to close it and leave the
      cursor nowhere, so the next tap was on a box eight pixels to the right —
      which the app already knew was the next thing to fill in.

      Only from the renewal date. "Started" is the last field on the card and
      has nothing after it to hand anything to.
    */
    /*
      The number pad opens over the bottom half of the screen, and Amount sits
      in the middle of a tall card — so handing it the keyboard without moving
      anything put the cursor in a box nobody could see.

      `focusThenReveal` waits for the keyboard before deciding where the field
      should sit, which is the only order that works — see the note there.
    */
    if (anchor && mounted) {
      focusThenReveal(context, focus: _amount, at: _amountTop);
    }
  }

  /*
    ── Turning on the split brings its fields to you ───────────────────────

    The toggle sits at the foot of a card that is already tall, so switching it
    on revealed two fields below the fold — and then the keyboard would have
    covered them anyway. Somebody answered a question by scrolling to find
    where the answer went.

    Same shape as the coverage card's Additional details: after the frame that
    builds them, bring the first one to the top of the screen and give it the
    keyboard.
  */
  void _openSplit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Keyboard first, then the scroll, or the field ends up behind it —
      // see `focusThenReveal`.
      focusThenReveal(context, focus: _payTo, at: _splitTop);
    });
  }

  /// What this will cost per month, while it is being typed.
  ///
  /// A weekly plan is 52.18 weeks a year, not four weeks a month — four
  /// undercounts by about 8%, which is the kind of error that makes a total
  /// look believable and wrong. This is how somebody notices that £5 a week is
  /// not £20 a month.
  String? get _monthly {
    final cents = parseMoneyToCents(widget.draft.amountText);
    if (cents == null || cents == 0) return null;
    if (widget.draft.cadence == Cadence.monthly) return null;

    final sub = toSubscription(
      SubscriptionDraft(
        name: 'x',
        anchorDate: '2026-01-01',
        cadence: widget.draft.cadence,
        amountText: widget.draft.amountText,
      ),
      propertyId: 'x',
    );

    final per = (monthlyCents(sub) / 100).toStringAsFixed(2);
    return 'That is ${currencySymbol(widget.draft.currency)}$per a month.';
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final monthly = _monthly;

    return SheetCard(
      title: widget.title,
      children: [
        const FieldLabel('How often'),
        SegRow<Cadence>(
          value: widget.draft.cadence,
          options: const [
            (Cadence.weekly, 'Weekly'),
            (Cadence.monthly, 'Monthly'),
            (Cadence.quarterly, 'Quarterly'),
            (Cadence.yearly, 'Yearly'),
          ],
          onPick: (v) {
            widget.draft.cadence = v;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /*
                    The one refusal this form makes.

                    A subscription is a cadence and one real renewal date, and
                    every other date in the app derives from that one — the next
                    renewal, the calendar, the six-month chart, the reminder.
                    Without it the row appears in a list sorted by when things
                    renew while having no answer to that question.
                  */
                  const FieldLabel('Next renewal'),
                  DateBox(
                    value: widget.draft.anchorDate,
                    onTap: () => _pickDate(anchor: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel('Amount', key: _amountTop),
                  MoneyBox(
                    initial: widget.draft.amountText,
                    currency: widget.draft.currency,
                    focus: _amount,
                    onChanged: (v) {
                      widget.draft.amountText = v;
                      widget.onChanged();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        if (monthly != null) ...[
          const SizedBox(height: 8),
          Text(
            monthly,
            style:
                TextStyle(fontFamily: fontBody, fontSize: 12.5, color: c.gold),
          ),
        ],
        const SizedBox(height: 14),
        const FieldLabel('Started'),
        DateBox(
          value: widget.draft.startedDate ?? '',
          onTap: () => _pickDate(anchor: false),
        ),
        const SizedBox(height: 16),
        Container(height: 1, color: c.line),
        const SizedBox(height: 14),

        /*
          Splitting. The amount above stays what YOU pay either way — every
          total in the app is built from it, and a number that sometimes means
          the whole bill and sometimes half of it makes the monthly figure
          meaningless. These two only record the arrangement, which is what the
          subtitle says out loud rather than leaving somebody to guess.
        */
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Split with someone',
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Records who the money goes to',
                    style: TextStyle(
                        fontFamily: fontBody, fontSize: 12.5, color: c.muted),
                  ),
                ],
              ),
            ),
            // The theme's own switch, unstyled here. Settings has three of
            // these and a fourth that looked almost the same would be a
            // fourth thing to keep in step.
            Switch(
              value: widget.draft.shared,
              onChanged: (v) {
                // On and off both. A switch that only buzzes one way feels
                // broken in the direction it stays silent.
                feedback(v ? Cue.expand : Cue.collapse);
                widget.draft.shared = v;
                widget.onChanged();

                // Turning it off is just a toggle; turning it on is a journey.
                if (v) _openSplit();
              },
            ),
          ],
        ),
        if (widget.draft.shared) ...[
          const SizedBox(height: 12),
          FieldLabel('Who it goes to', key: _splitTop),
          /*
            The action key goes to the next box, not away.

            It was a tick, which put the keyboard down and left somebody
            looking at a field they still had to reach past it to tap. These
            two are one answer in two halves — who, and how — so finishing the
            first means starting the second.
          */
          TextBox(
            initial: widget.draft.payTo,
            focus: _payTo,
            hint: 'Mum, my flatmate, the group',
            action: TextInputAction.next,
            onSubmitted: _payHow.requestFocus,
            onChanged: (v) {
              widget.draft.payTo = v;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 12),
          const FieldLabel('How they get it'),
          // The last box on the card keeps the tick: there is genuinely
          // nothing after it, and a "next" that went nowhere would be worse
          // than the tick was.
          TextBox(
            initial: widget.draft.payHow,
            focus: _payHow,
            hint: 'Standing order on the 1st',
            action: TextInputAction.done,
            onSubmitted: _payHow.unfocus,
            onChanged: (v) {
              widget.draft.payHow = v;
              widget.onChanged();
            },
          ),
        ],
      ],
    );
  }
}

/* --------------------------------------------------------------- reminder */

/// Whether to be told before it renews, and anything worth writing down.
class SubReminderCard extends StatelessWidget {
  const SubReminderCard({
    required this.draft,
    required this.onChanged,
    this.title = 'Reminder',
    this.notes = true,
    super.key,
  });

  final SubscriptionDraft draft;
  final VoidCallback onChanged;
  final String title;

  /// The notes box. On the wizard's last screen it stays, because that screen
  /// is otherwise four chips and a sentence.
  final bool notes;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      None is the default, and that is deliberate.

      A renewal is not an event most people need waking for: the money leaves
      whether they know or not, and nine monthly services would mean nine
      notifications a month for nothing. Choosing anything else is somebody
      saying that this one is different.
    */
    final days = draft.remindDays ?? 0;

    return SheetCard(
      title: title,
      children: [
        SegRow<int>(
          value: days,
          options: const [
            (0, 'None'),
            (1, '1 day'),
            (3, '3 days'),
            (7, '7 days'),
          ],
          onPick: (v) {
            draft.remindDays = v == 0 ? null : v;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        Text(
          switch (days) {
            0 => 'No reminder. You can turn one on later.',
            1 => 'A notification the day before it renews.',
            final int d => 'A notification $d days before it renews.',
          },
          style: TextStyle(
              fontFamily: fontBody, fontSize: 13, height: 1.45, color: c.muted),
        ),
        if (notes) ...[
          const SizedBox(height: 14),
          const FieldLabel('Notes'),
          TextBox(
            initial: draft.notes,
            hint: 'Optional',
            lines: 4,
            onChanged: (v) => draft.notes = v,
          ),
        ],
      ],
    );
  }
}

/* ------------------------------------------------------------- the pieces */

/// One service on the grid.
///
/// No selected state, deliberately: the grid is only on screen while nothing is
/// chosen. A lit tile would be a third place the same answer is drawn — see the
/// note where the grid is built.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});

  final ServiceDef service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Material(
      color: c.slate800,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Column(
            children: [
              ServiceMark(serviceId: service.id, name: service.name, size: 38),
              const SizedBox(height: 7),
              Text(
                service.name,
                textAlign: TextAlign.center,
                // Two lines, because "Nintendo Switch Online" is not going to
                // fit on one and truncating it to "Nintendo Sw..." loses the
                // half that says which subscription it is.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 10.5,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: c.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
