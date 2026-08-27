/// A row you can throw aside, with a tick when it is far enough.
///
/// ── The tick is the whole reason this is its own widget ───────────────────
/// A swipe has no edges. Nothing tells your thumb where the point of no return
/// is, so people either let go too early — nothing happens, and they assume the
/// gesture is not supported — or drag the row all the way off the screen to be
/// sure. **The haptic IS the threshold**, and it is the only way to feel one
/// without looking.
///
/// One buzz, latched, on the way past. Firing every frame beyond the line turns
/// a signal into a texture, and firing again on the way back would say "you have
/// crossed it" about crossing it in the safe direction.
///
/// ── And it still asks before anything goes ───────────────────────────────
/// The tick means "let go and I will ask", not "let go and it is gone". The
/// sheet behind `confirmDismiss` is what actually deletes.
library;

import 'package:flutter/material.dart';

import 'feedback.dart';
import 'theme.dart';

class SwipeToDelete extends StatefulWidget {
  const SwipeToDelete({
    required this.id,
    required this.name,
    required this.onDelete,
    required this.child,
    this.confirm,
    super.key,
  });

  /// Unique across the list. Prefixed by the caller, because an item and a
  /// document can share an id in different tables.
  final String id;

  final String name;
  final VoidCallback onDelete;

  /// Asked once the row is released past the threshold. Returning false puts
  /// the row back rather than deleting it.
  final Future<bool> Function()? confirm;

  final Widget child;

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete> {
  bool _ticked = false;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Dismissible(
      key: ValueKey('swipe-${widget.id}'),

      // One direction only. A row that can be thrown either way is a row that
      // gets thrown while somebody is scrolling back up the list.
      direction: DismissDirection.endToStart,

      onUpdate: (details) {
        if (details.reached && !_ticked) {
          _ticked = true;
          // `delete` rather than `tap`: a double pulse you would feel with the
          // phone face-down, because what is on the other side of this line is
          // a record of something you own.
          feedback(Cue.delete);
        } else if (!details.reached && _ticked) {
          // Re-armed, silently. Dragging back is a change of mind and does not
          // need announcing.
          _ticked = false;
        }
      },

      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: c.washEmber,
        child: Icon(Icons.delete_outline, color: c.ember),
      ),

      confirmDismiss: widget.confirm == null ? null : (_) => widget.confirm!(),
      onDismissed: (_) => widget.onDelete(),
      child: widget.child,
    );
  }
}
