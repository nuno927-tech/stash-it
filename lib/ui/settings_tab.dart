/// Settings, and the restore that got the data here.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../db/restore.dart';
import '../io/bundle_file.dart';
import '../logic/bundle.dart';
import '../logic/devmode.dart';
import '../logic/limits.dart';
import 'parts.dart';

const appVersion = '0.1.0';

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
          ── The one that is not built yet, and says so ──────────────────────

          The app can read a .stashit and cannot yet write one. That gap is
          worse here than it was on the web: the database is encrypted with a
          key that lives in this handset's Keystore and never leaves it, so a
          lost or reset phone is unrecoverable data unless a backup exists
          somewhere else.

          A disabled row saying "not built yet" is uncomfortable and correct.
          A missing row would let somebody assume it was somewhere they had not
          looked.
        */
        const ListTile(
          enabled: false,
          leading: Icon(Icons.upload_outlined),
          title: Text('Back up now'),
          subtitle: Text(
            'Not built yet. Until it is, keep the backup you restored from — '
            'the database on this phone is encrypted with a key that cannot '
            'leave it.',
          ),
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
