/// Picks a monochrome icon for an item that has no photo.
///
/// Translated from `src/lib/itemIcon.ts`.
///
/// Matching runs over what the user actually typed — name first, then brand,
/// model and notes — because "Bosch SHXM4AY55N" tells you less than
/// "dishwasher" does. A generic box is the floor, and the floor is fine: a
/// wrong icon is worse than a neutral one, because a wrong icon looks like the
/// app has misunderstood the thing.
///
/// Word-boundary matching, longest keyword first: "washing machine" must beat
/// "machine", and "microwave" must not match inside "wave".
library;

enum IconKey {
  fridge,
  dishwasher,
  washer,
  dryer,
  oven,
  microwave,
  kettle,
  coffee,
  tv,
  laptop,
  phone,
  speaker,
  camera,
  router,
  console,
  printer,
  saw,
  drill,
  hammer,
  wrench,
  mower,
  grill,
  bike,
  car,
  sofa,
  bed,
  chair,
  table,
  lamp,
  boiler,
  aircon,
  vacuum,
  watch,
  box,
}

/// Order matters only within a key; across keys the longest matching phrase
/// wins, so this list is free to be roughly alphabetical rather than carefully
/// ordered.
const Map<IconKey, List<String>> keywords = {
  IconKey.fridge: [
    'fridge',
    'refrigerator',
    'freezer',
    'ice maker',
    'wine cooler',
    'chiller',
  ],
  IconKey.dishwasher: ['dishwasher', 'dish washer'],
  IconKey.washer: ['washing machine', 'washer', 'laundry machine'],
  IconKey.dryer: ['tumble dryer', 'dryer', 'drier'],
  IconKey.oven: [
    'oven',
    'stove',
    'range',
    'cooktop',
    'hob',
    'air fryer',
    'toaster',
  ],
  IconKey.microwave: ['microwave'],
  IconKey.kettle: ['kettle', 'blender', 'mixer', 'food processor'],
  IconKey.coffee: ['coffee', 'espresso', 'nespresso', 'barista'],
  IconKey.tv: [
    'tv',
    'television',
    'bravia',
    'oled',
    'qled',
    'projector',
    'monitor',
    'display',
  ],
  IconKey.laptop: [
    'laptop',
    'macbook',
    'notebook',
    'computer',
    'pc',
    'desktop',
    'chromebook',
  ],
  IconKey.phone: ['phone', 'iphone', 'pixel', 'galaxy', 'tablet', 'ipad'],
  IconKey.speaker: [
    'speaker',
    'soundbar',
    'sonos',
    'stereo',
    'headphone',
    'earbud',
    'amplifier',
  ],
  IconKey.camera: ['camera', 'gopro', 'dslr', 'lens', 'camcorder', 'doorbell'],
  IconKey.router: ['router', 'modem', 'wifi', 'mesh', 'access point', 'nas'],
  IconKey.console: ['playstation', 'xbox', 'nintendo', 'switch', 'console'],
  IconKey.printer: ['printer', 'scanner', 'plotter'],
  IconKey.saw: ['saw', 'table saw', 'chainsaw', 'mitre', 'miter', 'jigsaw'],
  IconKey.drill: ['drill', 'driver', 'impact wrench', 'rotary tool'],
  IconKey.hammer: ['hammer', 'nailer', 'nail gun', 'mallet'],
  IconKey.wrench: [
    'wrench',
    'spanner',
    'socket set',
    'tool kit',
    'toolkit',
    'tool set',
  ],
  IconKey.mower: [
    'mower',
    'lawn mower',
    'lawnmower',
    'strimmer',
    'trimmer',
    'hedge',
    'leaf blower',
  ],
  IconKey.grill: [
    'grill',
    'bbq',
    'barbecue',
    'barbeque',
    'smoker',
    'pizza oven',
  ],
  IconKey.bike: ['bike', 'bicycle', 'e-bike', 'ebike', 'scooter'],
  IconKey.car: [
    'car',
    'van',
    'truck',
    'suv',
    'motorcycle',
    'motorbike',
    'caravan',
    'trailer',
  ],
  IconKey.sofa: ['sofa', 'couch', 'settee', 'loveseat', 'armchair', 'recliner'],
  IconKey.bed: ['bed', 'mattress', 'bunk', 'headboard'],
  IconKey.chair: ['chair', 'stool', 'bench'],
  IconKey.table: [
    'table',
    'desk',
    'sideboard',
    'dresser',
    'wardrobe',
    'cabinet',
    'bookcase',
    'shelf',
  ],
  IconKey.lamp: ['lamp', 'light', 'chandelier', 'sconce', 'lantern'],
  IconKey.boiler: [
    'boiler',
    'furnace',
    'water heater',
    'radiator',
    'heat pump',
    'thermostat',
    'heater',
  ],
  IconKey.aircon: [
    'air conditioner',
    'air con',
    'aircon',
    'ac unit',
    'hvac',
    'fan',
    'dehumidifier',
    'purifier',
  ],
  IconKey.vacuum: [
    'vacuum',
    'hoover',
    'roomba',
    'steam cleaner',
    'pressure washer',
  ],
  IconKey.watch: ['watch', 'fitbit', 'garmin', 'smartwatch'],
  IconKey.box: [],
};

class _Entry {
  _Entry(this.key, this.pattern);
  final IconKey key;
  final RegExp pattern;
}

String _escapeRegex(String s) =>
    s.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]!}');

/// Longest first, so multi-word phrases beat the single words inside them.
///
/// Compiled once at load rather than per lookup: this runs for every row in a
/// list that has no photograph, which on a fresh install is all of them.
final List<_Entry> _index = () {
  final flat = <MapEntry<IconKey, String>>[];
  keywords.forEach((key, words) {
    for (final w in words) {
      flat.add(MapEntry(key, w));
    }
  });

  flat.sort((a, b) => b.value.length.compareTo(a.value.length));

  return [
    for (final e in flat)
      // `\b` misbehaves for phrases ending in a non-word character, so the
      // boundary is written out rather than trusted — "e-bike" is the case.
      _Entry(
        e.key,
        RegExp('(^|[^a-z0-9])${_escapeRegex(e.value)}(\$|[^a-z0-9])',
            caseSensitive: false),
      ),
  ];
}();

IconKey? _findIn(String text) {
  final haystack = text.toLowerCase();
  for (final entry in _index) {
    if (entry.pattern.hasMatch(haystack)) return entry.key;
  }
  return null;
}

class IconSubject {
  const IconSubject({this.name, this.brand, this.model, this.notes});
  final String? name;
  final String? brand;
  final String? model;
  final String? notes;
}

IconKey iconKeyFor(IconSubject item) {
  // Name carries the most intent, so it gets its own pass before the rest.
  final name = item.name;
  if (name != null && name.isNotEmpty) {
    final hit = _findIn(name);
    if (hit != null) return hit;
  }

  final rest = [item.brand, item.model, item.notes]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' ');
  if (rest.isNotEmpty) {
    final hit = _findIn(rest);
    if (hit != null) return hit;
  }

  return IconKey.box;
}
