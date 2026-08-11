/**
 * Icon keyword matching.
 *
 *   npm run test:icon
 *
 * The rules that matter: the name beats the other fields, longer phrases beat
 * the words inside them, and a match must be on a word boundary — "wave" must
 * not select the microwave icon.
 */

import { iconKeyFor } from '@/lib/itemIcon';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

function expect(subject: Parameters<typeof iconKeyFor>[0], want: string) {
  const got = iconKeyFor(subject);
  const desc = subject.name ?? JSON.stringify(subject);
  check(`${desc} → ${want}`, got === want, got === want ? '' : `got ${got}`);
}

// Straight matches from the name.
expect({ name: 'Bosch Dishwasher' }, 'dishwasher');
expect({ name: 'LG Refrigerator' }, 'fridge');
expect({ name: 'Sony Bravia' }, 'tv');
expect({ name: 'DeWalt Table Saw' }, 'saw');
expect({ name: 'Dyson vacuum' }, 'vacuum');
expect({ name: 'Weber BBQ' }, 'grill');
expect({ name: 'MacBook Pro' }, 'laptop');
expect({ name: 'Nespresso machine' }, 'coffee');

// Longest phrase wins over the words inside it.
expect({ name: 'Washing machine' }, 'washer');
expect({ name: 'Bosch washer' }, 'washer');
expect({ name: 'Combination microwave' }, 'microwave');
expect({ name: 'Air conditioner' }, 'aircon');
expect({ name: 'Water heater' }, 'boiler');

// "table saw" must not become a table; "table" alone still should.
expect({ name: 'Table saw' }, 'saw');
expect({ name: 'Dining table' }, 'table');

// Word boundaries: no matching inside a longer word.
expect({ name: 'Wavelength meter' }, 'box');
expect({ name: 'Carpet cleaner' }, 'box');
expect({ name: 'Scartissue' }, 'box');

// Case and punctuation.
expect({ name: 'SAMSUNG TV' }, 'tv');
expect({ name: 'e-bike, blue' }, 'bike');

// Falls through name → other fields → category → generic.
expect({ name: 'SHXM4AY55N', notes: 'the dishwasher in the kitchen' }, 'dishwasher');
expect({ name: 'Unknown thing', category: 'vehicle' }, 'car');
expect({ name: 'Unknown thing', category: 'furniture' }, 'sofa');
expect({ name: 'Unknown thing' }, 'box');
expect({}, 'box');

// The name outranks the other fields even when both match.
expect({ name: 'Garden mower', notes: 'stored next to the fridge' }, 'mower');

console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
