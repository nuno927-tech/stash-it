/// Settings, and the restore that got the data here.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/backup.dart';
import '../db/repository.dart';
import '../db/restore.dart';
import '../io/bundle_file.dart';
import '../logic/bundle.dart';
import '../logic/devmode.dart';
import '../logic/limits.dart';
import 'parts.dart';

const appVersion = '0.1.0';

/// Raw table counts beside what the repository returns.
///
/// Temporary — see the Diagnostics section below.
class _Counts {
  const _Counts({
    required this.rawItems,
    required this.rawPapers,
    required this.rawSubs,
    required this.rawBlobs,
    required this.liveItems,
    required this.livePapers,
    required this.liveSubs,
    required this.deletedItems,
    required this.propertyIds,
  });

  final int rawItems;
  final int rawPapers;
  final int rawSubs;
  final int rawBlobs;

  final int liveItems;
  final int livePapers;
  final int liveSubs;

  final int deletedItems;
  final List<String> propertyIds;

  static Future<_Counts> of(Repository repo) async {
    final db = repo.db;

    // No `where` at all. This is the number that settles it.
    final items = await db.select(db.items).get();
    final papers = await db.select(db.papers).get();
    final subs = await db.select(db.subscriptions).get();
    final blobs = await db.select(db.blobs).get();

    return _Counts(
      rawItems: items.length,
      rawPapers: papers.length,
      rawSubs: subs.length,
      rawBlobs: blobs.length,
      liveItems: (await repo.activeItems()).length,
      livePapers: (await repo.activePapers()).length,
      liveSubs: (await repo.activeSubscriptions()).length,
      deletedItems: items.where((i) => i.deletedAt != null).length,
      propertyIds: {
        for (final i in items) i.propertyId,
        for (final p in papers) p.propertyId,
      }.toList(),
    );
  }
}

class SettingsTab extends StatefulWidget {
  const SettingsTab({required this.repo, super.key});

  final Repository repo;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String? _status;
  bool _busy = false;
  TapState _taps = noTaps;

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _status = null;
    });

    try {
      /*
        `withData` is off deliberately. With it on, the picker reads the whole
        file on the Java side and hands the bytes across the platform channel —
        and a backup with seventy-six photographs in it killed the process
        outright, natively, with nothing Dart could catch.
      */
      final picked = await FilePicker.platform.pickFiles();
      final files = picked?.files ?? const <PlatformFile>[];
      final path = files.isEmpty ? null : files.first.path;
      if (path == null) return;

      final bytes = await File(path).readAsBytes();
      final bundle = parseBackupBytes(bytes);
      final result = await restoreInto(widget.repo.db, bundle);

      setState(() {
        _status = 'Restored ${result.items} items, ${result.papers} documents, '
            '${result.subscriptions} subscriptions and ${result.blobs} files.';
      });
    } on BundleError catch (e) {
      // Every refusal already carries a sentence written for a person.
      setState(() => _status = e.message);
    } catch (e) {
      setState(() => _status = 'That did not work: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Writes the backup and hands it to the share sheet.
  ///
  /// ── Shared, not saved ─────────────────────────────────────────────────
  /// The file goes to a cache directory and straight into the share sheet, so
  /// it lands wherever the person chooses — Drive, Files, an email to
  /// themselves. Writing it into Downloads instead would need storage
  /// permission and would leave a file most people never look at again.
  ///
  /// The whole point is that the backup ends up somewhere that is **not this
  /// phone**, so the flow should end in an app that can do that.
  Future<void> _backUp() async {
    setState(() {
      _busy = true;
      _status = null;
    });

    try {
      final bytes = await exportBackup(widget.repo.db);

      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, backupFileName()));
      await file.writeAsBytes(bytes);

      // share_plus 10's API. Version 11 replaced this with
      // `SharePlus.instance.share(ShareParams(...))`; when the dependency
      // moves, so does this line and nothing else.
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Stash it backup',
      );

      setState(() {
        final kb = (bytes.length / 1024).round();
        _status = 'Made ${backupFileName()} — $kb KB. '
            'Keep it somewhere that is not this phone.';
      });
    } catch (e) {
      setState(() => _status = 'That did not work: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /*
    Ten taps on the version, and the run resets if you pause.

    Not a secret worth keeping — it is that a switch which lifts the item cap
    has no business being one stray thumb away on somebody's settings screen.
  */
  void _tapVersion() {
    setState(() {
      _taps = tap(_taps, DateTime.now());
      if (unlocked(_taps)) rememberUnlocked(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = tapHint(_taps);

    return ListView(
      children: [
        const SectionTitle('Your data'),

        FutureBuilder<int>(
          future: widget.repo.cappedCount(),
          builder: (context, snap) {
            final used = snap.data;
            return ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(used == null ? 'Counting…' : '$used of $freeItemLimit saved'),
              subtitle: const Text(
                'Items, documents and subscriptions together.',
              ),
            );
          },
        ),

        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Restore from a backup'),
          subtitle: const Text('Replaces everything on this phone.'),
          onTap: _busy ? null : _restore,
        ),

        /*
          ── The only copy that can survive this phone ──────────────────────

          The database is encrypted with a key held in this handset's Keystore,
          and that key never leaves. A factory reset or a lost phone produces a
          file nobody can open, us included. So this is not a convenience
          feature, and the subtitle says the actual reason rather than "keep
          your data safe".
        */
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: const Text('Back up now'),
          subtitle: const Text(
            'One file with everything in it. The only copy that survives '
            'losing this phone.',
          ),
          onTap: _busy ? null : _backUp,
        ),

        if (_busy) const LinearProgressIndicator(),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_status!, style: theme.textTheme.bodyMedium),
          ),

        const SectionTitle('Reminders'),
        const ListTile(
          enabled: false,
          leading: Icon(Icons.notifications_outlined),
          title: Text('Notify me'),
          subtitle: Text(
            'Not built yet. When it is, your phone will keep the schedule '
            'itself — nothing is sent anywhere.',
          ),
        ),

        /*
          ── Temporary, and it is here because guessing failed twice ────────

          Twenty-one items restored into an encrypted database and no screen
          showed them. The first theory — that every row carried the household
          id from the backup while the queries asked for the local one — was
          plausible, was fixed, and did not fix it.

          So this stops the guessing: raw table counts, with no `where` clause
          at all, next to what the repository actually returns. If the raw
          number is zero the restore is not writing; if it is twenty-one and
          the filtered number is zero, something is still filtering them out,
          and the property ids below say what.

          Goes away once the answer is known.
        */
        const SectionTitle('Diagnostics'),
        FutureBuilder<_Counts>(
          future: _Counts.of(widget.repo),
          builder: (context, snap) {
            final c = snap.data;
            if (c == null) return const LinearProgressIndicator();

            return Column(
              children: [
                ListTile(
                  dense: true,
                  title: const Text('Rows in the database'),
                  subtitle: Text(
                    'items ${c.rawItems} · documents ${c.rawPapers} · '
                    'subscriptions ${c.rawSubs} · blobs ${c.rawBlobs}',
                  ),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Rows the app can see'),
                  subtitle: Text(
                    'items ${c.liveItems} · documents ${c.livePapers} · '
                    'subscriptions ${c.liveSubs}',
                  ),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Household ids on those rows'),
                  subtitle: Text(
                    c.propertyIds.isEmpty ? 'none' : c.propertyIds.join(', '),
                  ),
                ),
                ListTile(
                  dense: true,
                  title: const Text('This repository is reading'),
                  subtitle: Text(widget.repo.propertyId),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Deleted rows'),
                  subtitle: Text('${c.deletedItems} items in the bin'),
                ),
              ],
            );
          },
        ),

        const SectionTitle('About'),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Stash it'),
          subtitle: Text(hint == null ? appVersion : '$appVersion · $hint'),
          onTap: _tapVersion,
        ),

        if (readUnlocked()) ...[
          const SectionTitle('Developer'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Database is encrypted'),
            subtitle: const Text(
              'SQLCipher, with a key from the Android Keystore. The app '
              'refuses to open if the library did not load, rather than '
              'writing a plaintext database it believes is encrypted.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('Hide developer tools'),
            onTap: () => setState(() {
              rememberUnlocked(false);
              _taps = noTaps;
            }),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}
