/// Copying just enough out of the encrypted database for the home screen.
///
/// ── The unavoidable bargain ────────────────────────────────────────────────
/// A widget is drawn by the launcher, while the app is not running, with no
/// key to the database and no way to ask for one. So whatever a widget shows
/// has to exist a second time, in the clear, outside the encryption.
///
/// That is not a flaw in this file — it is what a widget IS — and the only
/// honest response is to keep the copy as small as the picture on the screen.
/// `buildWidgetPayload` decides what that is: a title, a countdown, a tone.
/// No prices, no serial numbers, no notes, no photographs. The privacy policy
/// says so out loud, including the part people do not expect: a notification
/// redacts itself on a locked phone and a widget cannot.
///
/// ── Two pictures, every time ───────────────────────────────────────────────
/// The ring is an arc with a thin number in it, and RemoteViews can draw
/// neither, so the app renders its own face into a PNG and the launcher shows
/// the picture. Both palettes are rendered on every pass rather than "the
/// current one", because the phone can be switched to dark mode while the app
/// is not running to notice — and a picture's colours are fixed the moment it
/// is drawn. Two files is cheaper than a light card on a dark home screen.
///
/// ── How fresh it is ────────────────────────────────────────────────────────
/// As fresh as the last time the app ran, and no fresher. That is a real
/// limitation and worth being plain about: the counts move at midnight, and
/// nothing wakes the app at midnight to redraw them.
///
/// So this runs at every moment the app can honestly claim to know something
/// new — on launch, on resume, and whenever the shell sees the data change —
/// which between them cover every case except a phone left untouched across a
/// midnight. Fixing that last one means opening an encrypted database from a
/// background alarm, which is a much larger thing than it sounds and is not
/// worth it for a number that is one tap from being right.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../db/repository.dart';
import '../logic/widget_payload.dart';
import '../ui/widget_face.dart';

/// The provider classes Android should be told to redraw.
///
/// Fully qualified, because `updateWidget` resolves a bare name against the
/// package it thinks is running and gets that wrong in a flavoured build.
const List<String> _providers = [
  'app.stashit.RingWidget',
  'app.stashit.ComingUpWidget',
];

/// Keys the Kotlin side reads. Changing one here changes nothing there, which
/// is exactly the sort of break that shows up as a blank widget and no error,
/// so they are named once and listed together.
const String ringDarkKey = 'ring_dark';
const String ringLightKey = 'ring_light';
const String ringWordsKey = 'ring_words';

/// Coming up travels as data rather than as a picture.
///
/// The ring is one fixed composition and scales; a list is not. Somebody who
/// drags this widget taller expects more rows, and more rows is exactly what a
/// picture cannot give them — it can only get bigger. So the lines cross as
/// JSON and the launcher lays them out itself, which is also what lets it
/// decide how many will fit.
const String comingUpKey = 'coming_up';

/// Rendered at 3x, so a picture drawn for a 2x2 cell is still sharp when
/// somebody stretches it across four. Cheap: it is one 480px square.
const double _pixelRatio = 3;

/// Redraws every home screen widget from the current contents of the database.
///
/// Never throws. A widget that fails to update is a stale picture on a home
/// screen; an exception here would be a crash in the app somebody is actually
/// using, which is much worse for the same cause.
Future<void> mirrorWidgets(Repository repo) async {
  try {
    final items = await repo.activeItems();
    final papers = await repo.activePapers();
    final subscriptions = await repo.activeSubscriptions();

    final payload = buildWidgetPayload(
      items: items,
      papers: papers,
      subscriptions: subscriptions,
    );

    /*
      More lines than any one widget shows, because each widget on the home
      screen has its own settings and the filtering happens over there. See
      `widgetLinesForLauncher`, which explains why six of the soonest overall
      would leave a documents-only widget blank on a phone with a passport
      expiring.
    */
    final lines = widgetLinesForLauncher(
      items: items,
      papers: papers,
      subscriptions: subscriptions,
    );

    await _renderRing(payload, await _scout());

    /*
      Said in words as well as drawn.

      A screen reader cannot read a PNG, and a ring that announces itself as
      "image" is a widget somebody blind has no reason to keep. The Kotlin side
      puts this on the ImageView's contentDescription.
    */
    await HomeWidget.saveWidgetData<String>(
      comingUpKey,
      jsonEncode({
        'lines': [for (final line in lines) line.toJson()],
        /*
          The empty sentence is written here rather than in Kotlin, because
          which emptiness this is depends on the database — nothing stashed at
          all reads differently from nothing coming up, and one of those is
          fixed by adding something while the other is not.
        */
        'empty': emptyWidgetLine(
          anythingStashed: payload.inDate +
                  payload.needsAction +
                  payload.lapsed +
                  payload.noDate >
              0,
          kinds: const WidgetKinds(),
        ),
      }),
    );

    await HomeWidget.saveWidgetData<String>(
      ringWordsKey,
      '${payload.percent} per cent still in date. '
      '${payload.inDate} in date, '
      '${payload.needsAction} needing action, '
      '${payload.lapsed} lapsed.',
    );

    for (final provider in _providers) {
      await HomeWidget.updateWidget(qualifiedAndroidName: provider);
    }
  } on MissingPluginException {
    // No launcher here — the desktop test runs, and iOS if it ever exists.
  } catch (_) {
    // Anything else: leave the last good picture where it is.
  }
}

/*
   ── Scout, decoded before anybody asks for him ───────────────────────────────

   `Image.asset` resolves asynchronously: it starts loading, the widget builds
   without it, and the mascot appears a frame later. On a screen that is
   invisible. Here it is fatal, because the render captures the FIRST frame —
   the one with a hole where he goes — and the result is a widget that looks
   finished and is missing its subject, with no error anywhere.

   So he is decoded to a `ui.Image` first and handed to the face already drawn.

   Cached for the life of the process because he never changes and decoding a
   300px WebP on every save is work for nothing. Held as the decoded image
   rather than the bytes: the bytes are the cheap part.
*/
ui.Image? _scoutImage;

Future<ui.Image?> _scout() async {
  if (_scoutImage != null) return _scoutImage;

  try {
    final data = await rootBundle.load(scoutWidgetAsset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      // Twice the height he is drawn at, so he is crisp at 3x without carrying
      // a 300px original into every render.
      targetHeight: 208,
    );
    final frame = await codec.getNextFrame();
    return _scoutImage = frame.image;
  } catch (_) {
    // A face without a mascot is a worse widget, not a broken one.
    return null;
  }
}

Future<void> _renderRing(WidgetPayload payload, ui.Image? scout) async {
  for (final (key, dark) in [(ringDarkKey, true), (ringLightKey, false)]) {
    await HomeWidget.renderFlutterWidget(
      /*
        Wrapped by hand, because this is rendered outside the app's widget
        tree: there is no MediaQuery above it and no Directionality, and a Row
        without a text direction is an assertion rather than a picture.

        `noScaling` is deliberate and is the one place the app overrides an
        accessibility setting. A widget cannot reflow — the launcher gives it a
        fixed cell and scales whatever arrives — so honouring a large font
        setting here would push the number out of the ring rather than make it
        easier to read. The app's own dashboard scales properly, and that is
        the screen with room to.
      */
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.noScaling),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RingFace(payload: payload, dark: dark, scout: scout),
        ),
      ),
      key: key,
      logicalSize: ringFaceSize,
      pixelRatio: _pixelRatio,
    );
  }
}
