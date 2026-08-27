/// The line at the top of the dashboard.
///
/// Translated from `src/lib/greeting.ts`.
///
/// Three windows, not four. "Good night" is a farewell in English, not a
/// greeting, and anything cleverer for the small hours ("Up late?") is a joke
/// that stops being funny the second time someone reads it — and they will read
/// it every day. Evening simply runs long.
///
/// Pure, and takes its clock as an argument, because the boundaries are the
/// only thing here worth being sure about.
library;

enum DayPart { morning, afternoon, evening }

/// 05:00–11:59 · 12:00–17:59 · 18:00–04:59
DayPart dayPart([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h >= 5 && h < 12) return DayPart.morning;
  if (h >= 12 && h < 18) return DayPart.afternoon;
  return DayPart.evening;
}

const Map<DayPart, String> _partWord = {
  DayPart.morning: 'morning',
  DayPart.afternoon: 'afternoon',
  DayPart.evening: 'evening',
};

String greeting(String? name, [DateTime? now]) {
  final hello = 'Good ${_partWord[dayPart(now)]}';
  final who = cleanName(name);
  return who.isEmpty ? hello : '$hello, $who';
}

final RegExp _whitespace = RegExp(r'\s+');

/// A name is a display string, not data anything depends on, so this only has
/// to stop it wrecking the layout: collapse whitespace, take the first word,
/// cap the length. Someone who types their full legal name gets called by their
/// first name, which is what the greeting wanted anyway.
///
/// Nothing is stripped beyond whitespace. Apostrophes, accents and non-Latin
/// scripts all survive — a name filter that "cleans" O'Brien or 未来 is not
/// tidying anything, it is getting someone's name wrong.
String cleanName(String? raw) {
  final trimmed = (raw ?? '').replaceAll(_whitespace, ' ').trim();
  if (trimmed.isEmpty) return '';

  final first = trimmed.split(' ').first;
  return first.length > 24 ? first.substring(0, 24) : first;
}

/// What the input field accepts. Longer than the display cap on purpose: the
/// field should not stop you typing a name it will later shorten for the
/// greeting.
const int maxNameLength = 32;
