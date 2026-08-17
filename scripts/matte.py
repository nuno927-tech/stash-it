"""
Cutting Scout out of his backgrounds, cleanly.

Each pose was rendered twice, identically, on white and on black. For a pixel
composited over a background B:

    C_white = C·α + (1 − α)        C_black = C·α

Subtract and the subject cancels out, leaving an exact alpha channel:

    α = 1 − (C_white − C_black)    C = C_black / α

That much is arithmetic. The rest of this file is the two things the arithmetic
faithfully preserves that we don't want.

1. THE GENERATOR'S WATERMARK. A four-pointed sparkle sits in the corner of
   every render at roughly 36% alpha. It is invisible against white — which is
   why it survived review — and becomes a floating sprite the moment the
   cut-out is placed on anything dark. It cannot be keyed out by colour because
   it has no colour of its own; it is a translucent overlay.

   Connectivity used to be enough: it doesn't touch the squirrel. Then came a
   pose standing on a reflective floor, where the reflection reaches across the
   gap at ten or fifteen percent alpha and hands the sparkle a bridge. Raising
   the threshold that decides "connected" severs it — and also severs whiskers,
   which are just as faint. Every pose changed; that route is closed.

   So it is knocked out by position instead, which is safe because it has one.
   Measured across all ten renders the stamp lands in exactly the same 24×24
   pixels, 48 in from the right edge and 48 up from the bottom, every time.
   That is the behaviour of a stamp, not of a subject.

2. THE GROUND SHADOW. Part of the background in both renders, so it lands at
   very low alpha and reads as a grey haze on a dark page rather than as a
   shadow. Also the reason every "crop to content" was a no-op: the haze and
   the sparkle stretched the bounding box to the full frame, so nothing was
   ever actually cropped and every export was mostly empty space.

Both go the same way: floor the alpha, then keep only what is connected to the
subject. Anything that needs a shadow can draw its own, which is what the app
already does.
"""

import os

import numpy as np
from PIL import Image

# Below this, alpha is haze rather than fur. Real edge wisps sit well above it;
# the ground shadow sits well below.
FLOOR = 0.10

# Connectivity is decided on a quarter-scale mask. At full size the flood fill
# is a thousand iterations of a million-pixel array for no extra accuracy —
# nothing we're removing is four pixels wide.
SCALE = 4

# The crop is decided at a threshold the subject actually meets, not at "any
# alpha at all". Some renders carry a wide, near-invisible ambient glow off to
# one side; it survives the floor at two or three percent, and because it is
# joined to the squirrel the connectivity pass keeps it. Cropping to it padded
# the alert pose with 167 empty pixels down its left edge — a third of the
# frame — so centring the box put the visible animal noticeably right of centre.
#
# Measured across all eight poses the bounding box is stable from 0.2 to 0.7 and
# only explodes below 0.1: these edges are a couple of pixels of antialiasing,
# not a long fur falloff. So 0.2 finds the true silhouette and the margin below
# gives those pixels back.
CROP_AT = 0.20
CROP_MARGIN = 3

# The watermark's box, as an inset from the bottom-right corner. The stamp
# occupies 48..72 px in from each edge in every render; the slack is added
# outward, toward the corner, and never inward. Two pixels the other way was
# enough to clip the top edge of the folder pose's paperwork, which sits
# closer to that corner than anything else Scout has ever held.
MARK_NEAR, MARK_FAR = 44, 72

# Nothing in that box has ever been more than about half opaque — the stamp
# reads 0.31 against nothing and 0.51 over a dark reflective floor. Fur and
# paper go to 1.0. If a future render puts part of the subject in the corner,
# this trips and the export stops, rather than quietly punching a 24px hole in
# whatever was standing there.
MARK_CEILING = 0.75


def alpha_and_colour(white_path: str, black_path: str):
    w = np.asarray(Image.open(white_path).convert('RGB'), float) / 255
    b = np.asarray(Image.open(black_path).convert('RGB'), float) / 255

    # One alpha per pixel, not three. The channels agree to within a few
    # thousandths on these renders; averaging removes the last of the noise.
    alpha = np.clip(1 - (w - b).mean(axis=2), 0, 1)

    # b is the premultiplied colour. Unpremultiply where there's anything to
    # see; at α ≈ 0 the division is meaningless and the pixel is invisible.
    colour = np.clip(b / np.maximum(alpha, 1e-4)[..., None], 0, 1)
    return alpha, colour


def drop_watermark(alpha: np.ndarray, name: str) -> np.ndarray:
    """Zero the generator's stamp, and refuse if the subject is standing on it."""
    h, w = alpha.shape
    ys = slice(h - MARK_FAR, h - MARK_NEAR)
    xs = slice(w - MARK_FAR, w - MARK_NEAR)

    peak = float(alpha[ys, xs].max())
    if peak > MARK_CEILING:
        raise ValueError(
            f'{name}: something {peak:.2f} opaque is in the watermark corner. '
            f'That box is assumed to hold nothing but the stamp — check the render '
            f'before letting this through.'
        )

    out = alpha.copy()
    out[ys, xs] = 0.0
    return out


def keep_subject(alpha: np.ndarray) -> np.ndarray:
    """Zero everything not connected to the largest blob in the frame."""
    solid = alpha > FLOOR

    h, w = solid.shape
    small = solid[: h // SCALE * SCALE, : w // SCALE * SCALE]
    small = small.reshape(h // SCALE, SCALE, w // SCALE, SCALE).any(axis=(1, 3))

    # Seed from the centre of mass rather than the geometric centre: some poses
    # are curled up in one half of the frame.
    ys, xs = np.nonzero(small)
    if len(ys) == 0:
        return alpha
    cy, cx = int(ys.mean()), int(xs.mean())

    seed = np.zeros_like(small)
    # A patch, not a point — the centroid of a curled pose can land in a gap.
    seed[max(0, cy - 6) : cy + 6, max(0, cx - 6) : cx + 6] = True
    seed &= small
    if not seed.any():
        seed[ys[len(ys) // 2], xs[len(xs) // 2]] = True

    # Grow the seed through the mask until it stops changing.
    keep = seed
    while True:
        grown = keep.copy()
        grown[1:, :] |= keep[:-1, :]
        grown[:-1, :] |= keep[1:, :]
        grown[:, 1:] |= keep[:, :-1]
        grown[:, :-1] |= keep[:, 1:]
        grown &= small
        if grown.sum() == keep.sum():
            break
        keep = grown

    full = np.repeat(np.repeat(keep, SCALE, axis=0), SCALE, axis=1)
    if full.shape != alpha.shape:
        padded = np.zeros_like(solid)
        padded[: full.shape[0], : full.shape[1]] = full
        full = padded

    # Two pixels of slack so the quarter-scale boundary doesn't shave fur that
    # the full-resolution alpha still has something to say about.
    for _ in range(2 * SCALE):
        grown = full.copy()
        grown[1:, :] |= full[:-1, :]
        grown[:-1, :] |= full[1:, :]
        grown[:, 1:] |= full[:, :-1]
        grown[:, :-1] |= full[:, 1:]
        full = grown

    out = np.where(full, alpha, 0.0)
    # Rescale what's left so the floor doesn't leave a visible step at the
    # edge: 0.10 becomes 0, 1.0 stays 1.
    return np.clip((out - FLOOR) / (1 - FLOOR), 0, 1)


def find_render(source_dir: str, name: str, background: str) -> str:
    """
    One render, whatever it was saved as.

    The pairs arrive as PNG or JPEG depending on where they were exported from,
    and JPEG turns out to be fine here: the compression noise it leaves in a
    flat backdrop peaks around 0.07 alpha, which is below FLOOR, so none of it
    survives to the cut-out. What would not be fine is a pair saved in two
    different formats, or one of them re-encoded after a crop — the subtraction
    assumes the two frames are the same picture.
    """
    for ext in ('png', 'jpg', 'jpeg'):
        path = f'{source_dir}/scout-{name}-{background}.{ext}'
        if os.path.exists(path):
            return path
    raise FileNotFoundError(
        f'No {background} render for "{name}" in {source_dir} — looked for .png, .jpg and .jpeg.'
    )


def cutout(name: str, source_dir: str) -> Image.Image:
    """A clean RGBA image of one pose, cropped to the subject."""
    white = find_render(source_dir, name, 'white')
    black = find_render(source_dir, name, 'black')
    if os.path.splitext(white)[1] != os.path.splitext(black)[1]:
        raise ValueError(
            f'{name}: the pair is {os.path.basename(white)} and {os.path.basename(black)}. '
            f'Two formats means two different encoders rounded the same pixels differently, '
            f'and the alpha is the difference between them.'
        )
    alpha, colour = alpha_and_colour(white, black)
    alpha = keep_subject(drop_watermark(alpha, name))

    rgba = np.concatenate([colour, alpha[..., None]], axis=2)
    img = Image.fromarray((rgba * 255).round().astype('uint8'), 'RGBA')

    box = Image.fromarray((alpha >= CROP_AT).astype('uint8') * 255).getbbox()
    if not box:
        return img

    x0, y0, x1, y1 = box
    m, (w, h) = CROP_MARGIN, img.size
    return img.crop((max(0, x0 - m), max(0, y0 - m), min(w, x1 + m), min(h, y1 + m)))
