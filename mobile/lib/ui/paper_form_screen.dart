/// Adding and editing a document.
///
/// The rules live in `logic/paper_form.dart`. This is the boxes.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/notify_offer.dart';
import '../logic/paper_form.dart';
import '../logic/papers.dart';
import '../models/paper.dart';
import '../notify/sync.dart';
import 'feedback.dart';
import 'form_parts.dart';

class PaperFormScreen extends StatefulWidget {
  const PaperFormScreen({required this.repo, this.existing, super.key});

  final Repository repo;
  final Paper? existing;

  @override
  State<PaperFormScreen> createState() => _PaperFormScreenState();
}

class _PaperFormScreenState extends State<PaperFormScreen> {
  late final PaperDraft _draft =
      widget.existing == null ? PaperDraft() : draftOfPaper(widget.existing!);

  String? _problem;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  Future<void> _save() async {
    final problem = whyNotSaveablePaper(_draft);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    try {
      final paper = toPaper(_draft, propertyId: widget.repo.propertyId);
      if (_isNew) {
        await widget.repo.createPaper(paper);
      } else {
        await widget.repo.savePaper(paper);
      }

      unawaited(syncReminders(widget.repo));

      // The save cue: two rising notes. Items get it from the paper sheet that
      // follows them; these two had nothing, so a save here was silent while
      // the same action one tab over was not.
      feedback(Cue.save);

      // A document cannot be saved without an expiry, so this is always true —
      // written out anyway, because the day someone relaxes that rule is the
      // day this needs to start being a real check.
      if (datedSave(expiresOn: _draft.expiresOn)) armNotifyOffer();

      if (mounted) Navigator.of(context).pop(true);
    } on CapReached catch (e) {
      setState(() => _problem = e.message);
    } catch (e) {
      setState(() => _problem = 'That did not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add a document' : _draft.label),
        actions: [
          TextButton(
              onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_problem != null) ProblemCard(_problem!),

          /*
            The kind first, because picking one fills the name in — and
            because it sets the runway, which is the number this whole tab is
            built around.
          */
          Text('What is it', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in PaperKind.values)
                ChoiceChip(
                  label: Text(kindLabel[kind]!),
                  selected: _draft.kind == kind,
                  onSelected: (_) => setState(() => _draft.pickKind(kind)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          LabelledField(
            label: 'Call it',
            initial: _draft.label,
            // Rebuilt when the kind changes, since picking one renames it.
            key: ValueKey('label-${_draft.label}'),
            onChanged: (v) => _draft.label = v,
          ),

          /*
            "Whose" is the field people actually search a household by. Four
            passports are four rows with the same label, and the only thing
            telling them apart is this.
          */
          LabelledField(
            label: 'Whose',
            hint: 'The name on it',
            initial: _draft.holder,
            onChanged: (v) => _draft.holder = v,
          ),
          DateField(
            label: 'Expires',
            value: _draft.expiresOn,
            // A document expiring in the past is a real thing to record — it
            // is exactly what the red rows are — so there is no lower bound.
            onChanged: (v) => setState(() => _draft.expiresOn = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _draft.leadDays,
            decoration: const InputDecoration(
              labelText: 'Warn me',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: null, child: Text('Default for this kind')),
              DropdownMenuItem(value: 0, child: Text('Day of')),
              DropdownMenuItem(value: 30, child: Text('1 month before')),
              DropdownMenuItem(value: 90, child: Text('3 months before')),
              DropdownMenuItem(value: 182, child: Text('6 months before')),
              DropdownMenuItem(value: 240, child: Text('8 months before')),
              DropdownMenuItem(value: 365, child: Text('1 year before')),
            ],
            onChanged: (v) => setState(() => _draft.leadDays = v),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 14),
            child:
                Text(leadExplanation(_draft), style: theme.textTheme.bodySmall),
          ),
          LabelledField(
            label: 'Who issued it',
            initial: _draft.authority,
            onChanged: (v) => _draft.authority = v,
          ),
          LabelledField(
            label: 'Where it is kept',
            hint: 'Desk drawer, safe, wallet',
            initial: _draft.storedAt,
            onChanged: (v) => _draft.storedAt = v,
          ),
          LabelledField(
            label: 'Notes',
            initial: _draft.notes,
            lines: 3,
            onChanged: (v) => _draft.notes = v,
          ),

          /*
            ── What is not on this form, and stays off it ──────────────────

            Scans yes, document numbers no.

            A backup can be sealed with a passphrase now, and the app insists
            on one before the first scan — which is what made scans safe to
            offer at all. A number is different: it is never needed to remind
            you of a date, it is a better identity-theft package than the scan
            is, and anything the app never holds cannot leak.
          */
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Dates, details and a scan if you want one — but no document '
                'numbers. Scans need a backup passphrase, which the app will '
                'ask for.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!_isNew)
            DeleteButton(
              name: _draft.label,
              onConfirmed: () async {
                await widget.repo.softDeletePaper(widget.existing!.id);
                // A deleted document must stop reminding people about itself.
                unawaited(syncReminders(widget.repo));
                if (context.mounted) Navigator.of(context).pop(true);
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
