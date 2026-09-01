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

  /// Picking one off the grid answers three questions at once.
  void _choose(ServiceDef service) {
    feedback(Cue.tap);
    draft.serviceId = service.id;
    draft.name = service.name;
    name.text = service.name;
    onChanged();
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

    return SheetCard(
      title: title,
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

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final service in matches)
                    SizedBox(
                      width: width,
                      child: _ServiceTile(
                        service: service,
                        onTap: () => _choose(service),
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 14),

        /*
          ── The box goes under the grid, not over it ─────────────────────────

          It was the first thing on the card, which put a text box in front of
          somebody whose answer was almost certainly one of the fifty pictures
          below it — and on a new subscription it took focus, so the keyboard
          arrived and covered the grid before it had been looked at.

          Underneath, it reads as what it actually is: the way out for the gym,
          the window cleaner and the one service we do not have a logo for.

          `bareInput` rather than a hand-written decoration, because the theme
          sets `filled` and an `enabledBorder` and a decoration that only sets
          `border` does not switch either off — see the note there. That is what
          was drawing a second box inside this one.
        */
        WhiteField(
          child: TextField(
            controller: name,
            style: TextStyle(fontFamily: fontBody, fontSize: 17, color: c.text),
            cursorColor: c.gold,
            decoration: bareInput(
              hint: 'Netflix, Spotify, the gym...',
              hintStyle:
                  TextStyle(fontFamily: fontBody, fontSize: 17, color: c.muted),
            ),
            onChanged: (v) {
              draft.name = v;

              // Typing over a chosen service unpicks it. Otherwise a
              // subscription called "Netflix account" keeps Netflix's id, and
              // the id is what the rest of the app trusts.
              final picked = serviceFor(draft.serviceId);
              if (picked != null && picked.name != v) draft.serviceId = null;

              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

/* ---------------------------------------------------------------- billing */

/// How often, how much, since when, and who it is split with.
class SubBillingCard extends StatelessWidget {
  const SubBillingCard({
    required this.draft,
    required this.onChanged,
    this.title = 'Billing',
    super.key,
  });

  final SubscriptionDraft draft;
  final VoidCallback onChanged;
  final String title;

  Future<void> _pickDate(BuildContext context, {required bool anchor}) async {
    final now = DateTime.now();
    final current =
        DateTime.tryParse(anchor ? draft.anchorDate : (draft.startedDate ?? ''));

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
      draft.anchorDate = iso;
    } else {
      draft.startedDate = iso;
    }
    onChanged();
  }

  /// What this will cost per month, while it is being typed.
  ///
  /// A weekly plan is 52.18 weeks a year, not four weeks a month — four
  /// undercounts by about 8%, which is the kind of error that makes a total
  /// look believable and wrong. This is how somebody notices that £5 a week is
  /// not £20 a month.
  String? get _monthly {
    final cents = parseMoneyToCents(draft.amountText);
    if (cents == null || cents == 0) return null;
    if (draft.cadence == Cadence.monthly) return null;

    final sub = toSubscription(
      SubscriptionDraft(
        name: 'x',
        anchorDate: '2026-01-01',
        cadence: draft.cadence,
        amountText: draft.amountText,
      ),
      propertyId: 'x',
    );

    final per = (monthlyCents(sub) / 100).toStringAsFixed(2);
    return 'That is ${currencySymbol(draft.currency)}$per a month.';
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final monthly = _monthly;

    return SheetCard(
      title: title,
      children: [
        const FieldLabel('How often'),
        SegRow<Cadence>(
          value: draft.cadence,
          options: const [
            (Cadence.weekly, 'Weekly'),
            (Cadence.monthly, 'Monthly'),
            (Cadence.quarterly, 'Quarterly'),
            (Cadence.yearly, 'Yearly'),
          ],
          onPick: (v) {
            draft.cadence = v;
            onChanged();
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
                    value: draft.anchorDate,
                    onTap: () => _pickDate(context, anchor: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Amount'),
                  MoneyBox(
                    initial: draft.amountText,
                    currency: draft.currency,
                    onChanged: (v) {
                      draft.amountText = v;
                      onChanged();
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
          value: draft.startedDate ?? '',
          onTap: () => _pickDate(context, anchor: false),
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
                    'Records who the money goes to, not what it costs',
                    style: TextStyle(
                        fontFamily: fontBody, fontSize: 12.5, color: c.muted),
                  ),
                ],
              ),
            ),
            // The theme's own switch, unstyled here. Settings has three of these
            // and a fourth that looked almost the same would be a fourth thing
            // to keep in step.
            Switch(
              value: draft.shared,
              onChanged: (v) {
                // On and off both. A switch that only buzzes one way feels
                // broken in the direction it stays silent.
                feedback(v ? Cue.expand : Cue.collapse);
                draft.shared = v;
                onChanged();
              },
            ),
          ],
        ),
        if (draft.shared) ...[
          const SizedBox(height: 12),
          const FieldLabel('Who it goes to'),
          TextBox(
            initial: draft.payTo,
            hint: 'Mum, my flatmate, the group',
            onChanged: (v) {
              draft.payTo = v;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          const FieldLabel('How they get it'),
          TextBox(
            initial: draft.payHow,
            hint: 'Standing order on the 1st',
            onChanged: (v) {
              draft.payHow = v;
              onChanged();
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
