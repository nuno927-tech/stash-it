/// What leaves your account each month.
///
/// ── Why there is a chart and not just a total ─────────────────────────────
/// A monthly total is an average, and an average hides the only thing about
/// subscription spending that ever surprises anybody: it is not level. Three
/// annual plans that happen to renew in the same month make that month cost
/// four times what October does, and no amount of staring at "$94 a month"
/// will tell you that.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/format.dart';
import '../logic/subscriptions.dart';
import '../logic/timeline.dart';
import '../models/subscription.dart';
import 'notify_offer_dialog.dart';
import 'parts.dart';
import 'sub_form_screen.dart';

class SubsTab extends StatefulWidget {
  const SubsTab({required this.repo, super.key});

  final Repository repo;

  @override
  State<SubsTab> createState() => _SubsTabState();
}

class _SubsTabState extends State<SubsTab> {
  Future<void> open(BuildContext context, Subscription? sub) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SubFormScreen(repo: widget.repo, existing: sub),
      ),
    );
    if (!mounted) return;
    setState(() {});
    await maybeOfferNotifications(context, widget.repo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => open(context, null),
        tooltip: 'Add a subscription',
        child: const Icon(Icons.add),
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    return FutureBuilder<List<Subscription>>(
      future: widget.repo.activeSubscriptions(),
      builder: (context, snap) {
        final subs = snap.data;
        if (subs == null) return const Center(child: CircularProgressIndicator());

        if (subs.isEmpty) {
          return const Blank(
            'Nothing recurring yet.\n\n'
            'Add what you pay for and this shows what a month really costs, '
            'which months are the heavy ones, and what renews next.\n\n'
            'Tap + to add one.',
          );
        }

        final theme = Theme.of(context);
        final monthly = totalMonthlyCents(subs);
        final week = dueWithin(subs, 7);
        final spend = spendByMonth(subs, 6);
        final top = biggest(subs);

        final sorted = [...subs]..sort((a, b) {
            final da = daysUntilRenewal(a) ?? 9999;
            final db = daysUntilRenewal(b) ?? 9999;
            return da != db ? da - db : a.name.compareTo(b.name);
          });

        return ListView(
          children: [
            const SectionTitle('Subscriptions'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Wrap(
                children: [
                  Figure(value: _money(monthly), label: 'a month'),
                  Figure(value: _money(totalYearlyCents(subs)), label: 'a year'),
                  /*
                    The same money in the unit people actually feel. "$94 a
                    month" is a line on a statement; "about $3 a day" is a
                    coffee, and it is the framing that makes somebody look at
                    the list.
                  */
                  Figure(
                    value: '\$${(dailyCents(subs) / 100).toStringAsFixed(2)}',
                    label: 'a day',
                  ),
                  if (week.count > 0)
                    Figure(
                      value: _money(week.cents),
                      label: 'due this week',
                      tone: const Color(0xFFF2B33D),
                    ),
                ],
              ),
            ),

            const SectionTitle('The next six months'),
            _SpendChart(spend: spend),

            if (top != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Biggest is ${top.name}, at ${_money(monthlyCents(top))} a month.',
                  style: theme.textTheme.bodySmall,
                ),
              ),

            const SectionTitle('Renewing next'),
            for (final sub in sorted)
              _SubTile(sub: sub, onTap: () => open(context, sub)),
            const SizedBox(height: 88),
          ],
        );
      },
    );
  }
}

String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

/// Six bars, and the heaviest month named.
///
/// Whole months, including the part of this one already spent. A first bar
/// showing only what is left would be a different measurement from the five
/// beside it, which is the one thing a bar chart must never do.
class _SpendChart extends StatelessWidget {
  const _SpendChart({required this.spend});

  final List<MonthSpend> spend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = heaviest(spend);
    final most = peak?.cents ?? 0;

    return SizedBox(
      height: 150,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final month in spend)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      month.cents == 0 ? '' : _money(month.cents),
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: most == 0 ? 2 : 8 + (month.cents / most) * 78,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: month.cents == most && most > 0
                            ? const Color(0xFFF2B33D)
                            : theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      // Months are 1-based in Dart and 0-based in the
                      // TypeScript this came from — see `MonthSpend.month`.
                      dayMonth(DateTime(month.year, month.month)).split(' ').first,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubTile extends StatelessWidget {
  const _SubTile({required this.sub, this.onTap});

  final Subscription sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final at = nextRenewal(sub);
    final days = daysUntilRenewal(sub);
    final due = reminderDue(sub);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(sub.name.isEmpty ? '?' : sub.name[0].toUpperCase()),
      ),
      title: Text(sub.name),
      subtitle: Text(
        at == null
            ? 'No renewal date'
            : 'Renews ${dayMonth(at)} · ${cadenceLabel[sub.cadence]}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${currencySymbol(sub.currency)}${(sub.amountCents / 100).toStringAsFixed(2)}',
          ),
          if (days != null)
            Text(
              days == 0 ? 'today' : '$days d',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    // A reminder is the only thing that lifts a renewal out of
                    // the ordinary run of them.
                    color: due ? const Color(0xFFF2B33D) : null,
                  ),
            ),
        ],
      ),
    );
  }
}
