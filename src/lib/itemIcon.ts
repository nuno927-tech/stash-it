/**
 * Picks a monochrome icon for an item that has no photo.
 *
 * Matching runs over what the user actually typed — name first, then brand,
 * model and notes — because "Bosch SHXM4AY55N" tells you less than
 * "dishwasher" does. A generic box is the floor.
 *
 * Word-boundary matching, longest keyword first: "washing machine" must beat
 * "machine", and "microwave" must not match inside "wave".
 */

export type IconKey =
  | 'fridge'
  | 'dishwasher'
  | 'washer'
  | 'dryer'
  | 'oven'
  | 'microwave'
  | 'kettle'
  | 'coffee'
  | 'tv'
  | 'laptop'
  | 'phone'
  | 'speaker'
  | 'camera'
  | 'router'
  | 'console'
  | 'printer'
  | 'saw'
  | 'drill'
  | 'hammer'
  | 'wrench'
  | 'mower'
  | 'grill'
  | 'bike'
  | 'car'
  | 'sofa'
  | 'bed'
  | 'chair'
  | 'table'
  | 'lamp'
  | 'boiler'
  | 'aircon'
  | 'vacuum'
  | 'watch'
  | 'box';

/**
 * Order matters only within a key; across keys the longest matching phrase
 * wins, so this list is free to be alphabetical-ish rather than carefully
 * ordered.
 */
const KEYWORDS: Record<IconKey, string[]> = {
  fridge: ['fridge', 'refrigerator', 'freezer', 'ice maker', 'wine cooler', 'chiller'],
  dishwasher: ['dishwasher', 'dish washer'],
  washer: ['washing machine', 'washer', 'laundry machine'],
  dryer: ['tumble dryer', 'dryer', 'drier'],
  oven: ['oven', 'stove', 'range', 'cooktop', 'hob', 'air fryer', 'toaster'],
  microwave: ['microwave'],
  kettle: ['kettle', 'blender', 'mixer', 'food processor'],
  coffee: ['coffee', 'espresso', 'nespresso', 'barista'],
  tv: ['tv', 'television', 'bravia', 'oled', 'qled', 'projector', 'monitor', 'display'],
  laptop: ['laptop', 'macbook', 'notebook', 'computer', 'pc', 'desktop', 'chromebook'],
  phone: ['phone', 'iphone', 'pixel', 'galaxy', 'tablet', 'ipad'],
  speaker: ['speaker', 'soundbar', 'sonos', 'stereo', 'headphone', 'earbud', 'amplifier'],
  camera: ['camera', 'gopro', 'dslr', 'lens', 'camcorder', 'doorbell'],
  router: ['router', 'modem', 'wifi', 'mesh', 'access point', 'nas'],
  console: ['playstation', 'xbox', 'nintendo', 'switch', 'console'],
  printer: ['printer', 'scanner', 'plotter'],
  saw: ['saw', 'table saw', 'chainsaw', 'mitre', 'miter', 'jigsaw'],
  drill: ['drill', 'driver', 'impact wrench', 'rotary tool'],
  hammer: ['hammer', 'nailer', 'nail gun', 'mallet'],
  wrench: ['wrench', 'spanner', 'socket set', 'tool kit', 'toolkit', 'tool set'],
  mower: ['mower', 'lawn mower', 'lawnmower', 'strimmer', 'trimmer', 'hedge', 'leaf blower'],
  grill: ['grill', 'bbq', 'barbecue', 'barbeque', 'smoker', 'pizza oven'],
  bike: ['bike', 'bicycle', 'e-bike', 'ebike', 'scooter'],
  car: ['car', 'van', 'truck', 'suv', 'motorcycle', 'motorbike', 'caravan', 'trailer'],
  sofa: ['sofa', 'couch', 'settee', 'loveseat', 'armchair', 'recliner'],
  bed: ['bed', 'mattress', 'bunk', 'headboard'],
  chair: ['chair', 'stool', 'bench'],
  table: ['table', 'desk', 'sideboard', 'dresser', 'wardrobe', 'cabinet', 'bookcase', 'shelf'],
  lamp: ['lamp', 'light', 'chandelier', 'sconce', 'lantern'],
  boiler: ['boiler', 'furnace', 'water heater', 'radiator', 'heat pump', 'thermostat', 'heater'],
  aircon: ['air conditioner', 'air con', 'aircon', 'ac unit', 'hvac', 'fan', 'dehumidifier', 'purifier'],
  vacuum: ['vacuum', 'hoover', 'roomba', 'steam cleaner', 'pressure washer'],
  watch: ['watch', 'fitbit', 'garmin', 'smartwatch'],
  box: [],
};

/** Longest first, so multi-word phrases beat the single words inside them. */
const INDEX: { key: IconKey; word: string; len: number }[] = Object.entries(KEYWORDS)
  .flatMap(([key, words]) => words.map((word) => ({ key: key as IconKey, word, len: word.length })))
  .sort((a, b) => b.len - a.len);

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function findIn(text: string): IconKey | null {
  const haystack = text.toLowerCase();
  for (const { key, word } of INDEX) {
    // \b doesn't behave for phrases ending in a non-word char, so bound manually.
    const re = new RegExp(`(^|[^a-z0-9])${escapeRegex(word)}($|[^a-z0-9])`, 'i');
    if (re.test(haystack)) return key;
  }
  return null;
}

export interface IconSubject {
  name?: string;
  brand?: string;
  model?: string;
  notes?: string;
}

export function iconKeyFor(item: IconSubject): IconKey {
  // Name carries the most intent, so it gets its own pass before the rest.
  const fromName = item.name ? findIn(item.name) : null;
  if (fromName) return fromName;

  const rest = [item.brand, item.model, item.notes].filter(Boolean).join(' ');
  const fromRest = rest ? findIn(rest) : null;
  if (fromRest) return fromRest;

  return 'box';
}
