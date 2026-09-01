/// What the home screen shows, and the settings that shape it.
///
/// ── Why this is pure ──────────────────────────────────────────────────────
/// Everything past this file is native: Kotlin providers, RemoteViews, XML
/// size buckets, a launcher that behaves differently on every phone. None of
/// it can be unit tested and most of it cannot be debugged without a device.
///
/// So the decisions live here — which records qualify, in what order, how many
/// fit, what each line says — and the native half only draws what it is handed.
/// The part that can be wrong is the part with tests.
///
/// ── And it is deliberately a copy ─────────────────────────────────────────
/// A widget is drawn by the launcher, which cannot open an encrypted database
/// or ask the Keystore for anything. Whatever appears on the home screen has
/// been copied out into ordinary storage first. That is not an implementation
/// detail to be hidden — it is the trade the privacy policy now describes, and
/// the reason this file carries only what a widget actually displays. No
/// prices, no serials, no notes, no photographs: not because they would not
/// fit, but because copying them out would be giving away more than the screen
/// is asking for.
library;

import '../models/paper.dart';
import '../models/subscription.dart';
import '../models/types.dart';
import 'timeline.dart';

/// Which kinds a widget is showing. All three unless somebody says otherwise.
class WidgetKinds {
  const WidgetKinds({
    this.items = true,
    this.papers = true,
    this.subscriptions = true,
  });

  final bool items;
  final bool papers;
  final bool subscriptions;

  bool get none => !items && !papers && !subscriptions;

  bool accepts(TimelineKind kind) => switch (kind) {
        TimelineKind.item => items,
        TimelineKind.paper => papers,
        TimelineKind.subscription => subscriptions,
      };

  Map<String, Object?> toJson() => {
        'items': items,
        'papers': papers,
        'subscriptions': subscriptions,
      };

  static WidgetKinds fromJson(Map<String, Object?> json) => WidgetKinds(
        items: json['items'] as bool? ?? true,
        papers: json['papers'] as bool? ?? true,
        subscriptions: json['subscriptions'] as bool? ?? true,
      );
}

/// One line on the Coming up widget.
class WidgetLine {
  const WidgetLine({
    required this.title,
    required this.detail,
    required this.value,
    required this.unit,
    required this.tone,
    required this.kind,
  });

  final String title;

  /// The second line — what kind of thing it is, and whose.
  final String detail;

  /// The countdown, split the way the list rows split it: "27" and "days left".
  final String value;
  final String unit;

  /// Which of the four colours the native side should paint the number.
  final WidgetTone tone;

  /// Which kind of thing this is, so the launcher can drop it.
  ///
  /// The filtering happens THERE rather than here, and that is the whole reason
  /// this field exists. One payload is written for the whole phone, but each
  /// widget on the home screen has its own settings — somebody can have one
  /// showing everything and another showing only subscriptions. A payload
  /// filtered in Dart could only serve one of them.
  final TimelineKind kind;

  Map<String, Object?> toJson() => {
        'title': title,
        'detail': detail,
        'value': value,
        'unit': unit,
        'tone': tone.name,
        'kind': kind.name,
      };
}

/// The three states a countdown can be in, named for the native side.
///
/// Three and not four: the app's fourth state is "no term recorded", and an
/// item with nothing to count down never enters the timeline in the first
/// place. A value the payload cannot produce is a branch the Kotlin would have
/// to carry and never reach.
///
/// A colour sent as `#e8a33d` would be a second place the palette lives, and
/// the first to be forgotten when the theme changes. The name travels; the
/// launcher's own resources decide what it looks like.
enum WidgetTone { fine, soon, late_ }

/// Everything the three widgets need, in one object.
///
/// One payload rather than three, because they are all derived from the same
/// read and writing them separately is how two widgets on one home screen end
/// up disagreeing about the same afternoon.
class WidgetPayload {
  const WidgetPayload({
    required this.lines,
    required this.inDate,
    required this.needsAction,
    required this.lapsed,
    required this.noDate,
    required this.percent,
  });

  final List<WidgetLine> lines;

  /// The ring's four figures, and the number in the middle.
  final int inDate;
  final int needsAction;
  final int lapsed;
  final int noDate;
  final int percent;

  /// What the small widget says in one number.
  int get needsAMinute => needsAction + lapsed;

  Map<String, Object?> toJson() => {
        'lines': [for (final line in lines) line.toJson()],
        'inDate': inDate,
        'needsAction': needsAction,
        'lapsed': lapsed,
        'noDate': noDate,
        'percent': percent,
      };
}

/// The most lines any widget can show, at its largest.
///
/// Six is what a four-by-four holds at a readable size. Rendering more and
/// letting the launcher clip would mean the seventh line existing only as a
/// sliver, which reads as a rendering fault rather than as a list continuing.
const int widgetMaxLines = 6;

/// Builds what the widgets show.
///
/// Takes the records rather than a repository, for the same reason everything
/// else in `logic/` does: a test can hand it four items and a date.
WidgetPayload buildWidgetPayload({
  required List<Item> items,
  required List<Paper> papers,
  required List<Subscription> subscriptions,
  WidgetKinds kinds = const WidgetKinds(),
  int lines = widgetMaxLines,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();

  /*
    The same timeline the dashboard's Coming up list is built from, filtered to
    the kinds this widget was asked for. Deriving it again with its own rules
    would give a home screen that disagrees with the app it came from — the
    exact complaint the dashboard figures earned when they counted one thing
    and opened another.
  */
  final line = buildTimeline(items, subscriptions, papers, at)
      .where((entry) => kinds.accepts(entry.kind))
      .take(lines.clamp(0, widgetMaxLines))
      .map(_lineOf)
      .toList();

  // The ring counts what can run out — warranties and documents — and takes no
  // notice of the kind filter, because it is a picture of the whole collection
  // rather than of a slice. See `datedTally`.
  final tally = datedTally(items, papers, at);

  return WidgetPayload(
    lines: line,
    inDate: tally.inDate,
    needsAction: tally.needsStarting,
    lapsed: tally.lapsed,
    noDate: tally.noDate,
    percent: tally.percent,
  );
}

/// The lines to hand the launcher, when the launcher does the filtering.
///
/// ── Why this is not just `buildWidgetPayload().lines` ──────────────────────
/// One payload is written for the whole phone, and each widget on the home
/// screen has its own settings. So the filtering happens over there, which
/// means what goes over has to be enough for ANY of those settings — not for
/// the one this app happens to think is current.
///
/// Six of the soonest overall is not enough. A household with six warranties
/// running out this month and a passport due in July would send six warranties;
/// a widget set to documents only would then show nothing, on a phone with a
/// passport expiring.
///
/// So this keeps up to [perKind] of EACH kind while walking the timeline in its
/// existing order. The result is still one correctly sorted run — filtering it
/// to any subset preserves that order and still yields up to [perKind] rows.
///
/// The cost is up to three times as many lines in the plaintext copy outside
/// the encrypted database. Eighteen titles and eighteen countdowns, which is
/// the same kind of thing already going over, not a new kind.
List<WidgetLine> widgetLinesForLauncher({
  required List<Item> items,
  required List<Paper> papers,
  required List<Subscription> subscriptions,
  int perKind = widgetMaxLines,
  DateTime? now,
}) {
  final taken = <TimelineKind, int>{};
  final lines = <WidgetLine>[];

  for (final entry in buildTimeline(
    items,
    subscriptions,
    papers,
    now ?? DateTime.now(),
  )) {
    final already = taken[entry.kind] ?? 0;
    if (already >= perKind) continue;

    taken[entry.kind] = already + 1;
    lines.add(_lineOf(entry));

    // Every kind is full; nothing further down the timeline can be wanted by
    // any combination of settings.
    if (taken.length == TimelineKind.values.length &&
        taken.values.every((count) => count >= perKind)) {
      break;
    }
  }

  return lines;
}

WidgetLine _lineOf(Entry entry) {
  final (value, unit) = whenPartsFor(entry);

  return WidgetLine(
    title: entry.title,
    detail: entry.detail,
    value: value,
    unit: unit ?? '',
    tone: switch (entry.urgency) {
      Urgency.overdue || Urgency.now => WidgetTone.late_,
      Urgency.soon => WidgetTone.soon,
      Urgency.later => WidgetTone.fine,
    },
  );
}

/// What a widget with nothing to show says.
///
/// An empty collection and a filter that excluded everything are different
/// sentences, because one is fixed by adding something and the other by
/// changing the widget's own settings — and a widget that says the wrong one
/// sends somebody looking in the wrong place.
String emptyWidgetLine({required bool anythingStashed, required WidgetKinds kinds}) {
  if (kinds.none) return 'Nothing chosen to show';
  if (!anythingStashed) return 'Nothing stashed yet';
  return 'Nothing coming up';
}
