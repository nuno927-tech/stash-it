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
  static const Map<BackupStage, double> _startsAt = {
    BackupStage.reading: 0,
    BackupStage.packing: 0.04,
    BackupStage.sealing: 0.94,
    BackupStage.done: 1,
  };

  static const Map<BackupStage, double> _endsAt = {
    BackupStage.reading: 0.04,
    BackupStage.packing: 0.94,
    BackupStage.sealing: 1,
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
        BackupStage.done => 'Done',
      };
}

/// Called as the work moves along. Null when nobody is watching.
typedef BackupWatcher = void Function(BackupProgress step);
