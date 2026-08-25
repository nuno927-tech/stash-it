/// The dashboard.
///
/// Three things, in this order: how much of what you own is still in date,
/// what needs you, and anything the app is missing.
library;

// Material's `Tab` widget hidden in favour of ours — see shell.dart.
import 'package:flutter/material.dart' hide Tab;

import '../db/repository.dart';
import '../logic/greeting.dart';
import '../logic/nudges.dart';
import '../logic/swipe.dart';
import '../logic/timeline.dart';
import '../models/settings.dart';
import '../models/types.dart';
import 'parts.dart';
import 'scout.dart';
import 'theme.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({required this.repo, required this.onGo, super.key});

  final Repository repo;
  final void Function(Tab) onGo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Item>>(
      stream: repo.watchActiveItems(),
      builder: (context, _) {
        return FutureBuilder<_Home>(
          future: _Home.of(repo),
          builder: (context, snap) {
            final data = snap.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _HomeBody(data: data, onGo: onGo);
          },
        );
      },
    );
  }
}

class _Home {
  const _Home(this.tally, this.line, this.nudges, this.backup, this.settings);

  final DatedTally tally;
  final List<Entry> line;
  final List<Nudge> nudges;
  final BackupStatus? backup;
  final Settings settings;

  static Future<_Home> of(Repository repo) async {
    final items = await repo.activeItems();
    final papers = await repo.activePapers();
    final subs = await repo.activeSubscriptions();
    final settings = await repo.settings();

    final tally = datedTally(items, papers);

    return _Home(
      tally,
      buildTimeline(items, subs, papers),
      dueNudges(
        settings: settings,
        itemCount: items.length,
        endingSoon: tally.needsStarting,
      ),
      backupStatus(
        lastBackupAt: settings.lastBackupAt,
        everyDays: settings.backupReminderDays,
        itemCount: items.length,
      ),
      settings,
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.data, required this.onGo});

  final _Home data;
  final void Function(Tab) onGo;

  /// Where a figure should take you, or nothing when it has nothing to show.
  VoidCallback? _tap(KindSplit split) {
    final to = destinationFor(split);
    if (to == null) return null;
    return () => onGo(to == Destination.items ? Tab.items : Tab.papers);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = StashColors.of(context);
    final t = data.tally;

    return ListView(
      children: [
        /*
          The greeting sits under the wordmark, lighter and smaller.

          The masthead is the app saying its own name; this is the app saying
          hello to you. Same face, two hundred weight against eight hundred —
          the contrast is what stops the pair reading as one long heading.
        */
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            greeting(data.settings.displayName),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w200,
              letterSpacing: -0.34,
            ),
          ),
        ),

        const SectionTitle('Items and documents'),

        /*
          Scout presents the numbers rather than the screen simply having some.

          Beside the ring, not above it: the pair reads as somebody showing you
          a result, which is what the dashboard is. His baseline sits level with
          the ring's lower edge — the PWA nudges it 6px for the same reason.
        */
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 4, bottom: 6),
              child: Scout(
                pose: ScoutPose.report,
                height: 148,
                motion: [ScoutMotion.breathe],
              ),
            ),
            Ring(
              inDate: t.inDate,
              needsStarting: t.needsStarting,
              lapsed: t.lapsed,
              percent: t.percent,
            ),
          ],
        ),
        const SizedBox(height: 12),
        /*
          ── Only the actionable figures are chips ────────────────────────

          There was an "in date" chip here and it was wrong twice over: the
          ring already shows that share as its percentage, so the screen said
          the same thing in two places — and it had nowhere to go when tapped,
          because there is no screen for the things that are fine.

          A chip is an offer to take you somewhere. Everything in this row can
          be acted on; the ring is the summary.
        */
        /*
          Four equal columns with a rule above, which is `.coverstats`.

          "In date" is here and is not tappable — there is nothing to do about
          something that is fine — while the other three go somewhere. The ring
          shows the same share as a percentage, and that duplication is
          deliberate: the ring is the summary and this is the breakdown.
        */
        FigureRow([
          Figure(value: '${t.inDate}', label: 'in date', tone: c.moss),
          Figure(
            value: '${t.needsStarting}',
            label: 'action needed',
            tone: c.honey,
            onTap: _tap(t.needsStartingBy),
          ),
          Figure(
            value: '${t.lapsed}',
            label: 'lapsed',
            tone: c.ember,
            onTap: _tap(t.lapsedBy),
          ),
          Figure(
            value: '${t.noDate}',
            label: 'no date',
            onTap: _tap(t.noDateBy),
          ),
        ]),

        /*
          The backup line, and it never goes away.

          Between nudges the dashboard said nothing at all about backups, so
          the honest reading of a quiet screen was "fine" — and the state it
          was quietest about was a phone whose only copy of everything was
          itself. That matters more now than it did on the web: the database
          is encrypted with a key that never leaves this handset.
        */
        if (data.backup != null)
          ListTile(
            dense: true,
            leading: Icon(
              Icons.save_outlined,
              color: switch (data.backup!.tone) {
                BackupTone.ok => null,
                BackupTone.due => const Color(0xFFF2B33D),
                BackupTone.never => theme.colorScheme.error,
              },
            ),
            title: Text(data.backup!.label),
            // It says "never backed up" and the way to fix that is two taps
            // away on another tab. A line that reports a problem and cannot
            // reach the fix is a line that gets read and ignored.
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onGo(Tab.settings),
          ),

        for (final nudge in data.nudges)
          _NudgeCard(nudge: nudge, onAct: () => onGo(_where(nudge.kind))),

        SectionTitle(
          'Coming up',
          trailing: flaggedCount(data.line) == 0
              ? null
              : Text(
                  '${flaggedCount(data.line)} need you',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
        ),

        if (data.line.isEmpty)
          const Blank(
            'Nothing needs you.',
            pose: ScoutPose.resting,
            poseHeight: 104,
          )
        else
          for (final entry in data.line.take(12)) TimelineTile(entry: entry),

        const SizedBox(height: 24),
      ],
    );
  }
}

/// Where the one thing a nudge asks for actually happens.
Tab _where(NudgeKind kind) => switch (kind) {
      NudgeKind.backup => Tab.settings,
      NudgeKind.warranty => Tab.items,
    };

/// A card with something to do about it.
///
/// ── The button was missing, which made the card a complaint ───────────────
/// `Nudge.action` has always carried the words for it — "Back up now" — and
/// nothing rendered them. So the dashboard would say *"your 21 items live on
/// this phone and nowhere else"* and then offer no way to do anything about it.
///
/// That is precisely the failure `logic/nudges.dart` opens by describing: a
/// setting that writes to the database and changes nothing is worse than a
/// missing feature, because it looks answered. A warning with no button is the
/// same shape — it looks handled.
class _NudgeCard extends StatelessWidget {
  const _NudgeCard({required this.nudge, this.onAct});

  final Nudge nudge;
  final VoidCallback? onAct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nudge.title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text(nudge.body, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                // Ears up. The card only exists when something needs doing, so
                // the pose is the one that means exactly that — and the motion
                // is the restrained one, because a card you are trying to read
                // should not be twitching at you.
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Scout(
                    pose: ScoutPose.alert,
                    height: 84,
                    motion: [ScoutMotion.alert],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              // One button, because every nudge has exactly one thing to do
              // about it — see the note on `Nudge.action`.
              child: FilledButton(onPressed: onAct, child: Text(nudge.action)),
            ),
          ],
        ),
      ),
    );
  }
}
