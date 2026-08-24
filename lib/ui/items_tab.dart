/// Everything you own.
///
/// Ordered by what runs out first, with lifetime cover and undated records at
/// the bottom — the same order `coverageSchedule` uses inside a single item,
/// applied across the list.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/item_icon.dart';
import '../logic/search.dart';
import '../logic/timeline.dart';
import '../logic/warranty.dart';
import '../models/types.dart';
import 'parts.dart';

class ItemsTab extends StatefulWidget {
  const ItemsTab({required this.repo, super.key});

  final Repository repo;

  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<ItemsTab> {
  String _query = '';
  WarrantyState? _filter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Item>>(
      stream: widget.repo.watchActiveItems(),
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) return const Center(child: CircularProgressIndicator());

        var shown = all;

        if (_filter != null) {
          shown = shown.where((i) => warrantyState(i) == _filter).toList();
        }

        /*
          Search runs over the whole collection, not the filtered view, and it
          is the one place the app looks at everything at once — see
          logic/search.dart. Here it is items only; the merged search across
          documents and subscriptions belongs on a screen of its own.
        */
        if (_query.trim().isNotEmpty) {
          final hits = searchAll(_query, SearchInput(items: all));
          final ids = {
            for (final h in hits)
              if (h is ItemHit) h.item.id,
          };
          shown = shown.where((i) => ids.contains(i.id)).toList();
        }

        shown = [...shown]..sort(_soonestFirst);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _Chip(
                    label: 'All ${all.length}',
                    on: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final state in [
                    WarrantyState.endingSoon,
                    WarrantyState.covered,
                    WarrantyState.expired,
                    WarrantyState.unknown,
                  ])
                    _Chip(
                      label: switch (state) {
                        WarrantyState.endingSoon => 'Ending soon',
                        WarrantyState.covered => 'Covered',
                        WarrantyState.expired => 'Lapsed',
                        WarrantyState.unknown => 'No term',
                      },
                      on: _filter == state,
                      tone: toneOf(state, context),
                      onTap: () => setState(
                        () => _filter = _filter == state ? null : state,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Blank(
                      all.isEmpty
                          ? 'Nothing saved yet.'
                          : 'Nothing here matches that.',
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) => _ItemTile(item: shown[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Soonest to lapse first; nothing-to-count-down last.
///
/// An item with no term is not a failure and is not urgent either — it sits at
/// the bottom rather than being sorted as though its cover ended in 1970.
int _soonestFirst(Item a, Item b) {
  final ea = effectiveExpiry(a);
  final eb = effectiveExpiry(b);
  if (ea == null && eb == null) return a.name.compareTo(b.name);
  if (ea == null) return 1;
  if (eb == null) return -1;
  final byDate = ea.compareTo(eb);
  return byDate != 0 ? byDate : a.name.compareTo(b.name);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap, this.tone});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: on,
        onSelected: (_) => onTap(),
        avatar: tone == null
            ? null
            : CircleAvatar(backgroundColor: tone, radius: 6),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final state = warrantyState(item);
    final next = nextToLapse(item);
    final end = effectiveExpiry(item);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: toneOf(state, context).withValues(alpha: 0.2),
        child: Icon(_icon(item), size: 20, color: toneOf(state, context)),
      ),
      title: Text(item.name),
      subtitle: Text(_subtitle(item, state, end)),
      trailing: next?.daysLeft == null
          ? null
          : Text(
              '${next!.daysLeft} d',
              style: Theme.of(context).textTheme.labelMedium,
            ),
    );
  }

  String _subtitle(Item item, WarrantyState state, DateTime? end) {
    if (state == WarrantyState.unknown) return 'No warranty length recorded';
    if (end == null) return 'Covered for life';
    return switch (state) {
      WarrantyState.expired => 'Cover ended ${dayMonth(end)}',
      _ => 'Cover ends ${dayMonth(end)}',
    };
  }
}

/// The icon guesser, mapped onto Material's set.
///
/// A wrong icon is worse than a neutral one — it looks like the app has
/// misunderstood the thing — so anything the keyword table does not recognise
/// gets a plain box rather than a guess.
IconData _icon(Item item) {
  final key = iconKeyFor(IconSubject(
    name: item.name,
    brand: item.brand,
    model: item.model,
    notes: item.notes,
  ));

  return switch (key) {
    IconKey.fridge => Icons.kitchen,
    IconKey.dishwasher || IconKey.washer || IconKey.dryer => Icons.local_laundry_service,
    IconKey.oven || IconKey.microwave => Icons.microwave,
    IconKey.kettle || IconKey.coffee => Icons.coffee,
    IconKey.tv => Icons.tv,
    IconKey.laptop => Icons.laptop,
    IconKey.phone => Icons.smartphone,
    IconKey.speaker => Icons.speaker,
    IconKey.camera => Icons.photo_camera,
    IconKey.router => Icons.router,
    IconKey.console => Icons.videogame_asset,
    IconKey.printer => Icons.print,
    IconKey.saw || IconKey.drill || IconKey.hammer || IconKey.wrench => Icons.handyman,
    IconKey.mower || IconKey.grill => Icons.grass,
    IconKey.bike => Icons.pedal_bike,
    IconKey.car => Icons.directions_car,
    IconKey.sofa || IconKey.chair => Icons.chair,
    IconKey.bed => Icons.bed,
    IconKey.table => Icons.table_restaurant,
    IconKey.lamp => Icons.light,
    IconKey.boiler || IconKey.aircon => Icons.thermostat,
    IconKey.vacuum => Icons.cleaning_services,
    IconKey.watch => Icons.watch,
    IconKey.box => Icons.inventory_2_outlined,
  };
}
