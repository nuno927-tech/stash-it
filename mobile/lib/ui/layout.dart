/// How wide the screen is, and what that is allowed to change.
///
/// ── One question, asked in one place ───────────────────────────────────────
/// "Is this a tablet" is the sort of thing that gets answered slightly
/// differently in six files — 600 here, 640 there, `width` in one place and
/// `shortestSide` in another — and the result is a layout that switches at
/// three different moments as somebody rotates a device.
///
/// So it is asked here, and the numbers are named.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

/// The narrow edge of a tablet, in logical pixels.
///
/// 600 is Android's own line — `sw600dp` is what the platform calls a tablet
/// and what the Play Console sorts screenshots by — so a device this app calls
/// a tablet is the same device the store does.
///
/// The SHORTEST side, deliberately. A phone in landscape is 800 wide and is not
/// a tablet; a tablet in portrait is 600 wide and still is. Measuring the long
/// edge would make the answer change every time somebody turned the device
/// over, which is exactly what this must not do.
const double tabletShortestSide = 600;

/// Whether the app is running on a tablet-sized screen, in either orientation.
bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= tabletShortestSide;

/// Whether to draw the list and what is selected side by side.
///
/// A tablet AND landscape. Both halves matter:
///
///   A phone in landscape has the width for two columns and no height for
///   either — a list of eight rows beside a record with none of it visible is
///   worse than either alone.
///
///   A tablet in portrait is wide enough to split and should not be. Portrait
///   is a column, and a column of full-width rows is the right way to read a
///   list of things you are scanning rather than comparing.
///
/// So the split appears exactly where it helps: a tablet turned sideways, which
/// is how a tablet sits in a stand.
bool splitView(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.shortestSide >= tabletShortestSide && size.width > size.height;
}

/// The same question, without a `BuildContext`.
///
/// Needed once, by `PrefsController`, which sets the window's orientation
/// before there is a widget tree to ask. Reads the platform's own view rather
/// than a MediaQuery, which is the only thing available that early.
///
/// `views.first` is the app's window. On a phone or tablet there is exactly
/// one; the plural exists for desktop and for the foldable case where a second
/// display is attached, neither of which this app runs on.
bool get deviceIsTablet {
  final views = PlatformDispatcher.instance.views;
  if (views.isEmpty) return false;

  final view = views.first;
  if (view.devicePixelRatio <= 0) return false;

  return view.physicalSize.shortestSide / view.devicePixelRatio >=
      tabletShortestSide;
}

/// How wide the list pane is when the screen is split.
///
/// Fixed rather than a fraction: a list row is a name and a countdown, and it
/// needs about this much whatever the screen is. Giving it half of a large
/// tablet would set eight words in a column built for thirty, and the record
/// beside it — which has a photograph in it — is what deserves the extra.
const double listPaneWidth = 340;
