/// The "Stash it" button, and what it offers.
///
/// ── A pill with words on it, not a circle with a plus ─────────────────────
/// A floating `+` is a shape that means "add" only to people who already know
/// the app. The PWA's button says **Stash it** — the app's own name used as a
/// verb, which is the whole idea the product is built on — and that is worth
/// more than the eighty pixels a circle would save.
///
/// ── And it asks what kind ─────────────────────────────────────────────────
/// Three things can be stashed and they go to three different forms. The
/// alternative is a `+` on every tab that adds whatever that tab holds, which
/// works right up until somebody is looking at their subscriptions and wants to
/// add a receipt.
///
/// A list rather than three hard-coded buttons: the reason for making the
/// button expand instead of asking "which kind?" in a dialog is that a fourth
/// kind is plausible. Adding one should be a line in `_kinds` and nothing else.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import 'feedback.dart';
import 'item_form_screen.dart';
import 'paper_form_screen.dart';
import 'sub_form_screen.dart';
import 'theme.dart';

enum AddKind { item, subscription, paper }

const List<(AddKind, IconData, String, String)> _kinds = [
  (AddKind.item, Icons.inventory_2_outlined, 'Something you own', 'A kettle, a couch, the boiler'),
  (AddKind.subscription, Icons.autorenew, 'Something recurring', 'Netflix, the gym, insurance'),
  (AddKind.paper, Icons.badge_outlined, 'A document', 'A passport, a licence, a policy'),
];

class StashItButton extends StatelessWidget {
  const StashItButton({required this.repo, this.onDone, super.key});

  final Repository repo;

  /// Called after a form closes, whatever happened in it — the tab underneath
  /// has to rebuild whether something was saved, edited or deleted.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Material(
      color: c.gold,
      borderRadius: BorderRadius.circular(Radii.pill),
      // The shadow is gold rather than black: a coloured object lit from
      // behind throws its own colour, and a grey shadow under a gold pill on a
      // near-black background just reads as dirt.
      elevation: 6,
      shadowColor: c.gold.withValues(alpha: 0.6),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 20, color: c.onGold),
              const SizedBox(width: 6),
              Text(
                'Stash it',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                  color: c.onGold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    feedback(Cue.expand);

    final kind = await showModalBottomSheet<AddKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (kind, icon, label, note) in _kinds)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                subtitle: Text(note),
                onTap: () => Navigator.of(context).pop(kind),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (kind == null) {
      feedback(Cue.collapse);
      return;
    }
    if (!context.mounted) return;

    feedback(Cue.tap);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => switch (kind) {
          AddKind.item => ItemFormScreen(repo: repo),
          AddKind.subscription => SubFormScreen(repo: repo),
          AddKind.paper => PaperFormScreen(repo: repo),
        },
      ),
    );

    onDone?.call();
  }
}
