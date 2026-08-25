/// Adding and editing an item.
///
/// The rules live in `logic/item_form.dart` and are tested there. This is the
/// boxes.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/repository.dart';
import '../logic/format.dart';
import '../logic/item_form.dart';
import '../logic/notify_offer.dart';
import '../logic/prefs.dart';
import '../models/types.dart';
import '../notify/sync.dart';

class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({required this.repo, this.existing, super.key});

  final Repository repo;

  /// Null when adding.
  final Item? existing;

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  late final ItemDraft _draft =
      widget.existing == null ? ItemDraft() : draftOf(widget.existing!);

  String? _problem;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  Future<void> _save() async {
    final problem = whyNotSaveable(_draft);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    try {
      final item = toItem(
        _draft,
        propertyId: widget.repo.propertyId,
        createdAt: widget.existing?.createdAt,
      );

      if (_isNew) {
        await widget.repo.createItem(item);
      } else {
        await widget.repo.saveItem(item);
      }

      /*
        A saved item can move a reminder in either direction — adding cover
        creates one, deleting the purchase date removes one — so the schedule is
        rebuilt rather than added to. Not awaited: the form should close on the
        save, not on the notification tray.
      */
      unawaited(syncReminders(widget.repo));

      // And the one moment the offer means anything: something with a date on
      // it has just been saved. See logic/notify_offer.dart on why here and
      // not on the settings screen.
      if (datedSave(
        purchaseDate: _draft.purchaseDate,
        hasCover: _draft.realCoverages.any((c) => c.hasTerm),
      )) {
        armNotifyOffer();
      }

      if (mounted) Navigator.of(context).pop(true);
    } on CapReached catch (e) {
      // The free tier is full. The message already says how to fix it and
      // promises nothing is lost — see `restoreBlockedReason`.
      setState(() => _problem = e.message);
    } catch (e) {
      setState(() => _problem = 'That did not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_draft.purchaseDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1990),
      // A purchase date in the future is not a purchase date — the same rule
      // the receipt reader applies to a date it finds in an email.
      lastDate: now,
    );

    if (picked == null) return;
    setState(() {
      _draft.purchaseDate = '${picked.year.toString().padLeft(4, '0')}'
          '-${picked.month.toString().padLeft(2, '0')}'
          '-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add something' : _draft.name),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_problem != null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _problem!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),

          _Field(
            label: 'Call it',
            hint: 'Kettle, couch, the boiler',
            initial: _draft.name,
            onChanged: (v) => _draft.name = v,
            autofocus: _isNew,
          ),

          _Field(
            label: 'Brand',
            initial: _draft.brand,
            onChanged: (v) => _draft.brand = v,
          ),
          _Field(
            label: 'Model',
            initial: _draft.model,
            onChanged: (v) => _draft.model = v,
          ),

          /*
            Serial is here rather than hidden behind "more", because it is the
            field people come back for. Somebody making a claim is reading it
            off a plate with a torch, and the search matches on any four
            characters of it — see logic/search.dart.
          */
          _Field(
            label: 'Serial number',
            initial: _draft.serial,
            onChanged: (v) => _draft.serial = v,
          ),

          const SizedBox(height: 8),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bought on'),
            subtitle: Text(
              _draft.purchaseDate.isEmpty ? 'Not set' : _draft.purchaseDate,
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),

          _Field(
            label: 'Price',
            initial: _draft.priceText,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            // Formats as you type rather than on blur. Correcting a field
            // afterwards makes people wonder whether they typed it wrong.
            format: (v) => formatMoneyInput(v, _draft.currency),
            onChanged: (v) => _draft.priceText = v,
          ),

          _Field(
            label: 'Where from',
            hint: 'The shop',
            initial: _draft.retailer,
            onChanged: (v) => _draft.retailer = v,
          ),

          const Divider(height: 32),

          Row(
            children: [
              Expanded(
                child: Text('Cover', style: theme.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _draft.coverages.add(CoverageDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),

          /*
            A list, not two fixed slots.

            A couch has a lifetime frame, ten years on the cushions, five on
            the springs and one on the fabric. Two slots hold two of those and
            quietly lose the rest — and the one that matters is the shortest,
            because that is the one that will actually stop covering you.
          */
          if (_draft.coverages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nothing recorded. Without a length there is nothing to count '
                'down to, so nothing will warn you.',
                style: theme.textTheme.bodySmall,
              ),
            ),

          for (var i = 0; i < _draft.coverages.length; i++)
            _CoverageCard(
              key: ValueKey(_draft.coverages[i].id ?? 'new$i'),
              draft: _draft.coverages[i],
              onRemove: () => setState(() => _draft.coverages.removeAt(i)),
              onChanged: () => setState(() {}),
            ),

          const Divider(height: 32),

          /*
            Per-item notice. A roof and a kettle do not deserve the same
            warning, and thirty days is useless for anything needing a quote
            and a tradesman.

            "Default" is a real, selectable option rather than an absence, or
            there is no way back once somebody has picked a number.
          */
          DropdownButtonFormField<int?>(
            initialValue: _draft.leadDays,
            decoration: const InputDecoration(
              labelText: 'Warn me',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final choice in itemLeadChoices)
                DropdownMenuItem(value: choice.days, child: Text(choice.label)),
            ],
            onChanged: (v) => setState(() => _draft.leadDays = v),
          ),

          const SizedBox(height: 16),

          _Field(
            label: 'Notes',
            initial: _draft.notes,
            lines: 3,
            onChanged: (v) => _draft.notes = v,
          ),

          const SizedBox(height: 24),

          if (!_isNew)
            OutlinedButton.icon(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Soft delete, and the dialog says what that actually means.
  ///
  /// The web app promised "it goes to the bin for 30 days" and had no bin to
  /// go to — see logic/bin.dart. The promise is kept here, so the wording can
  /// be specific.
  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_draft.name}?'),
        content: const Text(
          'It goes to the bin for 30 days, so you can change your mind. '
          'Anything attached to it goes too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (sure != true || widget.existing == null) return;

    await widget.repo.softDeleteItem(widget.existing!.id);
    unawaited(syncReminders(widget.repo));
    if (mounted) Navigator.of(context).pop(true);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.initial,
    required this.onChanged,
    this.hint,
    this.lines = 1,
    this.keyboard,
    this.format,
    this.autofocus = false,
  });

  final String label;
  final String? hint;
  final String initial;
  final ValueChanged<String> onChanged;
  final int lines;
  final TextInputType? keyboard;
  final String Function(String)? format;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        initialValue: initial,
        autofocus: autofocus,
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        inputFormatters: format == null
            ? null
            : [
                TextInputFormatter.withFunction((old, now) {
                  final formatted = format!(now.text);
                  return TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }),
              ],
        onChanged: onChanged,
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.draft,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  final CoverageDraft draft;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final lifetime = draft.unit == CoverageUnit.lifetime;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: draft.label,
                    decoration: const InputDecoration(
                      labelText: 'What for',
                      hintText: 'Fabric, frame, parts and labor',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => draft.label = v,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 92,
                  child: TextFormField(
                    initialValue: draft.amountText,
                    // Lifetime never expires and never counts down, so there
                    // is nothing to type — see `CoverageUnit`.
                    enabled: !lifetime,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'How long',
                      hintText: lifetime ? '—' : '24',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => draft.amountText = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<CoverageUnit>(
                    initialValue: draft.unit,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: CoverageUnit.days, child: Text('days')),
                      DropdownMenuItem(value: CoverageUnit.months, child: Text('months')),
                      DropdownMenuItem(value: CoverageUnit.years, child: Text('years')),
                      DropdownMenuItem(
                        value: CoverageUnit.lifetime,
                        child: Text('lifetime'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      draft.unit = v;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
