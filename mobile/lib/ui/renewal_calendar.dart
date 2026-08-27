/// A month, with a dot on every day something is charged.
///
/// ── Why a calendar and not another list ───────────────────────────────────
/// The list already says what renews and when. What it cannot show is the
/// *shape* of a month — that the 25th, the 28th and the 1st are three days
/// apart and the rest of it is empty, or that four charges land in the same
/// week. Subscription spending is not level, and a calendar is the only view
/// that makes the clustering visible without arithmetic.
///
/// Monday first. The week people budget in starts on a Monday, and a Sunday
/// column at the far right is where a weekend belongs on a bill.
library;

import 'package:flutter/material.dart';

import '../logic/subscriptions.dart';
import '../models/subscription.dart';
import 'feedback.dart';
import 'theme.dart';

class RenewalCalendar extends StatefulWidget {
  const RenewalCalendar({
    required this.subs,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<Subscription> subs;

  /// The chosen day, or null. Selecting one highlights every subscription that
  /// charges on it — which is the point of the whole component.
  final DateTime? selected;

  final ValueChanged<DateTime?> onSelect;

  @override
  State<RenewalCalendar> createState() => _RenewalCalendarState();
}

class _RenewalCalendarState extends State<RenewalCalendar> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const List<String> _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  void _step(int by) {
    feedback(Cue.tap);
    setState(() => _month = DateTime(_month.year, _month.month + by));
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    final first = DateTime(_month.year, _month.month);
    final next = DateTime(_month.year, _month.month + 1);
    final days = next.difference(first).inDays;

    // `DateTime.weekday` is 1 for Monday, so Monday-first needs no shifting —
    // unlike the JavaScript this came from, where Sunday is 0 and every
    // calendar starts with an off-by-one.
    final lead = first.weekday - 1;

    /*
      Which days have a charge, worked out once for the whole month rather than
      per cell. `renewalsBetween` walks the cadence forward from the anchor, so
      asking it forty-two times would walk the same ground forty-two times.
    */
    final charged = <int, int>{};
    for (final sub in widget.subs) {
      for (final at in renewalsBetween(sub, first, next)) {
        charged[at.day] = (charged[at.day] ?? 0) + sub.amountCents;
      }
    }

    final today = DateTime.now();
    final isThisMonth = today.year == _month.year && today.month == _month.month;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      decoration: BoxDecoration(
        color: c.slate700,
        borderRadius: BorderRadius.circular(Radii.lg),
        
        boxShadow: cardShadow(c, dark: Theme.of(context).brightness == Brightness.dark),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _step(-1),
                icon: const Icon(Icons.chevron_left),
                color: c.muted,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  '${_months[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _step(1),
                icon: const Icon(Icons.chevron_right),
                color: c.muted,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 4),

          Row(
            children: [
              for (final d in _weekdays)
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: fontBody, fontSize: 11, color: c.muted),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 6),

          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Wider than tall. A square cell gives six rows of near-empty
            // space and pushes the list this screen is really about off the
            // bottom — the grid only has to be readable, not roomy.
            childAspectRatio: 1.55,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var day = 1; day <= days; day++)
                _Day(
                  day: day,
                  charged: charged.containsKey(day),
                  today: isThisMonth && today.day == day,
                  selected: widget.selected != null &&
                      widget.selected!.year == _month.year &&
                      widget.selected!.month == _month.month &&
                      widget.selected!.day == day,
                  onTap: () {
                    feedback(Cue.tap);
                    final picked = DateTime(_month.year, _month.month, day);
                    // Tapping the chosen day again clears it. A filter with no
                    // way off is a filter people back out of the screen to
                    // escape.
                    widget.onSelect(
                      widget.selected == picked ? null : picked,
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.charged,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool charged;
  final bool today;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      // Only a day with something on it does anything. A calendar where every
      // cell responds teaches people that tapping is how you find out, which on
      // an empty month is thirty taps for nothing.
      onTap: charged ? onTap : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? c.washGold : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.sm),
          // Today is outlined, a chosen day is filled. Two different facts, so
          // two different marks — an outline that also filled would make "the
          // day I tapped" and "today" indistinguishable on the day they agree.
          border: Border.all(
            color: today ? c.washGoldLine : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 12.5,
                height: 1.1,
                fontWeight: charged ? FontWeight.w600 : FontWeight.w400,
                color: charged ? c.text : c.muted,
              ),
            ),
            const SizedBox(height: 1),
            // The dot, not a number. How much is charged that day is a figure
            // nobody can read at this size, and the question the grid answers
            // is "which days", not "how much on each".
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: charged ? c.gold : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
