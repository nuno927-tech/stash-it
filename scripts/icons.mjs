/**
 * The app icon: Scout, close up, holding a receipt.
 *
 *   node scripts/icons.mjs
 *
 * Cut from the same paired renders as everything else (see mascot.mjs for how
 * and why), then cropped tight. A full-body mascot at 48px on a home screen is
 * a grey smudge; the crop keeps the face and the receipt, because the receipt
 * is the only part that says what the app is for.
 *
 * White rather than transparent. An icon with an alpha channel is at the mercy
 * of whatever the launcher puts behind it, and this artwork is a soft grey
 * animal — on a dark wallpaper it disappears. A solid plate is also what makes
 * the maskable version possible at all.
 *
 * Two purposes, and they are not the same picture:
 *
 *   any       what most launchers draw, rounded by the OS. Full bleed.
 *   maskable  what Android may crop to a circle, a squircle or a teardrop.
 *             Only the middle 80% is guaranteed to survive, so this one is
 *             framed wider — the same view, pulled back far enough that the
 *             face and the receipt land inside that circle whatever shape the
 *             launcher chooses. Getting it wrong is how icons end up with
 *             their subject's ears sliced off.
 *
 * The maskable is *not* the tight crop shrunk into the middle of a plate. That
 * was the first attempt and it looked wrong for a reason worth remembering:
 * the crop runs through the tail, so inset artwork ends in a hard vertical
 * line of fur against white. Full bleed hides that seam at the canvas edge
 * where nobody reads it as an edge.
 */

import { execFileSync } from 'node:child_process';

const python = `
from PIL import Image
import numpy as np

SRC = 'design/mascot-originals/scout-receipt'
w = np.asarray(Image.open(f'{SRC}-white.png').convert('RGB'), float) / 255
b = np.asarray(Image.open(f'{SRC}-black.png').convert('RGB'), float) / 255

alpha = np.clip(1 - (w - b).mean(axis=2), 0, 1)
colour = np.clip(b / np.maximum(alpha, 1e-4)[..., None], 0, 1)
art = Image.fromarray(
    (np.concatenate([colour, alpha[..., None]], axis=2) * 255).round().astype('uint8'), 'RGBA'
)

# Chosen by eye against the 1024 render: head and ears complete, both paws and
# the printed face of the receipt inside the frame, the trailing end of the
# slip running off the bottom edge rather than being shrunk to fit.
TIGHT = (150, 55, 860, 765)
PLATE = (255, 255, 255)

# The same framing at 80% scale, so what survives a circular mask is roughly
# what TIGHT shows. 710 / 0.8 = 888, centred on TIGHT's centre and nudged down
# to stay on the canvas.
WIDE = (60, 0, 950, 890)

def render(box, size):
    plate = Image.new('RGB', (size, size), PLATE)
    piece = art.crop(box).resize((size, size), Image.LANCZOS)
    plate.paste(piece, (0, 0), piece)
    return plate

render(TIGHT, 192).save('public/icon-192.png', 'PNG', optimize=True)
render(TIGHT, 512).save('public/icon-512.png', 'PNG', optimize=True)
render(TIGHT, 180).save('public/apple-touch-icon.png', 'PNG', optimize=True)
render(WIDE, 512).save('public/icon-maskable-512.png', 'PNG', optimize=True)

print('icon-192, icon-512, icon-maskable-512, apple-touch-icon')
`;

console.log(execFileSync('python3', ['-c', python]).toString().trim());
