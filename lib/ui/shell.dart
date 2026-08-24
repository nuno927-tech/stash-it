/// The five tabs, and the bar under them.
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
import 'home_tab.dart';
import 'items_tab.dart';
import 'papers_tab.dart';
import 'settings_tab.dart';
import 'subs_tab.dart';

class Shell extends StatefulWidget {
  const Shell({required this.repo, super.key});

  final Repository repo;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Tab _tab = Tab.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_tab) {
          Tab.home => HomeTab(repo: widget.repo, onGo: _go),
          Tab.items => ItemsTab(repo: widget.repo),
          Tab.subs => SubsTab(repo: widget.repo),
          Tab.papers => PapersTab(repo: widget.repo),
          Tab.settings => SettingsTab(repo: widget.repo),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => setState(() => _tab = Tab.values[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.donut_large_outlined),
            selectedIcon: Icon(Icons.donut_large),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Items',
          ),
          NavigationDestination(
            icon: Icon(Icons.repeat_outlined),
            selectedIcon: Icon(Icons.repeat),
            label: 'Subs',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'Documents',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
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
  void _go(Tab to) => setState(() => _tab = to);
}
