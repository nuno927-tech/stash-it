/// What leaves your account each month.
///
/// ── Why there is a chart and not just a total ─────────────────────────────
/// A monthly total is an average, and an average hides the only thing about
/// subscription spending that ever surprises anybody: it is not level. Three
/// annual plans that happen to renew in the same month make that month cost
/// four times what October does, and no amount of staring at "$94 a month"
/// will tell you that.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../notify/sync.dart';
import '../logic/format.dart';
import '../logic/subscriptions.dart';
import '../models/subscription.dart';
import 'notify_offer_dialog.dart';
import 'confirm_delete.dart';
import 'layout.dart';
import 'two_pane.dart';
import '../logic/card.dart';
import 'feedback.dart';
import 'parts.dart';
import 'share_card_sheet.dart';
import 'renewal_calendar.dart';
import 'scout.dart';
import 'service_mark.dart';
import 'status_pill.dart';
import 'spend_line.dart';
import 'sub_wizard_sheet.dart';
import 'sub_view_sheet.dart';
import 'swipe_to_delete.dart';
import 'theme.dart';
import 'undo_bar.dart';

class SubsTab extends StatefulWidget {
  const SubsTab({required this.repo, super.key});

  final Repository repo;

  @override
  State<SubsTab> createState() => _SubsTabState();
}

class _SubsTabState extends State<SubsTab> {
  /*
    Choosing subscriptions to send. Null means not choosing — same shape and
    same reasoning as the Items tab, which the note there explains.
  */
  Set<String>? _picked;

  void _startPicking(String id) {
    // Not `tap`. A long press that turns the whole list into a set of
    // checkboxes is a mode change, and it was answering with the same tick an
    // ordinary press gets — see `Cue.pick`.
    feedback(Cue.pick);
    setState(() => _picked = {id});
  }

  void _pick(String id) {
    feedback(Cue.tap);
    setState(() {
      final now = {..._picked!};
      now.contains(id) ? now.remove(id) : now.add(id);
      _picked = now;
    });
  }

  void _stopPicking() => setState(() => _picked = null);

  Future<void> _sendPicked() async {
    final chosen = _picked;
    if (chosen == null || chosen.isEmpty) return;

    final sent = await shareCardSheet(
      context,
      repo: widget.repo,
      pick: CardPick(subscriptions: chosen),
    );
    if (!mounted) return;
    if (sent) _stopPicking();
  }

  /// The day picked on the calendar, or null.
  DateTime? _day;

  /*
    ── What the right-hand pane is showing ─────────────────────────────────

    Only ever set on a wide screen — see `splitView`. On a phone, tapping a row
    opens a sheet and this stays null, because there is nowhere to put a second
    thing.

    The record rather than its id, unlike the items tab: that one watches a
    stream and can look the id up in what just arrived, and this one reads a
    future. `SubView` keeps its own copy fresh across an edit, and a delete
    from either side clears this.
  */
  Subscription? _open;

  Future<void> _delete(Subscription sub) async {
    // The pane cannot outlive the record it is about.
    if (_open?.id == sub.id) _open = null;
    await widget.repo.softDeleteSubscription(sub.id);
    unawaited(syncReminders(widget.repo));

    if (!mounted) return;
    setState(() {});
    showUndo(
      context,
      message: '${sub.name} moved to the bin.',
      onUndo: () async {
        await widget.repo.restoreSubscription(sub.id);
        unawaited(syncReminders(widget.repo));
        if (mounted) setState(() {});
      },
    );
  }

  /// No `BuildContext` parameter: `mounted` describes this State, and a
  /// context handed in from elsewhere is not tied to it. The analyzer says so.
  // Same split as Documents: an existing one is looked at, a new one is filled
  // in. See the note there.
  Future<void> open(Subscription? sub) async {
    if (sub == null) {
      await showSubWizard(context, repo: widget.repo);
    } else if (splitView(context)) {
      // Wide enough to show it beside the list. No sheet, nothing covered.
      setState(() => _open = sub);
      return;
    } else {
      await showSubView(context, repo: widget.repo, sub: sub);
    }
    if (!mounted) return;
    setState(() {});
    await maybeOfferNotifications(context, widget.repo);
  }

  @override
  Widget build(BuildContext context) {
    // See the note in papers_tab.dart — the shell owns the add button now.
    final list = _body(context);
    if (!splitView(context)) return list;

    return TwoPane(
      list: list,
      detail: _open == null
          ? null
          // Keyed by id so choosing a different row builds a new view rather
          // than handing the old one a new argument — its record is a `late`
          // field seeded once.
          : SubView(
              key: ValueKey(_open!.id),
              repo: widget.repo,
              sub: _open!,
              pane: true,
              onGone: () => setState(() => _open = null),
            ),
      emptyLine: 'Pick something on the left to see what it costs a month, '
          'a year, and when it next renews.',
    );
  }

  Widget _body(BuildContext context) {
    return FutureBuilder<List<Subscription>>(
      future: widget.repo.activeSubscriptions(),
      builder: (context, snap) {
        final subs = snap.data;
        if (subs == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (subs.isEmpty) {
          // Same sentence, calendar pose. See `firstThing`.
          return Blank(
            firstThing,
            pose: ScoutPose.calendar,
            onStash: () async {
              await showSubWizard(context, repo: widget.repo);
              if (context.mounted) setState(() {});
            },
          );
        }

        final theme = Theme.of(context);
        final c = StashColors.of(context);
        final week = dueWithin(subs, 7);
        final spend = spendByMonth(subs, 6);
        final top = biggest(subs);

        final sorted = [...subs]..sort((a, b) {
            final da = daysUntilRenewal(a) ?? 9999;
            final db = daysUntilRenewal(b) ?? 9999;
            return da != db ? da - db : a.name.compareTo(b.name);
          });

        /*
          ── What the chosen day does ──────────────────────────────────────

          It highlights rather than filters. Filtering would answer "what is
          charged on the 25th" by hiding everything else — and then the list
          under a calendar would change length every time somebody tapped it,
          which is disorienting on the screen whose whole point is seeing the
          month at once. Highlighting answers the same question and keeps the
          rest of the month in view for comparison.
        */
        bool charged(Subscription sub) {
          if (_day == null) return false;
          final from = DateTime(_day!.year, _day!.month, _day!.day);
          return renewalsBetween(sub, from, from.add(const Duration(days: 1)))
              .isNotEmpty;
        }

        final next = sorted.isEmpty ? null : sorted.first;

        /*
          ── The figures hold still while everything else moves ─────────────

          The month's total, the week's, and Scout beside them: those are what
          the tab is FOR, and they were the first child of the list, so they
          left the screen the moment somebody scrolled to the calendar under
          them.

          The calendar, the rows and the year graph scroll below. Same shape
          as Items and Documents.
        */
        return SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_picked != null)
                PickingBar(
                  count: _picked!.length,
                  onCancel: _stopPicking,
                  onSend: _picked!.isEmpty ? null : _sendPicked,
                )
              else
                _Tiles(subs: subs, week: week),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 14, bottom: 120),
                  children: [
                    RenewalCalendar(
                      subs: subs,
                      selected: _day,
                      onSelect: (d) => setState(() => _day = d),
                    ),
                    if (next != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontFamily: fontBody, fontSize: 12.5, color: c.muted),
                            children: [
                              const TextSpan(text: 'Next up: '),
                              TextSpan(
                                text: next.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, color: c.text),
                              ),
                              TextSpan(
                                text:
                                    ' on the ${_ordinal(nextRenewal(next)?.day ?? 1)}, '
                                    '${_money(next.amountCents)}.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SectionTitle('Everything you pay for'),
                    for (final sub in sorted)
                      SubTile(
                        sub: sub,
                        lit: charged(sub),
                        picking: _picked != null,
                        picked: _picked?.contains(sub.id) ?? false,
                        onTap: () => _picked == null ? open(sub) : _pick(sub.id),
                        onLongPress:
                            _picked == null ? () => _startPicking(sub.id) : null,
                        onDelete: () => _delete(sub),
                      ),
                    const SectionTitle('The year ahead'),
                    SpendLine(spend: spend),
                    if (top != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Text(
                          'Biggest is ${top.name}, at '
                          '${_money(monthlyCents(top))} a month.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

/// "25th", "1st", "22nd". Written out because a bare number in the middle of a
/// sentence reads as a quantity — "Claude on the 25, $21.27" is two figures
/// with no way to tell which is money.
String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// The four figures, two by two.
///
/// A grid rather than one row of four: at three across the yearly total wraps
/// on a narrow phone, and a wrapped figure beside three unwrapped ones is a row
/// that looks broken rather than full.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.subs, required this.week});

  final List<Subscription> subs;
  final DueWithin week;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      ── Scout stands to the right of the grid, not above it ─────────────────

      Two by two on the left, him on the right, filling the height of both
      rows. The tiles give up the width rather than him being tucked into a
      corner — the same arrangement as the Items screen, and for the same
      reason: he is holding up the month these figures are about.
    */
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FigureTile(
                        _money(totalMonthlyCents(subs)),
                        'A MONTH',
                        // The figure this tab is about, so it carries the
                        // wash and the gold.
                        lit: true,
                        tone: c.gold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: FigureTile(
                            _money(totalYearlyCents(subs)), 'A YEAR')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FigureTile(
                        '${subs.length}',
                        subs.length == 1 ? 'SERVICE' : 'SERVICES',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FigureTile(
                        _money(week.cents),
                        'DUE THIS WEEK',
                        // Amber only when there is something to be due. A
                        // coloured zero is an alarm about nothing.
                        tone: week.count > 0 ? c.honey : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Scout(
              pose: ScoutPose.calendar,
              height: 132,
              motion: [ScoutMotion.breathe],
            ),
          ),
        ],
      ),
    );
  }
}

/// One subscription, drawn the same way wherever it appears.
///
/// Public for the same reason as `PaperTile` — see the note there.
class SubTile extends StatelessWidget {
  const SubTile({
    super.key,
    required this.sub,
    this.lit = false,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.picking = false,
    this.picked = false,
  });

  final Subscription sub;

  /// Charged on the day picked in the calendar above.
  final bool lit;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  /// Whether the list is choosing rows to send, and whether this one is in.
  final bool picking;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    // Swipe-to-delete is suspended while picking, the same as on the other two.
    if (onDelete == null || picking) return _row(context, c);

    return SwipeToDelete(
      id: 'sub-${sub.id}',
      name: sub.name,
      // A tick when the row is far enough — see `SwipeToDelete`, which
      // exists for that one buzz.
      confirm: () => confirmDelete(context, name: sub.name),
      onDelete: onDelete!,
      child: _row(context, c),
    );
  }

  Widget _row(BuildContext context, StashColors c) {
    final at = nextRenewal(sub);
    final due = reminderDue(sub);
    final monthly = monthlyCents(sub);

    /*
      A subscription has only two states worth colouring: renewing inside its
      reminder window, or not. There is no "overdue" — the money leaves
      whether anybody was told or not, which is the whole reason the reminder
      is off by default. See the note on `remindDays`.
    */
    final status = due ? StashStatus.soon : StashStatus.settled;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        decoration: BoxDecoration(
          // The chosen day's charges are washed gold, not moved to the top.
          // See the note on `charged` — the list keeping its order is what
          // makes the highlight readable as an answer rather than a reshuffle.
          color: lit ? c.washGoldSoft : c.slate800,
          // The calendar's own highlight wins when both apply: the person
          // tapped a day and is looking for that answer, not this one.
          gradient: lit ? null : statusWash(c, status),
          border: Border(bottom: BorderSide(color: c.slate700)),
        ),
        child: Row(
          children: [
            // The tick leads the row while picking — it is what a tap changes.
            if (picking) ...[
              Icon(
                picked ? Icons.check_circle : Icons.circle_outlined,
                size: 21,
                color: picked ? c.gold : c.slate600,
              ),
              const SizedBox(width: 11),
            ],
            /*
              The real mark now.

              This was initials on a colour derived from the name — a stand-in
              written while the service catalogue was still only in the web
              app. The catalogue came across with the subscription form, so the
              list gets the actual logo and falls back to initials only for
              something unlisted, which is what the gym was always going to be.
            */
            ServiceMark(serviceId: sub.serviceId, name: sub.name, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sub.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.15,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (due) ...[
                        const StatusPill(
                            status: StashStatus.soon, label: 'Renewing'),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          at == null
                              ? 'No renewal date'
                              : '${cadenceLabel[sub.cadence]} · ${_ordinal(at.day)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 11.5,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${currencySymbol(sub.currency)}'
                  '${(sub.amountCents / 100).toStringAsFixed(2)}',
                  /*
                    Gold, like the countdown on the dashboard's "Coming up".

                    Three lists, three right-hand columns, and each was picking
                    its own colour: this one was plain text, the timeline was
                    gold, the documents tab was muted grey. They all answer the
                    same shape of question — "here is the number for this row"
                    — so they read as one idea now rather than three.

                    The display face at 18 against the name's 15.5 — see the
                    scale note in theme.dart.
                  */
                  style: figureStyle(c, size: 18).copyWith(color: c.gold),
                ),
                // The monthly equivalent, but only when the cadence is not
                // monthly. Printing "$15.50/mo" under a monthly charge of
                // $15.50 is the same number twice.
                if (sub.cadence != Cadence.monthly)
                  Text(
                    '\$${(monthly / 100).toStringAsFixed(2)}/mo',
                    style: TextStyle(
                        fontFamily: fontBody, fontSize: 11, color: c.muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
