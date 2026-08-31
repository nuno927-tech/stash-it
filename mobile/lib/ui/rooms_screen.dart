/// The rooms, in the order you want them.
///
/// ── Why the order is worth a whole screen ─────────────────────────────────
/// Alphabetical is the wrong order for a house. Nobody thinks "attic, bathroom,
/// bedroom" — they think ground floor upward, or the rooms they actually use
/// first and the loft last. The order is a map of somebody's home, and it is
/// the only thing on this screen that cannot be derived.
///
/// ── Drag and drop, with the stock widget ──────────────────────────────────
/// `logic/reorder.dart` was ported in phase 1 and never called: it does the hit
/// testing for a hand-rolled drag, and it opens by describing a real off-by-one
/// where the row under your finger was always the row in your hand.
///
/// `ReorderableListView` does that arithmetic itself and does it right. So this
/// screen uses the stock widget and `reorder.dart` keeps waiting for the
/// grouped items list, which is the case it was actually written for — a list
/// with headers between the rows, where the stock widget cannot help.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../models/types.dart';
import 'confirm_delete.dart';
import 'feedback.dart';
import 'scout.dart';
import 'theme.dart';

Future<void> showRooms(BuildContext context, Repository repo) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate700,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => RoomsScreen(repo: repo),
  );
}

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({required this.repo, super.key});

  final Repository repo;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<Room>? _rooms;
  Map<String, int> _counts = const {};
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rooms = await widget.repo.rooms();
    final counts = await widget.repo.itemsPerRoom();
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _counts = counts;
    });
  }

  /*
    ── The list moves first, the database catches up ───────────────────────

    A drag that waited on a write before redrawing would snap back under your
    finger for the length of the transaction. So the local list is reordered
    immediately and `reorderRooms` is sent after — and it writes every position
    rather than the two that moved, so a failure halfway cannot leave two rooms
    claiming the same place.
  */
  Future<void> _move(int from, int to) async {
    final rooms = _rooms;
    if (rooms == null) return;

    // `ReorderableListView` reports the index the row would land at BEFORE the
    // held row is taken out, so anything moving down is one too far.
    final target = to > from ? to - 1 : to;
    if (target == from) return;

    feedback(Cue.tap);

    final next = [...rooms];
    next.insert(target, next.removeAt(from));
    setState(() => _rooms = next);

    await widget.repo.reorderRooms([for (final r in next) r.id]);
  }

  Future<void> _add() async {
    final name = await _askName(context, title: 'Add a room');
    if (name == null || name.isEmpty) return;

    feedback(Cue.save);
    await widget.repo.createRoom(name);
    await _load();
  }

  Future<void> _rename(Room room) async {
    final name = await _askName(context, title: 'Rename', initial: room.name);
    if (name == null || name.isEmpty || name == room.name) return;

    feedback(Cue.save);
    await widget.repo.renameRoom(room.id, name);
    await _load();
  }

  Future<void> _delete(Room room) async {
    final count = _counts[room.id] ?? 0;

    final sure = await confirmDelete(
      context,
      name: room.name,
      // No bin for a room. There is nothing in it to recover — the label is the
      // whole record — and promising a thirty-day window for something that can
      // be retyped in four seconds is a promise with no purpose.
      permanent: true,
    );
    if (!sure) return;

    final orphaned = await widget.repo.deleteRoom(room.id);
    await _load();

    if (!mounted) return;
    setState(() {
      _status = orphaned == 0
          ? '${room.name} is gone.'
          // Said plainly, because "delete the garage" sounds like it might take
          // the lawnmower with it. It does not, and somebody about to hesitate
          // over that deserves to know before they wonder.
          : '${room.name} is gone. $orphaned '
              '${orphaned == 1 ? 'item' : 'items'} kept everything except the room.';
    });
    if (count != orphaned) return;
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final rooms = _rooms;

    return FractionallySizedBox(
      heightFactor: 0.66,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rooms',
                          style: TextStyle(
                            fontFamily: fontDisplay,
                            fontWeight: FontWeight.w800,
                            fontSize: 26,
                            letterSpacing: -0.6,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hold and drag to put them in your own order.',
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 12,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Scout(
                    pose: ScoutPose.folder,
                    height: 82,
                    motion: [ScoutMotion.breathe],
                  ),
                ],
              ),
            ),

            if (_status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(
                  _status!,
                  style: TextStyle(fontFamily: fontBody, fontSize: 12.5, color: c.text),
                ),
              ),

            Expanded(
              child: rooms == null
                  ? const Center(child: CircularProgressIndicator())
                  : rooms.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No rooms yet.\n\n'
                              'They are a way to say where something lives — '
                              'useful once you own more than a shelf of things.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: fontBody,
                                fontSize: 13,
                                height: 1.5,
                                color: c.muted,
                              ),
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: rooms.length,
                          onReorder: _move,
                          // The whole row is the handle. A dedicated grip is one
                          // more thing to aim at on a list whose rows are two
                          // words long.
                          buildDefaultDragHandles: false,
                          itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
                            key: ValueKey(rooms[i].id),
                            index: i,
                            child: _Row(
                              room: rooms[i],
                              count: _counts[rooms[i].id] ?? 0,
                              onRename: () => _rename(rooms[i]),
                              onDelete: () => _delete(rooms[i]),
                            ),
                          ),
                        ),
            ),

            Container(height: 1, color: c.line),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  'Add a room',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: c.onGold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.onGold,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.room,
    required this.count,
    required this.onRename,
    required this.onDelete,
  });

  final Room room;
  final int count;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Material(
      color: c.slate700,
      child: InkWell(
        onTap: onRename,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              Icon(Icons.drag_indicator, size: 20, color: c.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // What is actually in it. The number is the only reason
                      // to hesitate before deleting one, so it belongs on the
                      // row rather than in the confirmation.
                      count == 0
                          ? 'Nothing in here'
                          : '$count ${count == 1 ? 'item' : 'items'}',
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 11.5,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 20, color: c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One field, in a dialog rather than a sheet.
///
/// A sheet would cover the list you are naming something in relation to, and a
/// room name is two words — the smallest question the app asks, and the only
/// one that does not need a screen.
Future<String?> _askName(
  BuildContext context, {
  required String title,
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final c = StashColors.of(context);

  final answer = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: c.slate700,
      title: Text(
        title,
        style: TextStyle(
          fontFamily: fontDisplay,
          fontWeight: FontWeight.w800,
          fontSize: 19,
          color: c.text,
        ),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) => Navigator.of(context).pop(v),
        style: TextStyle(fontFamily: fontBody, color: c.text),
        // Third example is a possessive on purpose — rooms are often "whose"
        // rather than "where", and the hint is the only place that gets said.
        // It used to be the developer's own name.
        decoration: const InputDecoration(hintText: 'Garage, loft, Sam\'s office'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  controller.dispose();
  return answer?.trim();
}
