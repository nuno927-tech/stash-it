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
        SheetEntrance(child: _SubViewSheet(repo: repo, sub: sub)),
  );
}

class _SubViewSheet extends StatefulWidget {
  const _SubViewSheet({required this.repo, required this.sub});

  final Repository repo;
  final Subscription sub;

  @override
  State<_SubViewSheet> createState() => _SubViewSheetState();
}

class _SubViewSheetState extends State<_SubViewSheet> {
  late Subscription _sub = widget.sub;

  Future<void> _edit() async {
    await showSubForm(context, repo: widget.repo, existing: _sub);
    if (!mounted) return;

    final fresh = await widget.repo.subscription(_sub.id);
    if (!mounted) return;
    if (fresh == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _sub = fresh);
  }

  Future<void> _delete() async {
    final sure = await confirmDelete(context, name: _sub.name);
    if (!sure || !mounted) return;
    await widget.repo.softDeleteSubscription(_sub.id);
    if (mounted) Navigator.of(context).pop();
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
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
              children: [
                // The service's own mark, at size — the fastest way to know
                // which of nine similarly-priced things this is.
                ViewFace(
                  child: ServiceMark(
                    serviceId: _sub.serviceId,
                    name: _sub.name,
                    size: 76,
                  ),
                ),

                /*
                  ── The headline number is money, not days ──────────────────

                  The other two sheets count down to something running out.
                  This one does not run out — it renews — so a countdown would
                  be answering a question nobody asked. What somebody opens a
                  subscription to find is what it costs, so that is the number,
                  and the next charge date sits in the details with the rest.
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
      ),
    );
  }

  Widget _price(StashColors c, StashStatus status) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
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
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w200,
                  fontSize: 34,
                  height: 1,
                  letterSpacing: -1,
                  color: c.text,
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
