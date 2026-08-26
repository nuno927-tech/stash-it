/// Adding and editing a subscription, as the sheet the PWA uses.
///
/// The rules live in `logic/subscription_form.dart` and the catalogue in
/// `logic/services.dart`. This is the boxes.
///
/// ── The grid is the field ─────────────────────────────────────────────────
/// The old form opened on an empty "Call it" box, which asked somebody to type
/// "Netflix" — a word the app already knows, spelled a way it could then never
/// match against its own logo list. The grid answers the name, the logo and
/// the service id in one tap, and the text field underneath is for the gym.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/repository.dart';
import '../logic/format.dart';
import '../logic/notify_offer.dart';
import '../logic/services.dart';
import '../logic/subscription_form.dart';
import '../logic/subscriptions.dart';
import '../models/subscription.dart';
import '../notify/sync.dart';
import 'confirm_delete.dart';
import 'feedback.dart';
import 'service_mark.dart';
import 'theme.dart';

/// Opens the form. Resolves true when something was saved.
Future<bool?> showSubForm(
  BuildContext context, {
  required Repository repo,
  Subscription? existing,
}) {
  feedback(Cue.expand);

  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => _SubFormSheet(repo: repo, existing: existing),
  );
}

class _SubFormSheet extends StatefulWidget {
  const _SubFormSheet({required this.repo, this.existing});

  final Repository repo;
  final Subscription? existing;

  @override
  State<_SubFormSheet> createState() => _SubFormSheetState();
}

class _SubFormSheetState extends State<_SubFormSheet> {
  late final SubscriptionDraft _draft = widget.existing == null
      ? SubscriptionDraft()
      : draftOfSubscription(widget.existing!);

  late final TextEditingController _name =
      TextEditingController(text: _draft.name);

  String? _problem;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /* ------------------------------------------------------------- saving */

  Future<void> _save() async {
    final problem = whyNotSaveableSubscription(_draft);
    if (problem != null) {
      feedback(Cue.error);
      setState(() => _problem = problem);
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    try {
      final sub = toSubscription(_draft, propertyId: widget.repo.propertyId);

      if (_isNew) {
        await widget.repo.createSubscription(sub);
      } else {
        await widget.repo.saveSubscription(sub);
      }

      unawaited(syncReminders(widget.repo));
      feedback(Cue.save);

      /*
        The notification offer, only when a reminder was actually asked for.

        Every other save in the app offers on the strength of having a date. A
        subscription always has one and almost never wants waking for — see the
        note on `remindDays` — so offering on a date alone would be offering an
        empty schedule to somebody who just chose None two fields up.
      */
      if (_draft.remindDays != null && _draft.remindDays != 0) {
        if (datedSave(expiresOn: _draft.anchorDate)) armNotifyOffer();
      }

      if (mounted) Navigator.of(context).pop(true);
    } on CapReached catch (e) {
      setState(() => _problem = e.message);
    } catch (e) {
      setState(() => _problem = 'That did not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final sure = await confirmDelete(context, name: _draft.name);
    if (!sure || widget.existing == null) return;

    await widget.repo.softDeleteSubscription(widget.existing!.id);
    unawaited(syncReminders(widget.repo));
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Picking one off the grid answers three questions at once.
  void _choose(ServiceDef service) {
    feedback(Cue.tap);
    setState(() {
      _draft.serviceId = service.id;
      _draft.name = service.name;
      _name.text = service.name;
    });
  }

  Future<void> _pickDate({required bool anchor}) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(anchor ? _draft.anchorDate : (_draft.startedDate ?? ''));

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      /*
        The next renewal is allowed to be in the future and the start is not.

        They are the two halves of the same arithmetic — `nextRenewal` walks
        forward from the anchor — and a "started" date after today would mean a
        subscription that has not begun paying for a renewal that already has.
      */
      lastDate: anchor ? DateTime(now.year + 12) : now,
    );

    if (picked == null) return;
    feedback(Cue.tap);

    final iso = '${picked.year.toString().padLeft(4, '0')}'
        '-${picked.month.toString().padLeft(2, '0')}'
        '-${picked.day.toString().padLeft(2, '0')}';

    setState(() {
      if (anchor) {
        _draft.anchorDate = iso;
      } else {
        _draft.startedDate = iso;
      }
    });
  }

  /// What this will cost per month, while it is being typed.
  ///
  /// A weekly plan is 52.18 weeks a year, not four weeks a month — four
  /// undercounts by about 8%, which is the kind of error that makes a total
  /// look believable and wrong. This is how somebody notices that £5 a week is
  /// not £20 a month.
  String? get _monthly {
    final cents = parseMoneyToCents(_draft.amountText);
    if (cents == null || cents == 0) return null;
    if (_draft.cadence == Cadence.monthly) return null;

    final sub = toSubscription(
      SubscriptionDraft(
        name: 'x',
        anchorDate: '2026-01-01',
        cadence: _draft.cadence,
        amountText: _draft.amountText,
      ),
      propertyId: 'x',
    );

    final per = (monthlyCents(sub) / 100).toStringAsFixed(2);
    return 'That is ${currencySymbol(_draft.currency)}$per a month.';
  }

  /* -------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.66,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
              children: [
                _serviceCard(c),
                const SizedBox(height: 14),
                _billingCard(c),
                const SizedBox(height: 14),
                _reminderCard(c),

                if (!_isNew) ...[
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: Icon(Icons.delete_outline, size: 18, color: c.ember),
                      label: Text(
                        'Delete this subscription',
                        style: TextStyle(fontFamily: fontBody, color: c.ember),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _footer(c),
        ],
      ),
    );
  }

  /* ------------------------------------------------------------ service */

  Widget _serviceCard(StashColors c) {
    /*
      The grid narrows as you type.

      Not a dropdown and not an autocomplete list: the whole point of a logo is
      that it is recognised faster than it is read, so the answer to "which
      one" is a picture rather than a row of text. Typing filters it, and
      typing something not on the list is itself a valid answer — the field
      keeps whatever was typed and the mark falls back to initials.
    */
    final matches = searchServices(_draft.name);

    return _Card(
      title: 'Service',
      children: [
        _Field(
          child: TextField(
            controller: _name,
            autofocus: _isNew,
            style: TextStyle(fontFamily: fontBody, fontSize: 17, color: c.text),
            cursorColor: c.gold,
            decoration: InputDecoration(
              hintText: 'Netflix, Spotify, the gym...',
              hintStyle: TextStyle(fontFamily: fontBody, fontSize: 17, color: c.muted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (v) => setState(() {
              _draft.name = v;

              // Typing over a chosen service unpicks it. Otherwise a
              // subscription called "Netflix account" keeps Netflix's id, and
              // the id is what the rest of the app trusts.
              final picked = serviceFor(_draft.serviceId);
              if (picked != null && picked.name != v) _draft.serviceId = null;
            }),
          ),
        ),
        const SizedBox(height: 14),

        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Not one we know. That is fine — it saves under whatever you '
              'called it, with its initials for a mark.',
              style: TextStyle(fontFamily: fontBody, fontSize: 13, height: 1.45, color: c.muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              const gap = 8.0;
              // Five across, as the PWA has it. At four the tiles are large
              // enough to look like buttons rather than a palette; at six the
              // names wrap to three lines.
              final width = (box.maxWidth - gap * 4) / 5;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final service in matches)
                    SizedBox(
                      width: width,
                      child: _ServiceTile(
                        service: service,
                        on: _draft.serviceId == service.id,
                        onTap: () => _choose(service),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  /* ------------------------------------------------------------ billing */

  Widget _billingCard(StashColors c) {
    final monthly = _monthly;

    return _Card(
      title: 'Billing',
      children: [
        const _Label('How often'),
        _Seg<Cadence>(
          value: _draft.cadence,
          options: const [
            (Cadence.weekly, 'Weekly'),
            (Cadence.monthly, 'Monthly'),
            (Cadence.quarterly, 'Quarterly'),
            (Cadence.yearly, 'Yearly'),
          ],
          onPick: (v) => setState(() => _draft.cadence = v),
        ),
        const SizedBox(height: 14),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /*
                    The one refusal this form makes.

                    A subscription is a cadence and one real renewal date, and
                    every other date in the app derives from that one — the next
                    renewal, the calendar, the six-month chart, the reminder.
                    Without it the row appears in a list sorted by when things
                    renew while having no answer to that question.
                  */
                  const _Label('Next renewal'),
                  _DateBox(
                    value: _draft.anchorDate,
                    onTap: () => _pickDate(anchor: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Amount'),
                  _MoneyBox(
                    initial: _draft.amountText,
                    currency: _draft.currency,
                    onChanged: (v) => setState(() => _draft.amountText = v),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (monthly != null) ...[
          const SizedBox(height: 8),
          Text(
            monthly,
            style: TextStyle(fontFamily: fontBody, fontSize: 12.5, color: c.gold),
          ),
        ],

        const SizedBox(height: 14),
        const _Label('Started'),
        _DateBox(
          value: _draft.startedDate ?? '',
          onTap: () => _pickDate(anchor: false),
        ),

        const SizedBox(height: 16),
        Container(height: 1, color: c.line),
        const SizedBox(height: 14),

        /*
          Splitting. The amount above stays what YOU pay either way — every
          total in the app is built from it, and a number that sometimes means
          the whole bill and sometimes half of it makes the monthly figure
          meaningless. These two only record the arrangement, which is what the
          subtitle says out loud rather than leaving somebody to guess.
        */
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Split with someone',
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Records who the money goes to, not what it costs',
                    style: TextStyle(fontFamily: fontBody, fontSize: 12.5, color: c.muted),
                  ),
                ],
              ),
            ),
            // The theme's own switch, unstyled here. Settings has three of
            // these and a fourth that looked almost the same would be a fourth
            // thing to keep in step.
            Switch(
              value: _draft.shared,
              onChanged: (v) {
                // On and off both. A switch that only buzzes one way feels
                // broken in the direction it stays silent.
                feedback(v ? Cue.expand : Cue.collapse);
                setState(() => _draft.shared = v);
              },
            ),
          ],
        ),

        if (_draft.shared) ...[
          const SizedBox(height: 12),
          const _Label('Who it goes to'),
          _Box(
            initial: _draft.payTo,
            hint: 'Mum, my flatmate, the group',
            onChanged: (v) => _draft.payTo = v,
          ),
          const SizedBox(height: 12),
          const _Label('How they get it'),
          _Box(
            initial: _draft.payHow,
            hint: 'Standing order on the 1st',
            onChanged: (v) => _draft.payHow = v,
          ),
        ],
      ],
    );
  }

  /* ----------------------------------------------------------- reminder */

  Widget _reminderCard(StashColors c) {
    /*
      None is the default, and that is deliberate.

      A renewal is not an event most people need waking for: the money leaves
      whether they know or not, and nine monthly services would mean nine
      notifications a month for nothing. Choosing anything else is somebody
      saying that this one is different.
    */
    final days = _draft.remindDays ?? 0;

    return _Card(
      title: 'Reminder',
      children: [
        _Seg<int>(
          value: days,
          options: const [
            (0, 'None'),
            (1, '1 day'),
            (3, '3 days'),
            (7, '7 days'),
          ],
          onPick: (v) => setState(() => _draft.remindDays = v == 0 ? null : v),
        ),
        const SizedBox(height: 12),
        Text(
          switch (days) {
            0 => 'No reminder. You can turn one on later.',
            1 => 'A notification the day before it renews.',
            int d => 'A notification $d days before it renews.',
          },
          style: TextStyle(fontFamily: fontBody, fontSize: 13, height: 1.45, color: c.muted),
        ),
        const SizedBox(height: 14),

        const _Label('Notes'),
        _Box(
          initial: _draft.notes,
          hint: 'Optional',
          lines: 4,
          onChanged: (v) => _draft.notes = v,
        ),
      ],
    );
  }

  /* ------------------------------------------------------------- footer */

  Widget _footer(StashColors c) {
    final problem = _problem ?? whyNotSaveableSubscription(_draft);

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        14 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: c.slate900,
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (problem != null) ...[
            Text(
              problem,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: fontBody, fontSize: 13, color: c.muted),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: c.onGold,
                disabledBackgroundColor: c.gold,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
              ),
              child: Text(
                _isNew ? 'Save subscription' : 'Save changes',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: c.onGold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------- the pieces */

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.on, required this.onTap});

  final ServiceDef service;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Material(
      color: on ? c.washGold : c.slate800,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(color: on ? c.washGoldLine : c.hairline),
          ),
          child: Column(
            children: [
              ServiceMark(serviceId: service.id, name: service.name, size: 38),
              const SizedBox(height: 7),
              Text(
                service.name,
                textAlign: TextAlign.center,
                // Two lines, because "Nintendo Switch Online" is not going to
                // fit on one and truncating it to "Nintendo Sw..." loses the
                // half that says which subscription it is.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 10.5,
                  height: 1.25,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? c.gold : c.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.slate700,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: fontDisplay,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: c.text,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: fontBody,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: c.muted,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: c.slate800,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: c.hairline),
      ),
      child: child,
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.initial,
    required this.onChanged,
    this.hint,
    this.lines = 1,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return _Field(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: lines > 1 ? 10 : 2),
      child: TextFormField(
        initialValue: initial,
        maxLines: lines,
        style: TextStyle(fontFamily: fontBody, fontSize: 15, color: c.text),
        cursorColor: c.gold,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontFamily: fontBody, fontSize: 15, color: c.muted),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: lines > 1 ? 2 : 14),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// The amount, with the currency symbol inside the box rather than beside it.
class _MoneyBox extends StatelessWidget {
  const _MoneyBox({
    required this.initial,
    required this.currency,
    required this.onChanged,
  });

  final String initial;

  /// The currency itself, not just its symbol — the formatter needs it too.
  /// A box that shows £ and formats to two decimals because it was told "USD"
  /// is wrong in every zero-decimal currency there is.
  final String currency;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return _Field(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Text(
            currencySymbol(currency),
            style: TextStyle(fontFamily: fontBody, fontSize: 15, color: c.muted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              initialValue: initial,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontFamily: fontBody, fontSize: 15, color: c.text),
              cursorColor: c.gold,
              decoration: InputDecoration(
                hintText: '12.99',
                hintStyle: TextStyle(fontFamily: fontBody, fontSize: 15, color: c.muted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              // Formats as you type rather than on blur, for the same reason
              // the item's price does: correcting a field afterwards makes
              // people wonder whether they typed it wrong.
              inputFormatters: [
                TextInputFormatter.withFunction((old, now) {
                  final formatted = formatMoneyInput(now.text, currency);
                  return TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _Field(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? 'Pick one' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: value.isEmpty ? fontBody : fontMono,
                  fontSize: 14,
                  color: value.isEmpty ? c.muted : c.text,
                ),
              ),
            ),
            Icon(Icons.calendar_today_outlined, size: 17, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class _Seg<T> extends StatelessWidget {
  const _Seg({required this.value, required this.options, required this.onPick});

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.slate800,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: c.hairline),
      ),
      child: Row(
        children: [
          for (final (key, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  feedback(Cue.tap);
                  onPick(key);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                  decoration: BoxDecoration(
                    color: key == value ? c.slate600 : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 13,
                      fontWeight: key == value ? FontWeight.w700 : FontWeight.w500,
                      color: key == value ? c.text : c.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
