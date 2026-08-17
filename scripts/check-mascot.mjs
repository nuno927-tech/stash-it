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

import { existsSync, readdirSync, readFileSync } from 'node:fs';

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

/*
  Whether the set could actually be regenerated.

  The committed webp files are what the app ships, so a pose whose renders
  have gone missing keeps working indefinitely — right up until someone runs
  mascot.mjs, at which point it silently doesn't come back. That happened:
  `lounge` lost its pair during a tidy-up and nothing noticed, because nothing
  was looking at the source folder.

  Only checked when the folder is populated. It's gitignored, so on a fresh
  clone there are no renders at all and demanding them would fail for
  everyone. This is a check for the machine that holds the art.
*/
const ORIGINALS = 'design/mascot-originals';
const EXTS = ['png', 'jpg', 'jpeg'];

if (existsSync(ORIGINALS) && readdirSync(ORIGINALS).some((f) => /^scout-/i.test(f))) {
  // mascot.mjs may point a pose at a differently-named pair.
  const alias = Object.fromEntries(
    [...exports_.matchAll(/name:\s*'([a-z]+)',\s*from:\s*'([a-z]+)'/g)].map((m) => [m[1], m[2]]),
  );
  const pair = (pose) => {
    const src = alias[pose] ?? pose;
    return ['white', 'black'].every((bg) =>
      EXTS.some((e) => existsSync(`${ORIGINALS}/scout-${src}-${bg}.${e}`)),
    );
  };
  const orphans = declared.filter((p) => !pair(p));
  if (orphans.length === 0) {
    check('every pose can be re-exported from its renders', true, `${declared.length} pairs`);
  } else {
    /*
      A warning, not a failure. Nothing in the app is broken — the committed
      cut-out is right there and still correct — and no change to the code can
      fix it, because what's missing is a file on somebody's disk. A red suite
      that can't be turned green by working on the repo is a red suite people
      learn to ignore, which costs more than this is worth.
    */
    console.log(`WARN  no renders on this machine for: ${orphans.join(', ')}`);
    console.log('      The committed cut-outs still work. They just cannot be regenerated.');
  }
}

// The site's images are committed like the app's, so a pose the site draws
// without a file behind it is a broken image on the marketing page.
const site = readFileSync('site/index.html', 'utf8');
const drawn = new Set([...site.matchAll(/img\/(scout-[a-z]+\.webp)/g)].map((m) => m[1]));
for (const file of [...drawn].sort()) {
  check(`the site's ${file} exists`, existsSync(`${SITE}/${file}`));
}

console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
