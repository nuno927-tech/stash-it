/**
 * Export the mascot poses the app and the site actually use.
 *
 *   node scripts/mascot.mjs
 *
 * The matting itself — and the two things it has to clean up on the way, the
 * generator's watermark and the baked ground shadow — lives in matte.py.
 * This file is only the list of what to produce and how large.
 *
 * A build-time tool, run by hand when the renders change. The outputs are
 * committed; the originals are 40 MB and are not.
 */

import { execFileSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';

const FROM = 'design/mascot-originals';
const TO = 'src/assets/mascot';
const SITE = 'site/img';

/**
 * Longest edge, at twice the size each pose is actually drawn at and no more.
 * Every one of these is inlined whole into the single-file build and precached
 * by the service worker, so idle resolution on a 48px mascot is paid for on
 * every install.
 */
/*
 * `from` names the render pair on disk when it differs from the pose the app
 * knows. The bin pose was drawn as "pail" and the app calls it what the screen
 * calls it; renaming the source would only move the mismatch.
 */
const APP = [
  { name: 'acorn', size: 400 }, // 200 on the empty dashboard
  { name: 'alert', size: 300 }, // 130 beside what needs doing
  { name: 'bin', from: 'pail', size: 300 }, // 130 at the top of Recently deleted
  { name: 'clipboard', size: 200 }, // 64 on the item form's first section
  { name: 'folder', size: 260 }, // 92 after a save, 130 in the tour
  { name: 'receipt', size: 360 }, // 180 on the empty items list
  { name: 'report', size: 320 }, // 150 beside the ring
  { name: 'resting', size: 240 }, // 110 when there's nothing to do
  { name: 'settings', size: 240 }, // 110 on its own card
  { name: 'waving', size: 320 }, // 150 on the welcome sheet
  { name: 'lounge', size: 400 }, // 190 on the support card
];

/**
 * The site draws the same poses much larger. Separate exports rather than one
 * shared set: the app pays for its images on every install, the site pays only
 * when someone visits.
 */
const WEB = [
  { name: 'acorn', size: 660 },
  { name: 'waving', size: 560 },
  { name: 'alert', size: 520 },
  { name: 'bin', from: 'pail', size: 480 },
  { name: 'clipboard', size: 460 },
  { name: 'folder', size: 520 },
  { name: 'receipt', size: 460 },
  { name: 'settings', size: 460 },
  { name: 'resting', size: 460 },
  { name: 'report', size: 420 },
  { name: 'lounge', size: 560 },
];

mkdirSync(TO, { recursive: true });
mkdirSync(SITE, { recursive: true });

function run(python) {
  console.log(execFileSync('python3', ['-c', python]).toString().trim());
}

const job = (poses, dir, quality) => `
import sys
sys.path.insert(0, 'scripts')
from matte import cutout
from PIL import Image

for name, source, size in ${JSON.stringify(poses.map((p) => [p.name, p.from ?? p.name, p.size]))}:
    # A pose whose renders aren't on this machine is skipped, not fatal. The
    # originals are gitignored and get shuffled about; one missing pair should
    # not stop the other ten being re-exported, and the committed webp for it
    # is still there and still correct. \`npm run test:mascot\` reports the gap.
    try:
        img = cutout(source, '${FROM}')
    except FileNotFoundError:
        print(f'{name:9s} skipped — no source pair')
        continue
    before = img.size
    img.thumbnail((size, size), Image.LANCZOS)
    img.save(f'${dir}/scout-{name}.webp', 'WEBP', quality=${quality}, method=6)
    print(f'{name:9s} {before[0]}x{before[1]} -> {img.width}x{img.height}')
`;

run(job(APP, TO, 86));
run(job(WEB, SITE, 80));

/**
 * The launch screen loads its image from /public directly — it paints before
 * any bundle exists, so it can't use an imported asset. It's also the very
 * first byte of the app, which makes its weight the one that matters most.
 *
 * Flattened onto the cream, with no alpha. The splash is light in both themes
 * on purpose (the OS draws the same colour from the manifest and the two have
 * to match), so transparency there buys nothing and costs a third of a
 * megabyte. WebP because every browser that can run this app has supported it
 * for years.
 */
run(`
from PIL import Image
img = Image.open('${TO}/scout-acorn.webp').convert('RGBA')
img.thumbnail((400, 400), Image.LANCZOS)
flat = Image.new('RGB', img.size, (244, 242, 237))
flat.paste(img, (0, 0), img)
flat.save('public/splash-scout.webp', 'WEBP', quality=84, method=6)
print(f'splash    {flat.width}x{flat.height}')
`);
