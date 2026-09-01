/// What the home screen is handed.
///
///   flutter test test/widget_payload_test.dart
///
/// The native half cannot be tested — Kotlin providers, RemoteViews and a
/// launcher that behaves differently on every phone. So everything that can be
/// decided in Dart is, and this is where those decisions are held: which
/// records qualify, in what order, how many, and what each line says.
///
/// The rule worth stating: a widget must never disagree with the app it came
/// from. Somebody looking at a home screen and then opening the app is checking
/// the same fact twice, and two answers is worse than one.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/timeline.dart';
import 'package:stash_it/logic/warranty.dart';
import 'package:stash_it/logic/widget_payload.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';

/// 1 March 2026, so every date below reads as a distance from one morning.
final today = DateTime(2026, 3, 1);

String iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Item item(String name, {required int coverEndsIn}) => Item(
      id: name,
      name: name,
      propertyId: 'home',
      purchaseDate: iso(today.subtract(const Duration(days: 30))),
      coverages: [
        Coverage(
          id: 'w',
          label: 'Warranty',
          unit: CoverageUnit.days,
          amount: 30 + coverEndsIn,
        ),
      ],
    );

Paper paper(String label, {required int expiresIn}) => Paper(
      id: label,
      propertyId: 'home',
      kind: PaperKind.passport,
      label: label,
      expiresOn: iso(today.add(Duration(days: expiresIn))),
      leadDays: 0,
    );

Subscription sub(String name, {required int renewsIn}) => Subscription(
      id: name,
      propertyId: 'home',
      name: name,
      cadence: Cadence.yearly,
      anchorDate: iso(today.add(Duration(days: renewsIn))),
      amountCents: 999,
      currency: 'GBP',
    );

void main() {
  setUp(() => setEndingSoonDays(defaultEndingSoonDays));
  tearDown(() => setEndingSoonDays(defaultEndingSoonDays));

  group('what it puts on the home screen', () {
    test('the soonest thing is first, whatever kind it is', () {
      /*
        The widget must not group by kind. Somebody glancing at a home screen
        wants what is nearest, and a list that showed three warranties before a
        passport expiring tomorrow would be sorted for the app's convenience
        rather than theirs.
      */
      final payload = buildWidgetPayload(
        items: [item('Kettle', coverEndsIn: 40)],
        papers: [paper('Passport', expiresIn: 2)],
        subscriptions: [sub('Netflix', renewsIn: 20)],
        now: today,
      );

      expect(payload.lines.first.title, 'Passport');
      expect(payload.lines.map((l) => l.title),
          containsAllInOrder(['Passport', 'Netflix', 'Kettle']));
    });

    test('it never hands over more than the largest widget can draw', () {
      final payload = buildWidgetPayload(
        items: [for (var i = 0; i < 20; i++) item('Thing $i', coverEndsIn: i + 1)],
        papers: const [],
        subscriptions: const [],
        now: today,
      );

      expect(payload.lines.length, widgetMaxLines);
    });

    test('a smaller widget is handed fewer, not the same and clipped', () {
      // Clipping happens in the launcher where nothing can see it, and a copy
      // out of the encrypted database should carry what is shown and no more.
      final payload = buildWidgetPayload(
        items: [for (var i = 0; i < 20; i++) item('Thing $i', coverEndsIn: i + 1)],
        papers: const [],
        subscriptions: const [],
        lines: 3,
        now: today,
      );

      expect(payload.lines.length, 3);
    });
  });

  group('the kinds a widget was asked for', () {
    test('an excluded kind does not appear', () {
      final payload = buildWidgetPayload(
        items: [item('Kettle', coverEndsIn: 5)],
        papers: [paper('Passport', expiresIn: 2)],
        subscriptions: [sub('Netflix', renewsIn: 3)],
        kinds: const WidgetKinds(papers: false, subscriptions: false),
        now: today,
      );

      expect(payload.lines.map((l) => l.title), ['Kettle']);
    });

    test('excluding everything leaves an empty list, not a crash', () {
      final payload = buildWidgetPayload(
        items: [item('Kettle', coverEndsIn: 5)],
        papers: const [],
        subscriptions: const [],
        kinds: const WidgetKinds(
            items: false, papers: false, subscriptions: false),
        now: today,
      );

      expect(payload.lines, isEmpty);
    });

    test('the ring ignores the kind filter', () {
      /*
        The list is a slice somebody chose; the ring is a picture of the whole
        collection. A ring that moved when you unticked "documents" would be
        answering a different question from the one on the dashboard.
      */
      final everything = buildWidgetPayload(
        items: [item('Kettle', coverEndsIn: 5)],
        papers: [paper('Passport', expiresIn: 400)],
        subscriptions: const [],
        now: today,
      );
      final justItems = buildWidgetPayload(
        items: [item('Kettle', coverEndsIn: 5)],
        papers: [paper('Passport', expiresIn: 400)],
        subscriptions: const [],
        kinds: const WidgetKinds(papers: false),
        now: today,
      );

      expect(justItems.inDate, everything.inDate);
      expect(justItems.needsAction, everything.needsAction);
      expect(justItems.percent, everything.percent);
    });
  });

  group('the line itself', () {
    test('it carries the countdown split the way the list splits it', () {
      final payload = buildWidgetPayload(
        items: const [],
        papers: [paper('Passport', expiresIn: 12)],
        subscriptions: const [],
        now: today,
      );

      final line = payload.lines.single;
      expect(line.value, '12');
      expect(line.unit, contains('day'));
    });

    test('the tone is a name, never a colour', () {
      // The palette lives in one place. A hex string here would be a second,
      // and the one that gets forgotten when the theme changes.
      final payload = buildWidgetPayload(
        items: const [],
        papers: [paper('Passport', expiresIn: 2)],
        subscriptions: const [],
        now: today,
      );

      expect(WidgetTone.values, contains(payload.lines.single.tone));
      expect(payload.lines.single.toJson()['tone'], isA<String>());
    });

    test('what is copied out is only what the widget shows', () {
      /*
        This is the privacy promise in test form. A widget needs a plaintext
        copy outside the encrypted database, so the payload must carry the face
        of the widget and nothing more — no price, no serial, no notes.
      */
      final json = buildWidgetPayload(
        items: [item('Kettle', coverEndsIn: 5)],
        papers: const [],
        subscriptions: const [],
        now: today,
      ).toJson();

      final keys = (json['lines'] as List)
          .cast<Map<String, Object?>>()
          .expand((line) => line.keys)
          .toSet();

      expect(keys, {'title', 'detail', 'value', 'unit', 'tone'});
    });
  });

  group('with nothing to show', () {
    test('an empty stash and an empty filter say different things', () {
      // One is fixed by adding something, the other by changing the widget's
      // own settings, and the wrong sentence sends somebody to the wrong place.
      expect(
        emptyWidgetLine(anythingStashed: false, kinds: const WidgetKinds()),
        'Nothing stashed yet',
      );
      expect(
        emptyWidgetLine(
          anythingStashed: true,
          kinds: const WidgetKinds(
              items: false, papers: false, subscriptions: false),
        ),
        'Nothing chosen to show',
      );
      expect(
        emptyWidgetLine(anythingStashed: true, kinds: const WidgetKinds()),
        'Nothing coming up',
      );
    });
  });

  group('the settings survive a round trip', () {
    test('through JSON, which is how the native side stores them', () {
      const kinds = WidgetKinds(items: true, papers: false, subscriptions: true);
      final back = WidgetKinds.fromJson(kinds.toJson());

      expect(back.items, isTrue);
      expect(back.papers, isFalse);
      expect(back.subscriptions, isTrue);
    });

    test('a payload written by an older version still reads', () {
      // Widget settings outlive upgrades — the widget stays on the home screen
      // — so a missing key has to mean "show it" rather than throwing.
      final back = WidgetKinds.fromJson(const {});
      expect(back.items && back.papers && back.subscriptions, isTrue);
    });
  });
}
