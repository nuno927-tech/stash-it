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
import '../logic/devmode.dart';
import '../logic/swipe.dart';
import 'add_button.dart';
import 'feedback.dart';
import 'home_tab.dart';
import 'items_tab.dart';
import 'nav_icons.dart';
import 'papers_tab.dart';
import 'parts.dart';
import 'scout.dart';
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

  TapState _taps = noTaps;
  String? _hint;

  void _tapTitle() {
    setState(() {
      _taps = tap(_taps, DateTime.now());
      _hint = tapHint(_taps);
      if (unlocked(_taps)) {
        rememberUnlocked(true);
        // The Settings screen has to redraw to show what just appeared.
        _generation++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

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
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                  // Doing the job the screen is for: paperwork on Items, the
                  // month on Subscriptions, a clipboard on Documents, the
                  // control desk on Settings.
                  pose: switch (_tab) {
                    Tab.items => ScoutPose.receipt,
                    Tab.subs => ScoutPose.calendar,
                    Tab.papers => ScoutPose.clipboard,
                    Tab.settings => ScoutPose.settings,
                    Tab.home => null,
                  },
                  /*
                    Ten taps on the word "Settings", and the run resets if you
                    pause. Not a secret worth keeping — it is that a switch
                    which lifts the item cap has no business being one stray
                    thumb away on somebody's settings screen.

                    The heading rather than the version row, which is where the
                    port had put it: a title that does something when tapped is
                    invisible to anybody not looking for it, and a version
                    number that does is a version number people tap by accident
                    while reading it.
                  */
                  onTap: _tab == Tab.settings ? _tapTitle : null,
                  trailing: _hint == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 6),
                          child: Text(_hint!, style: Theme.of(context).textTheme.bodySmall),
                        ),
                ),

              /*
                The screen and the add button share one stack, so the button's
                scrim can dim the screen. As a `floatingActionButton` it sat in
                the Scaffold's own slot, sized to itself, and could only ever
                have dimmed the eighty pixels it occupied.
              */
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
                    Positioned.fill(
                      child: StashItButton(
                        repo: widget.repo,
                        onDone: () => setState(() => _generation++),
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
