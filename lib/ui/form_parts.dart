/// The pieces every form screen uses.
///
/// `LabelledField` rather than `FormField`, because Flutter already has a
/// `FormField` and a name collision in a file that imports material is a
/// compile error at best and the wrong widget at worst.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Why this cannot be saved, at the top where it will be read.
///
/// One message at a time, in the order somebody would fix them. A form that
/// lights up four errors at once is a form that gets abandoned.
class ProblemCard extends StatelessWidget {
  const ProblemCard(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

class LabelledField extends StatelessWidget {
  const LabelledField({
    required this.label,
    required this.initial,
    required this.onChanged,
    this.hint,
    this.lines = 1,
    this.keyboard,
    this.format,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final String? hint;
  final String initial;
  final ValueChanged<String> onChanged;
  final int lines;
  final TextInputType? keyboard;

  /// Formats as you type rather than on blur. Correcting a field after the
  /// fact makes people wonder whether they typed it wrong; showing the shape
  /// as they go makes the rule obvious without a hint underneath.
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

/// A `YYYY-MM-DD` date, picked rather than typed.
///
/// Typed dates are how 03/04/2026 happens — the ambiguity that
/// `parseLooseDate` refuses to resolve when it finds one in an email. A picker
/// cannot produce one.
class DateField extends StatelessWidget {
  const DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    super.key,
  });

  final String label;

  /// `YYYY-MM-DD`, or empty.
  final String value;
  final ValueChanged<String> onChanged;

  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value.isEmpty ? 'Not set' : value),
      trailing: const Icon(Icons.calendar_today_outlined),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value) ?? now,
          firstDate: firstDate ?? DateTime(1990),
          lastDate: lastDate ?? DateTime(now.year + 30),
        );
        if (picked == null) return;

        onChanged('${picked.year.toString().padLeft(4, '0')}'
            '-${picked.month.toString().padLeft(2, '0')}'
            '-${picked.day.toString().padLeft(2, '0')}');
      },
    );
  }
}

/// Soft delete, and the dialog says what that actually means.
///
/// The web app promised "it goes to the bin for 30 days" and had no bin to go
/// to — `restoreItem` sat in the repository, called from nowhere. The promise
/// is kept here, so the wording can be specific rather than reassuring.
class DeleteButton extends StatelessWidget {
  const DeleteButton({
    required this.name,
    required this.onConfirmed,
    super.key,
  });

  final String name;
  final Future<void> Function() onConfirmed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final sure = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete $name?'),
            content: const Text(
              'It goes to the bin for 30 days, so you can change your mind.',
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

        if (sure == true) await onConfirmed();
      },
      icon: const Icon(Icons.delete_outline),
      label: const Text('Delete'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
