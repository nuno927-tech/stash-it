/// Adding and editing a subscription.
///
/// The rules live in `logic/subscription_form.dart`. This is the boxes.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/format.dart';
import '../logic/notify_offer.dart';
import '../logic/subscription_form.dart';
import '../logic/subscriptions.dart';
import '../logic/timeline.dart';
import '../models/subscription.dart';
import '../notify/sync.dart';
import 'feedback.dart';
import 'form_parts.dart';

class SubFormScreen extends StatefulWidget {
  const SubFormScreen({required this.repo, this.existing, super.key});

  final Repository repo;
  final Subscription? existing;

  @override
  State<SubFormScreen> createState() => _SubFormScreenState();
}

class _SubFormScreenState extends State<SubFormScreen> {
  late final SubscriptionDraft _draft = widget.existing == null
      ? SubscriptionDraft()
      : draftOfSubscription(widget.existing!);

  String? _problem;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  Future<void> _save() async {
    final problem = whyNotSaveableSubscription(_draft);
    if (problem != null) {
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

      // The save cue: two rising notes. Items get it from the paper sheet that
      // follows them; these two had nothing, so a save here was silent while
      // the same action one tab over was not.
      feedback(Cue.save);

      /*
        Only when a reminder was actually asked for.

        Every other save in the app offers notifications on the strength of
        having a date. A subscription always has one and almost never wants
        waking for — see the note on `remindDays` in logic/reminders.dart — so
        offering here on a date alone would be offering an empty schedule to
        somebody who just declined the reminder two fields up.
      */
      if (_draft.remindDays != null && _draft.remindDays != 0) {
        if (datedSave(expiresOn: _draft.anchorDate)) armNotifyOffer();
      }

      if (mounted) Navigator.of(context).pop(true);
    } on CapReached catch (e) {
      setState(() => _problem = e.message);
    } catch (e) {
      setState(() => _problem = 'That did not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// What this will cost per month, shown while it is being typed.
  ///
  /// A weekly plan is 52.18 weeks a year, not four weeks a month — four
  /// undercounts by about 8%, which is the kind of error that makes a total
  /// look believable and wrong. Showing the normalised figure here is how
  /// somebody notices that £5 a week is not £20 a month.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthly = _monthly;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add a subscription' : _draft.name),
        actions: [
          TextButton(
              onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_problem != null) ProblemCard(_problem!),
          LabelledField(
            label: 'What is it',
            hint: 'Netflix, the gym, car insurance',
            initial: _draft.name,
            autofocus: _isNew,
            onChanged: (v) => _draft.name = v,
          ),
          LabelledField(
            label: 'How much',
            initial: _draft.amountText,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            format: (v) => formatMoneyInput(v, _draft.currency),
            onChanged: (v) => setState(() => _draft.amountText = v),
          ),
          DropdownButtonFormField<Cadence>(
            initialValue: _draft.cadence,
            decoration: const InputDecoration(
              labelText: 'How often',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final c in Cadence.values)
                DropdownMenuItem(value: c, child: Text(cadenceLabel[c]!)),
            ],
            onChanged: (v) =>
                setState(() => _draft.cadence = v ?? Cadence.monthly),
          ),
          if (monthly != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(monthly, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 8),

          /*
            One real renewal date. Everything else — the next renewal, the
            calendar, the six-month chart, the reminder — is `nextRenewal`
            walking forward from this.

            "Next renews" rather than "started on", because the date somebody
            can actually look up is the one on next month's statement.
          */
          DateField(
            label: 'Next renews',
            value: _draft.anchorDate,
            onChanged: (v) => setState(() => _draft.anchorDate = v),
          ),
          if (_draft.anchorDate.isNotEmpty) _renewalPreview(theme),
          const SizedBox(height: 12),

          /*
            Off by default, and that is the whole design.

            A renewal is not an event most people need waking for: the money
            leaves whether they know or not, and nine monthly services would
            mean nine notifications a month for nothing. This field is somebody
            saying that this one is different.
          */
          DropdownButtonFormField<int?>(
            initialValue: _draft.remindDays,
            decoration: const InputDecoration(
              labelText: 'Remind me before it renews',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Do not')),
              DropdownMenuItem(value: 1, child: Text('The day before')),
              DropdownMenuItem(value: 3, child: Text('3 days before')),
              DropdownMenuItem(value: 7, child: Text('A week before')),
            ],
            onChanged: (v) => setState(() => _draft.remindDays = v),
          ),
          const SizedBox(height: 14),
          LabelledField(
            label: 'Notes',
            initial: _draft.notes,
            lines: 3,
            onChanged: (v) => _draft.notes = v,
          ),
          const SizedBox(height: 20),
          if (!_isNew)
            DeleteButton(
              name: _draft.name,
              onConfirmed: () async {
                await widget.repo.softDeleteSubscription(widget.existing!.id);
                unawaited(syncReminders(widget.repo));
                if (context.mounted) Navigator.of(context).pop(true);
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// The next three renewals, so a clamped month is visible before it surprises
  /// anybody.
  ///
  /// An anchor on the 31st visits the 28th in February and comes back to the
  /// 31st in March. That is what the card issuer does and it looks like a bug
  /// until you see it written out.
  Widget _renewalPreview(ThemeData theme) {
    final sub = toSubscription(
      SubscriptionDraft(
        name: _draft.name.isEmpty ? 'x' : _draft.name,
        anchorDate: _draft.anchorDate,
        cadence: _draft.cadence,
        amountText: _draft.amountText,
      ),
      propertyId: 'x',
    );

    final from = DateTime.now();
    final dates = <DateTime>[];
    var cursor = from;
    for (var i = 0; i < 3; i++) {
      final at = nextRenewal(sub, cursor);
      if (at == null) break;
      dates.add(at);
      cursor = at.add(const Duration(days: 1));
    }

    if (dates.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Then ${dates.map(dayMonth).join(', ')}',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
