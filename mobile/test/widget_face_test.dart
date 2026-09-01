/// The face that gets photographed.
///
///   flutter test test/widget_face_test.dart
///
/// The launcher half cannot be tested and the PNG cannot be inspected here, so
/// what this pins is the thing that actually broke twice while it was being
/// written: the face is rendered OUTSIDE the app's widget tree, with no Theme,
/// no MediaQuery and no Directionality above it.
///
/// Every one of those is an inherited lookup that throws rather than returning
/// null, and the failure lands in a render call that swallows it — the widget
/// simply never appears on the home screen and nothing anywhere says why. So
/// the face is pumped here in the same bare conditions `widget_mirror.dart`
/// renders it in, and anything it reaches for that is not there fails loudly.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/widget_payload.dart';
import 'package:stash_it/ui/widget_face.dart';

/// The wrapping `_renderRing` uses, and nothing more. If a test here needs a
/// MaterialApp to pass, the real render will not have one.
Widget bare(Widget child) => MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

WidgetPayload payload({
  int inDate = 8,
  int needsAction = 2,
  int lapsed = 1,
  int percent = 73,
}) =>
    WidgetPayload(
      lines: const [],
      inDate: inDate,
      needsAction: needsAction,
      lapsed: lapsed,
      noDate: 0,
      percent: percent,
    );

void main() {
  group('the ring face draws with nothing above it', () {
    testWidgets('no Theme, no MaterialApp, no app', (tester) async {
      await tester.pumpWidget(bare(RingFace(payload: payload(), dark: true)));

      expect(tester.takeException(), isNull);
      expect(find.text('73'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
    });

    testWidgets('light as well as dark', (tester) async {
      // Both are rendered on every pass, so both have to survive the same
      // bare conditions. A palette that only works one way round would show up
      // as a widget that is blank in daylight.
      await tester.pumpWidget(bare(RingFace(payload: payload(), dark: false)));
      expect(tester.takeException(), isNull);
    });
  });

  group('the sizes it has to survive', () {
    testWidgets('100% does not overflow the ring', (tester) async {
      /*
        The case that broke the dashboard's ring: "100%" is fractionally wider
        than the circle it sits in, and a household with everything in date is
        not an edge case. FittedBox is what fixes it; this is what notices if
        somebody takes it out.
      */
      await tester.pumpWidget(
        bare(RingFace(payload: payload(percent: 100), dark: true)),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('an empty stash draws a ring rather than throwing', (tester) async {
      // Zero of everything means a total of zero, and the painter divides by
      // the total. It returns early instead; this says so out loud.
      await tester.pumpWidget(
        bare(RingFace(
          payload: payload(inDate: 0, needsAction: 0, lapsed: 0, percent: 0),
          dark: true,
        )),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('the whole card is on it', () {
    testWidgets('wordmark, dial and all four figures', (tester) async {
      /*
        The widget is meant to BE the dashboard's card, not a summary of it.
        Somebody who taps it arrives at a screen that looks like what they
        tapped, and a widget that showed three of the four counts would make
        the fourth look like something the app had just invented.
      */
      await tester.pumpWidget(
        bare(RingFace(
          payload: payload(inDate: 8, needsAction: 2, lapsed: 1, percent: 73),
          dark: true,
        )),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Stash'), findsOneWidget);

      for (final label in ['in date', 'action needed', 'lapsed', 'no date']) {
        expect(find.text(label), findsOneWidget, reason: 'missing "$label"');
      }
    });

    testWidgets('it draws without Scout rather than failing', (tester) async {
      // The mascot is decoded before the render and handed in. If that ever
      // fails — a renamed asset, a decode that throws — the widget should
      // still be a widget.
      await tester.pumpWidget(bare(RingFace(payload: payload(), dark: true)));
      expect(tester.takeException(), isNull);
    });
  });

  test('the face is wider than it is tall, because the card is', () {
    // Wordmark, dial, Scout beside it and four figures underneath does not fit
    // in a square, and the info XML claims four cells by three to match.
    expect(ringFaceSize.width, greaterThan(ringFaceSize.height));
  });
}
