/**
 * Scout's roster, the files behind it, and the export list agree.
 *
 *   npm run test:mascot
 *
 * Three lists describe the same nine poses and live in three files:
 *
 *   src/components/Scout.tsx    the type, the imports, and SCOUT_POSES
 *   src/assets/mascot/*.webp    the cut-outs themselves
 *   scripts/mascot.mjs          what to re-export when a render changes
 *
 * Adding a pose means touching all three, and the ways of getting it wrong
 * fail at different times. A missing webp fails the build immediately, which
 * is fine. The other two don't fail at all: a pose left out of SCOUT_POSES
 * simply never appears in the gallery, and a pose left out of mascot.mjs keeps
 * working until someone regenerates the set months later and it silently
 * doesn't come back. Both are the kind of thing you notice a version too late.
 *
 * This is a text scan rather than an import, because Scout.tsx imports .webp
 * files and Node has no idea what to do with those.
 */

import { existsSync, readFileSync } from 'node:fs';

const SCOUT = 'src/components/Scout.tsx';
const EXPORTS = 'scripts/mascot.mjs';
const ASSETS = 'src/assets/mascot';
const SITE = 'site/img';

let failures = 0;

function check(label, ok, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const scout = readFileSync(SCOUT, 'utf8');
const exports_ = readFileSync(EXPORTS, 'utf8');

/** The union type is the definition of the cast; everything else follows it. */
const declared = [
  ...scout
    .slice(scout.indexOf('export type ScoutPose'), scout.indexOf('export type ScoutMotion'))
    .matchAll(/'([a-z]+)'/g),
].map((m) => m[1]);

/** The roster the easter-egg gallery reads. */
const roster = [...scout.matchAll(/\{\s*pose:\s*'([a-z]+)'/g)].map((m) => m[1]);

/**
 * Both export lists in mascot.mjs: the app's sizes and the site's. The end
 * marker is searched from the start of the block, not from the top of the
 * file — `mkdirSync` also appears in the import line, and slicing to that gave
 * an empty string and a cheerful pass.
 */
const listed = (from, to) => {
  const start = exports_.indexOf(from);
  const end = exports_.indexOf(to, start);
  return [...exports_.slice(start, end).matchAll(/name:\s*'([a-z]+)'/g)].map((m) => m[1]);
};

const app = listed('const APP', 'const WEB');
const web = listed('const WEB', 'mkdirSync(');

check('the cast is declared', declared.length >= 8, `${declared.length} poses`);

const missing = (list) => declared.filter((p) => !list.includes(p));

check('every pose is in the gallery roster', missing(roster).length === 0, missing(roster).join(', '));
check('the roster invents nothing', roster.every((p) => declared.includes(p)), roster.join(', '));
check('every pose imports a file', declared.every((p) => scout.includes(`scout-${p}.webp`)));

for (const pose of declared) {
  check(`${pose} has a cut-out`, existsSync(`${ASSETS}/scout-${pose}.webp`));
}

check('every pose is re-exported for the app', missing(app).length === 0, missing(app).join(', '));
check('and for the site', missing(web).length === 0, missing(web).join(', '));

// The site's images are committed like the app's, so a pose the site draws
// without a file behind it is a broken image on the marketing page.
const site = readFileSync('site/index.html', 'utf8');
const drawn = new Set([...site.matchAll(/img\/(scout-[a-z]+\.webp)/g)].map((m) => m[1]));
for (const file of [...drawn].sort()) {
  check(`the site's ${file} exists`, existsSync(`${SITE}/${file}`));
}

console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
