/// Asking for one line of text.
///
/// ── The bug this exists to make impossible ────────────────────────────────
/// There were three copies of this, and every one of them did:
///
///     final controller = TextEditingController(text: initial);
///     final answer = await showDialog(... TextField(controller: controller) ...);
///     controller.dispose();
///
/// which looks careful and is wrong. `showDialog` and `showModalBottomSheet`
/// complete the moment `pop` is called — the route's exit animation is still
/// running and the `TextField` is still mounted and still listening. Disposing
/// the controller there pulls it out from under a live `EditableText`, and the
/// tear-down that follows is what trips the framework's `_dependents.isEmpty`
/// assertion.
///
/// It fired on a custom warranty length, a custom coverage name and a custom
/// room name — every place that asked for a line of text, which is the tell
/// that it was the shape and not the screen.
///
/// The fix is ownership, not timing. A `StatefulWidget` inside the route holds
/// the controller and disposes it in its own `dispose()`, which the framework
/// calls when the subtree is genuinely gone. There is no moment to get wrong.
///
/// ── And one copy, not three ───────────────────────────────────────────────
/// Three helpers with the same name in three files is how the item form ended
/// up with a sheet and the rooms screen with a dialog, for the same question.
/// This is the sheet, because every other input in the app is one.
library;

import 'package:flutter/material.dart';

import 'form_sheet_parts.dart';
import 'theme.dart';

/// Returns what was typed, or null if it was dismissed.
///
/// The value comes back trimmed; an empty answer is returned as null, because
/// every caller treats "" and "cancelled" the same way and each used to write
/// its own check for it.
Future<String?> askText(
  BuildContext context, {
  required String title,
  String? hint,
  String initial = '',
  bool number = false,
}) async {
  final typed = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate700,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => _TextPrompt(
      title: title,
      hint: hint,
      initial: initial,
      number: number,
    ),
  );

  final tidied = typed?.trim();
  return (tidied == null || tidied.isEmpty) ? null : tidied;
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.hint,
    required this.initial,
    required this.number,
  });

  final String title;
  final String? hint;
  final String initial;
  final bool number;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  /// Owned here, and only here — see the note at the top of this file.
  late final TextEditingController _field =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(_field.text);

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        // The keyboard's own height, so the field is never behind it.
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: c.text,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _field,
            autofocus: true,
            keyboardType:
                widget.number ? TextInputType.number : TextInputType.text,
            textCapitalization: widget.number
                ? TextCapitalization.none
                : TextCapitalization.sentences,
            style: TextStyle(fontFamily: fontBody, fontSize: 16, color: c.text),
            onSubmitted: (_) => _done(),
            // Filled, and nothing else. Setting only `border` leaves the
            // theme's `enabledBorder` in place — see `bareInput`.
            decoration: sunkenInput(hint: widget.hint, fill: c.slate600),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _done,
            style: FilledButton.styleFrom(
              backgroundColor: c.gold,
              foregroundColor: c.onGold,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            child: Text(
              'Done',
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: c.onGold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Holds controllers for as long as a route's content is on screen.
///
/// For the prompts that ask for more than one line and so cannot use
/// `askText` — a URL and its title, a word typed to confirm. They hit the same
/// trap described at the top of this file: a controller created beside the
/// `await` and disposed the moment it returns, while the route is still
/// animating out and the fields are still live.
///
/// Wrapping the content puts the disposal on the framework's own clock. It
/// runs when this element unmounts, which is when the route has genuinely
/// gone, and there is no line of code that can be placed a moment too early.
class OwnsControllers extends StatefulWidget {
  const OwnsControllers({
    required this.controllers,
    required this.child,
    super.key,
  });

  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<OwnsControllers> createState() => _OwnsControllersState();
}

class _OwnsControllersState extends State<OwnsControllers> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
