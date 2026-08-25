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
import '../logic/bin.dart';
import '../logic/bundle.dart';
import '../logic/devmode.dart';
import '../logic/reminders.dart';
import '../models/settings.dart';
import '../notify/sync.dart';
import 'bin_screen.dart';
import 'feedback.dart';
import 'parts.dart';
import 'prefs_scope.dart';
import 'scout.dart';

const appVersion = '0.15.0';

class SettingsTab extends StatefulWidget {
  const SettingsTab({required this.repo, super.key});

  final Repository repo;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String? _status;
  bool _busy = false;

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

  /// Recomputed on each rebuild rather than cached, because a save on another
  /// tab changes it and nothing tells this screen.
  Future<int> get _pendingCount => syncReminders(widget.repo);

  /// "3 things · last day", or "Nothing here".
  ///
  /// Built here rather than in `binSummary` because the three queries are the
  /// repository's business and the sentence is the logic's — the same split as
  /// everywhere else, and the reason `binSummary` takes `BinEntry` rather than
  /// three lists.
  Future<String> get _binLine async {
    final entries = [
      for (final i in await widget.repo.deletedItems())
        BinEntry(id: i.id, kind: BinKind.item, name: i.name, deletedAt: i.deletedAt),
      for (final p in await widget.repo.deletedPapers())
        BinEntry(
            id: p.id, kind: BinKind.paper, name: p.label, deletedAt: p.deletedAt),
      for (final s in await widget.repo.deletedSubscriptions())
        BinEntry(
            id: s.id,
            kind: BinKind.subscription,
            name: s.name,
            deletedAt: s.deletedAt),
    ];
    return binSummary(entries);
  }

  /// The switch, and the OS prompt behind it.
  ///
  /// Turning it on has to ask Android, and Android only asks once per install —
  /// after a decline, the switch cannot be turned on from in here at all, which
  /// is why the failure says where to go rather than just refusing.
  Future<void> _setNotify(bool wanted) async {
    setState(() => _busy = true);

    try {
      var enabled = false;
      if (wanted) enabled = await notifications.ask();

      await widget.repo.setNotify(enabled: enabled);
      await syncReminders(widget.repo);

      if (!mounted) return;
      setState(() {
        _status = wanted && !enabled
            ? 'Android is holding notifications for Stash it. Turn them on in '
                'the phone\'s app settings and this switch will follow.'
            : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Theme, sound and haptics.
  ///
  /// ── All three had to actually do something before they went on screen ──
  /// `nudges.dart` opens by describing two settings that wrote to the database
  /// and changed nothing anybody could see, and calls that worse than a missing
  /// feature because it looks answered. Adding a sound switch with no sound
  /// behind it would have been the third.
  ///
  /// So the theme repaints the whole app through `PrefsScope`, the haptics call
  /// `HapticFeedback`, and the tones are synthesised in `ui/feedback.dart` from
  /// the same note table the PWA uses. Each switch previews itself as it is
  /// turned on, because a toggle you cannot hear is one you have to take on
  /// trust.
  Widget _appearance(BuildContext context) {
    final prefs = PrefsScope.of(context);

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.contrast),
          title: const Text('Theme'),
          subtitle: Text(switch (prefs.theme) {
            ThemeChoice.system => 'Match my device',
            ThemeChoice.light => 'Light',
            ThemeChoice.dark => 'Dark',
          }),
          trailing: SegmentedButton<ThemeChoice>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeChoice.system, icon: Icon(Icons.brightness_auto_outlined)),
              ButtonSegment(value: ThemeChoice.light, icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeChoice.dark, icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {prefs.theme},
            onSelectionChanged: (s) {
              feedback(Cue.tap);
              prefs.set(theme: s.first);
            },
          ),
        ),

        SwitchListTile(
          secondary: const Icon(Icons.volume_up_outlined),
          title: const Text('Sound'),
          subtitle: const Text(
            'Short tones on saving, deleting and moving about. Off by default.',
          ),
          value: prefs.sounds,
          onChanged: (on) {
            prefs.set(sounds: on);
            // Demonstrated with `save`, which is the one with a shape to it.
            // Previewing `tap` would prove almost nothing — it is deliberately
            // the least interesting sound in the set.
            if (on) previewCue(Cue.save, sounds: true, haptics: prefs.haptics);
          },
        ),

        SwitchListTile(
          secondary: const Icon(Icons.vibration),
          title: const Text('Haptics'),
          subtitle: const Text(
            'A tick under your thumb. The scale is the point — a tap is barely '
            'there, a delete you would feel with the phone face-down.',
          ),
          value: prefs.haptics,
          onChanged: (on) {
            prefs.set(haptics: on);
            if (on) previewCue(Cue.delete, sounds: false, haptics: true);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        // At the control desk, which is what this screen is.
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Center(
            child: Scout(
              pose: ScoutPose.settings,
              height: 104,
              motion: [ScoutMotion.breathe],
            ),
          ),
        ),

        const SectionTitle('Your data'),

        /*
          A count, not a quota.

          This said "1 of 25 saved" while the cap was on. It is off now — see
          `capEnforced` — and a screen advertising a limit nothing enforces is
          worse than one that says nothing: somebody would ration themselves
          against a number that does not exist.
        */
        FutureBuilder<int>(
          future: widget.repo.cappedCount(),
          builder: (context, snap) {
            final used = snap.data;
            return ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(used == null ? 'Counting…' : '$used saved'),
              subtitle: const Text(
                'Items, documents and subscriptions together.',
              ),
            );
          },
        ),

        /*
          ── The bin, and why it is a row rather than a tab ─────────────────

          The delete dialog has always promised a thirty-day window. This is
          the way to it, and until it existed the promise was unkeepable.

          Not a sixth tab: a tab is for somewhere you go regularly, and the bin
          is somewhere you go once, urgently, having just deleted the wrong
          passport. The subtitle carries the count so the row itself answers
          "is there anything in there" without being opened.
        */
        FutureBuilder<String>(
          future: _binLine,
          builder: (context, snap) => ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Bin'),
            subtitle: Text(snap.data ?? 'Counting…'),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BinScreen(repo: widget.repo),
                ),
              );
              // The count on this row is now stale, and the restored record
              // has to reappear in the tally above it.
              if (mounted) setState(() {});
            },
          ),
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
        FutureBuilder<Settings>(
          future: widget.repo.settings(),
          builder: (context, snap) {
            final settings = snap.data;
            final on = settings?.notifyEnabled == true;

            return Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Notify me'),
                  subtitle: const Text(
                    'A warning when a warranty is running out or a document '
                    'needs renewing. Set on this phone, sent nowhere.',
                  ),
                  value: on,
                  onChanged: settings == null || _busy ? null : _setNotify,
                ),

                /*
                  ── Why the pending count is on screen ──────────────────────

                  A switch says what was intended. This says what is actually
                  scheduled — and the two come apart in ways nothing else would
                  show: permission revoked in system settings months ago,
                  nothing due inside the sixty-day horizon, or every date
                  already past. "On, 0 pending" is a sentence somebody can ask
                  about; a switch on its own quietly lies.
                */
                if (on)
                  FutureBuilder<int>(
                    future: _pendingCount,
                    builder: (context, count) => Padding(
                      padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                      child: Text(
                        switch (count.data) {
                          null => 'Checking…',
                          0 => 'Nothing due in the next $horizonDays days.',
                          1 => '1 reminder set.',
                          final n => '$n reminders set.',
                        },
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        const SectionTitle('How it looks and feels'),
        _appearance(context),

        const SectionTitle('About'),
        // Not the tap target any more — the heading is. See `_tapTitle` in
        // shell.dart: a version number people tap by accident while reading it
        // is a worse hiding place than a word that does nothing visible.
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Stash it'),
          subtitle: Text(appVersion),
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
            onTap: () => setState(() => rememberUnlocked(false)),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}
