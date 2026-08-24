/// Documents that expire.
///
/// ── Sorted by when to start, not by when they run out ─────────────────────
/// Those two orders genuinely differ. A passport expiring in nine months needs
/// starting before a driving license expiring in four, because one needs eight
/// months of runway and the other needs two. Sorting by the printed date puts
/// them the wrong way round, which is the mistake this whole feature exists to
/// prevent — so the list uses `sortPapers`, which sorts by renew-by.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/papers.dart';
import '../logic/timeline.dart';
import '../models/paper.dart';
import 'parts.dart';

class PapersTab extends StatelessWidget {
  const PapersTab({required this.repo, super.key});

  final Repository repo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Paper>>(
      future: repo.activePapers(),
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) return const Center(child: CircularProgressIndicator());

        if (all.isEmpty) {
          return const Blank(
            'Passports, licenses, insurance — the things that expire on you.\n\n'
            "Dates and general details only. No scans, no document numbers.",
          );
        }

        final sorted = sortPapers(all);
        final needing = needsRenewing(all).length;

        return ListView(
          children: [
            SectionTitle(
              'Documents',
              trailing: needing == 0
                  ? null
                  : Text(
                      '$needing need you',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
            ),
            for (final paper in sorted) _PaperTile(paper: paper),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _PaperTile extends StatelessWidget {
  const _PaperTile({required this.paper});

  final Paper paper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = paperState(paper);
    final expiry = expiryOf(paper);
    final start = renewBy(paper);

    final tone = switch (state) {
      PaperState.valid => const Color(0xFF5FBF7E),
      PaperState.renew => const Color(0xFFF2B33D),
      PaperState.expired => theme.colorScheme.error,
    };

    final holder = paper.holder?.trim();

    return ListTile(
      /*
        Anything needing action is circled, the same way the ring marks it on
        the dashboard. Two screens, one visual language: if it has a coloured
        edge, it wants something from you.
      */
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: state == PaperState.valid ? Colors.transparent : tone,
            width: 2,
          ),
        ),
        child: Icon(Icons.description_outlined, size: 20, color: tone),
      ),
      title: Text(
        holder == null || holder.isEmpty ? paper.label : '${paper.label} — $holder',
      ),
      subtitle: Text(_line(state, expiry, start)),
      trailing: Text(
        kindLabel[paper.kind]!,
        style: theme.textTheme.labelSmall,
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
