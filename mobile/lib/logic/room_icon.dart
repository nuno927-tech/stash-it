/// Which glyph a room gets, worked out from its name.
///
/// Ported from `roomIconKey` in `src/components/RoomIcon.tsx`, keyword list
/// included, so a room called "The Shed" gets the same icon in both apps.
///
/// ── Matched, not stored ───────────────────────────────────────────────────
/// The obvious design is an `icon` column on the room and a picker beside the
/// name field. It was not built, for two reasons.
///
/// Rooms are invented by the person using the app. A stored icon means a fixed
/// list to choose from, and the list is wrong the moment somebody adds
/// "Nursery" or renames Garage to "The Shed" — either they get a wrong icon
/// they now have to go and fix, or they get a picker in the way of typing a
/// word. Matching on the name means the icon is right without anybody being
/// asked, and it follows a rename for free.
///
/// And it costs nothing to be wrong. An unrecognised room gets a house, which
/// is what a room is. Nothing depends on the answer.
///
/// ── Longest phrase wins ───────────────────────────────────────────────────
/// "Living Room" has to beat "Room", and "Powder Room" has to beat both. The
/// index is sorted by phrase length so the most specific match is tried first;
/// with the list in declaration order, every room ending in the word "room"
/// would collapse to the same generic glyph.
library;

enum RoomIconKey {
  kitchen,
  living,
  family,
  dining,
  bedroom,
  nursery,
  bathroom,
  laundry,
  garage,
  basement,
  attic,
  office,
  workshop,
  outdoor,
  storage,
  gym,
  pantry,
  hall,

  /// The fallback, and the reason this can never fail: a house.
  room,
}

const Map<RoomIconKey, List<String>> _keywords = {
  RoomIconKey.kitchen: ['kitchen', 'kitchenette', 'scullery'],
  RoomIconKey.living: [
    'living room', 'living', 'lounge', 'sitting room', 'front room',
    'parlour', 'parlor',
  ],
  RoomIconKey.family: [
    'family room', 'family', 'den', 'rec room', 'games room', 'playroom',
    'media room', 'tv room',
  ],
  RoomIconKey.dining: ['dining room', 'dining', 'breakfast room'],
  RoomIconKey.bedroom: [
    'bedroom', 'primary bedroom', 'master', 'guest room', 'bed room',
  ],
  RoomIconKey.nursery: ['nursery', 'baby', "kid's room", 'kids room'],
  RoomIconKey.bathroom: [
    'bathroom', 'bath', 'ensuite', 'en suite', 'shower room', 'washroom',
    'toilet', 'powder room', 'wc',
  ],
  RoomIconKey.laundry: ['laundry', 'utility', 'utility room', 'mud room', 'mudroom'],
  RoomIconKey.garage: ['garage', 'carport', 'car port'],
  RoomIconKey.basement: ['basement', 'cellar', 'crawl space'],
  RoomIconKey.attic: ['attic', 'loft', 'roof space'],
  RoomIconKey.office: ['office', 'study', 'library', 'workspace'],
  RoomIconKey.workshop: ['workshop', 'shed', 'shop', 'tool room'],
  RoomIconKey.outdoor: [
    'outdoor', 'garden', 'yard', 'patio', 'deck', 'porch', 'balcony',
    'terrace', 'greenhouse',
  ],
  RoomIconKey.storage: ['storage', 'closet', 'cupboard', 'wardrobe room', 'store room'],
  RoomIconKey.gym: ['gym', 'home gym', 'fitness'],
  RoomIconKey.pantry: ['pantry', 'larder'],
  RoomIconKey.hall: [
    'hall', 'hallway', 'entry', 'entryway', 'foyer', 'landing', 'stairs',
    'corridor',
  ],
  RoomIconKey.room: [],
};

/// Every phrase, longest first, each compiled once.
///
/// Built at first use rather than on every call: this runs per room header on
/// a list that rebuilds whenever an item changes, and there are about sixty
/// patterns.
final List<(RoomIconKey, RegExp)> _index = () {
  final all = <(RoomIconKey, String)>[
    for (final entry in _keywords.entries)
      for (final word in entry.value) (entry.key, word),
  ]..sort((a, b) => b.$2.length.compareTo(a.$2.length));

  return [
    for (final (key, word) in all)
      /*
        Whole words only.

        Without the boundaries, "bath" matches "Bathroom cupboard" — fine — but
        also "Sunbathing deck", and "den" matches "Garden". The guard is "not a
        letter or a digit" rather than `\b`, so "Kid's room" still matches
        across the apostrophe.
      */
      (key, RegExp('(^|[^a-z0-9])${RegExp.escape(word)}(\$|[^a-z0-9])',
          caseSensitive: false)),
  ];
}();

RoomIconKey roomIconKey(String name) {
  final text = name.toLowerCase().trim();

  for (final (key, pattern) in _index) {
    if (pattern.hasMatch(text)) return key;
  }

  return RoomIconKey.room;
}
