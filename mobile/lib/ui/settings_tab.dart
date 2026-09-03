/// Settings, and the restore that got the data here.
library;

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/backup.dart';
import '../db/repository.dart';
import '../db/restore.dart';
import '../logic/backup_progress.dart';
import '../logic/bin.dart';
import '../logic/bundle.dart';
import '../billing/current.dart';
import '../logic/contact.dart';
import '../logic/limits.dart';
import '../logic/devmode.dart';
import '../io/auto_backup_run.dart';
import '../io/backup_folder.dart';
import '../io/crash_log.dart';
import '../logic/crash_log.dart';
import '../io/sealed_backup.dart';
import '../io/vault.dart';
import '../logic/vault.dart';
import '../io/csv.dart';
import '../io/pin_widget.dart';
import '../logic/prefs.dart';
import '../logic/reminders.dart';
import '../models/settings.dart';
import '../models/types.dart';
import '../notify/sync.dart';
import 'bin_screen.dart';
import 'confetti.dart';
import 'confirm_delete.dart';
import 'crash_screen.dart';
import 'diagnostics.dart';
import 'folder_probe_screen.dart';
import 'passphrase_sheet.dart';
import 'schedule_screen.dart';
import 'feedback.dart';
import 'parts.dart';
import 'prefs_scope.dart';
import 'privacy.dart';
import 'tour_screen.dart';
import 'pro_badge.dart';
import '../io/card_file.dart';
import 'ask_text.dart';
import 'backup_sheets.dart';
import 'card_arrival_screen.dart';
import 'unlock_sheet.dart';
import 'rooms_screen.dart';
import 'scout.dart';
import 'scout_album.dart';
import 'theme.dart';

const appVersion = '1.19.0';

/*
  ── Asking Settings to go somewhere ─────────────────────────────────────────

  The dashboard's backup line offers a fix — "Back up" — and switching to
  Settings only got somebody as far as the room the fix is in. On a page of
  eight cards that is most of the way to the answer and none of the way to
  the thing they pressed for.

  A notifier rather than a constructor argument, because the widget that knows
  where to go and the widget that can scroll are two tabs apart, with a shell
  in between that rebuilds its children by key. Same shape as `pendingLink`
  for notification taps, and for the same reason: the answer has to survive
  being set before anything able to act on it exists.
*/
enum SettingsAnchor { backup }

final ValueNotifier<SettingsAnchor?> settingsJump =
    ValueNotifier<SettingsAnchor?>(null);

class SettingsTab extends StatefulWidget {
  const SettingsTab({required this.repo, super.key});

  final Repository repo;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String? _status;
  bool _busy = false;

  /// Whether a passphrase is set. Re-read after it changes, not on every
  /// rebuild — it is a platform call into the secure store.
  late Future<bool> _locked = backupsAreLocked();

  /*
    ── Asked once, not on every rebuild ────────────────────────────────────

    Whether the launcher will take a pin request cannot change while the app is
    open — it is a property of the launcher, and swapping launchers restarts
    this process. Held as a future rather than a bool so the card can draw
    itself before the answer lands, which it does in under a frame.
  */
  late final Future<bool> _canPin = canPinWidgets();

  /// Read once and re-read after the crash screen closes, which is the only
  /// thing that changes it from in here.
  Future<List<CrashNote>> _crashes = readCrashes();

  /// What the last test notification did, shown under the button that sent it.
  /// Null until one is sent, which is when the row explains itself instead.
  String? _testedNotification;

  /*
    ── What "something is wrong" should already know ─────────────────────────

    A bug report used to arrive as a sentence and a version number, and every
    question that followed — how many records, is the backup folder still
    granted, did it crash, on what — cost a day each way. All of it is on the
    phone and none of it was in the email.

    So the Problem chip gathers it. Only that chip: a question and an idea are
    not about this phone, and attaching a diagnostic block to "could it do X"
    is noise wearing a lab coat.

    It goes in the BODY, visible, under a rule that says what it is and that
    deleting it is allowed — because the whole email is composed in their own
    mail app and nothing is sent until they press send. That is the same rule
    the mailto link was chosen for in the first place.
  */
  Future<String> _evidence() async {
    final out = StringBuffer();

    try {
      final facts = await gather(
        widget.repo,
        // Not from a MediaQuery: this runs from a button handler and finishes
        // after several awaits, by which time the context that would have
        // supplied it is a promise nobody made. See the note in gather.
        textScale: 1,
      );
      out.writeln(facts.text);
    } catch (e) {
      out.writeln('Diagnostics could not be read: $e');
    }

    try {
      final crashes = await readCrashes();
      if (crashes.isNotEmpty) {
        out
          ..writeln()
          ..writeln('Problems recorded (${crashes.length}), newest first:')
          ..writeln(crashReport(crashes));
      }
    } catch (e) {
      out.writeln('The crash log could not be read: $e');
    }

    return out.toString().trimRight();
  }

  Future<void> _reportProblem() async {
    setState(() => _busy = true);

    try {
      // Gathered before the mail app opens, not after — a compose window that
      // fills in a second later is one somebody has already started typing in.
      final evidence = await _evidence();
      await _open(contactUri(ContactKind.bug, appVersion, evidence: evidence));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /*
    ── The status line expires ─────────────────────────────────────────────

    It used to sit there until something else replaced it, which meant a
    message about a spreadsheet exported ten minutes ago was still under the
    version card while somebody was backing out of Erase everything — a line
    that had nothing to do with what they had just done, at the exact moment
    they most wanted to know what they had just done.

    A confirmation is an event. Rendered as permanent page furniture it stops
    being a confirmation and becomes a claim about the present, and the claim
    goes stale within seconds.
  */
  Timer? _expiry;

  void _say(String? words) {
    if (!mounted) return;

    _expiry?.cancel();
    setState(() => _status = words);
    if (words == null) return;

    _expiry = Timer(const Duration(seconds: 9), () {
      if (mounted) setState(() => _status = null);
    });
  }

  /*
    Asks the launcher, and says what happened.

    There is no way to learn whether somebody accepted the launcher's own
    confirmation — see `pinWidget` — so the line says what was asked rather than
    claiming a widget now exists. A confirmation that might be wrong is worse
    than no confirmation.
  */
  Future<void> _pin(String label, PinnableWidget which) async {
    final asked = await pinWidget(which);
    if (!mounted) return;

    _say(asked
        ? '$label sent to your home screen — confirm it there.'
        : 'Your launcher would not take it. Press and hold the home screen '
            'instead, then choose Widgets.');
  }

  @override
  void initState() {
    super.initState();
    settingsJump.addListener(_jump);

    /*
      And once after the first frame, for the commoner order: the dashboard
      sets the anchor and switches tab in the same breath, so the value is
      already there before this widget exists — and a ValueNotifier does not
      replay. Same two paths as the notification link in `shell.dart`.
    */
    WidgetsBinding.instance.addPostFrameCallback((_) => _jump());
  }

  void _jump() {
    if (settingsJump.value != SettingsAnchor.backup || !mounted) return;
    settingsJump.value = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final node = _backupKey.currentContext;
      if (node == null || !mounted) return;

      Scrollable.ensureVisible(
        node,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        // A little off the top rather than flush against it, so the card does
        // not read as the first thing on the page and hide that there is more
        // above it.
        alignment: 0.08,
      );

      setState(() => _lit = true);
      _unlight?.cancel();
      _unlight = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _lit = false);
      });
    });
  }

  @override
  void dispose() {
    settingsJump.removeListener(_jump);
    _unlight?.cancel();
    _expiry?.cancel();
    super.dispose();
  }

  /// The run of taps on the version number, which opens the developer tools.
  TapState _taps = noTaps;

  /// And the separate run on Scout, which opens his album. Two hidden things
  /// wanting two different audiences want two different gestures — see the
  /// note on `_pokeScout`.
  TapState _pokes = noTaps;

  void _pokeScout() {
    setState(() => _pokes = tap(_pokes, DateTime.now()));

    // A tick on every one, and the fanfare on the tenth. Somebody who taps him
    // twice has felt the app notice, which is the only hint offered — and the
    // payoff has to sound like a payoff, not like a file saving.
    feedback(unlocked(_pokes) ? Cue.unlock : Cue.tap);

    if (!unlocked(_pokes)) return;

    setState(() => _pokes = noTaps);

    /*
      Both after the frame that reset the run.

      A route pushed from inside a gesture handler that has just called
      `setState` races the rebuild, and the confetti — a plain overlay insert —
      wins every time, so the album arrived to an empty screen. One frame's
      wait puts them in the right order.
    */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Over the app rather than inside the sheet, so it starts before the
      // album has finished sliding up and the two read as one event.
      dropConfetti(context);
      showScoutAlbum(context);
    });
  }

  void _tapVersion() {
    setState(() {
      _taps = tap(_taps, DateTime.now());
      if (unlocked(_taps)) rememberUnlocked(true);
    });

    // The save cue on the tenth, the ordinary tap on the nine before it — so
    // the run is audible as a run, and the thing that opens sounds different
    // from the thing that counts.
    feedback(unlocked(_taps) ? Cue.save : Cue.tap);
  }

  Future<void> _restore() async {
    _say(null);
    setState(() => _busy = true);

    // Declared out here rather than beside the code that fills it, because the
    // `finally` that deletes it is out here too — and it is the size of the
    // whole backup, so leaving one behind is not a small mistake.
    File? scratch;

    try {
      /*
        ── Neither the bytes nor the copy ────────────────────────────────────

        `withData` is off deliberately. With it on, the picker reads the whole
        file on the Java side and hands the bytes across the platform channel —
        and a backup with seventy-six photographs in it killed the process
        outright, natively, with nothing Dart could catch.

        `withReadStream` is on for a related reason. Without it the picker
        still copies the whole file into this app's cache before returning a
        path, and for a backup chosen from Google Drive that copy is a
        download: on a 185 MB backup, a silent minute with the button greyed
        out and the settings page showing, before any progress sheet existed.

        A stream instead, copied below where the bytes can be counted.
      */
      final picked = await FilePicker.platform.pickFiles(withReadStream: true);
      final files = picked?.files ?? const <PlatformFile>[];
      if (files.isEmpty) return;

      final chosen = files.first;
      final stream = chosen.readStream;
      if (stream == null) return;

      // The picker is a whole other screen and somebody can leave this tab
      // while it is up. Nothing below may touch a context that has gone.
      if (!mounted) return;

      var wasLocked = false;

      /*
        ── All three steps inside the one sheet ──────────────────────────────

        Unlocking, then inflating and hashing, then writing. Every one of them
        used to happen with nothing on screen or behind a bar that never moved:
        the decryption ran before the sheet opened, and the parse ran on the
        isolate that draws the screen. Thirty seconds of a phone that looked
        broken.

        `openBackupFile` sniffs the file. A plain zip from any version this app
        has ever had goes straight through; a sealed one is opened with the
        passphrase held on this phone, and only if THAT fails is anybody asked
        to type one — the case that matters, a backup restored onto a new phone.
      */
      final result = await runWithAcorns<RestoreResult>(
        context,
        title: 'Putting everything back',
        job: (onStep) async {
          /*
            The download, counted.

            This is the one part of a restore that can report honestly — a
            known number of bytes arriving one buffer at a time — and it is
            also the longest part when the backup lives in the cloud.
          */
          onStep(BackupProgress(
            BackupStage.fetching,
            total: chosen.size,
          ));

          final dir = await getTemporaryDirectory();
          scratch = File(p.join(dir.path, 'restoring.stashit'));

          final sink = scratch!.openWrite();
          var got = 0;
          var said = 0;

          try {
            /*
              `addStream` rather than a loop of `add`, so the sink can push
              back. Adding without awaiting lets a fast download outrun the
              disk and buffer the difference, which on a backup this size is
              the whole file in memory — the thing the streaming was for.

              And a report every two megabytes rather than every buffer: the
              buffers are 64 KB, so the loop would otherwise rebuild the sheet
              three thousand times to move a bar the width of a hair.
            */
            await sink.addStream(stream.map((buffer) {
              got += buffer.length;

              if (got - said >= 2 * 1024 * 1024 || got == chosen.size) {
                said = got;
                onStep(BackupProgress(
                  BackupStage.fetching,
                  done: got,
                  total: chosen.size,
                ));
              }

              return buffer;
            }));
            await sink.flush();
          } finally {
            await sink.close();
          }

          onStep(const BackupProgress(BackupStage.unlocking));

          /*
            Reading, decrypting, unzipping and hashing, all in one isolate.

            It used to be three: the file was read here, decrypted in an
            isolate, copied back, then copied into another isolate to be
            parsed. Every one of those is the whole backup, and on a large one
            that was the wait rather than the work.
          */
          final opened = await openBackupFile(
            scratch!.path,
            ask: () async {
              if (!mounted) return null;
              return askForPassphrase(context);
            },
          );
          wasLocked = opened.wasLocked;

          onStep(const BackupProgress(BackupStage.restoring));
          final done = await restoreInto(widget.repo.db, opened.bundle);

          onStep(const BackupProgress(BackupStage.done));
          return done;
        },
      );

      if (!mounted) return;
      await showRestoreDone(
        context,
        items: result.items,
        papers: result.papers,
        subscriptions: result.subscriptions,
        files: result.blobs,
      );

      /*
        Still said in the card as well, for somebody who dismissed the sheet
        before reading it — and it names the lock.

        Restoring on the phone that holds the passphrase opens a locked backup
        without asking, which looks exactly like restoring one that was never
        locked. Saying which it was is the only way somebody can tell the lock
        is working.
      */
      _say('Restored ${result.items} items, ${result.papers} documents, '
          '${result.subscriptions} subscriptions and ${result.blobs} files'
          '${wasLocked ? ', from a locked backup.' : '.'}'
          // The other direction has had a breakdown behind the developer panel
          // for three releases, and it is how eighty seconds was found. This
          // one had none, and cost twenty that nobody could account for.
          '${unlocked(_taps) && lastVaultTimings != null ? '\n\n$lastVaultTimings' : ''}');
    } on VaultProblem catch (e) {
      // A wrong passphrase, or a file that did not survive the trip. Both
      // arrive here already written for a person — see `unlockBackup`.
      _say(e.message);
    } on BundleError catch (e) {
      // Every refusal already carries a sentence written for a person.
      _say(e.message);
    } catch (e) {
      _say('That did not work: $e');
    } finally {
      // This app's own copy of the backup, the size of the whole thing. It
      // goes whatever happened.
      if (scratch != null) {
        await scratch!.delete().catchError((_) => scratch!);
      }

      if (mounted) setState(() => _busy = false);
    }
  }

  /*
    ── Taking in a card somebody sent ────────────────────────────────────────

    Deliberately its own action, sitting apart from Restore, and worded so the
    two cannot be mistaken for each other. Restore REPLACES what is on the
    phone; this ADDS to it. They are one row apart in a list, so the difference
    has to be in the words rather than in the reader's memory.

    Android's file association for `.stashcard` is registered in the manifest,
    but it cannot be relied on: a card arriving through a messaging app is a
    `content://` URI that frequently carries no filename to match against, and
    the sending app chooses the MIME type it declares. So the association is a
    convenience and THIS is the route that always works.
  */
  Future<void> _addCard() async {
    _say(null);
    setState(() => _busy = true);

    try {
      // Same reasoning as `_restore` for leaving `withData` off.
      final picked = await FilePicker.platform.pickFiles();
      final files = picked?.files ?? const <PlatformFile>[];
      final path = files.isEmpty ? null : files.first.path;
      if (path == null) return;

      final bytes = await File(path).readAsBytes();
      final card = parseCardBytes(bytes);

      if (!mounted) return;
      final added =
          await showCardArrival(context, repo: widget.repo, card: card);

      if (added != null && added > 0) {
        _say('Added $added ${added == 1 ? 'thing' : 'things'} to your stash.');
      }
    } on BundleError catch (e) {
      // Including the one that says "that is a backup, not a card".
      _say(e.message);
    } catch (e) {
      _say('That did not work: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* ------------------------------------------------------- the lock */

  /// Sets or replaces the passphrase.
  ///
  /// Nothing already written is re-encrypted. Old files keep opening with the
  /// old passphrase, and the app says so rather than quietly leaving somebody
  /// with a folder of files they can no longer read.
  Future<void> _setPassphrase() async {
    final was = await backupPassphrase();
    if (!mounted) return;

    final phrase = await askForNewPassphrase(context);
    if (phrase == null || !mounted) return;

    await setBackupPassphrase(phrase);
    if (!mounted) return;

    setState(() => _locked = backupsAreLocked());
    _say(was == null
        ? 'Backups are locked from now on. Write the passphrase down.'
        : 'Passphrase changed. Backups already written still open with the '
            'old one.');
  }

  /// Turns it off.
  Future<void> _clearPassphrase() async {
    /*
      Refused while a document scan exists — see `whyKeepTheLock`.

      Checked here rather than by hiding the row, because a control that
      vanishes teaches nothing. This one stays, is pressed, and answers with
      the reason and the way out.
    */
    final keep = whyKeepTheLock(await widget.repo.paperScanCount());
    if (keep != null) {
      if (!mounted) return;
      feedback(Cue.error);
      _say(keep);
      return;
    }

    if (!mounted) return;

    final sure = await confirmUnlockBackups(context);
    if (!sure || !mounted) return;

    await clearBackupPassphrase();
    if (!mounted) return;

    setState(() => _locked = backupsAreLocked());
    _say('Backups are no longer locked. Ones already written stay locked.');
  }

  /* --------------------------------------------- the automatic backup */

  /// Asks Android for a folder, and remembers whichever one comes back.
  ///
  /// The picker is the platform's, so what it offers is whatever that phone
  /// has: internal storage, an SD card, and any cloud app that publishes a
  /// document tree. The app does not know which is which and does not need to.
  Future<void> _chooseFolder() async {
    _say(null);

    final tree = await pickBackupFolder();
    // Cancelled. Not a failure, and saying so would be the app complaining
    // that somebody changed their mind.
    if (tree == null || !mounted) return;

    final label = await folderLabel(tree);
    if (!mounted) return;

    /*
      Guarded, because an unguarded failure here says nothing at all.

      The future is not awaited by the row that calls it, so a settings write
      that threw produced a screen which simply did not change — the same
      picture as a picker somebody backed out of.
    */
    try {
      await _saveSettings((s) => s.copyWith(
            backupFolder: tree,
            backupFolderLabel: label ?? 'the folder you chose',
            clearAutoBackupError: true,
          ));
    } catch (e) {
      if (mounted) _say('That folder could not be saved: $e');
      return;
    }

    /*
      One straight away, rather than waiting for the interval.

      It proves the folder works while somebody is still looking at the screen
      they set it up on — and the alternative is telling them it is all
      arranged and finding out a fortnight later that it was not.
    */
    if (!mounted) return;
    setState(() => _busy = true);

    try {
      final done = await backUpToFolder(widget.repo);
      if (!mounted) return;

      _say(done.wrote
          ? 'Backed up to ${label ?? 'the folder'}. '
              'It will happen again on its own.'
          : done.problem ?? 'That did not work.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  /// Turns it off, and hands the permission back.
  ///
  /// Releasing the grant matters: an app that keeps write access to a folder it
  /// has stopped using is an app asking to be distrusted, and the person who
  /// switched this off is exactly the person who would mind.
  Future<void> _stopAutoBackup() async {
    final settings = await widget.repo.settings();
    final tree = settings.backupFolder;
    if (tree == null) return;

    await forgetBackupFolder(tree);
    await _saveSettings((s) => s.copyWith(
          clearBackupFolder: true,
          clearAutoBackupError: true,
        ));

    if (mounted) {
      _say('Automatic backups off. Nothing already written was deleted.');
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
    _say(null);
    setState(() => _busy = true);

    try {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, backupFileName()));
      if (!mounted) return;

      /*
        Behind a sheet with a moving bar, and written straight to the file.

        The bytes used to come back here so that this could write them out —
        which meant the whole backup crossed an isolate boundary twice more
        than it had to, and on a large collection that was most of the wait.
        `exportSealedBackupToFile` zips, seals and writes in one isolate.
      */
      await runWithAcorns<void>(
        context,
        title: 'Gathering everything',
        // Sealed if a passphrase is set. The same call the automatic backup
        // makes, so the two cannot disagree about whether a file is locked.
        job: (onStep) => exportSealedBackupToFile(
          widget.repo.db,
          path: file.path,
          onStep: onStep,
        ),
      );

      if (!mounted) return;

      // share_plus 10's API. Version 11 replaced this with
      // `SharePlus.instance.share(ShareParams(...))`; when the dependency
      // moves, so does this line and nothing else.
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Stash it backup',
      );

      final kb = (await file.length() / 1024).round();
      _say('Made ${backupFileName()} — $kb KB. '
          'Keep it somewhere that is not this phone.');
    } catch (e) {
      _say('That did not work: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /*
    ── Held, not recomputed ────────────────────────────────────────────────

    These were getters returning a fresh `Future` on every build, which meant
    every `setState` on this screen re-ran all four — and one of them is
    `syncReminders`, which cancels every pending notification and schedules
    them again through a platform channel.

    So flipping a switch cost a database read, a blob scan and a full
    reschedule, and the screen visibly stuttered. They are computed once and
    refreshed by `_refresh` when something actually changes them.
  */
  late Future<Settings> _settings = widget.repo.settings();
  late Future<String> _bin = _readBinLine();
  late Future<String> _size = _readSize();

  /// How many things are saved, for the free-tier row.
  late Future<int> _count = widget.repo.cappedCount();

  /// The number beside "Rooms". Held, not asked for inside `build` — a future
  /// created there is a new query every time anything on this page is tapped,
  /// which is the habit the note above is about.
  late Future<List<Room>> _rooms = widget.repo.rooms();

  /// Where "Back up" from the dashboard lands.
  final GlobalKey _backupKey = GlobalKey();

  /// Briefly washed gold after a jump, so the eye knows where it arrived.
  /// Landing mid-page with nothing marked is a scroll that reads as an
  /// accident rather than an answer.
  bool _lit = false;

  Timer? _unlight;

  void _refresh({bool reminders = false}) {
    if (!mounted) return;
    setState(() {
      _settings = widget.repo.settings();
      _bin = _readBinLine();
      _size = _readSize();
      _count = widget.repo.cappedCount();
      _rooms = widget.repo.rooms();
    });

    /*
      Not awaited and not held.

      There used to be a "3 reminders set" line under the notify switch, and
      this future fed it. The line is gone, but the reschedule still has to
      happen — turning notifications off has to actually cancel the sixty days
      of pending ones, or they keep arriving.
    */
    if (reminders) unawaited(syncReminders(widget.repo));
  }

  /// "3 things · last day", or "Nothing here".
  ///
  /// It used to build that sentence by loading every deleted item, document
  /// and subscription as objects — three full reads out of an encrypted
  /// database, on the tab everybody notices being slow, to print a number and
  /// a countdown. `binGlance` asks SQLite for exactly those two facts.
  Future<String> _readBinLine() async {
    final (count, oldest) = await widget.repo.binGlance();
    return binLine(count: count, oldest: oldest);
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

      if (!mounted) return;
      // The one place a reschedule is actually warranted: the switch that
      // decides whether there is a schedule at all.
      _refresh(reminders: true);
      _say(wanted && !enabled
          ? 'Android is holding notifications for Stash it. Turn them on in '
              'the phone\'s app settings and this switch will follow.'
          : null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Whether this phone has a fingerprint reader or a face unlock worth using.
  ///
  /// Probed once. A dead switch invites the question "why will this not work"
  /// rather than answering it, so on a device with no sensor the whole Lock
  /// card is absent instead.
  late final Future<bool> _biometricsAvailable = _probeBiometrics();

  Future<bool> _probeBiometrics() async {
    try {
      final auth = LocalAuthentication();
      return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /*
    ── The lock guards the APP, not the data ─────────────────────────────────

    The database is encrypted with a key in this handset's Keystore, and that
    key is released to this app whether or not somebody has just put a finger
    on the sensor. So this stops a person picking up an unlocked phone; it does
    not stop somebody with the phone and a laptop.

    Saying so plainly beside the switch is the whole point. A lock that people
    believe is stronger than it is, is worse than no lock — it is the reason
    they stop taking backups.
  */
  Future<void> _setLock(bool wanted) async {
    if (!wanted) {
      await _saveSettings((s) => s.copyWith(biometricLock: false));
      feedback(Cue.delete);
      return;
    }

    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Confirm it is you, so the lock can be switched on',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!ok) {
        _say('The device did not confirm. The lock is still off.');
        return;
      }
    } catch (e) {
      _say('This phone would not run the check: $e');
      return;
    }

    await _saveSettings((s) => s.copyWith(biometricLock: true));
    feedback(Cue.save);

    /*
      This sentence was a lie for sixty versions.

      Nothing read `biometricLock`. The prompt above — the one confirming the
      switch — was the only check the app ever ran, and because it looks
      exactly like the lock working, it read as proof that it did. See
      lib/ui/lock_gate.dart, which is now the thing that makes it true.

      It says "put down" rather than "closed" on purpose: the gate allows a
      thirty-second grace so the camera, the file picker and the share sheet do
      not each cost a fingerprint.
    */
    _say('Locked. You will be asked when you open the app, and if you put the '
        'phone down for a while.');
  }

  /// Read, change, write. Every setting on this screen goes through here so
  /// there is one place that remembers to rebuild afterwards.
  Future<void> _saveSettings(Settings Function(Settings) change) async {
    final now = await widget.repo.settings();
    await widget.repo.saveSettings(change(now));
    _refresh();
  }

  Future<void> _open(Uri uri) async {
    feedback(Cue.tap);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _say('No app on this phone could open that.');
    }
  }

  /*
    ── Nine in the morning, or whenever suits ──────────────────────────────

    Every reminder used to fire at `defaultSendHour` and nothing exposed it —
    which is fine until somebody is asleep at nine, or driving at nine, and the
    app's one output arrives at the wrong moment every single day.

    Six to ten at night, in whole hours. Anything outside that is a reminder
    somebody will not act on, and a minute field would invite 09:07 and then a
    complaint that an inexact alarm did not honour it.
  */
  static String _hourLabel(int h) {
    final suffix = h < 12 ? 'am' : 'pm';
    final twelve = h % 12 == 0 ? 12 : h % 12;
    return '$twelve$suffix';
  }

  static int _hourOf(String label) {
    final pm = label.endsWith('pm');
    final twelve = int.parse(label.replaceAll(RegExp(r'[^0-9]'), ''));
    final base = twelve % 12;
    return pm ? base + 12 : base;
  }

  /// Three files, shared together.
  ///
  /// Not a backup and not offered as one — see lib/io/csv.dart. This is the
  /// version an insurer or a solicitor can open.
  Future<void> _exportCsv() async {
    _say(null);
    setState(() => _busy = true);

    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);

      final files = <XFile>[];
      Future<void> write(String name, String body) async {
        final f = File(p.join(dir.path, 'stash-it-$name-$stamp.csv'));
        await f.writeAsString(body);
        files.add(XFile(f.path));
      }

      await write('items', itemsCsv(await widget.repo.activeItems()));
      await write('documents', papersCsv(await widget.repo.activePapers()));
      await write('subscriptions',
          subscriptionsCsv(await widget.repo.activeSubscriptions()));

      await Share.shareXFiles(files, subject: 'Stash it — spreadsheets');

      // Deliberately does NOT stamp `lastBackupAt`. A spreadsheet holds no
      // photographs and cannot be restored, so counting it as a backup would
      // silence the reminder on the strength of a file that does not do the
      // job the reminder is about.
      _say('Three files: items, documents, subscriptions.');
    } catch (e) {
      _say('That did not work: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /*
    ── Erasing everything, and why it is offered at all ────────────────────

    Without it the only way to start over is to uninstall — and uninstalling is
    what people actually do, which loses the app rather than the data and takes
    the notification permission with it.

    Two confirmations, because this is the one action in the app with no bin,
    no undo and no thirty days. The second asks for the word, so it cannot be
    reached by two taps in the same place.
  */
  Future<void> _erase() async {
    _say(null);

    final sure = await confirmDelete(
      context,
      name: 'everything in Stash it',
      permanent: true,
    );
    if (!sure || !mounted) return;

    final typed = await _askErase(context);
    if (typed != true || !mounted) return;

    setState(() => _busy = true);
    await widget.repo.eraseEverything();
    await syncReminders(widget.repo);

    if (!mounted) return;
    setState(() => _busy = false);
    _say('Erased. Restore from a backup if you have one.');
    _refresh();
  }

  Future<void> _share() async {
    feedback(Cue.tap);
    await Share.share(
      'Stash it — warranties, documents and subscriptions, all on your phone '
      'and nowhere else. $storeUrl',
      subject: 'Stash it',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    final prefs = PrefsScope.of(context);

    /*
      ── The heading does not wait for the database ────────────────────────

      The whole screen used to be inside the `FutureBuilder`, so arriving here
      meant a centred spinner where the page should be, and then the page —
      one read's worth of nothing, on the tab people already say is slow.

      The title and Scout owe nothing to the settings row, so they are drawn
      on the first frame. Only the cards, which genuinely need the answer,
      wait for it.
    */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /*
          ── Outside the scroller, like the greeting on Home ──────────────

          The subtitle is a caption on the heading, and a caption that
          scrolls away from the thing it captions is just the first row of
          the list. Scout goes with it because he is standing next to the
          title, not next to Appearance.

          This is the same fix the dashboard had: chrome above, content
          below, and the line between them in one place per screen.
        */
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            // The text sits at the top of the row, tight under the title,
            // and Scout hangs below it. Centred, he was 132 tall and the
            // subtitle was being pushed down to his middle — a caption on
            // the heading floating halfway down the screen.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'How Stash it behaves.',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -0.4,
                    color: c.muted,
                  ),
                ),
              ),
              /*
                ── Ten taps on Scout ──────────────────────────────────────

                It was ten taps on the word "Settings", which is a fine
                hiding place and a poor invitation: a heading is the one
                thing on a screen nobody suspects of doing anything.

                A mascot is the opposite. He is already the only object on
                the screen that looks alive, and poking an animal to see
                what happens is a thing people do without being asked —
                which is exactly the behaviour an easter egg needs.

                Every tap ticks, so somebody who tries it twice learns the
                app noticed. That tick is the whole invitation.
              */
              GestureDetector(
                // Named so the test can poke him without guessing which
                // Scout on the screen is the one that answers.
                key: const Key('scout-easter-egg'),
                behavior: HitTestBehavior.opaque,
                onTap: _pokeScout,
                child: const Scout(
                  pose: ScoutPose.settings,
                  height: 132,
                  motion: [ScoutMotion.breathe],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Settings>(
            future: _settings,
            builder: (context, snap) {
              final settings = snap.data;

              // Empty, not a spinner. The read is a few milliseconds and a
              // spinner that appears and vanishes inside one blink is more
              // movement than waiting was.
              if (settings == null) return const SizedBox.shrink();

              return _cards(context, c, settings, prefs);
            },
          ),
        ),
      ],
    );
  }

  Widget _cards(
    BuildContext context,
    StashColors c,
    Settings settings,
    PrefsController prefs,
  ) {
    return ListView(
      /*
        ── 24, not 120 ─────────────────────────────────────────────────

        The 120 was clearance for the floating "Stash it" pill, so the last
        row could not hide under it. That button is not on this screen any
        more, and the padding stayed — which left a hundred pixels of
        nothing to scroll past after the share button, on the one screen
        people reach the bottom of.
      */
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        /* ---------------------------------------------------- go pro */

        /*
              ── Why this is first, and why it looks different ─────────────

              It was ninth of ten, styled as a card like every other card,
              titled "Free tier" — a status row about a limit rather than an
              offer. Somebody who wanted to pay had to scroll past theme,
              sounds, notifications, the lock, reminders, backup and the bin
              to find out how, and nothing on the way down suggested there
              was anything to find.

              So it moved to the top and stopped pretending to be a setting.
              Gold fill, gold edge, and the only button on this screen that
              is not a row — because it is the one thing here that is not a
              preference, and a page of identical cards is a page where the
              one that matters is invisible.

              It disappears entirely once unlocked. A card saying "unlimited"
              to somebody who has already paid is a receipt, and a receipt is
              what the Play Store is for.
            */
        FutureBuilder<Settings>(
          future: _settings,
          builder: (context, settingsSnap) {
            final entitlements = settingsSnap.data?.entitlements;
            if (entitlements == null) return const SizedBox.shrink();

            /*
                  ── Paid, so the offer becomes a receipt ────────────────────

                  This used to return nothing at all, which meant the single
                  most visible consequence of paying was that something
                  disappeared off the top of Settings. The card that had been
                  asking for money every time you opened the screen simply
                  stopped existing, and there was nowhere in the app that
                  acknowledged the purchase had happened.

                  It keeps the same slot and the same shape — gold wash, gold
                  edge, first thing on the page — so what changes is the
                  sentence rather than the layout.
                */
            if (entitlements.proUnlock) {
              return _ProCard(
                onTap: () async {
                  final count = await _count;
                  if (!context.mounted) return;
                  await showUnlock(
                    context,
                    repo: widget.repo,
                    billing: appBilling,
                    count: count,
                    owned: true,
                  );
                },
              );
            }

            return FutureBuilder<int>(
              future: _count,
              builder: (context, countSnap) {
                final count = countSnap.data;
                if (count == null) return const SizedBox.shrink();

                final left = remainingFree(count, entitlements) ?? 0;
                final full = left == 0;

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                  decoration: BoxDecoration(
                    color: c.washGold,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: c.gold.withValues(alpha: 0.45)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.workspace_premium_outlined,
                              size: 20, color: c.gold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Go Pro',
                              style: TextStyle(
                                fontFamily: fontDisplay,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: c.text,
                              ),
                            ),
                          ),
                          Text(
                            'One payment',
                            style: TextStyle(
                              fontFamily: fontBody,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.gold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$count', style: figureStyle(c, size: 34)),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 5),
                            child: Text(
                              'of $freeItemLimit saved',
                              style: TextStyle(
                                fontFamily: fontBody,
                                fontSize: 14,
                                color: c.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      /*
                            A bar, because "14 of 20" is a fact and a bar is a
                            feeling — and the feeling is the useful half of the
                            answer here. It turns amber inside the last five,
                            the same threshold `shouldMentionCap` uses, so the
                            colour and the wording can never disagree about
                            what "nearly full" means.
                          */
                      /*
                            Filled rather than drawn.

                            The bar is the one thing on this card that is a
                            quantity rather than a sentence, and it sits under
                            a number that says the same thing. Arriving full
                            made it read as a background shape; filling makes
                            it read as a measurement of something.

                            `TweenAnimationBuilder` also handles the case that
                            matters more than first paint: saving an item
                            nudges the bar along instead of jumping it, so the
                            movement is legible as "that one you just added".
                          */
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.pill),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: (count / freeItemLimit).clamp(0.0, 1.0),
                          ),
                          duration: const Duration(milliseconds: 850),
                          curve: Curves.easeOutCubic,
                          builder: (context, filled, _) =>
                              LinearProgressIndicator(
                            value: MediaQuery.of(context).disableAnimations
                                ? (count / freeItemLimit).clamp(0.0, 1.0)
                                : filled,
                            minHeight: 7,
                            backgroundColor: c.field,
                            valueColor: AlwaysStoppedAnimation(
                              full
                                  ? c.ember
                                  : (left <= warnWhenLeft ? c.honey : c.gold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        full
                            ? 'Full. Nothing is lost and nothing is hidden — '
                                'the limit only stops new ones.'
                            : 'Unlimited items, documents and subscriptions '
                                'for one payment. No subscription, no ads, '
                                'and nothing leaves your phone.',
                        style: hintStyle(c),
                      ),
                      const SizedBox(height: 14),
                      _BigButton(
                        label: 'Go Pro',
                        icon: Icons.lock_open_outlined,
                        onTap: () async {
                          final unlocked = await showUnlock(
                            context,
                            repo: widget.repo,
                            billing: appBilling,
                            count: count,
                          );
                          if (unlocked) _refresh();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),

        /* ------------------------------------------------ appearance */

        _Card(
          title: 'Appearance',
          children: [
            _SegRow<ThemeChoice>(
              value: prefs.theme,
              options: const [
                (ThemeChoice.light, 'Light'),
                (ThemeChoice.dark, 'Dark'),
                (ThemeChoice.system, 'Auto'),
              ],
              onChange: (v) => prefs.set(theme: v),
            ),
            _Rule(c),
            _SwitchRow(
              label: 'Sounds',
              value: prefs.sounds,
              onChanged: (on) {
                prefs.set(sounds: on);
                // Demonstrated with `save`, the one with a shape to it.
                // Previewing `tap` would prove almost nothing — it is
                // deliberately the least interesting sound in the set.
                if (on) {
                  previewCue(Cue.save, sounds: true, haptics: prefs.haptics);
                }
              },
            ),
            _Rule(c),
            _SwitchRow(
              label: 'Haptics',
              value: prefs.haptics,
              onChanged: (on) {
                prefs.set(haptics: on);
                if (on) previewCue(Cue.delete, sounds: false, haptics: true);
              },
            ),

            /*
              ── The one part of the app that lives outside it ────────────────

              Nobody discovers a widget from inside an app: adding one means
              long pressing an empty patch of home screen, finding a picker
              every launcher draws differently, and scrolling to S. So the app
              says the three exist, and — where the launcher allows it, which
              is most of them since Android 8 — offers to place one rather than
              explaining how.

              A card of its own before this, with a paragraph and three rows
              each carrying a line of description. Three names and three
              buttons say the same thing in a fifth of the height, and the
              names were always doing the work: "Coming up", "The ring" and
              "Quick add" describe themselves.

              Here rather than anywhere else because a widget IS appearance —
              it is what the app looks like when nobody has opened it.
            */
            const SizedBox(height: 14),
            _Rule(c),
            const SizedBox(height: 10),
            Text(
              'Home screen widgets',
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<bool>(
              future: _canPin,
              builder: (context, probe) {
                final canPin = probe.data ?? false;

                Widget chip(String label, PinnableWidget which) => Expanded(
                      child: _ContactChip(
                        label: label,
                        onTap: canPin ? () => _pin(label, which) : null,
                      ),
                    );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // `Expanded` so all three are the same width whatever the
                    // words are, exactly as the contact chips below.
                    Row(
                      children: [
                        chip('Coming up', PinnableWidget.comingUp),
                        const SizedBox(width: 8),
                        chip('The ring', PinnableWidget.ring),
                        const SizedBox(width: 8),
                        chip('Quick add', PinnableWidget.quickAdd),
                      ],
                    ),

                    /*
                      The only line under this section, and only on a launcher
                      that will not take a widget by request. Without it the
                      three chips are dead controls with no explanation, which
                      is worse than a sentence.
                    */
                    if (!canPin)
                      _Note(
                        'Press and hold your home screen, choose Widgets, and '
                        'scroll to Stash it.',
                        c,
                      ),
                  ],
                );
              },
            ),
          ],
        ),

        /* ------------------------------- notifications, then the lock */

        _Card(
          title: 'Push Notifications',
          trailing: Switch(
            // On unless somebody has said otherwise. Null is a record
            // written before the field existed and is not a decision — see
            // `notifyEnabled` in models/settings.dart.
            value: settings.notifyEnabled ?? true,
            onChanged: _busy
                ? null
                : (v) {
                    feedback(v ? Cue.expand : Cue.collapse);
                    _setNotify(v);
                  },
          ),
          children: [
            if (settings.notifyEnabled ?? true)
              _PickRow(
                label: 'What time',
                value: _hourLabel(settings.reminderHour ?? defaultSendHour),
                options: [for (var h = 6; h <= 22; h++) _hourLabel(h)],
                onChange: (v) => _saveSettings(
                  (s) => s.copyWith(reminderHour: _hourOf(v)),
                ).then((_) => _refresh(reminders: true)),
              ),
          ],
        ),

        FutureBuilder<bool>(
          future: _biometricsAvailable,
          builder: (context, probe) {
            if (probe.data != true) return const SizedBox.shrink();

            /*
                  The whole card is the control.

                  It was a heading called "Lock", a row that repeated it as
                  "Unlock with biometrics", and four lines explaining what the
                  lock does not cover — three pieces of furniture around one
                  switch. The explanation lives in the privacy sheet with the
                  rest of what is and is not protected; the switch says what it
                  does in its own title.
                */
            return _Card(
              title: 'Biometrics to unlock',
              trailing: Switch(
                value: biometricLockOf(settings),
                onChanged: _busy
                    ? null
                    : (v) {
                        feedback(v ? Cue.expand : Cue.collapse);
                        _setLock(v);
                      },
              ),
              children: const [],
            );
          },
        ),

        /* ------------------------------------------------- your home */

        _Card(
          title: 'Your home',
          children: [
            _FieldRow(
              label: 'Your name',
              note: 'Only used in the greeting.',
              value: settings.displayName ?? '',
              // A placeholder, not a default — nothing is saved until
              // something is typed. "Nuno" was the developer's own name
              // shipping to every user as the example of what a name looks
              // like, which is a small thing that reads as an oversight.
              hint: 'Scout',
              onSubmit: (v) =>
                  _saveSettings((s) => s.copyWith(displayName: v.trim())),
            ),
            _Rule(c),
            _LinkRow(
              label: 'Bin',
              trailing: FutureBuilder<String>(
                future: _bin,
                builder: (context, snap) => Text(
                  snap.data ?? '',
                  style: TextStyle(
                      fontFamily: fontBody, fontSize: 12, color: c.muted),
                ),
              ),
              onTap: () async {
                feedback(Cue.tap);
                await showBin(context, widget.repo);
                if (mounted) setState(() {});
              },
            ),
            _Rule(c),
            _LinkRow(
              label: 'Rooms',
              note: 'Where things live, in your own order.',
              trailing: FutureBuilder<List<Room>>(
                future: _rooms,
                builder: (context, snap) => Text(
                  snap.data == null ? '' : '${snap.data!.length}',
                  style: TextStyle(
                      fontFamily: fontBody, fontSize: 12.5, color: c.muted),
                ),
              ),
              onTap: () async {
                await showRooms(context, widget.repo);
                _refresh();
              },
            ),
            _Rule(c),
            _SegRow<RoomsView>(
              label: 'Rooms start',
              value: prefsFrom(settings).roomsView,
              options: const [
                (RoomsView.collapsed, 'Collapsed'),
                (RoomsView.expanded, 'Expanded'),
              ],
              onChange: (v) => _saveSettings((s) => s.copyWith(roomsView: v)),
            ),
            _Rule(c),
            _PickRow(
              label: 'Currency',
              note: 'New items only.',
              value: settings.currency,
              options: currencies,
              onChange: (v) => _saveSettings((s) => s.copyWith(currency: v)),
            ),
            /*
                  ── "Warn me before a warranty ends" is not here ────────────

                  It moved to the item form, where it belongs: a roof and a
                  kettle do not deserve the same notice, and thirty days is
                  useless for anything needing a quote and a tradesman.

                  `reminderOffsetsDays` still exists and `endingSoonDays` still
                  reads it — it is the fallback for an item that has not chosen
                  — but a global control for a per-item decision was a setting
                  that would be wrong for most of the collection whatever it
                  was set to.
                */
          ],
        ),

        /* ---------------------------------------------------- backup */

        /*
              Keyed and washable, because the dashboard's backup line sends
              people straight here — see `settingsJump`. The wash fades after
              a beat: it says "this is the one" and then gets out of the way,
              rather than leaving a highlight somebody has to work out how to
              clear.
            */
        KeyedSubtree(
          key: _backupKey,
          /*
                ── The twelve pixels the wash costs ────────────────────────

                The wrapper's margin and the card's own inset ADD. Left as
                12 and 16 this card sat 28 from the edge while every other
                card sat at 16 — visibly narrower, and the sort of thing you
                see immediately and cannot name.

                So the twelve comes out of the card instead: 12 outside plus
                4 inside is the same 16, and the difference is a ring of gold
                in the gap rather than a band across the page.
              */
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            // Gold above comes free from the card's own 10px top padding.
            // Below there is none, so it is added here — as padding, which
            // grows the wash, rather than as margin, which would move the
            // card.
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _lit ? c.washGold : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.lg + 6),
            ),
            child: _Card(
              inset: 4,
              title: 'Backup',
              trailing: Text(
                settings.lastBackupAt == null
                    ? 'Never'
                    : settings.lastBackupAt!.toIso8601String().substring(0, 10),
                style: TextStyle(
                  fontFamily: fontMono,
                  fontFeatures: tabularFigures,
                  fontSize: 12,
                  color: c.muted,
                ),
              ),
              children: [
                /*
                  ── Automatic backups first, and almost nothing said ─────────

                  This card had an opening paragraph, a segmented row, two
                  status rows and five buttons, six of which carried two or
                  three lines of explanation. Every sentence was true and the
                  card was unreadable: the one feature that protects somebody
                  without their doing anything sat fourth, below an interval
                  and a passphrase, in the same weight as exporting a
                  spreadsheet.

                  So the folder comes first and everything else is ordered
                  behind it, and a note now has to earn its place. The test
                  applied to each one: does this change what somebody DOES? If
                  it only describes what they can already see, it is gone.

                  Three survived. "Replaces what is on the phone" prevents an
                  import somebody cannot undo. "Adds to what you have" is the
                  same sentence for the opposite case, and the two are one row
                  apart. And the warning that an unlocked backup is readable is
                  shown only while backups ARE unlocked, which is the only time
                  it is news.
                */
                FutureBuilder<bool>(
                  future: _locked,
                  // Locked until told otherwise. The alternative default puts
                  // "anyone who opens that folder can read this" on screen for
                  // one frame on every build, to people who locked theirs
                  // months ago.
                  builder: (context, snap) => _FolderRow(
                    settings: settings,
                    locked: snap.data ?? true,
                    busy: _busy,
                    onChoose: _chooseFolder,
                    onStop: _stopAutoBackup,
                  ),
                ),
                const SizedBox(height: 4),
                _SegRow<int>(
                  // Labelled now that the paragraph above it is gone. Weekly,
                  // Monthly, Quarterly, Never means nothing on its own, and it
                  // sets two things at once — how often one is written and how
                  // often somebody is nudged when none has been.
                  label: 'How often',
                  value: settings.backupReminderDays,
                  options: [
                    for (final choice in backupReminderChoices)
                      (choice.days!, choice.label),
                  ],
                  onChange: (days) => _saveSettings(
                      (s) => s.copyWith(backupReminderDays: days)),
                ),

                /*
                  The lock, under the destination rather than over it.

                  It used to sit above, so that "is this readable by anyone who
                  finds it" was asked before "where does it go". That was the
                  right question in the wrong place: nobody sets a passphrase
                  on a feature they have not turned on yet. The warning that
                  carries the point moved into the folder row instead, where it
                  appears only while the backups really are unlocked.
                */
                const SizedBox(height: 14),
                _Rule(c),
                FutureBuilder<bool>(
                  future: _locked,
                  builder: (context, snap) => _LockRow(
                    locked: snap.data ?? false,
                    busy: _busy,
                    onSet: _setPassphrase,
                    onClear: _clearPassphrase,
                  ),
                ),
                _Rule(c),

                const SizedBox(height: 12),
                _BigButton(
                  label: 'Back up now',
                  // How much is about to be written out is a fact about this
                  // action, not a separate setting — so it rides on the button.
                  note: _size,
                  onTap: _busy ? null : _backUp,
                ),
                const SizedBox(height: 12),
                _BigButton(
                  label: 'Import from a backup',
                  onTap: _busy ? null : _restore,
                ),
                _Note('Replaces what is on the phone.', c),
                const SizedBox(height: 12),
                _BigButton(
                  label: 'Add a card someone sent',
                  onTap: _busy ? null : _addCard,
                ),
                _Note('Adds to what you have.', c),
              ],
            ),
          ),
        ),

        /*
          ── Not backups, and no longer filing as though they were ────────────

          Exporting a spreadsheet produces something deliberately NOT a backup,
          and erasing everything is the opposite of one. Both sat at the bottom
          of the Backup card because they act on the same data, which is a
          reason to put things near each other and not a reason to call them
          the same thing — and between them they added two more rows and two
          more notes to the longest card on the page.
        */
        _Card(
          title: 'All your data',
          children: [
            _LinkRow(
              label: 'Export as a spreadsheet',
              note: 'Three CSV files. Not a backup.',
              onTap: _busy ? null : _exportCsv,
            ),
            _Rule(c),
            _LinkRow(
              label: 'Erase everything',
              // The one note here that changes what somebody does. What is
              // about to go is listed in the confirmation, which is where a
              // destructive action belongs — this is the warning that gets
              // them to read it.
              note: 'Nothing comes back.',
              onTap: _busy ? null : _erase,
            ),
          ],
        ),

        /* --------------------------------------------------- notices */

        /* -------------------------------------------------- stash it */

        // The Go Pro card used to sit here, ninth of ten. It is now the
        // first thing on the page — see `_GoPro` at the top of the list.

        _Card(
          title: 'Stash it',
          children: [
            // Shown in the app rather than opened in a browser — see
            // lib/ui/privacy.dart on why the words ship with the build
            // they describe.
            _LinkRow(
              label: 'Take the tour',
              note: 'Eight screens. What it does and how to feed it.',
              onTap: () => showTour(context, repo: widget.repo),
            ),
            _Rule(c),
            _LinkRow(
              label: 'Privacy policy',
              onTap: () => showPrivacy(context),
            ),
            _Rule(c),

            /*
                  ── One heading, three buttons ────────────────────────────────

                  These were three rows in the same list as Take the tour and
                  Privacy policy, each with its own chevron, all of them doing
                  the identical thing: open the mail app addressed to the same
                  person. Three rows that differ only in the subject line read
                  as three destinations, and the row above them — a tour —
                  reads as a fourth of the same kind.

                  A heading says who they reach once, and the three buttons say
                  what to write about. Which is what the choice actually is.
                */
            const SizedBox(height: 6),
            Text(
              'Contact the developer',
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Opens your mail app.',
              style: TextStyle(
                  fontFamily: fontBody, fontSize: 11.5, color: c.muted),
            ),
            const SizedBox(height: 12),

            /*
                  ── One line, three equal shares ──────────────────────────────

                  A Wrap was tried first and the labels defeated it: "Suggest a
                  feature" and "Something's broken" will not share a line at any
                  text scale, so the row became two and the three stopped
                  reading as one set of choices.

                  Shortening the labels is the fix rather than the compromise.
                  Question, Idea, Problem — one word each, and the heading above
                  already says what they do, so a longer label was only ever
                  repeating "contact the developer about" three times.

                  `Expanded` so all three are the same width whatever the words
                  are, and a Row is safe now that the widest is seven letters.
                */
            Row(
              children: [
                Expanded(
                  child: _ContactChip(
                    label: 'Question',
                    onTap: () =>
                        _open(contactUri(ContactKind.question, appVersion)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ContactChip(
                    label: 'Idea',
                    onTap: () =>
                        _open(contactUri(ContactKind.idea, appVersion)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ContactChip(
                    label: 'Problem',
                    onTap: _busy ? null : _reportProblem,
                  ),
                ),
              ],
            ),
          ],
        ),

        Padding(
          // Above the version card. The version card is the app signing
          // off, and a button pressed under a signature reads as part of
          // it rather than as a thing you can press.
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _BigButton(
            label: 'Share Stash it',
            icon: Icons.ios_share,
            onTap: _share,
          ),
        ),

        /*
              ── The version, and the second hidden gesture ──────────────────

              Ten taps here opens the developer tools. It is a separate run from
              the one on Scout, because the two hide different things for
              different people: Scout hides a joke, and this hides a switch that
              lifts the item cap.

              A version number is a poor easter egg — nobody pokes one to see
              what happens — and a good place for something that should only be
              reached deliberately, because anybody who wants it knows to come
              here.
            */
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tapVersion,
            child: StashCard(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Column(
                  children: [
                    // The wordmark itself, not a version of it. One widget
                    // means the gold "it" here and the gold "it" on Home
                    // cannot drift apart — they are the same object at a
                    // different size.
                    const Wordmark(fontSize: 26),
                    const SizedBox(height: 2),
                    Text(
                      'v$appVersion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: fontMono,
                        fontFeatures: tabularFigures,
                        fontSize: 13,
                        color: c.gold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tapHint(_taps) ??
                          'Everything you own, on your own phone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 14,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (_busy)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LinearProgressIndicator(),
          ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _status!,
              style: TextStyle(
                  fontFamily: fontBody, fontSize: 12.5, color: c.text),
            ),
          ),

        if (readUnlocked()) ...[
          _Card(
            title: 'Developer',
            children: [
              /*
                    ── Read-only, and that is why it ships ──────────────────────

                    Nothing on the diagnostics sheet writes a record, grants
                    anything or changes a setting, and nothing on it is private
                    — counts, sizes, versions and a time zone, with no names
                    and no dates out of anybody's records.

                    That constraint is what makes it safe outside a debug
                    build, and it is also what makes it useful: the point is
                    that somebody can paste it to a stranger without reading it
                    carefully first.
                  */
              _LinkRow(
                label: 'Diagnostics',
                note: 'Counts and versions, copyable. Nothing private.',
                onTap: () => showDiagnostics(context, widget.repo),
              ),
              _Rule(c),

              /*
                ── The evidence that did not exist ─────────────────────────

                Nothing caught a crash before this: no `FlutterError.onError`,
                no handler on the platform dispatcher. Consistent with having
                no server to send anything to, and it left "it crashed" as a
                sentence with nothing attached — which during a tester period
                is the difference between a fix and a fortnight of asking
                what they were doing at the time.

                The count is on the row because a screen you have to open to
                discover it is empty is a screen nobody opens. Zero is the
                answer worth seeing at a glance, and it is the usual one.

                Unlike Diagnostics this one is NOT safe to paste unread — an
                exception quotes whatever it choked on. The screen says so.
              */
              FutureBuilder<List<CrashNote>>(
                future: _crashes,
                builder: (context, snap) {
                  final many = snap.data?.length ?? 0;

                  return _LinkRow(
                    label: 'Crashes',
                    note: many == 0
                        ? 'Nothing has gone wrong.'
                        : '$many recorded. May name a record.',
                    trailing: many == 0
                        ? null
                        : Text(
                            '$many',
                            style: TextStyle(
                              fontFamily: fontMono,
                              fontFeatures: tabularFigures,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.ember,
                            ),
                          ),
                    onTap: () async {
                      await showCrashes(context);
                      // Re-read on the way back: the screen offers to throw
                      // the log away, and a row still saying 3 afterwards
                      // would look like the button did nothing.
                      if (mounted) setState(() => _crashes = readCrashes());
                    },
                  );
                },
              ),
              _Rule(c),

              /*
                    ── The one part of the app that cannot be watched ───────────

                    A notification is scheduled now and arrives days later, on a
                    phone that may have been off, after an OS free to delay it.
                    When one does not turn up there is nothing to inspect, and
                    "never scheduled" looks exactly like "scheduled and
                    swallowed".

                    This lists what will fire and when, alongside what the phone
                    says it is holding — two numbers that should agree and are
                    worth seeing when they do not.
                  */
              _LinkRow(
                label: 'Scheduled reminders',
                note: 'What will fire, and when.',
                onTap: () => showSchedule(context, widget.repo),
              ),
              _Rule(c),

              /*
                    ── What the folder picker actually offered ──────────────────

                    Automatic backups write to whatever document tree the person
                    picked, and every part of that lives in another process: the
                    picker is Android's, the folder belongs to a provider, and
                    the write can fail for reasons no log in this app records.

                    Which is exactly the situation "it stopped backing up" is
                    reported from. This says what the grant is, whether Android
                    still honours it, what is in the folder, and whether a real
                    write lands right now.
                  */
              _LinkRow(
                label: 'Backup folder',
                note: 'The grant, the contents, and a test write.',
                onTap: () => showFolderProbe(context, widget.repo),
              ),
              _Rule(c),

              /*
                    ── Debug builds only, and that is not a detail ──────────────

                    This grants the unlock, and for one version it shipped
                    behind nothing but ten taps on the version number. That is
                    not a secret: ten taps on a version number is how Android's
                    own developer options work, which means it is a convention
                    somebody finds by accident rather than a lock somebody has
                    to pick. The paywall was one gesture deep for every person
                    who installed the app.

                    `kDebugMode` is a compile-time constant, so in a release
                    build this whole subtree folds away and is tree-shaken out.
                    It is not hidden in the shipped APK; it is not in it.

                    What this still is NOT, and cannot be: proof against
                    somebody who decompiles and patches. The app has no server
                    by design, so the entitlement is a boolean on the handset
                    and anybody determined enough can set it. The goal is that
                    a casual user cannot stumble in — see the note in
                    RELEASE.md on what a client-side check is worth.

                    Testers get Play promo codes: real purchases, revocable,
                    and they exercise the buy path so a broken one is found
                    before release rather than after.
                  */
              if (kDebugMode)
                FutureBuilder<Settings>(
                  future: _settings,
                  builder: (context, snap) {
                    final on = snap.data?.entitlements;
                    if (on == null) return const SizedBox.shrink();

                    return _LinkRow(
                      label: on.proUnlock
                          ? 'Unlocked'
                          : 'Grant unlock (debug build)',
                      note: on.proUnlock
                          ? 'Source: ${on.source ?? 'unknown'}'
                          : 'Not compiled into release builds. Testers get promo codes.',
                      onTap: on.proUnlock
                          ? null
                          : () async {
                              await widget.repo.grantUnlock('dev');
                              feedback(Cue.unlock);
                              _refresh();
                            },
                    );
                  },
                ),
              _Rule(c),

              /*
                ── An action, filed with the actions ──────────────────────────

                This was on the Diagnostics screen, which is the one screen in
                the app whose entire claim is that it does nothing: read-only,
                nothing written, nothing sent, safe to ship outside a debug
                build. A button that fires a notification broke that, and it
                was only there because the notification counts are printed
                nearby.

                Under the unlock line rather than above it: everything above is
                a place to go, and this is the one thing on the card that
                happens where you stand.
              */
              _LinkRow(
                label: 'Test notification',
                note: _testedNotification ??
                    'Fires one now, to see whether the phone lets it through.',
                onTap: _busy
                    ? null
                    : () async {
                        feedback(Cue.tap);
                        final sent = await notifications.sendTest();
                        if (!mounted) return;

                        setState(() => _testedNotification = sent
                            ? 'Sent. If nothing appeared, the phone is holding '
                                'it — check the app in Android settings.'
                            : 'This phone would not send one.');
                      },
              ),
              _Rule(c),
              _LinkRow(
                label: 'Hide developer tools',
                onTap: () => setState(() {
                  rememberUnlocked(false);
                  // The run is reset too, or the next single tap on the
                  // version lands on nine and puts them straight back.
                  _taps = noTaps;
                }),
              ),
            ],
          ),
        ],

        /*
          ── The maker's plate ─────────────────────────────────────────────────

          Last thing on the page, under the version and under the developer
          tools when they are showing. It is not a control and does not want to
          be near one.

          Half the column width, centred. Full width made it the largest thing
          on a page of settings — a maker's mark that outweighs the app's own
          version number is a signature in the wrong hand. At half it reads as
          what it is: a credit at the bottom.

          ── PNG, not JPEG ─────────────────────────────────────────────────────
          The background is pure white and the type is sharp-edged black on it,
          which is the exact case JPEG handles worst: it rings around hard
          edges and mottles flat areas, so "pure white" would come back as a
          field of 253s with a faint halo round every letter.

          The file is 520 wide, which covers this render at 3x with a little to
          spare — halving the display size halved the pixels needed, so the
          asset went 886 to 520 and 201KB to 88KB rather than shipping four
          times the resolution anybody will see.

          A smaller radius with it. 26 was proportionate on a full-width plate
          and would be a lozenge at half the size.
        */
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: Image.asset(
                  'assets/brand/flux-studios.png',
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "196 MB" — how much the database is carrying.
  ///
  /// The blob bytes rather than the file on disk: the file includes SQLite's
  /// free pages and the encryption overhead, and neither is a thing anybody can
  /// act on. What somebody wants to know is how big the backup will be.
  Future<String> _readSize() async {
    final bytes = await widget.repo.storageBytes();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(bytes > 10 * 1024 * 1024 ? 0 : 1)} MB';
  }
}

/// The second confirmation on Erase everything.
///
/// ── Why a word has to be typed ──────────────────────────────────────────────
/// Every other destructive action in the app has a bin behind it. This one has
/// nothing — no undo, no thirty days, no restore unless a backup already
/// exists somewhere else. A second tap in the same place as the first is not a
/// second decision; typing is.
Future<bool?> _askErase(BuildContext context) {
  final controller = TextEditingController();
  final c = StashColors.of(context);

  return showDialog<bool>(
    context: context,
    // The controller outlives the await by exactly as long as the dialog
    // does — see `OwnsControllers`. It was never disposed at all here.
    builder: (context) => OwnsControllers(
      controllers: [controller],
      child: AlertDialog(
        backgroundColor: c.slate700,
        title: Text(
          'Type ERASE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: c.text,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'There is no bin behind this one, and no undo. If you have a '
              'backup file it can be restored; if you do not, this is the end '
              'of it.',
              style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 13,
                  height: 1.45,
                  color: c.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(fontFamily: fontMono, color: c.text),
              decoration: const InputDecoration(hintText: 'ERASE'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep everything'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pop(controller.text.trim().toUpperCase() == 'ERASE'),
            child: Text('Erase', style: TextStyle(color: c.ember)),
          ),
        ],
      ),
    ),
  );
}

/// The public policy page, required by the Play Store listing whether or not
/// the app also carries the words.
///
/// The policy people actually read is the one inside the app; see
/// lib/ui/privacy.dart. This is the address, not the source of truth.
///
/// ── Two things were wrong with the address this replaces ──────────────────
/// It read `nuno927.github.io`. The account is **nuno927-tech**, so the URL
/// resolved to nothing at all — a privacy policy that 404s, which is worse
/// than none because the listing went out of its way to point at it. Nothing
/// in a build catches a URL that is merely wrong.
///
/// And it pointed at `privacy.html`, which is the **web** app's policy. That
/// one describes a push server and unencrypted browser storage, neither of
/// which is true here, and it says the app is free with an optional tip —
/// this one has a purchase in it. Play checks the policy against what the app
/// actually does.
///
/// So: a page of its own, generated from the same facts as lib/ui/privacy.dart
/// and living in the web repo's `site/` folder, which is what GitHub Pages
/// serves at the root of the project site.
const String privacyUrl =
    'https://nuno927-tech.github.io/stash-it/privacy-android.html';

/*
  ── PLACEHOLDER. Replace before the first public release. ───────────────────

  The share text points here, so until the listing exists every share sends
  somebody to a Play Store page that does not.

  The address is predictable from the application id, which is why it can be
  written down now: `app.stashit` is set in android/app/build.gradle.kts and is
  permanent after the first publish. So this URL will be correct the moment the
  listing goes live — but it is wrong until then, and "wrong until then" is
  exactly the kind of thing that ships.

  RELEASE.md carries this as a checklist item. Verify it resolves before the
  closed test goes out, because testers are the first people who will use this
  button.
*/
const String storeUrl =
    'https://play.google.com/store/apps/details?id=app.stashit';

/// The biometric preference, read through `prefsFrom` so a record written
/// before the field existed still answers.
bool biometricLockOf(Settings s) => prefsFrom(s).biometricLock;

/* ------------------------------------------------------------------ parts */

/// One settings card: a heading, a rounded panel, the rows inside it.
///
/// Grouped rather than one long list, because a flat list of eighteen controls
/// is eighteen things to read before finding the one you came for. The heading
/// sits outside the panel so it reads as a label on the group rather than as
/// its first row.
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.children,
    this.trailing,
    this.inset = 16,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  /// How far the panel sits from the edge of the page.
  ///
  /// Sixteen everywhere, and it is not a thing to vary for taste — a column of
  /// cards at two different widths reads as a mistake before it reads as
  /// emphasis. It exists for one case: the Backup card is wrapped in a wash
  /// that needs room of its own, and that room has to come out of this number
  /// rather than be added outside it. See the note at the wrapper.
  final double inset;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 10, inset, 0),
      child: StashCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      /*
                        The display face, as every other heading in the app.

                        These were Inter at 700, which is the same weight the
                        rows inside them use for a label — so a card's name and
                        the name of a switch it contains were the same object
                        at slightly different sizes. Bricolage is what says
                        "this is a heading" on the five page titles and the
                        wordmark, and a settings card is the same kind of thing
                        one level down.

                        Tracking pulled in, because Bricolage at 700 sets wide
                        and a heading this small wants to read as one shape.
                      */
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: c.text,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              // Nothing between the heading and the first row when the card
              // is only a title and a switch — the switch is IN the heading, and
              // spacing under it would be spacing under nothing.
              if (children.isNotEmpty) const SizedBox(height: 2),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A hairline between rows. Not a `Divider`, which brings its own height and
/// indent rules that fight the card's padding.
/// Whether backup files are locked, and the way to change that.
///
/// ── Above the folder, deliberately ─────────────────────────────────────────
/// "Is this readable by anyone who finds it" is a question worth answering
/// before "where does it go", and a person setting up automatic backups into a
/// cloud folder should meet the lock on the way past rather than after.
class _LockRow extends StatelessWidget {
  const _LockRow({
    required this.locked,
    required this.busy,
    required this.onSet,
    required this.onClear,
  });

  final bool locked;
  final bool busy;
  final VoidCallback onSet;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    if (!locked) {
      return _LinkRow(
        label: 'Lock backups with a passphrase',
        onTap: busy ? null : onSet,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LinkRow(
          // The warning that used to sit here — nobody can reset it — is said
          // where it can still be acted on: in the sheet that sets the
          // passphrase, before there is one to forget.
          label: 'Backups are locked',
          trailing: Icon(Icons.lock_outline, size: 18, color: c.moss),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              TextButton(
                onPressed: busy ? null : cued(onSet),
                child: Text(
                  'Change passphrase',
                  style: TextStyle(
                      fontFamily: fontBody, fontSize: 12.5, color: c.gold),
                ),
              ),
              TextButton(
                onPressed: busy ? null : cued(onClear, cue: Cue.collapse),
                child: Text(
                  'Stop locking',
                  style: TextStyle(
                      fontFamily: fontBody, fontSize: 12.5, color: c.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Where automatic backups go, and whether the last one arrived.
///
/// ── Four states, and the app has to be able to say which ───────────────────
/// Never set up. Set up and working. Set up and failing. Set up and the
/// permission is gone — which is what a reinstall does, and which looks
/// identical to "working" unless somebody says so out loud.
///
/// The last one is the reason this row exists at all. A backup that quietly
/// stopped is worse than one that never started, because the app goes on
/// looking as though it is protecting somebody.
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.settings,
    required this.locked,
    required this.busy,
    required this.onChoose,
    required this.onStop,
  });

  final Settings settings;

  /// Whether backups carry a passphrase, which decides whether the warning
  /// under the folder is news or noise.
  final bool locked;

  final bool busy;
  final VoidCallback onChoose;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final folder = settings.backupFolder;

    /*
      Nothing set up yet, so this is the one thing on the card worth pressing —
      and it gets the only button that looks like it.

      A row with a chevron reads as a setting to adjust later. This is the
      feature the card exists for, and on a phone that has never backed up it
      is the difference between a collection that survives losing the phone and
      one that does not.
    */
    if (folder == null) {
      return _BigButton(
        label: 'Back up automatically',
        icon: Icons.cloud_upload_outlined,
        onTap: busy ? null : onChoose,
      );
    }

    final trouble = settings.lastAutoBackupError;
    final at = settings.lastAutoBackupAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LinkRow(
          label: 'Backing up to ${settings.backupFolderLabel ?? 'a folder'}',
          note: trouble ??
              (at == null
                  ? 'Nothing written yet.'
                  : 'Last one ${at.toIso8601String().substring(0, 10)}.'),
          trailing: Icon(
            // The one place a colour carries meaning on this page, and it is
            // backed by the sentence underneath rather than replacing it.
            trouble == null ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: trouble == null ? c.moss : c.ember,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              TextButton(
                onPressed: busy ? null : cued(onChoose),
                child: Text(
                  'Change folder',
                  style: TextStyle(
                      fontFamily: fontBody, fontSize: 12.5, color: c.gold),
                ),
              ),
              TextButton(
                onPressed: busy ? null : cued(onStop, cue: Cue.collapse),
                child: Text(
                  'Stop',
                  style: TextStyle(
                      fontFamily: fontBody, fontSize: 12.5, color: c.muted),
                ),
              ),
            ],
          ),
        ),
        /*
          Only while it is true.

          An unlocked `.stashit` is a plain zip — deliberately, so somebody
          with a broken install can open it and read their own data. That is a
          good trade for a file on your own phone and a different one for a
          file sitting in a cloud account, and somebody whose backups go to a
          synced folder is entitled to know which of the two they have.

          It used to be printed under the folder either way, including to
          people who had already locked theirs, where it was not a warning but
          a paragraph. Shown now only when there is something to warn about.
        */
        if (!locked)
          _Note(
            'Anyone who opens that folder can read this. Lock it below.',
            c,
          ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.c);
  final StashColors c;

  @override
  Widget build(BuildContext context) => Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: c.line);
}

class _Note extends StatelessWidget {
  const _Note(this.text, this.c);
  final String text;
  final StashColors c;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          style: TextStyle(
              fontFamily: fontBody, fontSize: 12, height: 1.45, color: c.muted),
        ),
      );
}

/// A row of choices, one of them on.
///
/// ── A segmented row, not a dropdown ───────────────────────────────────────
/// Every option is visible without a tap, which for four or five short words is
/// the whole difference between a setting people adjust and one they never open.
/// A dropdown hides the range, and the range is what tells you what the setting
/// even means.
class _SegRow<T> extends StatelessWidget {
  const _SegRow({
    required this.value,
    required this.options,
    required this.onChange,
    this.label,
  });

  final String? label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChange;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.slate600,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              children: [
                for (final (v, text) in options)
                  Expanded(
                    child: GestureDetector(
                      // Every segment, from one place. It was wired at three of
                      // the five call sites, which is how a control ends up
                      // feeling different depending which card it is in.
                      onTap: () {
                        if (v == value) return;
                        feedback(Cue.tap);
                        onChange(v);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: v == value ? c.slate800 : Colors.transparent,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 12.5,
                            fontWeight:
                                v == value ? FontWeight.w700 : FontWeight.w400,
                            color: v == value ? c.text : c.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/*
  ── One line, and no room for a second ──────────────────────────────────────

  This briefly took an optional `note` for a subtitle under the label. It was
  added for one switch — a portrait lock, since removed entirely — and taken
  away again the moment that subtitle turned out to be restating its own label
  in longer words.

  Not kept "in case something needs it later". An unused optional parameter is
  an invitation: the next switch with a slightly weak label gets a sentence
  under it instead of a better label, and a settings page becomes a manual one
  reasonable line at a time.

  If a switch genuinely cannot be explained by its label, the label is wrong.
*/
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // The Column that used to be here held the label above a note. With
          // the note gone it wrapped one child and aligned it against itself,
          // which is scaffolding for a thing that is not there any more.
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            // On and off both. A switch that only buzzes one way feels broken
            // in the direction it stays silent.
            onChanged: onChanged == null
                ? null
                : (v) {
                    feedback(v ? Cue.expand : Cue.collapse);
                    onChanged!(v);
                  },
          ),
        ],
      ),
    );
  }
}

/// A label on the left, a text box on the right.
///
/// Written on submit rather than on every keystroke: a settings row that saves
/// per character writes a dozen rows for one name, and half of them are
/// spelling mistakes on their way somewhere.
class _FieldRow extends StatefulWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    required this.onSubmit,
    this.note,
    this.hint,
  });

  final String label;
  final String? note;
  final String value;
  final String? hint;
  final ValueChanged<String> onSubmit;

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                if (widget.note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.note!,
                    style: TextStyle(
                        fontFamily: fontBody, fontSize: 11.5, color: c.muted),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 116,
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.right,
              textInputAction: TextInputAction.done,
              onSubmitted: widget.onSubmit,
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
                widget.onSubmit(_controller.text);
              },
              style: TextStyle(
                  fontFamily: fontBody, fontSize: 13.5, color: c.text),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: c.slate800,
                hintText: widget.hint,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  borderSide: BorderSide(color: c.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  borderSide: BorderSide(color: c.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  borderSide: BorderSide(color: c.gold, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A label, and a menu of short values on the right.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChange,
    this.note,
  });

  final String label;
  final String? note;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    note!,
                    style: TextStyle(
                        fontFamily: fontBody, fontSize: 11.5, color: c.muted),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: c.slate800,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: c.line),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: options.contains(value) ? value : options.first,
                isDense: true,
                borderRadius: BorderRadius.circular(Radii.md),
                dropdownColor: c.slate700,
                style: TextStyle(
                    fontFamily: fontBody, fontSize: 13.5, color: c.text),
                items: [
                  for (final o in options)
                    DropdownMenuItem(value: o, child: Text(o)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  feedback(Cue.tap);
                  onChange(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row that goes somewhere, or shows one fact on the right.
/// One of the three ways to write in.
///
/// A chip rather than a full-width row: three of these are one decision with
/// three answers, and stacking them as rows would put them back to looking
/// like three separate places to go.
///
/// Centred and single-line, because the three are `Expanded` to equal widths —
/// left-aligned text in equal boxes reads as a ragged column rather than a
/// row of buttons.
class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.label, required this.onTap});

  final String label;

  /// Null when there is nothing this chip can do — a launcher too old to be
  /// handed a widget, which is the only case so far.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final off = onTap == null;

    return Material(
      color: c.slate600,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: off
            ? null
            : () {
                feedback(Cue.tap);
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: off ? c.muted : c.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, this.note, this.trailing, this.onTap});

  final String label;
  final String? note;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              feedback(Cue.tap);
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      note!,
                      style: TextStyle(
                          fontFamily: fontBody, fontSize: 11.5, color: c.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null)
              Icon(Icons.chevron_right, size: 20, color: c.muted),
          ],
        ),
      ),
    );
  }
}

/// The gold, full-width kind. Backup and restore are two halves of one job, so
/// they get the same weight — drawing one as a ghost outline would imply one of
/// them was the safe option and the other was not.
/// The receipt that sits where the offer used to.
///
/// Tappable, and it opens the same sheet the offer did — see `showUnlock`'s
/// `owned` flag. The six reasons somebody paid are the same six things they
/// bought, so the list is shared rather than written twice; only the footer
/// changes from a price to a thank-you.
class _ProCard extends StatelessWidget {
  const _ProCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Material(
        color: c.washGold,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: () {
            feedback(Cue.tap);
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 14, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: c.gold.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium_outlined,
                        size: 20, color: c.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stash it Pro',
                        style: TextStyle(
                          fontFamily: fontDisplay,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: c.text,
                        ),
                      ),
                    ),
                    const ProBadge(),
                    const SizedBox(width: 4),
                    // A chevron, because the card does something. Without one
                    // it is a status panel that happens to be tappable, which
                    // nobody discovers.
                    Icon(Icons.chevron_right, size: 20, color: c.muted),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlimited. Thanks for supporting Scout and Stash it',
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 13,
                    height: 1.45,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, this.note, this.icon, this.onTap});

  final String label;
  final Future<String>? note;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Material(
      color: onTap == null ? c.slate600 : c.gold,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap == null
            ? null
            : () {
                feedback(Cue.tap);
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: onTap == null ? c.muted : c.onGold),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  color: onTap == null ? c.muted : c.onGold,
                ),
              ),
              if (note != null)
                FutureBuilder<String>(
                  future: note,
                  builder: (context, snap) => snap.data == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Text(
                            snap.data!,
                            style: TextStyle(
                              fontFamily: fontBody,
                              fontSize: 12.5,
                              color: (onTap == null ? c.muted : c.onGold)
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
