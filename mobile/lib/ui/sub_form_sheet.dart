/// Adding and editing a subscription, as the sheet the PWA uses.
///
/// The rules live in `logic/subscription_form.dart`, the catalogue in
/// `logic/services.dart`, the three cards in `sub_cards.dart` and the write
/// itself in `save_sub.dart`. This is the order they go in and the footer.
///
/// ── Why so little is left here ─────────────────────────────────────────────
/// The cards used to be built in this file and there was only one screen that
/// needed them. Then the step-by-step sheet arrived wanting the same grid, the
/// same cadence row and the same reminder choices, and two copies of a control
/// drift the first time either is touched.
///
/// So this form shows all three cards at once, which is the right shape for
/// EDITING — somebody arriving to change one specific thing needs to find it —
/// and `sub_wizard_sheet.dart` shows the same three one at a time, which is the
/// right shape for the first thirty seconds.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/auto_advance.dart';
import '../logic/subscription_form.dart';
import '../models/subscription.dart';
import '../notify/sync.dart';
import 'auto_advance.dart';
import 'confirm_delete.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'save_sub.dart';
import 'sub_cards.dart';
import 'theme.dart';

/// Opens the form. Resolves true when something was saved.
Future<bool?> showSubForm(
  BuildContext context, {
  required Repository repo,
  Subscription? existing,

  /*
    What was already typed on the way here.

    The step-by-step sheet offers a way out into this form, and an escape hatch
    that throws away the name somebody has just typed is one they use once.
    Ignored when `existing` is set: an edit already has a name.
  */
  String startingName = '',
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
    builder: (context) => SheetEntrance(
      child: _SubFormSheet(
        repo: repo,
        existing: existing,
        startingName: startingName,
      ),
    ),
  );
}

class _SubFormSheet extends StatefulWidget {
  const _SubFormSheet({
    required this.repo,
    this.existing,
    this.startingName = '',
  });

  final Repository repo;
  final Subscription? existing;

  /// Typed on the step-by-step sheet before somebody asked for the long way.
  final String startingName;

  @override
  State<_SubFormSheet> createState() => _SubFormSheetState();
}

class _SubFormSheetState extends State<_SubFormSheet> {
  late final SubscriptionDraft _draft = widget.existing == null
      ? SubscriptionDraft(name: widget.startingName.trim())
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

    final outcome = await saveSubDraft(
      context,
      repo: widget.repo,
      draft: _draft,
      isNew: _isNew,
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

  Future<void> _delete() async {
    final sure = await confirmDelete(context, name: _draft.name);
    if (!sure || widget.existing == null) return;

    await widget.repo.softDeleteSubscription(widget.existing!.id);
    unawaited(syncReminders(widget.repo));
    if (mounted) Navigator.of(context).pop(true);
  }

  /* -------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    // Just under the tab heading — see `sheetTop`. Five cards of answers do not
    // fit in two thirds, and what you saw first was a third of a form.
    final top = sheetTop(context);

    /*
      Service is one answer, so it advances the moment there is a name — from
      the grid or typed. The cadence is never unset, so it is not listed;
      "Started" is, and so are the two split fields when the toggle is on,
      because a card with a switch turned on is not finished until the fields it
      revealed are.
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
                SubServiceCard(
                  draft: _draft,
                  name: _name,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: _billingCardKey,
                  child: SubBillingCard(
                    draft: _draft,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: _reminderCardKey,
                  child: SubReminderCard(
                    draft: _draft,
                    onChanged: () => setState(() {}),
                  ),
                ),
                if (!_isNew) ...[
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon:
                          Icon(Icons.delete_outline, size: 18, color: c.ember),
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
          SheetFooter(
            label: _isNew ? 'Save subscription' : 'Save changes',
            // Said before the button is pressed rather than after. The one
            // refusal this form makes, in the one place somebody is already
            // looking.
            problem: _problem ?? whyNotSaveableSubscription(_draft),
            onSave: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
