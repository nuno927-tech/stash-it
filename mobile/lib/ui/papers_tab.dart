/// Documents that expire.
///
/// ── Sorted by when to start, not by when they run out ─────────────────────
/// Those two orders genuinely differ. A passport expiring in nine months needs
/// starting before a driving license expiring in four, because one needs eight
/// months of runway and the other needs two. Sorting by the printed date puts
/// them the wrong way round, which is the mistake this whole feature exists to
/// prevent — so the list uses `sortPapers`, which sorts by renew-by.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../notify/sync.dart';
import '../logic/papers.dart';
import '../logic/timeline.dart';
import '../models/paper.dart';
import 'notify_offer_dialog.dart';
import 'confirm_delete.dart';
import 'feedback.dart';
import 'paper_form_sheet.dart';
import 'paper_icon.dart';
import 'status_pill.dart';
import 'parts.dart';
import 'scout.dart';
import 'swipe_to_delete.dart';
import 'theme.dart';
import 'undo_bar.dart';

class PapersTab extends StatefulWidget {
  const PapersTab({required this.repo, super.key});

  final Repository repo;

  @override
  State<PapersTab> createState() => _PapersTabState();
}

class _PapersTabState extends State<PapersTab> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};

  /// The row a chip just pointed at, lit for a few seconds.
  ///
  /// Timed rather than permanent: the highlight is an answer to "which one",
  /// and an answer that stays on screen becomes a selection somebody then has
  /// to work out how to clear.
  String? _lit;
  Timer? _dim;

  @override
  void dispose() {
    _dim?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _find(List<Paper> sorted, PaperState? state) async {
    feedback(Cue.tap);

    final target = state == null
        ? (sorted.isEmpty ? null : sorted.first)
        : sorted.where((p) => paperState(p) == state).firstOrNull;

    if (target == null) return;

    final key = _keys[target.id];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        // Not flush to the top: a row pinned to the very edge of the viewport
        // looks like the list starts there rather than like the list scrolled.
        alignment: 0.25,
      );
    }

    if (!mounted) return;
    setState(() => _lit = target.id);

    _dim?.cancel();
    _dim = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _lit = null);
    });
  }

  Future<void> _delete(Paper paper) async {
    await widget.repo.softDeletePaper(paper.id);
    unawaited(syncReminders(widget.repo));

    if (!mounted) return;
    setState(() {});
    showUndo(
      context,
      message: '${paper.label} moved to the bin.',
      onUndo: () async {
        await widget.repo.restorePaper(paper.id);
        unawaited(syncReminders(widget.repo));
        if (mounted) setState(() {});
      },
    );
  }

  /// The form, then a rebuild.
  ///
  /// Unlike Items, this tab reads a future rather than a stream — so a save
  /// has to be told about. Worth knowing the difference is deliberate: the
  /// items list is watched because it is the one people leave open.
  /// No `BuildContext` parameter: `mounted` describes this State, and a
  /// context handed in from elsewhere is not tied to it. The analyzer says so.
  Future<void> open(Paper? paper) async {
    await showPaperForm(context, repo: widget.repo, existing: paper);
    if (!mounted) return;
    setState(() {});
    await maybeOfferNotifications(context, widget.repo);
  }

  @override
  Widget build(BuildContext context) {
    // No button of its own: the shell's "Stash it" pill adds all three kinds,
    // and a per-tab `+` alongside it would be two ways to do one thing that
    // disagree about what "add" means on this screen.
    return _body(context);
  }

  Widget _body(BuildContext context) {
    return FutureBuilder<List<Paper>>(
      future: widget.repo.activePapers(),
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) return const Center(child: CircularProgressIndicator());

        if (all.isEmpty) {
          return const Blank(
            'Passports, licenses, insurance — the things that expire on you.\n\n'
            'Dates and general details only. No scans, no document numbers.\n\n'
            'Tap Stash it to add one.',
            pose: ScoutPose.clipboard,
          );
        }

        final sorted = sortPapers(all);
        final needing = needsRenewing(all).where((p) => paperState(p) == PaperState.renew).length;
        final expired = all.where((p) => paperState(p) == PaperState.expired).length;
        final next = sorted.isEmpty ? null : sorted.first;

        // A key per row, so a chip can scroll to the one it is about.
        _keys.removeWhere((id, _) => !all.any((p) => p.id == id));
        for (final p in sorted) {
          _keys.putIfAbsent(p.id, GlobalKey.new);
        }

        return ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _Tiles(
              total: all.length,
              needing: needing,
              expired: expired,
              next: next,
              // Each chip scrolls to the first row it is about and lights it
              // up. A count that cannot take you to what it counted is a
              // number you have to go and find by hand.
              onFind: (state) => _find(sorted, state),
            ),

            const SectionTitle('Expiring'),

            for (final paper in sorted)
              _PaperTile(
                key: _keys[paper.id],
                paper: paper,
                lit: _lit == paper.id,
                onTap: () => open(paper),
                onDelete: () => _delete(paper),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

/// The four figures, with Scout beside them.
///
/// The same arrangement as Items and Subscriptions: a two-by-two grid on the
/// left, him on the right filling both rows, doing the job the screen is for.
class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.total,
    required this.needing,
    required this.expired,
    required this.next,
    required this.onFind,
  });

  final int total;
  final int needing;
  final int expired;
  final Paper? next;
  final void Function(PaperState?) onFind;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final start = next == null ? null : renewBy(next!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _Tile('$total', 'DOCUMENTS')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Tile(
                        '$needing',
                        'NEEDS ACTION',
                        tone: needing > 0 ? c.honey : null,
                        onTap: needing > 0 ? () => onFind(PaperState.renew) : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Tile(
                        '$expired',
                        'OUT OF DATE',
                        tone: expired > 0 ? c.ember : null,
                        onTap: expired > 0 ? () => onFind(PaperState.expired) : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Tile(
                        // The date to start, not the date it expires. The whole
                        // reason this tab sorts by renew-by is that those two
                        // are different, and only one of them is actionable.
                        start == null ? '—' : dayMonth(start),
                        'UP NEXT',
                        small: true,
                        onTap: next == null ? null : () => onFind(null),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Scout(
              pose: ScoutPose.clipboard,
              height: 132,
              motion: [ScoutMotion.breathe],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
    this.value,
    this.label, {
    this.tone,
    this.onTap,
    this.small = false,
  });

  final String value;
  final String label;
  final Color? tone;
  final VoidCallback? onTap;

  /// A date rather than a count, so it needs less room to itself.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        decoration: BoxDecoration(
          color: tone == null ? c.slate700 : c.washGoldSoft,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: tone == null ? Colors.transparent : c.washGoldLine),
          boxShadow: cardShadow(c, dark: Theme.of(context).brightness == Brightness.dark),
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
                  fontSize: small ? 19 : 23,
                  letterSpacing: -0.8,
                  height: 1.05,
                  color: tone ?? c.text,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.67,
                color: c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperTile extends StatelessWidget {
  const _PaperTile({
    required this.paper,
    this.lit = false,
    this.onTap,
    this.onDelete,
    super.key,
  });

  final Paper paper;

  /// Just scrolled to by a chip.
  final bool lit;

  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    if (onDelete == null) return _row(context, c);

    return SwipeToDelete(
      id: 'paper-${paper.id}',
      name: paper.label,
      // A tick when the row is far enough — see `SwipeToDelete`, which
      // exists for that one buzz.
      confirm: () => confirmDelete(context, name: paper.label),
      onDelete: onDelete!,
      child: _row(context, c),
    );
  }

  Widget _row(BuildContext context, StashColors c) {
    final state = paperState(paper);
    final expiry = expiryOf(paper);
    final start = renewBy(paper);

    final tone = switch (state) {
      PaperState.valid => c.moss,
      PaperState.renew => c.honey,
      PaperState.expired => c.ember,
    };

    final holder = paper.holder?.trim();
    final acts = state != PaperState.valid;

    final status = switch (state) {
      PaperState.expired => StashStatus.overdue,
      PaperState.renew => StashStatus.soon,
      PaperState.valid => StashStatus.settled,
    };

    final body = Row(
      children: [
        /*
          Anything needing action is circled, the same way the ring marks it on
          the dashboard. Two screens, one visual language: if it has a coloured
          edge, it wants something from you.
        */
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: acts ? tone : Colors.transparent, width: 2),
          ),
          // The kind's own mark, not the same sheet of paper thirteen times.
          // A passport, a paw and a car are told apart before the label under
          // them is read, which is the whole reason a list has icons.
          child: PaperGlyph(paper.kind, color: tone, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                holder == null || holder.isEmpty
                    ? paper.label
                    : '${paper.label} — $holder',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.15,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  if (acts) ...[
                    StatusPill(
                      status: status,
                      // "Expired" and "Renew" — the state, where the sentence
                      // beside it carries the date. Saying both twice would be
                      // saying nothing twice.
                      label: state == PaperState.expired ? 'Expired' : 'Renew',
                    ),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      _line(state, expiry, start),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 11.5,
                        color: c.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        /*
          The kind, in the same gold as the other two lists' right-hand
          columns. It is not a number, but it is the same slot answering the
          same shape of question, and a muted 11pt label in the place where
          the other two screens put their answer read as a leftover.
        */
        Text(
          kindLabel[paper.kind]!,
          textAlign: TextAlign.right,
          // The display face, like every other right-hand answer in the app —
          // the item countdown, the subscription amount, the timeline's
          // number. Inter was the odd one out in a column that is meant to
          // read as the same thing four times.
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: c.gold,
          ),
        ),
      ],
    );

    /*
      ── Boxed when it wants something, plain when it does not ────────────────

      The same rule the dashboard's timeline uses: a border rather than a fill,
      because these rows already carry a coloured circle and a coloured line,
      and a solid background on top is the third way of saying one thing. On a
      bad month four filled rows in a row stop reading as urgent and start
      reading as the background.
    */
    if (!acts) {
      return InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
          decoration: BoxDecoration(
            color: lit ? c.washGoldSoft : c.slate800,
            border: Border(bottom: BorderSide(color: c.slate700)),
          ),
          child: body,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      child: Material(
        color: lit ? c.washGoldSoft : c.slate800,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(11),
            /*
              The wash replaces the outline. A border around a row that already
              carries a coloured circle and a coloured word was the third way
              of saying one thing — and four boxed rows together stopped
              reading as urgent and started reading as a table.
            */
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              gradient: lit ? null : statusWash(c, status),
              border: lit ? Border.all(color: c.washGoldLine) : null,
            ),
            child: body,
          ),
        ),
      ),
    );
  }

  String _line(PaperState state, DateTime? expiry, DateTime? start) {
    if (expiry == null) return 'No expiry recorded';

    return switch (state) {
      PaperState.expired => 'Expired ${dayMonth(expiry)}',
      // The window is open, which is a state and not a countdown — see
      // `whenLabel`. Saying "62 days late" about a passport that does not
      // expire until February would be worse than saying nothing.
      PaperState.renew => 'Start now · expires ${dayMonth(expiry)}',
      PaperState.valid =>
        start == null ? 'Expires ${dayMonth(expiry)}' : 'Start ${dayMonth(start)}',
    };
  }
}
