/// What this phone is actually doing, in one screen you can paste into an
/// email.
///
/// ── Why this ships in release ─────────────────────────────────────────────
/// Everything here is read-only. Nothing on this sheet writes a record, grants
/// anything, or changes a setting — a curious person who finds the ten taps
/// gets facts and nothing else, which is why it is safe outside a debug build
/// while the grant button is not.
///
/// The point is support. "Reminders aren't working" and "it crashed" arrive as
/// sentences with no evidence attached, and every round trip asking for more
/// costs a day. One block of text somebody can copy turns a guess into a
/// diagnosis.
///
/// ── And nothing in it is private ──────────────────────────────────────────
/// Counts, sizes, versions, a time zone. No names, no dates from anybody's
/// records, no document labels. That constraint is load-bearing: the whole
/// point is that somebody can paste it to a stranger without reading it
/// carefully first, and a diagnostics block that leaks "Passport — Nuno" is a
/// diagnostics block nobody should send.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../billing/billing.dart';
import '../billing/current.dart';
import '../db/repository.dart';
import '../logic/limits.dart';
import '../logic/reminders.dart' show defaultSendHour;
import '../models/types.dart';
import '../notify/sync.dart';
import 'feedback.dart';
import 'settings_tab.dart' show appVersion;
import 'theme.dart';

/// Everything the sheet shows, already formatted.
///
/// Gathered in one place rather than per-row so the copied text and the screen
/// cannot disagree — the block on screen IS the block on the clipboard.
class Diagnostics {
  const Diagnostics({required this.sections, required this.text});

  /// Heading to rows, in display order.
  final List<(String, List<(String, String)>)> sections;

  /// The same thing as plain text.
  final String text;
}

/*
  ── No BuildContext in here ─────────────────────────────────────────────────

  It took one, read `MediaQuery` from it, and did so after six awaits — which
  the analyzer objects to and is right to. A context is only valid while the
  widget that owns it is mounted, and by the time the database, the
  notification plugin and the store have all answered, that is a promise
  nobody made.

  The one thing it actually wanted was the text scale, which is a double. The
  caller reads it synchronously and passes it in, and this function goes back
  to being what it looks like: facts in, a block of text out, no widget tree
  involved.
*/
Future<Diagnostics> gather(Repository repo, {required double textScale}) async {
  final settings = await repo.settings();
  final items = (await repo.activeItems()).length;
  final papers = (await repo.activePapers()).length;
  final subs = (await repo.activeSubscriptions()).length;
  final docs = (await repo.activeDocs()).length;

  final binned = (await repo.deletedItems()).length +
      (await repo.deletedPapers()).length +
      (await repo.deletedSubscriptions()).length;

  final bytes = await repo.storageBytes();
  final orphans = (await repo.orphanedBlobs()).length;

  final pending = await notifications.scheduled();
  final allowed = await notifications.permitted();

  Offer? offer;
  try {
    offer = await appBilling.offer();
  } catch (_) {
    offer = null;
  }

  final counted = items + papers + subs;

  String size(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  final sections = <(String, List<(String, String)>)>[
    (
      'Build',
      [
        ('Version', appVersion),
        ('Backup schema', 'v$schemaVersion'),
        ('Cap', capEnforced ? 'on, $freeItemLimit' : 'off'),
        (
          'Unlocked',
          settings.entitlements.proUnlock
              ? 'yes (${settings.entitlements.source ?? 'unknown'})'
              : 'no'
        ),
      ],
    ),
    (
      'Records',
      [
        ('Items', '$items'),
        ('Documents', '$papers'),
        ('Subscriptions', '$subs'),
        ('Counted against the cap', '$counted of $freeItemLimit'),
        ('Attachments', '$docs'),
        ('In the bin', '$binned'),
      ],
    ),
    (
      'Storage',
      [
        ('Files held', size(bytes)),
        // Not zero means something is holding bytes nothing points at. It is
        // never fatal and it is exactly the kind of slow leak that only shows
        // up in a number like this one.
        ('Orphaned files', '$orphans'),
      ],
    ),
    (
      'Reminders',
      [
        ('Permission', allowed ? 'granted' : 'not granted'),
        ('Switched on', settings.notifyEnabled == true ? 'yes' : 'no'),
        ('Scheduled', '${pending.length}'),
        ('Send hour', '${settings.reminderHour ?? defaultSendHour}:00'),
        ('Time zone', notifications.zone),
      ],
    ),
    (
      'Store',
      [
        ('Reachable', offer?.available == true ? 'yes' : 'no'),
        ('Price', offer?.price.isNotEmpty == true ? offer!.price : '—'),
      ],
    ),
    (
      'Device',
      [
        ('System', Platform.operatingSystemVersion),
        ('Locale', Platform.localeName),
        ('Text size', '${(textScale * 100).round()}%'),
      ],
    ),
  ];

  final buffer = StringBuffer('Stash it diagnostics\n');
  for (final (heading, rows) in sections) {
    buffer.writeln('\n$heading');
    for (final (label, value) in rows) {
      buffer.writeln('  $label: $value');
    }
  }

  return Diagnostics(sections: sections, text: buffer.toString());
}

/// Opens diagnostics as a screen of its own.
///
/// ── A page, not a sheet ────────────────────────────────────────────────────
/// The rest of the app opens things in a two-thirds sheet, and that idiom
/// earns its place: a sheet keeps the screen behind it visible, which is right
/// when you are picking a thing or filling one field.
///
/// This is neither. It is thirty-odd rows of numbers somebody reads top to
/// bottom, usually while typing them into a support email — and a sheet fights
/// that on both counts. It gives up a third of the height to a screen nobody
/// is looking at, and every scroll to the top risks a drag that dismisses the
/// whole thing.
///
/// So it gets the full page and a back button, which is what a document is.
Future<void> showDiagnostics(BuildContext context, Repository repo) {
  feedback(Cue.expand);

  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(builder: (context) => DiagnosticsScreen(repo: repo)),
  );
}

/// Public because it is a route now rather than a sheet's contents.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({required this.repo, super.key});

  final Repository repo;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsState();
}

class _DiagnosticsState extends State<DiagnosticsScreen> {
  /*
    Read once, in `didChangeDependencies` rather than in a field initialiser,
    because the text scale comes from an inherited widget and reading one of
    those from an initialiser is the same mistake in a quieter form.

    Held rather than rebuilt: a `FutureBuilder` handed a fresh future on every
    frame re-runs eight database queries for ever.
  */
  Future<Diagnostics>? _data;

  String? _said;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= gather(
      widget.repo,
      textScale: MediaQuery.of(context).textScaler.scale(14) / 14,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Scaffold(
      backgroundColor: c.slate900,
      appBar: AppBar(
        backgroundColor: c.slate900,
        title: Text(
          'Diagnostics',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.6,
            color: c.text,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<Diagnostics>(
          future: _data,
          builder: (context, snap) {
            final data = snap.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    children: [
                      // The title lives in the app bar now. What is left is the
                      // sentence that matters: what this is safe to do with.
                      Text(
                        'Counts and versions only — no names, no dates, nothing '
                        'out of your records. Safe to paste into an email.',
                        style: hintStyle(c),
                      ),
                      const SizedBox(height: 18),
                      for (final (heading, rows) in data.sections) ...[
                        Text(heading.toUpperCase(), style: fieldLabelStyle(c)),
                        const SizedBox(height: 6),
                        for (final (label, value) in rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontFamily: fontBody,
                                      fontSize: 13,
                                      color: c.muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    value,
                                    textAlign: TextAlign.right,
                                    // Mono, because half of these are numbers
                                    // and the other half are versions, and both
                                    // are read character by character.
                                    style: TextStyle(
                                      fontFamily: fontMono,
                                      fontFeatures: tabularFigures,
                                      fontSize: 13,
                                      color: c.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (_said != null) ...[
                        Text(_said!, style: hintStyle(c)),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  decoration: BoxDecoration(
                    color: c.slate900,
                    border: Border(top: BorderSide(color: c.hairline)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final sent = await notifications.sendTest();
                            if (!context.mounted) return;
                            setState(() => _said = sent
                                ? 'Sent. If nothing appeared, the phone is holding '
                                    'it — check the app in Android settings.'
                                : 'This phone would not send one.');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.text,
                            side: BorderSide(color: c.line),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                          ),
                          child: Text(
                            'Test notification',
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
                                ClipboardData(text: data.text));
                            feedback(Cue.save);
                            if (!context.mounted) return;
                            setState(() =>
                                _said = 'Copied. Paste it into the email.');
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
                            'Copy',
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
