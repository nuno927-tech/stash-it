/**
 * Cut the mascot renders out of their backgrounds.
 *
 *   node scripts/mascot.mjs
 *
 * Each pose was rendered twice, identically, once on white and once on black.
 * That pair is worth more than either image alone: it gives an exact alpha
 * channel for free, including the fur wisps and the contact shadow, which no
 * amount of keying a single image can recover.
 *
 * For a pixel composited over a background B:
 *
 *     C_white = C·α + (1 − α)          C_black = C·α
 *
 * Subtract and the subject cancels out entirely:
 *
 *     α = 1 − (C_white − C_black)      C = C_black / α
 *
 * C_black is the premultiplied colour, so the division is the only place this
 * can go wrong — at α ≈ 0 it's 0/0, and those pixels are invisible anyway.
 *
 * The shadow falls out correctly on its own: it's part of the background in
 * both renders, so it lands at a low alpha and becomes a soft contact shadow
 * rather than a grey puddle glued to the artwork. That was the actual bug in
 * the first icon set — a baked background that turned into a black square
 * behind the mascot on the launch screen.
 *
 * This is a build-time tool, run by hand when the renders change. The outputs
 * are committed; the originals are 40 MB and are not.
 */

import { execFileSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';

const FROM = 'design/mascot-originals';
const TO = 'src/assets/mascot';

/**
 * Longest edge in the exported file: twice the largest size each pose is
 * actually drawn at, and no more. Every one of these is inlined whole into the
 * single-file build and precached by the service worker, so an idle 200px of
 * resolution on a mascot shown at 48px is paid for on every install.
 */
const POSES = [
  { name: 'acorn', size: 400 }, // 200 on the empty dashboard
  { name: 'alert', size: 260 }, // 120 when a search finds nothing
  { name: 'receipt', size: 360 }, // 180 on the empty items list
  { name: 'report', size: 200 }, // 72 on the cover card
  { name: 'resting', size: 180 }, // 64 when there's nothing to do
  { name: 'settings', size: 160 }, // 48 in the settings header
  { name: 'waving', size: 320 }, // 150 on the welcome sheet
];

mkdirSync(TO, { recursive: true });

const python = `
import sys
from PIL import Image
import numpy as np

name, size, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
w = np.asarray(Image.open(f'${FROM}/scout-{name}-white.png').convert('RGB'), float) / 255
b = np.asarray(Image.open(f'${FROM}/scout-{name}-black.png').convert('RGB'), float) / 255

# One alpha for the pixel, not three. The channels agree to within a few
# thousandths on these renders; averaging removes the last of the noise.
alpha = np.clip(1 - (w - b).mean(axis=2), 0, 1)

# b is already premultiplied. Unpremultiply where there's anything to see.
safe = np.maximum(alpha, 1e-4)[..., None]
colour = np.clip(b / safe, 0, 1)

rgba = np.concatenate([colour, alpha[..., None]], axis=2)
img = Image.fromarray((rgba * 255).round().astype('uint8'), 'RGBA')

# Crop to what is actually drawn. A 1024 square that is four fifths empty
# makes every layout guess at where the mascot really sits.
box = Image.fromarray((alpha > 0.02).astype('uint8') * 255).getbbox()
img = img.crop(box)

img.thumbnail((size, size), Image.LANCZOS)
img.save(out, 'WEBP', quality=86, method=6)
print(f'{name:9s} {box[2]-box[0]}x{box[3]-box[1]} -> {img.width}x{img.height}')
`;

for (const { name, size } of POSES) {
  const out = `${TO}/scout-${name}.webp`;
  console.log(execFileSync('python3', ['-c', python, name, String(size), out]).toString().trim());
}

/**
 * The avatar is the head of the acorn pose, not a separate render. A 36px
 * circle of a full-body mascot is a grey smudge; cropping to the face is the
 * only way anything reads at that size.
 */
const avatar = `
from PIL import Image
import numpy as np
img = Image.open('${TO}/scout-acorn.webp')
a = np.asarray(img)[..., 3]
box = Image.fromarray((a > 8).astype('uint8') * 255).getbbox()
x0, y0, x1, y1 = box
w = x1 - x0
# The head occupies roughly the top 45% of the standing poses. Square, and
# centred on the face rather than on the bounding box.
side = int(w * 0.60)
cx = (x0 + x1) // 2
cy = y0 + int((y1 - y0) * 0.19)
img.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)).resize(
    (160, 160), Image.LANCZOS
).save('${TO}/scout-avatar.webp', 'WEBP', quality=90, method=6)
print('avatar    160x160')
`;
console.log(execFileSync('python3', ['-c', avatar]).toString().trim());

/**
 * The launch screen loads its image from /public directly — it paints before
 * any bundle exists, so it can't use an imported asset. It is also the very
 * first byte of the app, which makes its weight the one that matters most.
 *
 * So: flattened onto the cream, with no alpha channel. The splash is light in
 * both themes on purpose (the OS draws the same colour from the manifest and
 * the two have to match), so transparency there buys nothing and costs a third
 * of a megabyte. WebP because every browser that can run this app has
 * supported it for years.
 */
const splash = `
from PIL import Image
img = Image.open('${TO}/scout-acorn.webp').convert('RGBA')
img.thumbnail((400, 400), Image.LANCZOS)
flat = Image.new('RGB', img.size, (244, 242, 237))
flat.paste(img, (0, 0), img)
flat.save('public/splash-scout.webp', 'WEBP', quality=84, method=6)
print(f'splash    {flat.width}x{flat.height}')
`;
console.log(execFileSync('python3', ['-c', splash]).toString().trim());
