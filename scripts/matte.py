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
   it has no colour of its own; it is a translucent overlay. It can be removed
   by connectivity: it doesn't touch the squirrel.

2. THE GROUND SHADOW. Part of the background in both renders, so it lands at
   very low alpha and reads as a grey haze on a dark page rather than as a
   shadow. Also the reason every "crop to content" was a no-op: the haze and
   the sparkle stretched the bounding box to the full frame, so nothing was
   ever actually cropped and every export was mostly empty space.

Both go the same way: floor the alpha, then keep only what is connected to the
subject. Anything that needs a shadow can draw its own, which is what the app
already does.
"""

import numpy as np
from PIL import Image

# Below this, alpha is haze rather than fur. Real edge wisps sit well above it;
# the ground shadow sits well below.
FLOOR = 0.10

# Connectivity is decided on a quarter-scale mask. At full size the flood fill
# is a thousand iterations of a million-pixel array for no extra accuracy —
# nothing we're removing is four pixels wide.
SCALE = 4


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


def cutout(name: str, source_dir: str) -> Image.Image:
    """A clean RGBA image of one pose, cropped to the subject."""
    alpha, colour = alpha_and_colour(
        f'{source_dir}/scout-{name}-white.png',
        f'{source_dir}/scout-{name}-black.png',
    )
    alpha = keep_subject(alpha)

    rgba = np.concatenate([colour, alpha[..., None]], axis=2)
    img = Image.fromarray((rgba * 255).round().astype('uint8'), 'RGBA')

    box = Image.fromarray((alpha > 0.02).astype('uint8') * 255).getbbox()
    return img.crop(box) if box else img
