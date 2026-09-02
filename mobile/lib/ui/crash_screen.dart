/// Everything that has gone wrong on this phone.
///
/// ── Read this before sending it ────────────────────────────────────────────
/// The diagnostics screen is deliberately safe to paste to a stranger without
/// reading — counts, sizes, versions, no names. This screen is not, and it
/// says so at the top rather than leaving somebody to find out.
///
/// An exception message is written by whoever threw it, and it may quote what
/// it choked on: a document label, a file name, the title of a record. That
/// cannot be scrubbed reliably — there is no rule that separates "Bad state:
/// no element" from "FormatException: Passport — renewal". So the whole text
/// is on screen, in full, before anybody copies anything, and nothing is ever
/// sent on its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../io/crash_log.dart';
import '../logic/crash_log.dart';
import 'feedback.dart';
import 'theme.dart';

Future<void> showCrashes(BuildContext context) {
  feedback(Cue.expand);

  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(builder: (context) => const CrashScreen()),
  );
}

class CrashScreen extends StatefulWidget {
  const CrashScreen({super.key});

  @override
  State<CrashScreen> createState() => _CrashScreenState();
}

class _CrashScreenState extends State<CrashScreen> {
  late Future<List<CrashNote>> _notes = readCrashes();
  String? _said;

  void _reload() => setState(() {
        _notes = readCrashes();
        _said = null;
      });

  /*
    A dialog, not the delete sheet.

    The delete sheet is the app's shape for destroying a record, and borrowing
    it here would say something untrue about what this does: no record is
    touched, nothing is recoverable that was not already gone, and the only
    loss is the evidence. A one-line question is the right weight.
  */
  Future<void> _clear(List<CrashNote> notes) async {
    feedback(Cue.tap);
    final c = StashColors.of(context);

    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.slate800,
        title: Text(
          'Throw away the log?',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: c.text,
          ),
        ),
        content: Text(
          '${notes.length} recorded '
          '${notes.length == 1 ? 'problem' : 'problems'}. None of your records '
          'are touched — this only forgets what went wrong.',
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
              'Keep',
              style: TextStyle(fontFamily: fontBody, color: c.text),
            ),
          ),
          TextButton(
            onPressed:
                cued(() => Navigator.of(context).pop(true), cue: Cue.collapse),
            child: Text(
              'Throw away',
              style: TextStyle(fontFamily: fontBody, color: c.ember),
            ),
          ),
        ],
      ),
    );

    if (yes != true || !mounted) return;

    await clearCrashes();
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Scaffold(
      backgroundColor: c.slate900,
      appBar: AppBar(
        backgroundColor: c.slate900,
        title: Text(
          'Crashes',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.6,
            color: c.text,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: c.muted),
            onPressed: _reload,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<CrashNote>>(
          future: _notes,
          builder: (context, snap) {
            final notes = snap.data;
            if (notes == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (notes.isEmpty) return _Empty(c);

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    children: [
                      _Warning(c),
                      const SizedBox(height: 14),
                      for (final note in notes) ...[
                        _Note(note: note, c: c),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                if (_said != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      _said!,
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 12.5,
                        color: c.muted,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _clear(notes),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: c.line),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                          ),
                          child: Text(
                            'Throw away',
                            style: TextStyle(
                              fontFamily: fontBody,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: c.text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: crashReport(notes)),
                            );
                            feedback(Cue.save);
                            if (!context.mounted) return;
                            setState(() => _said =
                                'Copied. Read it before you paste it.');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: c.gold,
                            foregroundColor: c.onGold,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                          ),
                          child: Text(
                            'Copy all',
                            style: TextStyle(
                              fontFamily: fontDisplay,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: c.onGold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.c);
  final StashColors c;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.washGold,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.washGoldLine),
        ),
        child: Text(
          'Unlike Diagnostics, this can contain the name of one of your '
          'records — an error quotes whatever it choked on. Read it before '
          'you send it to anyone.',
          style: TextStyle(
            fontFamily: fontBody,
            fontSize: 13,
            height: 1.5,
            color: c.text,
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.c);
  final StashColors c;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Nothing has gone wrong.\n\n'
            'Problems are written down here as they happen, on this phone. '
            'Nothing is sent anywhere.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 14,
              height: 1.6,
              color: c.muted,
            ),
          ),
        ),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.note, required this.c});

  final CrashNote note;
  final StashColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.slate800,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${crashSourceLabel[note.source]} · v${note.version}',
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.muted,
                  ),
                ),
              ),
              Text(
                // Seconds included: two crashes a second apart is the loop
                // that matters, and a date alone cannot show it.
                note.at.toIso8601String().substring(0, 19).replaceFirst('T', ' '),
                style: TextStyle(
                  fontFamily: fontMono,
                  fontFeatures: tabularFigures,
                  fontSize: 11.5,
                  color: c.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note.message,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 13,
              height: 1.4,
              color: c.text,
            ),
          ),
          if (note.stack.isNotEmpty) ...[
            const SizedBox(height: 8),

            /*
              Collapsed, because a stack is for the person fixing it and a list
              of twenty expanded ones is a screen nobody can scan for the one
              they were asked about.
            */
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  'Where it happened',
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.gold,
                  ),
                ),
                iconColor: c.gold,
                collapsedIconColor: c.muted,
                children: [
                  SelectableText(
                    note.stack,
                    style: TextStyle(
                      fontFamily: fontMono,
                      fontSize: 10.5,
                      height: 1.5,
                      color: c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
