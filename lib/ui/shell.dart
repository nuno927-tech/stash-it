/// The five tabs, the bar under them, and the swipe between them.
///
/// ── The order is not cosmetic ─────────────────────────────────────────────
/// It comes from `Tab` in logic/swipe.dart, which is the same list the swipe
/// gesture steps through. They were once two lists: Subscriptions was added to
/// the bar and not to the order, so swiping left from Items landed on Settings
/// — it skipped the tab sitting between them and nothing on screen explained
/// why. One list, one order.
library;

// Material exports a `Tab` widget — the thing that sits in a `TabBar`. Ours is
// the enum in logic/swipe.dart, which is the app's five destinations. Material
// is the one hidden, because this app has no TabBar and every mention of `Tab`
// in these files means a destination.
import 'package:flutter/material.dart' hide Tab;

import '../db/repository.dart';
import '../logic/swipe.dart';
import 'add_button.dart';
import 'feedback.dart';
import 'home_tab.dart';
import 'items_tab.dart';
import 'nav_icons.dart';
import 'papers_tab.dart';
import 'parts.dart';
import 'settings_tab.dart';
import 'subs_tab.dart';
import 'theme.dart';

class Shell extends StatefulWidget {
  const Shell({required this.repo, super.key});

  final Repository repo;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Tab _tab = Tab.home;

  /// Bumped to force the visible tab to rebuild after the add sheet closes.
  /// Items watches a stream and does not need it; the other three read futures.
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      ── The add button sits OVER the whole app, title bar and nav included ──

      It has been moved twice. As a `floatingActionButton` it lived in the
      Scaffold's own slot, sized to itself, so its scrim could dim the eighty
      pixels it occupied and nothing else. Moved into the body it could dim the
      screen but not the heading above it or the tab bar below — and a menu
      that leaves two strips of the app fully lit is a menu that has not taken
      over, which is the one thing it needs to look like.

      So it stacks on top of the entire Scaffold. Everything is behind the
      scrim because everything is behind it.
    */
    return Stack(
      children: [
        _scaffold(context, c),

        /*
          ── Not on Settings ────────────────────────────────────────────────

          There is nothing on that screen to add one of. Every other tab is a
          list the button puts things into; Settings is the one place where a
          floating "Stash it" answers no question, and it sits over the version
          card and the share button while doing it.
        */
        if (_tab != Tab.settings)
          Positioned.fill(
            child: StashItButton(
              repo: widget.repo,
              onDone: () => setState(() => _generation++),
            ),
          ),
      ],
    );
  }

  Widget _scaffold(BuildContext context, StashColors c) {
    return Scaffold(
      body: SafeArea(
        /*
          ── The swipe, which `logic/swipe.dart` has always known how to do ───

          `nextTab` and the direction rules were ported in phase 1, tested, and
          then never called — the sixth green-test-no-caller in this port. The
          gesture is what makes a five-tab app feel like a phone app rather
          than a website with a tab bar.

          `onHorizontalDragEnd` rather than tracking the drag: the velocity is
          the whole signal, and a partial drag with a live preview is a much
          bigger piece of work for something people do without looking.
        */
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final vx = details.primaryVelocity ?? 0;

            // Below this it was a scroll that wandered, not a swipe. The web
            // version fought the browser for the same reason `touch-action:
            // pan-y` is set there.
            if (vx.abs() < 220) return;

            final to = nextTab(_tab, vx < 0 ? Direction.left : Direction.right);
            if (to == null) return;
            _select(to);
          },
          child: Column(
            children: [
              // The heading belongs to the shell, not to each screen: it has to
              // be in the same place, at the same size, after every swipe, and
              // five screens each drawing their own is five chances for one to
              // drift. Home takes the wordmark — see `Wordmark`.
              if (_tab == Tab.home)
                const Padding(
                  // The same 2 and 4 as `TabTitle`, so the wordmark and every
                  // screen's name sit on exactly the same line. They are the
                  // same object doing the same job, and a four-pixel drift
                  // between tabs is visible the moment you swipe.
                  padding: EdgeInsets.fromLTRB(16, 2, 16, 4),
                  child: Align(alignment: Alignment.centerLeft, child: Wordmark()),
                )
              else
                TabTitle(
                  switch (_tab) {
                    Tab.items => 'Items',
                    Tab.subs => 'Subscriptions',
                    Tab.papers => 'Documents',
                    Tab.settings => 'Settings',
                    Tab.home => '',
                  },
                  /*
                    None. Every screen stands Scout beside its own content, at a
                    size worth looking at — Settings included, now.

                    He was in this heading for Settings alone, and a pose here
                    forces the row to align on its bottom edge, which pushed
                    that one title a few pixels off the line every other tab
                    sits on. A heading that moves between tabs is the one thing
                    this widget exists to prevent.
                  */
                  pose: null,
                  /*
                    ── The album moved off this title ──────────────────────────

                    Ten taps on the word "Settings" used to open Scout's album.
                    It was well hidden and badly signposted: a heading is the
                    one thing on a screen nobody suspects of doing anything, so
                    in practice the only people who found it were told.

                    It lives on Scout himself now, over in the Settings tab —
                    see `_pokeScout`. Poking the animal is a thing people
                    already do.
                  */
                ),

              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: KeyedSubtree(
                        key: ValueKey('${_tab.name}-$_generation'),
                        child: switch (_tab) {
                          Tab.home => HomeTab(repo: widget.repo, onGo: _select),
                          Tab.items => ItemsTab(repo: widget.repo),
                          Tab.subs => SubsTab(repo: widget.repo),
                          Tab.papers => PapersTab(repo: widget.repo),
                          Tab.settings => SettingsTab(repo: widget.repo),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: NavigationBar(
        height: 74,
        backgroundColor: c.slate800,
        selectedIndex: _tab.index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => _select(Tab.values[i]),
        destinations: [
          for (final tab in Tab.values)
            NavigationDestination(
              icon: NavIcon(tab, color: c.muted),
              selectedIcon: NavIcon(tab, color: c.gold),
              label: switch (tab) {
                Tab.home => 'Home',
                Tab.items => 'Items',
                Tab.subs => 'Subs',
                Tab.papers => 'Documents',
                Tab.settings => 'Settings',
              },
            ),
        ],
      ),
    );
  }

  /*
    Tapping a figure on the dashboard goes somewhere.

    `destinationFor` decides where, and it exists because of a real bug: every
    chip under the ring opened the Items list, and both of its counts span
    items and documents. A house whose "action needed" was two passports
    tapped an accurate number and landed on an empty items screen — the count
    was right, the destination was wrong, and the app looked as though it had
    mislaid them.
  */
  void _select(Tab to) {
    if (to == _tab) return;
    // A lower, rounder note than an ordinary tap: moving between tabs is a
    // bigger gesture, and pitch carries that better than volume does.
    feedback(Cue.nav);
    setState(() => _tab = to);
  }
}
