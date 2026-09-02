/// How far along a backup is.
///
/// ── Why stages and not one percentage ─────────────────────────────────────
/// A backup is three jobs with wildly different costs. Reading the tables is
/// milliseconds. Reading the photographs is most of the wall clock on a real
/// collection — seventy-six of them is not unusual. Zipping and hashing is a
/// single long push at the end that cannot report anything from inside.
///
/// One bar rising smoothly from 0 to 100 would be a lie about all three: it
/// would sit at 2% for a moment, crawl for ten seconds, then freeze at 90%
/// while the longest single operation ran. So the stage is named as well as
/// measured, and the bar only claims precision where there is some — the
/// photographs, which are counted.
///
/// ── And why the numbers are weighted ──────────────────────────────────────
/// The weights below are not equal thirds. They are roughly what the three
/// stages actually cost on a collection with photographs in it, so the bar
/// moves at something close to a steady rate rather than lurching.
library;

enum BackupStage {
  /// The tables. Fast, and over before it is read.
  reading,

  /// The photographs and receipts, one at a time. The long one.
  packing,

  /// Hashing and zipping, on a background isolate. Cannot report from inside,
  /// so it is a stage with a name rather than a number.
  sealing,

  /*
    ── Encrypting, when there is a passphrase ─────────────────────────────────

    A stage of its own because it is the longest silent stretch in the app and
    it had no name: the bar reached the end, the sheet closed, and then the
    phone spent fifteen seconds doing the thing nobody had been told about
    before the share sheet appeared.

    Skipped entirely when backups are not locked, which is why it sits between
    sealing and done rather than replacing either.
  */
  locking,

  /*
    ── And the three the other direction uses ─────────────────────────────────

    One enum, two journeys. A backup goes reading → packing → sealing →
    locking; a restore goes unlocking → restoring. Neither ever
    emits the other's stages, and each subset climbs in order, which is all the
    weights below need to be true.

    A restore is where this mattered most and had least: thirty seconds of
    decrypting, inflating, hashing and writing, behind a bar that never moved
    because nothing on that path ever reported anything.
  */
  /*
    Reading the file, decrypting it, inflating it and hashing it — all one
    stage, because it is all one isolate. It was three, and splitting it meant
    copying the whole backup between them, which cost more than the work.
  */
  unlocking,
  restoring,

  done,
}

class BackupProgress {
  const BackupProgress(this.stage, {this.done = 0, this.total = 0});

  final BackupStage stage;

  /// Files packed so far, and how many there are. Both zero for the stages
  /// that have nothing to count.
  final int done;
  final int total;

  /*
    ── The counted stage owns nearly all of the bar ─────────────────────────

    Packing used to end at 0.82, so a collection that packed quickly showed six
    acorns of eight within a second and then sat there — the two remaining
    acorns belonged to sealing, which reports nothing from inside and so never
    moved them. Six lit acorns and no movement is exactly the "did it crash"
    picture the bar was added to remove.

    Two things changed. Sealing is now fast, because photographs are stored
    rather than deflated (see `writeBundle`), so the stretch that could not
    report is a moment rather than the main event. And what it costs is
    reflected here: packing runs 0.04 to 0.94, which is the part that can
    count, so the acorns fill through the work rather than around it.
  */
  /*
    ── Room left at the end for the lock ──────────────────────────────────────

    Packing used to run to 0.94 and sealing owned the rest. With a passphrase
    set that was wrong twice over: the bar filled while the longest part had not
    started, and a collection with few photographs jumped to seven and a half
    acorns of eight within a second and then sat there.

    So packing ends at 0.80 and the two stages that cannot count from inside
    share what is left. On an unlocked backup `locking` never arrives and the
    bar eases from 0.92 to full, which is a shorter last step rather than a
    stuck one.
  */
  static const Map<BackupStage, double> _startsAt = {
    BackupStage.reading: 0,
    BackupStage.packing: 0.04,
    BackupStage.sealing: 0.80,
    BackupStage.locking: 0.92,
    BackupStage.unlocking: 0,
    BackupStage.restoring: 0.80,
    BackupStage.done: 1,
  };

  static const Map<BackupStage, double> _endsAt = {
    BackupStage.reading: 0.04,
    BackupStage.packing: 0.80,
    BackupStage.sealing: 0.92,
    BackupStage.locking: 1,
    BackupStage.unlocking: 0.80,
    BackupStage.restoring: 1,
    BackupStage.done: 1,
  };

  /// 0..1, for the bar.
  double get fraction {
    final from = _startsAt[stage]!;
    final to = _endsAt[stage]!;

    // Only packing knows how far through itself it is. The other two report
    // their start, and the bar eases across the gap on its own.
    if (stage != BackupStage.packing || total == 0) return from;
    return from + (to - from) * (done / total).clamp(0, 1);
  }

  /// What to say while it happens. Second person, present tense, and specific
  /// about the photographs because that is the part worth waiting through.
  String get label => switch (stage) {
        BackupStage.reading => 'Reading your things',
        BackupStage.packing => total == 0
            ? 'Packing'
            : 'Packing $done of $total file${total == 1 ? '' : 's'}',
        BackupStage.sealing => 'Sealing it up',
        BackupStage.locking => 'Locking it with your passphrase',
        BackupStage.unlocking => 'Opening the file',
        BackupStage.restoring => 'Putting it back',
        BackupStage.done => 'Done',
      };
}

/// Called as the work moves along. Null when nobody is watching.
typedef BackupWatcher = void Function(BackupProgress step);
