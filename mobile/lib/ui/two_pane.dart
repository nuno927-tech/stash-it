/// A list beside whatever is selected in it, for a tablet turned sideways.
///
/// ── What a wide screen is actually for ─────────────────────────────────────
/// A phone shows a list, and tapping a row covers the list with the record.
/// That is right on a phone: there is only room for one thing, so the app is
/// honest about it and shows one thing.
///
/// On a tablet in landscape the same design is a column of rows down the left
/// third of the screen with two thirds of nothing beside it, and then a sheet
/// that slides up over all of it. The information was already on screen; the
/// app just refused to use the space.
///
/// So: list on the left, selection on the right, and nothing covering anything.
///
/// ── Which is not a second version of the app ───────────────────────────────
/// The pane draws the same widget the sheet draws — see `pane:` on
/// `ItemView`, `SubView` and `PaperView`. Two versions of a record screen would
/// be two things to keep in step, and the tablet's would be the one nobody
/// noticed had gone wrong.
///
/// Only the frame differs, and this is the frame.
library;

import 'package:flutter/material.dart';

import 'layout.dart';
import 'theme.dart';

/// The frame. [list] on the left, [detail] on the right when there is one.
class TwoPane extends StatelessWidget {
  const TwoPane({
    required this.list,
    required this.detail,
    required this.emptyLine,
    super.key,
  });

  final Widget list;

  /// Null when nothing is selected, which is the state the screen opens in.
  final Widget? detail;

  /// What the right side says while nothing is selected. Written by the caller
  /// because "Pick something to see it" is a different sentence for a shelf of
  /// appliances than it is for a drawer of passports.
  final String emptyLine;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: listPaneWidth, child: list),

        // A hairline, not a gap. The two panes are one screen, and a gutter
        // wide enough to see reads as two windows side by side.
        Container(width: 1, color: c.line),

        Expanded(
          child: detail ??
              _Nothing(line: emptyLine, c: c),
        ),
      ],
    );
  }
}

/// The right pane before anything is chosen.
///
/// Deliberately quiet: it is not an empty state in the sense the Home tab means
/// — there is plenty here, none of it picked yet — so it says what to do in one
/// muted line and gets out of the way.
class _Nothing extends StatelessWidget {
  const _Nothing({required this.line, required this.c});

  final String line;
  final StashColors c;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            line,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 14,
              height: 1.5,
              color: c.muted,
            ),
          ),
        ),
      );
}
