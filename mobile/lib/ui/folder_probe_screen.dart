/// What the backup folder actually is, and whether a write lands right now.
///
/// ── Why this exists ────────────────────────────────────────────────────────
/// Automatic backups write into a folder chosen through Android's own picker,
/// and every moving part of that is in somebody else's process: the picker
/// belongs to the system, the folder to a document provider, and the write can
/// fail for reasons nothing in this app records. A cloud provider signed out. A
/// grant dropped by a reinstall. An SD card taken out. No space at the far end.
///
/// The report that arrives is always "it stopped backing up", and until now
/// there was nothing to look at. This is the something.
///
/// ── Read-only, apart from the one button that is not ───────────────────────
/// Everything here reads. "Try a write" does not: it puts a small file in the
/// folder and deletes it again, which is the only way to answer the question
/// that matters — not "does the app think it can write" but "did a write land".
///
/// Behind the developer tools, because it is a diagnostic. Somebody who just
/// wants to know whether their backups are working reads the line on the Backup
/// card, which is written from the same facts.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/repository.dart';
import '../io/auto_backup_run.dart';
import '../io/backup_folder.dart';
import '../io/vault.dart';
import '../logic/auto_backup.dart';
import 'feedback.dart';
import 'theme.dart';

Future<void> showFolderProbe(BuildContext context, Repository repo) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (context) => FolderProbeScreen(repo: repo)),
    );

/// Everything worth knowing, gathered in one pass.
class _Probe {
  const _Probe({
    required this.tree,
    required this.label,
    required this.granted,
    required this.files,
    required this.lastAt,
    required this.problem,
  });

  final String? tree;
  final String? label;

  /// Whether Android still honours the grant. The interesting case is a folder
  /// that is set and NOT granted — which looks identical to working until
  /// something asks.
  final bool granted;

  final List<FolderEntry> files;
  final DateTime? lastAt;
  final String? problem;
}

class FolderProbeScreen extends StatefulWidget {
  const FolderProbeScreen({required this.repo, super.key});

  final Repository repo;

  @override
  State<FolderProbeScreen> createState() => _FolderProbeScreenState();
}

class _FolderProbeScreenState extends State<FolderProbeScreen> {
  late Future<_Probe> _data = _gather();
  String? _said;
  bool _busy = false;

  Future<_Probe> _gather() async {
    final settings = await widget.repo.settings();
    final tree = settings.backupFolder;

    if (tree == null) {
      return const _Probe(
        tree: null,
        label: null,
        granted: false,
        files: [],
        lastAt: null,
        problem: null,
      );
    }

    return _Probe(
      tree: tree,
      label: await folderLabel(tree),
      granted: await folderStillGranted(tree),
      files: await listBackupFolder(tree),
      lastAt: settings.lastAutoBackupAt,
      problem: settings.lastAutoBackupError,
    );
  }

  void _say(String words) {
    if (mounted) setState(() => _said = words);
  }

  /// Opens the picker and reports what came back, without saving it.
  ///
  /// This is the question the whole feature turned on: which sources does the
  /// picker offer on THIS phone. The answer is different on every launcher and
  /// every set of installed cloud apps, and it cannot be looked up — only
  /// opened.
  Future<void> _tryPicker() async {
    final tree = await pickBackupFolder();
    _say(tree == null
        ? 'Picker closed with nothing chosen.'
        : 'Picker returned:\n$tree');
  }

  /// Writes a small file, checks it is listed, and deletes it.
  ///
  /// A real write, because "the app believes it has permission" and "a file
  /// arrived" are different facts and only the second one is a backup.
  Future<void> _tryWrite() async {
    final settings = await widget.repo.settings();
    final tree = settings.backupFolder;

    if (tree == null) {
      _say('No folder chosen.');
      return;
    }

    setState(() => _busy = true);

    File? scratch;
    try {
      final dir = await getTemporaryDirectory();
      scratch = File(p.join(dir.path, 'stash-it-write-test.txt'));
      await scratch.writeAsString('Written by Stash it at ${DateTime.now()}');

      final landed = await writeToBackupFolder(
        tree: tree,
        name: 'stash-it-write-test.txt',
        from: scratch.path,
      );

      if (landed == null) {
        _say('The write was refused. Nothing landed.');
        return;
      }

      // Named back, because providers rename: a file asked for as .txt can
      // arrive as .txt.bin, and knowing that is half of debugging a missing
      // backup.
      final after = await listBackupFolder(tree);
      final found = after.where((f) => f.name == landed).isNotEmpty;

      _say(found
          ? 'Wrote and found "$landed". Deleting it again.'
          : 'Wrote "$landed" but it is not in the listing.');

      for (final f in after.where((f) => f.name == landed)) {
        await deleteInBackupFolder(f.uri);
      }
    } catch (e) {
      _say('Threw: $e');
    } finally {
      if (scratch != null) await scratch.delete().catchError((_) => scratch!);
      if (mounted) {
        setState(() {
          _busy = false;
          _data = _gather();
        });
      }
    }
  }

  /// Times the crypto, rather than guessing where the seconds went.
  ///
  /// Encrypting a backup was slow through three releases and each fix was a
  /// theory. This measures: which implementation is running, how long the
  /// derivation takes, and how many megabytes a second the cipher manages.
  Future<void> _timeCrypto() async {
    setState(() => _busy = true);
    _say('Timing…');

    try {
      _say(await cryptoTimings());
    } catch (e) {
      _say('Threw: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs the real thing, now, and reports exactly what it reported.
  Future<void> _runNow() async {
    setState(() => _busy = true);

    try {
      final watch = Stopwatch()..start();
      final done = await backUpToFolder(widget.repo);
      final took = watch.elapsedMilliseconds;

      // The phase timings the lock left behind — see `lastVaultTimings`. This
      // is the whole reason the button is here rather than in Settings.
      _say([
        done.wrote
            ? 'Wrote ${done.name} in $took ms.'
            : (done.problem ?? 'Nothing written, and no reason given.'),
        if (lastVaultTimings != null) '\n$lastVaultTimings',
      ].join());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _data = _gather();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Scaffold(
      backgroundColor: c.slate900,
      appBar: AppBar(
        backgroundColor: c.slate900,
        title: Text(
          'Backup folder',
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
            tooltip: 'Read it again',
            icon: Icon(Icons.refresh, color: c.muted),
            onPressed: cued(() => setState(() => _data = _gather())),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<_Probe>(
          future: _data,
          builder: (context, snap) {
            final probe = snap.data;
            if (probe == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _facts(probe, c),
                const SizedBox(height: 18),
                _buttons(c),
                if (_said != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.slate800,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: c.hairline),
                    ),
                    child: SelectableText(
                      _said!,
                      style: TextStyle(
                        fontFamily: fontMono,
                        fontFeatures: tabularFigures,
                        fontSize: 12,
                        height: 1.4,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'In the folder',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 8),
                if (probe.files.isEmpty)
                  Text('Nothing, or nothing readable.', style: hintStyle(c))
                else
                  for (final file in probe.files) _file(file, c),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _facts(_Probe probe, StashColors c) {
    final rows = <(String, String)>[
      ('Folder set', probe.tree == null ? 'no' : 'yes'),
      ('Android honours it', probe.granted ? 'yes' : 'no'),
      ('Called', probe.label ?? '—'),
      (
        'Last automatic',
        probe.lastAt?.toIso8601String().substring(0, 16) ?? 'never',
      ),
      ('Last problem', probe.problem ?? 'none'),
      ('Files listed', '${probe.files.length}'),
      ('Ours', '${probe.files.where((f) => isOurBackup(f.name)).length}'),
      ('Kept', '$backupsToKeep'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    label,
                    style: TextStyle(
                        fontFamily: fontBody, fontSize: 13, color: c.muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
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
        if (probe.tree != null) ...[
          const SizedBox(height: 10),
          // The whole URI, selectable. It names the provider, which is the one
          // fact that says whether this is a cloud folder or a local one.
          SelectableText(
            probe.tree!,
            style: TextStyle(
                fontFamily: fontMono, fontSize: 11, color: c.muted),
          ),
        ],
      ],
    );
  }

  Widget _buttons(StashColors c) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Try(label: 'Open the picker', onTap: _busy ? null : _tryPicker),
          _Try(label: 'Try a write', onTap: _busy ? null : _tryWrite),
          _Try(label: 'Back up now', onTap: _busy ? null : _runNow),
          _Try(label: 'Time the crypto', onTap: _busy ? null : _timeCrypto),
        ],
      );

  Widget _file(FolderEntry file, StashColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              isOurBackup(file.name)
                  ? Icons.inventory_2_outlined
                  : Icons.remove,
              size: 15,
              color: isOurBackup(file.name) ? c.gold : c.muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: fontMono, fontSize: 12, color: c.text),
              ),
            ),
            Text(
              file.at?.toIso8601String().substring(0, 10) ?? '—',
              style: TextStyle(
                fontFamily: fontMono,
                fontFeatures: tabularFigures,
                fontSize: 11,
                color: c.muted,
              ),
            ),
          ],
        ),
      );
}

class _Try extends StatelessWidget {
  const _Try({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return OutlinedButton(
      onPressed: cued(onTap),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: fontBody, fontSize: 13, color: c.text),
      ),
    );
  }
}
