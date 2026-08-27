/// Adding and editing a subscription, as the sheet the PWA uses.
///
/// The rules live in `logic/subscription_form.dart` and the catalogue in
/// `logic/services.dart`. This is the boxes.
///
/// ── The grid is the field ─────────────────────────────────────────────────
/// The old form opened on an empty "Call it" box, which asked somebody to type
/// "Netflix" — a word the app already knows, spelled a way it could then never
/// match against its own logo list. The grid answers the name, the logo and
/// the service id in one tap, and the text field underneath is for the gym.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../billing/current.dart';
import '../db/repository.dart';
import '../logic/format.dart';
import '../logic/notify_offer.dart';
import '../logic/services.dart';
import '../logic/subscription_form.dart';
import '../logic/subscriptions.dart';
import '../models/subscription.dart';
import '../notify/sync.dart';
import '../logic/auto_advance.dart';
import 'auto_advance.dart';
import 'confirm_delete.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'service_mark.dart';
import 'theme.dart';
import 'unlock_sheet.dart';

/// Opens the form. Resolves true when something was saved.
Future<bool?> showSubForm(
  BuildContext context, {
  required Repository repo,
  Subscription? existing,
}) {
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
    builder: (context) => _SubFormSheet(repo: repo, existing: existing),
  );
}

class _SubFormSheet extends StatefulWidget {
  const _SubFormSheet({required this.repo, this.existing});

  final Repository repo;
  final Subscription? existing;

  @override
  State<_SubFormSheet> createState() => _SubFormSheetState();
}

class _SubFormSheetState extends State<_SubFormSheet> {
  late final SubscriptionDraft _draft = widget.existing == null
      ? SubscriptionDraft()
      : draftOfSubscription(widget.existing!);

  late final TextEditingController _name =
      TextEditingController(text: _draft.name);

  String? _problem;
  bool _saving = false;

  final GlobalKey _billingCardKey = GlobalKey();
  final GlobalKey _reminderCardKey = GlobalKey();

  late final AutoAdvance _toBilling = AutoAdvance(_billingCardKey);
  late final AutoAdvance _toReminder = AutoAdvance(_reminderCardKey);

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _name.dispose();
    _toBilling.dispose();
    _toReminder.dispose();
    super.dispose();
  }

  /* ------------------------------------------------------------- saving */

  Future<void> _save() async {
    final problem = whyNotSaveableSubscription(_draft);
    if (problem != null) {
      feedback(Cue.error);
      setState(() => _problem = problem);
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    try {
      final sub = toSubscription(_draft, propertyId: widget.repo.propertyId);

      if (_isNew) {
        await widget.repo.createSubscription(sub);
      } else {
        await widget.repo.saveSubscription(sub);
      }

      unawaited(syncReminders(widget.repo));
      // Not `save` — that is what a settings toggle gets. This is the app
      // doing the one thing it is for. See the note on `Cue.stashed`.
      feedback(Cue.stashed);

      /*
        The notification offer, only when a reminder was actually asked for.

        Every other save in the app offers on the strength of having a date. A
        subscription always has one and almost never wants waking for — see the
        note on `remindDays` — so offering on a date alone would be offering an
        empty schedule to somebody who just chose None two fields up.
      */
      if (_draft.remindDays != null && _draft.remindDays != 0) {
        if (datedSave(expiresOn: _draft.anchorDate)) armNotifyOffer();
      }

      if (mounted) Navigator.of(context).pop(true);
    } on CapReached catch (e) {
      /*
        The wall, and the way through it, in the same moment.

        Showing the sentence alone leaves somebody holding a filled-in form
        with nowhere to go — and the form is still filled in behind this
        sheet, so unlocking and pressing Save again works with nothing
        retyped. That is the whole reason the offer opens here rather than
        sending them to Settings.
      */
      setState(() => _problem = e.message);
      if (!mounted) return;

      final unlocked = await showUnlock(
        context,
        repo: widget.repo,
        billing: appBilling,
        count: e.count,
      );

      // Straight back into the save they were already trying to make.
      if (unlocked && mounted) {
        setState(() => _problem = null);
        await _save();
      }
    } catch (e) {
      setState(() => _problem = 'That did not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final sure = await confirmDelete(context, name: _draft.name);
    if (!sure || widget.existing == null) return;

    await widget.repo.softDeleteSubscription(widget.existing!.id);
    unawaited(syncReminders(widget.repo));
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Picking one off the grid answers three questions at once.
  void _choose(ServiceDef service) {
    feedback(Cue.tap);
    setState(() {
      _draft.serviceId = service.id;
      _draft.name = service.name;
      _name.text = service.name;
    });
  }

  Future<void> _pickDate({required bool anchor}) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(anchor ? _draft.anchorDate : (_draft.startedDate ?? ''));

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

    setState(() {
      if (anchor) {
        _draft.anchorDate = iso;
      } else {
        _draft.startedDate = iso;
      }
    });
  }

  /// What this will cost per month, while it is being typed.
  ///
  /// A weekly plan is 52.18 weeks a year, not four weeks a month — four
  /// undercounts by about 8%, which is the kind of error that makes a total
  /// look believable and wrong. This is how somebody notices that £5 a week is
  /// not £20 a month.
  String? get _monthly {
    final cents = parseMoneyToCents(_draft.amountText);
    if (cents == null || cents == 0) return null;
    if (_draft.cadence == Cadence.monthly) return null;

    final sub = toSubscription(
      SubscriptionDraft(
        name: 'x',
        anchorDate: '2026-01-01',
        cadence: _draft.cadence,
        amountText: _draft.amountText,
      ),
      propertyId: 'x',
    );

    final per = (monthlyCents(sub) / 100).toStringAsFixed(2);
    return 'That is ${currencySymbol(_draft.currency)}$per a month.';
  }

  /* -------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    // Just under the tab heading — see `sheetTop`. Five cards of answers do
    // not fit in two thirds, and what you saw first was a third of a form.
    final top = sheetTop(context);

    /*
      Service is one answer, so it advances the moment there is a name — from
      the grid or typed. The cadence is never unset, so it is not listed;
      "Started" is, and so are the two split fields when the toggle is on,
      because a card with a switch turned on is not finished until the fields
      it revealed are.
    */
    _toBilling.update(context, complete: cardFilled([_draft.name]));
    _toReminder.update(
      context,
      complete: cardFilled([
        _draft.anchorDate,
        _draft.amountText,
        _draft.startedDate,
        if (_draft.shared) ...[_draft.payTo, _draft.payHow],
      ]),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: top,
      minChildSize: 0.4,
      maxChildSize: top,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
              children: [
                _serviceCard(c),
                const SizedBox(height: 14),
                KeyedSubtree(key: _billingCardKey, child: _billingCard(c)),
                const SizedBox(height: 14),
                KeyedSubtree(key: _reminderCardKey, child: _reminderCard(c)),

                if (!_isNew) ...[
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: Icon(Icons.delete_outline, size: 18, color: c.ember),
                      label: Text(
                        'Delete this subscription',
                        style: TextStyle(fontFamily: fontBody, color: c.ember),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _footer(c),
        ],
      ),
    );
  }

  /* ------------------------------------------------------------ service */

  Widget _serviceCard(StashColors c) {
    /*
      The grid narrows as you type.

      Not a dropdown and not an autocomplete list: the whole point of a logo is
      that it is recognised faster than it is read, so the answer to "which
      one" is a picture rather than a row of text. Typing filters it, and
      typing something not on the list is itself a valid answer — the field
      keeps whatever was typed and the mark falls back to initials.
    */
    final matches = searchServices(_draft.name);

    return SheetCard(
      title: 'Service',
      children: [
        /*
          ── Once one is chosen, the grid goes ────────────────────────────────

          The grid filters on whatever is in the name box, and choosing a
          service puts its name in that box — so after a tap the fifty-seven
          tiles collapsed to exactly one, sitting small and left-aligned where
          the grid had been, with the large centred mark below it. Two icons
          for one answer, and the little one looked like a leftover.

          It is a leftover. A grid is for choosing between things; once the
          choice is made there is nothing left to choose between, so what
          belongs here is the answer and a way to change it.
        */
        if (serviceFor(_draft.serviceId) case final chosen?) ...[
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
                    setState(() {
                      // Both, because the grid filters on the name. Clearing
                      // only the id would bring back a grid of one.
                      _draft.serviceId = null;
                      _draft.name = '';
                      _name.clear();
                    });
                  },
                  child: Text(
                    'Choose a different one',
                    style: TextStyle(fontFamily: fontBody, fontSize: 13, color: c.muted),
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
              style: TextStyle(fontFamily: fontBody, fontSize: 13, height: 1.45, color: c.muted),
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
          `border` does not switch either off — see the note there. That is
          what was drawing a second box inside this one.
        */
        WhiteField(
          child: TextField(
            controller: _name,
            style: TextStyle(fontFamily: fontBody, fontSize: 17, color: c.text),
            cursorColor: c.gold,
            decoration: bareInput(
              hint: 'Netflix, Spotify, the gym...',
              hintStyle: TextStyle(fontFamily: fontBody, fontSize: 17, color: c.muted),
            ),
            onChanged: (v) => setState(() {
              _draft.name = v;

              // Typing over a chosen service unpicks it. Otherwise a
              // subscription called "Netflix account" keeps Netflix's id, and
              // the id is what the rest of the app trusts.
              final picked = serviceFor(_draft.serviceId);
              if (picked != null && picked.name != v) _draft.serviceId = null;
            }),
          ),
        ),
      ],
    );
  }

  /* ------------------------------------------------------------ billing */

  Widget _billingCard(StashColors c) {
    final monthly = _monthly;

    return SheetCard(
      title: 'Billing',
      children: [
        const FieldLabel('How often'),
        SegRow<Cadence>(
          value: _draft.cadence,
          options: const [
            (Cadence.weekly, 'Weekly'),
            (Cadence.monthly, 'Monthly'),
            (Cadence.quarterly, 'Quarterly'),
            (Cadence.yearly, 'Yearly'),
          ],
          onPick: (v) => setState(() => _draft.cadence = v),
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
                    value: _draft.anchorDate,
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
                  const FieldLabel('Amount'),
                  MoneyBox(
                    initial: _draft.amountText,
                    currency: _draft.currency,
                    onChanged: (v) => setState(() => _draft.amountText = v),
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
            style: TextStyle(fontFamily: fontBody, fontSize: 12.5, color: c.gold),
          ),
        ],

        const SizedBox(height: 14),
        const FieldLabel('Started'),
        DateBox(
          value: _draft.startedDate ?? '',
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
                    'Records who the money goes to, not what it costs',
                    style: TextStyle(fontFamily: fontBody, fontSize: 12.5, color: c.muted),
                  ),
                ],
              ),
            ),
            // The theme's own switch, unstyled here. Settings has three of
            // these and a fourth that looked almost the same would be a fourth
            // thing to keep in step.
            Switch(
              value: _draft.shared,
              onChanged: (v) {
                // On and off both. A switch that only buzzes one way feels
                // broken in the direction it stays silent.
                feedback(v ? Cue.expand : Cue.collapse);
                setState(() => _draft.shared = v);
              },
            ),
          ],
        ),

        if (_draft.shared) ...[
          const SizedBox(height: 12),
          const FieldLabel('Who it goes to'),
          TextBox(
            initial: _draft.payTo,
            hint: 'Mum, my flatmate, the group',
            onChanged: (v) => _draft.payTo = v,
          ),
          const SizedBox(height: 12),
          const FieldLabel('How they get it'),
          TextBox(
            initial: _draft.payHow,
            hint: 'Standing order on the 1st',
            onChanged: (v) => _draft.payHow = v,
          ),
        ],
      ],
    );
  }

  /* ----------------------------------------------------------- reminder */

  Widget _reminderCard(StashColors c) {
    /*
      None is the default, and that is deliberate.

      A renewal is not an event most people need waking for: the money leaves
      whether they know or not, and nine monthly services would mean nine
      notifications a month for nothing. Choosing anything else is somebody
      saying that this one is different.
    */
    final days = _draft.remindDays ?? 0;

    return SheetCard(
      title: 'Reminder',
      children: [
        SegRow<int>(
          value: days,
          options: const [
            (0, 'None'),
            (1, '1 day'),
            (3, '3 days'),
            (7, '7 days'),
          ],
          onPick: (v) => setState(() => _draft.remindDays = v == 0 ? null : v),
        ),
        const SizedBox(height: 12),
        Text(
          switch (days) {
            0 => 'No reminder. You can turn one on later.',
            1 => 'A notification the day before it renews.',
            final int d => 'A notification $d days before it renews.',
          },
          style: TextStyle(fontFamily: fontBody, fontSize: 13, height: 1.45, color: c.muted),
        ),
        const SizedBox(height: 14),

        const FieldLabel('Notes'),
        TextBox(
          initial: _draft.notes,
          hint: 'Optional',
          lines: 4,
          onChanged: (v) => _draft.notes = v,
        ),
      ],
    );
  }

  /* ------------------------------------------------------------- footer */

  Widget _footer(StashColors c) => SheetFooter(
        label: _isNew ? 'Save subscription' : 'Save changes',
        // Said before the button is pressed rather than after. The one refusal
        // this form makes, in the one place somebody is already looking.
        problem: _problem ?? whyNotSaveableSubscription(_draft),
        onSave: _saving ? null : _save,
      );

}

/* ------------------------------------------------------------- the pieces */

/// One service on the grid.
///
/// No selected state, deliberately: the grid is only on screen while nothing
/// is chosen. A lit tile would be a third place the same answer is drawn — see
/// the note where the grid is built.
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





/// The amount, with the currency symbol inside the box rather than beside it.


