/// Setting a passphrase, and typing one back in.
///
/// ── Two sheets, because they are two different conversations ───────────────
/// Setting one is a warning: this is the only thing that opens your backups,
/// nobody can reset it, write it down. Typing one back in is a question with a
/// wrong answer, and the wrong answer needs to be sayable without losing what
/// was typed.
///
/// They share a file because they share the field and the tone, and nothing
/// else.
library;

import 'package:flutter/material.dart';

import '../logic/vault.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'theme.dart';

/// Asks for a new passphrase, twice, and returns it.
///
/// Null when somebody backs out — which they may, and which must leave the app
/// exactly as it was rather than half-locked.
Future<String?> askForNewPassphrase(BuildContext context) {
  feedback(Cue.expand);

  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => const SheetEntrance(child: _SetSheet()),
  );
}

/// Asks for an existing one, to open a file.
Future<String?> askForPassphrase(BuildContext context, {String? because}) {
  feedback(Cue.expand);

  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => SheetEntrance(child: _AskSheet(because: because)),
  );
}

/// Are you sure you want backups readable again.
///
/// A dialog rather than the delete sheet: nothing is being destroyed, and
/// borrowing the shape the app uses for destruction would say something untrue
/// about what this does.
Future<bool> confirmUnlockBackups(BuildContext context) async {
  feedback(Cue.tap);
  final c = StashColors.of(context);

  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: c.slate800,
      title: Text(
        'Stop locking backups?',
        style: TextStyle(
          fontFamily: fontDisplay,
          fontWeight: FontWeight.w800,
          fontSize: 19,
          color: c.text,
        ),
      ),
      content: Text(
        'New backups will be plain files again — readable by anyone who opens '
        'the folder they land in.\n\n'
        'Backups already written stay locked, and still need the passphrase.',
        style: TextStyle(
          fontFamily: fontBody,
          fontSize: 13.5,
          height: 1.5,
          color: c.muted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: cued(() => Navigator.of(context).pop(false)),
          child: Text(
            'Keep locking',
            style: TextStyle(fontFamily: fontBody, color: c.text),
          ),
        ),
        TextButton(
          onPressed: cued(
            () => Navigator.of(context).pop(true),
            cue: Cue.collapse,
          ),
          child: Text(
            'Stop',
            style: TextStyle(fontFamily: fontBody, color: c.ember),
          ),
        ),
      ],
    ),
  );

  return answer ?? false;
}

/* ------------------------------------------------------------ setting one */

class _SetSheet extends StatefulWidget {
  const _SetSheet();

  @override
  State<_SetSheet> createState() => _SetSheetState();
}

class _SetSheetState extends State<_SetSheet> {
  final TextEditingController _first = TextEditingController();
  final TextEditingController _second = TextEditingController();
  final FocusNode _firstFocus = FocusNode();
  final FocusNode _secondFocus = FocusNode();

  String? _problem;

  /*
    ── Shown, not hidden ───────────────────────────────────────────────────

    Dots are for a password typed in a coffee shop forty times a week. This is
    typed twice in a lifetime, on a phone the person is holding, and it is the
    one string in the app they cannot afford to get wrong — so the default is
    that they can see it, with a way to hide it if somebody is looking over
    their shoulder.
  */
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _firstFocus.requestFocus());
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _firstFocus.dispose();
    _secondFocus.dispose();
    super.dispose();
  }

  void _done() {
    final phrase = _first.text.trim();

    final bad = whyNotAPassphrase(phrase);
    if (bad != null) {
      feedback(Cue.error);
      setState(() => _problem = bad);
      return;
    }

    if (phrase != _second.text.trim()) {
      feedback(Cue.error);
      setState(() => _problem = 'Those two do not match.');
      return;
    }

    feedback(Cue.save);
    Navigator.of(context).pop(phrase);
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: screen * 0.78,
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: insets),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    Text(
                      'Lock your backups',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w800,
                        fontSize: 25,
                        letterSpacing: -0.7,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Backup files stop being readable by anyone who finds '
                      'them. Nothing else changes — the app opens exactly as '
                      'it does now.',
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 13.5,
                        height: 1.5,
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 20),

                    /*
                      ── The warning goes above the field, not under it ──────

                      Everything about this is irreversible in a way people do
                      not expect from an app: there is no reset, no email, no
                      support desk with a copy. Somebody who reads it after
                      typing has already decided.
                    */
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.washGold,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: c.washGoldLine),
                      ),
                      child: Text(
                        'Write it down somewhere that is not this phone.\n\n'
                        'Nobody can reset it and nobody has a copy — not us, '
                        'not Google. A backup whose passphrase is forgotten is '
                        'gone, and so is everything in it.',
                        style: TextStyle(
                          fontFamily: fontBody,
                          fontSize: 13,
                          height: 1.5,
                          color: c.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const FieldLabel('Passphrase'),
                    TextBox(
                      initial: '',
                      controller: _first,
                      focus: _firstFocus,
                      hint: 'Four words you will remember',
                      obscure: _hidden,
                      action: TextInputAction.next,
                      onSubmitted: _secondFocus.requestFocus,
                      onChanged: (_) {
                        if (_problem != null) setState(() => _problem = null);
                      },
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('And again'),
                    TextBox(
                      initial: '',
                      controller: _second,
                      focus: _secondFocus,
                      hint: 'The same one',
                      obscure: _hidden,
                      action: TextInputAction.done,
                      onSubmitted: _done,
                      onChanged: (_) {
                        if (_problem != null) setState(() => _problem = null);
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: cued(
                          () => setState(() => _hidden = !_hidden),
                        ),
                        child: Text(
                          _hidden ? 'Show it' : 'Hide it',
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 13,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SheetFooter(
                label: 'Lock backups',
                problem: _problem,
                onSave: _done,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------- typing one */

class _AskSheet extends StatefulWidget {
  const _AskSheet({this.because});

  /// Why it is being asked for, when that is not obvious.
  final String? because;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final TextEditingController _typed = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _typed.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _done() {
    final phrase = _typed.text.trim();
    if (phrase.isEmpty) return;

    feedback(Cue.tap);
    Navigator.of(context).pop(phrase);
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: screen * 0.55,
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: insets),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    Text(
                      'That backup is locked',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w800,
                        fontSize: 25,
                        letterSpacing: -0.7,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.because ??
                          'It was made on a phone with a passphrase set. Type '
                              'that passphrase to open it.',
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 13.5,
                        height: 1.5,
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const FieldLabel('Passphrase'),
                    TextBox(
                      initial: '',
                      controller: _typed,
                      focus: _focus,
                      hint: 'The one you wrote down',
                      action: TextInputAction.done,
                      onSubmitted: _done,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
              SheetFooter(label: 'Open it', problem: null, onSave: _done),
            ],
          ),
        ),
      ),
    );
  }
}
