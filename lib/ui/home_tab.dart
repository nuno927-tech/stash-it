/// The dashboard, drawn to match the PWA screen for screen.
///
/// ── The shape of it, and why cards ────────────────────────────────────────
/// Every block on this screen is a card on a plain surface: the cover panel,
/// the backup line, the subscription chips, what is coming up, what needs a
/// minute, what was added recently. That is not decoration — the dashboard is
/// six unrelated answers stacked vertically, and without an edge round each
/// one they read as a single long list whose sections nobody can find.
///
/// The order is the order somebody asks the questions in. How much of what I
/// own is still covered. Is my only copy safe. What am I paying. What happens
/// next. What is missing. What did I just put in.
library;

// Material's `Tab` widget hidden in favour of ours — see shell.dart.
import 'package:flutter/material.dart' hide Tab;

import '../db/repository.dart';
import '../logic/dashboard.dart';
import '../logic/greeting.dart';
import '../logic/nudges.dart';
import '../logic/subscriptions.dart';
import '../logic/swipe.dart';
import '../logic/timeline.dart';
import '../logic/warranty.dart';
import '../models/settings.dart';
import '../models/subscription.dart';
import '../models/types.dart';
import 'feedback.dart';
import 'parts.dart';
import 'scout.dart';
import 'theme.dart';
import 'thumb.dart';

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
            return _HomeBody(repo: repo, data: data, onGo: onGo);
          },
        );
      },
    );
  }
}

class _Home {
  const _Home({
    required this.tally,
    required this.line,
    required this.backup,
    required this.settings,
    required this.gaps,
    required this.recent,
    required this.subs,
  });

  final DatedTally tally;
  final List<Entry> line;
  final BackupStatus? backup;
  final Settings settings;
  final List<Gap> gaps;
  final List<Item> recent;
  final List<Subscription> subs;

  static Future<_Home> of(Repository repo) async {
    final items = await repo.activeItems();
    final papers = await repo.activePapers();
    final subs = await repo.activeSubscriptions();
    final docs = await repo.activeDocs();
    final settings = await repo.settings();

    return _Home(
      tally: datedTally(items, papers),
      line: buildTimeline(items, subs, papers),
      backup: backupStatus(
        lastBackupAt: settings.lastBackupAt,
        everyDays: settings.backupReminderDays,
        itemCount: items.length,
      ),
      settings: settings,
      gaps: gapsFor(items, docs),
      recent: metricsFor(items, docs).recent,
      subs: subs,
    );
  }
}

class _HomeBody extends StatefulWidget {
  const _HomeBody({required this.repo, required this.data, required this.onGo});

  final Repository repo;
  final _Home data;
  final void Function(Tab) onGo;

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  /*
    Five, then the rest behind a tap.

    Long enough that the flagged rows are always visible on a normal week,
    short enough that nine monthly subscriptions cannot push the
    recently-added strip off the bottom of the screen.
  */
  static const int _shown = 5;
  bool _all = false;

  /// Where a figure should take you, or nowhere when it has nothing to show.
  VoidCallback? _tap(KindSplit split) {
    final to = destinationFor(split);
    if (to == null) return null;
    return () => widget.onGo(to == Destination.items ? Tab.items : Tab.papers);
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final data = widget.data;
    final t = data.tally;

    final line = _all ? data.line : data.line.take(_shown).toList();
    final more = data.line.length - line.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        /*
          The greeting sits under the wordmark, lighter and smaller.

          The masthead is the app saying its own name; this is the app saying
          hello to you. Same face, two hundred weight against eight hundred —
          the contrast is what stops the pair reading as one long heading.
        */
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
          child: Text(
            greeting(data.settings.displayName),
            style: TextStyle(
              fontFamily: fontDisplay,
              fontSize: 17,
              fontWeight: FontWeight.w200,
              letterSpacing: -0.34,
              color: c.muted,
            ),
          ),
        ),

        const _Label('Items and documents'),
        _CoverCard(tally: t, tap: _tap),

        if (data.backup != null) _BackupRow(status: data.backup!, onGo: widget.onGo),

        if (data.subs.isNotEmpty) ...[
          _Label(
            'Subscriptions',
            trailing: _OutlinePill(
              '${data.subs.length} service${data.subs.length == 1 ? '' : 's'}',
              onTap: () => widget.onGo(Tab.subs),
            ),
          ),
          _SpendChips(subs: data.subs),
        ],

        if (data.line.isNotEmpty) ...[
          const _Label('Coming up'),
          for (final entry in line) _TimelineRow(entry: entry),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: GestureDetector(
                onTap: () {
                  feedback(Cue.expand);
                  setState(() => _all = true);
                },
                child: Text(
                  'Show $more more',
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.gold,
                  ),
                ),
              ),
            ),
        ] else
          const Blank('Nothing needs you.', pose: ScoutPose.resting, poseHeight: 104),

        if (data.gaps.isNotEmpty) _NeedsCard(gaps: data.gaps, onGo: widget.onGo),

        if (data.recent.isNotEmpty) ...[
          _Label(
            'Recently added',
            trailing: _OutlinePill('See all', onTap: () => widget.onGo(Tab.items)),
          ),
          _RecentStrip(repo: widget.repo, items: data.recent),
        ],
      ],
    );
  }
}

/* ----------------------------------------------------------------- pieces */

/// A section label: small, muted, and outside the card it introduces.
///
/// Outside rather than inside, because the same label pattern has to work for
/// the chip row and the horizontal strip, neither of which has one box to put a
/// title in.
class _Label extends StatelessWidget {
  const _Label(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.muted,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// The small outlined pill on the right of a section label — "7 services",
/// "See all". A quieter affordance than a button and a louder one than text.
class _OutlinePill extends StatelessWidget {
  const _OutlinePill(this.text, {this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.pill),
      onTap: onTap == null
          ? null
          : () {
              feedback(Cue.tap);
              onTap!();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          text,
          style: TextStyle(fontFamily: fontBody, fontSize: 12.5, color: c.text),
        ),
      ),
    );
  }
}

/// The headline card: the ring, Scout beside it, the four counts, and the
/// sentence that says what the percentage is a percentage OF.
///
/// That last line matters more than it looks. A ring showing 83% with no
/// denominator is a score out of nothing — the sentence is what makes it a
/// measurement.
class _CoverCard extends StatelessWidget {
  const _CoverCard({required this.tally, required this.tap});

  final DatedTally tally;
  final VoidCallback? Function(KindSplit) tap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Ring(
                        inDate: tally.inDate,
                        needsStarting: tally.needsStarting,
                        lapsed: tally.lapsed,
                        percent: tally.percent,
                      ),
                    ),
                  ),
                  // Presenting your numbers, on the same baseline as the ring's
                  // lower edge — the pair reads as somebody showing you a
                  // result, which is what a dashboard is.
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Scout(
                      pose: ScoutPose.report,
                      height: 150,
                      motion: [ScoutMotion.breathe],
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: c.line, height: 1),

            /*
              Four equal columns. "In date" is not tappable — there is nothing
              to do about something that is fine — while the other three go to
              whichever screen their count is actually made of. See
              `destinationFor`: they all used to open the items list, so a
              household whose two "action needed" were passports tapped a
              correct number and landed on an empty screen.
            */
            Row(
              children: [
                Expanded(
                  child: Figure(value: '${tally.inDate}', label: 'in date', tone: c.moss),
                ),
                Expanded(
                  child: Figure(
                    value: '${tally.needsStarting}',
                    label: 'action needed',
                    tone: c.honey,
                    onTap: tap(tally.needsStartingBy),
                  ),
                ),
                Expanded(
                  child: Figure(
                    value: '${tally.lapsed}',
                    label: 'lapsed',
                    tone: c.ember,
                    onTap: tap(tally.lapsedBy),
                  ),
                ),
                Expanded(
                  child: Figure(
                    value: '${tally.noDate}',
                    label: 'no date',
                    onTap: tap(tally.noDateBy),
                  ),
                ),
              ],
            ),

            Divider(color: c.line, height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontFamily: fontBody, fontSize: 12, color: c.muted),
                    children: [
                      const TextSpan(text: 'Across '),
                      TextSpan(
                        text: '${tally.items}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
                      ),
                      TextSpan(text: tally.items == 1 ? ' item and ' : ' items and '),
                      TextSpan(
                        text: '${tally.papers}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
                      ),
                      TextSpan(text: tally.papers == 1 ? ' document' : ' documents'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The backup line, and it never goes away.
///
/// Between nudges the dashboard said nothing at all about backups, so the
/// honest reading of a quiet screen was "fine" — and the state it was quietest
/// about was a phone whose only copy of everything was itself. That matters
/// more here than it did on the web: the database is encrypted with a key that
/// never leaves this handset.
class _BackupRow extends StatelessWidget {
  const _BackupRow({required this.status, required this.onGo});

  final BackupStatus status;
  final void Function(Tab) onGo;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    final tone = switch (status.tone) {
      BackupTone.ok => c.moss,
      BackupTone.due => c.honey,
      BackupTone.never => c.ember,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: c.slate700,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: c.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                status.label,
                style: TextStyle(fontFamily: fontBody, fontSize: 13.5, color: c.text),
              ),
            ),
            // A line that reports a problem and cannot reach the fix is a line
            // that gets read and ignored.
            GestureDetector(
              onTap: () {
                feedback(Cue.tap);
                onGo(Tab.settings);
              },
              child: Text(
                'Back up',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: c.gold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What it costs, in three units.
///
/// The monthly figure is the one people budget in, so it is the one wearing
/// gold. A day and a year are the same money said two other ways: "about $2.49
/// a day" is a coffee, and "$908 a year" is a decision — and neither of those
/// sentences is available from a monthly total without arithmetic nobody does.
class _SpendChips extends StatelessWidget {
  const _SpendChips({required this.subs});

  final List<Subscription> subs;

  @override
  Widget build(BuildContext context) {
    String money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _Chip(money(totalMonthlyCents(subs)), 'A MONTH', lead: true),
          ),
          const SizedBox(width: 10),
          // `dailyCents` returns a double — a month's spend divided by 30.44
          // does not land on a whole cent, and rounding it before the yearly
          // figure is worked out would make the three numbers disagree.
          Expanded(child: _Chip(money(dailyCents(subs).round()), 'A DAY')),
          const SizedBox(width: 10),
          Expanded(child: _Chip(money(totalYearlyCents(subs)), 'A YEAR')),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.value, this.label, {this.lead = false});

  final String value;
  final String label;

  /// The one worth reading first, in gold on its own wash.
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: lead ? c.washGoldSoft : c.slate700,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: lead ? c.washGoldLine : c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w200,
                fontSize: 22,
                letterSpacing: -0.6,
                height: 1,
                color: lead ? c.gold : c.text,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: c.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of what is coming up.
///
/// ── Circled when it needs you, plain when it does not ─────────────────────
/// A flagged entry gets a bordered card; everything else is a plain row with a
/// dot. That is a bigger difference than a colour change, and it has to be: the
/// list is sorted worst-first, so the things that matter are already at the top
/// — the border is what stops somebody scrolling past them on the way to
/// reading the whole list.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final when = whenLabelFor(entry);
    final urgent = entry.urgency == Urgency.now || entry.urgency == Urgency.overdue;

    final body = Row(
      children: [
        if (!urgent) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: entry.flagged ? c.honey : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 11),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: fontBody, fontSize: 12, color: c.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          when,
          style: TextStyle(
            fontFamily: fontBody,
            fontSize: 12.5,
            fontWeight: urgent ? FontWeight.w700 : FontWeight.w400,
            color: urgent ? c.gold : c.muted,
          ),
        ),
      ],
    );

    if (!urgent) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: body,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: c.slate800,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.line),
        ),
        child: body,
      ),
    );
  }
}

/// What is missing, and why it matters.
///
/// ── Not a scolding, and the copy is where that is decided ─────────────────
/// Every row says the number, the thing, and **why it is worth doing** — "it is
/// the first thing a claim asks for, and shops will not reissue one". A card
/// that listed four counts without the second half would be an app telling
/// somebody off for not filling in its forms.
class _NeedsCard extends StatelessWidget {
  const _NeedsCard({required this.gaps, required this.onGo});

  final List<Gap> gaps;
  final void Function(Tab) onGo;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final total = gaps.fold<int>(0, (n, g) => n + g.count);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ears up, down the left of the card. Same card as the resting
              // state, opposite posture — the difference between the two should
              // be legible before a word is read.
              const Scout(
                pose: ScoutPose.alert,
                height: 132,
                motion: [ScoutMotion.alert],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Needs a minute',
                            style: TextStyle(
                              fontFamily: fontBody,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                        ),
                        Text(
                          '$total',
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 13,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                    for (final gap in gaps) ...[
                      Divider(color: c.line, height: 18),
                      InkWell(
                        onTap: () {
                          feedback(Cue.tap);
                          onGo(Tab.items);
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${gap.count}',
                                style: TextStyle(
                                  fontFamily: fontDisplay,
                                  fontWeight: FontWeight.w200,
                                  fontSize: 21,
                                  height: 1.1,
                                  color: c.gold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    // The count is already in the column to the
                                    // left; leaving it in the sentence too puts
                                    // the same number twice on one row.
                                    gap.label.replaceFirst(RegExp(r'^\d+\s+'), ''),
                                    style: TextStyle(
                                      fontFamily: fontBody,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.text,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    gap.why,
                                    style: TextStyle(
                                      fontFamily: fontBody,
                                      fontSize: 11.5,
                                      color: c.muted,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 6, top: 2),
                              child: Icon(Icons.chevron_right, size: 18, color: c.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The last few things you put in, photograph first.
///
/// Horizontal, and a picture rather than a text box. A grid of three text rows
/// was the least interesting thing on the screen, and these are the items
/// somebody most recently held in their hands — they will recognise the
/// photograph faster than they will read the name.
///
/// Nothing on the picture is words. An earlier version put the countdown in a
/// chip lying on the photo and it was illegible twice over: too small, then
/// abbreviated to "2y 4m" *because* it was small. The ring carries the state —
/// the same ring as every row of the items list, so it needs no learning — and
/// the sentence sits underneath on solid ground.
class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.repo, required this.items});

  final Repository repo;
  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = items[i];

          // Worked out once. Three calls to the same pure function on every
          // frame of a horizontal scroll is three times the arithmetic for one
          // answer.
          final left = warrantyParts(item);

          return SizedBox(
            width: 176,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The photograph fills the width, with the ring in the corner
                  // rather than around it. At this size a ring round the whole
                  // picture would be a hoop with a stamp inside it.
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: _Photo(repo: repo, item: item)),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: ItemArtLive(
                            repo: repo,
                            item: item,
                            size: 30,
                            stroke: 2.6,
                            fallback: const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          left.unit == 'no warranty'
                              ? 'No warranty'
                              : left.value == 'Lifetime'
                                  ? 'Covered for life'
                                  : '${left.value} ${left.unit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 12,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Just the picture, filling its box.
class _Photo extends StatelessWidget {
  const _Photo({required this.repo, required this.item});

  final Repository repo;
  final Item item;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return FutureBuilder<ImageProvider?>(
      future: thumbFor(repo, item.thumbBlobId ?? item.photoBlobId),
      builder: (context, snap) {
        final image = snap.data;
        if (image == null) {
          return Container(
            color: c.slate600,
            child: Icon(Icons.inventory_2_outlined, size: 28, color: c.muted),
          );
        }
        return Image(image: image, fit: BoxFit.cover);
      },
    );
  }
}
