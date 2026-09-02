/// One subscription, as a product page.
///
/// Same reasoning as the other two: tapping a row went straight into the edit
/// form, so the answer to "what am I paying for this" arrived as a text field
/// with a keyboard behind it. This reads; Edit is one button away.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/card.dart';
import '../logic/dates.dart';
import '../logic/subscriptions.dart';
import '../logic/timeline.dart';
import '../models/subscription.dart';
import 'confirm_delete.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'service_mark.dart';
import 'share_card_sheet.dart';
import 'status_pill.dart';
import 'sub_form_sheet.dart';
import 'theme.dart';
import 'view_sheet_parts.dart';

/// Opens the sheet. Resolves once it closes; the caller refreshes either way.
Future<void> showSubView(
  BuildContext context, {
  required Repository repo,
  required Subscription sub,
}) async {
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
    builder: (context) =>
        SheetEntrance(child: SubView(repo: repo, sub: sub)),
  );
}

/// One sub, as a sheet on a phone and as the right-hand pane on a
/// tablet.
///
/// Public and frame-agnostic for the same reason as `ItemView` — the longer
/// note is there. One widget, two frames; a tablet-only copy of a record screen
/// is a copy that drifts.
class SubView extends StatefulWidget {
  const SubView({
    required this.repo,
    required this.sub,
    this.pane = false,
    this.onGone,
    super.key,
  });

  final Repository repo;
  final Subscription sub;

  /// True when this is the right-hand pane rather than a sheet.
  final bool pane;

  /// Told when the record stops existing. A pane cannot pop itself — that
  /// would take the whole tab off the navigator, list and all.
  final VoidCallback? onGone;

  @override
  State<SubView> createState() => _SubViewState();
}

class _SubViewState extends State<SubView> {
  late Subscription _sub = widget.sub;

  /// Gone. See `onGone`.
  void _close() {
    if (widget.onGone != null) {
      widget.onGone!();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _edit() async {
    await showSubForm(context, repo: widget.repo, existing: _sub);
    if (!mounted) return;

    final fresh = await widget.repo.subscription(_sub.id);
    if (!mounted) return;
    if (fresh == null) {
      _close();
      return;
    }
    setState(() => _sub = fresh);
  }

  Future<void> _delete() async {
    final sure = await confirmDelete(context, name: _sub.name);
    if (!sure || !mounted) return;
    await widget.repo.softDeleteSubscription(_sub.id);
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final at = nextRenewal(_sub);
    final due = reminderDue(_sub);
    final top = sheetTop(context);

    /*
      A subscription has two states worth colouring, and "overdue" is not one
      of them. The money leaves whether anybody was told or not — which is the
      whole reason the reminder is off by default. See the note on `remindDays`.
    */
    final status = due ? StashStatus.soon : StashStatus.settled;

    final cells = <(String, String)>[
      ('Every', cadenceLabel[_sub.cadence] ?? ''),
      if (at != null) ('Next charge', dayMonthMaybeYear(at)),
      ('A month', _money(monthlyCents(_sub))),
      ('A year', _money(monthlyCents(_sub) * 12)),
      if ((_sub.startedDate ?? '').isNotEmpty)
        ('Started', _fromIso(_sub.startedDate!)),
      if ((_sub.payHow ?? '').isNotEmpty) ('Paid by', _sub.payHow!),
      if ((_sub.payTo ?? '').isNotEmpty) ('Paid to', _sub.payTo!),
      if (_sub.shared == true) ('Shared', 'Yes'),
    ];

    /*
      The same contents in both frames — a sheet you can fling away, or a pane
      filling the space it was given. See `ItemView` for the longer note.
    */
    Widget contents(ScrollController? scroll) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                children: [
                  // The service's own mark, at size — the fastest way to know
                  // which of nine similarly-priced things this is.
                  // Unframed: a logo already sits on a surface without help.
                  ViewFace.bare(
                    child: ServiceMark(
                      serviceId: _sub.serviceId,
                      name: _sub.name,
                      size: 72,
                    ),
                  ),

                  /*
                    ── The headline number is money, not days ──────────────────

                    The other two sheets count down to something running out.
                    This one does not run out — it renews — so a countdown would
                    be answering a question nobody asked. What somebody opens a
                    subscription to find is what it costs, so that is the
                    number, and the next charge date sits in the details with
                    the rest.
                  */
                  _price(c, status),

                  ViewCells(label: 'Details', cells: cells),
                  if ((_sub.notes ?? '').trim().isNotEmpty)
                    ViewNote(text: _sub.notes!.trim()),
                ],
              ),
            ),
            ViewFooter(
              onEdit: _edit,
              onDelete: _delete,
              deleteLabel: 'Delete this subscription',
              onSend: () => shareCardSheet(
                context,
                repo: widget.repo,
                pick: CardPick(subscriptions: {_sub.id}),
              ),
            ),
          ],
        );

    if (widget.pane) return contents(null);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: top,
      minChildSize: 0.4,
      maxChildSize: top,
      builder: (context, scroll) => contents(scroll),
    );
  }

  Widget _price(StashColors c, StashStatus status) {
    return Padding(
      // Tight, to match the bare mark above it — see `ViewHeadline.tight`.
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sub.name,
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w800,
              fontSize: 25,
              height: 1.12,
              letterSpacing: -0.6,
              color: c.text,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(
                status: status,
                label: status == StashStatus.soon ? 'Renewing' : 'Active',
              ),
              const Spacer(),
              Text(
                _money(_sub.amountCents),
                // Same weight and colour rule as the countdown on the other
                // two sheets: the figure is the answer, not decoration.
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  height: 1,
                  letterSpacing: -1.2,
                  color: status == StashStatus.soon ? c.honey : c.text,
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  cadencePer[_sub.cadence] ?? '',
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
    );
  }

  String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  String _fromIso(String iso) {
    final d = parseDate(iso);
    return d == null ? iso : dayMonthMaybeYear(d);
  }
}
