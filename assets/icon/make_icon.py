from PIL import Image, ImageDraw
import math

S, SS = 1024, 4
W = S * SS

INK   = (18, 16, 14)
GOLD  = (242, 179, 61)
CREAM = (245, 240, 232)

def art(draw, cx, cy, scale, bg):
    """The ring and the box, drawn about a centre. bg is the knockout colour."""
    # ── The ring ──────────────────────────────────────────────────────────
    # Nearly closed, with a small gap at the bottom. A wide gap reads as an
    # arch; a closed circle reads as a full stop. 300 degrees reads as a gauge
    # part way round, which is what the dashboard ring actually is.
    r = W * 0.335 * scale
    width = int(W * 0.078 * scale)
    draw.arc([cx-r, cy-r, cx+r, cy+r], start=-241, end=61, fill=GOLD, width=width)

    # PIL draws an arc's stroke INWARD from the bounding box, so the centre
    # line of the stroke sits at r - width/2. Capping at r put the round ends
    # outside the arc and left a visible kink at each join.
    rc = r - width/2
    for angle in (-241, 61):
        a = math.radians(angle)
        ex, ey = cx + rc*math.cos(a), cy + rc*math.sin(a)
        draw.ellipse([ex-width/2, ey-width/2, ex+width/2, ey+width/2], fill=GOLD)

    # ── The box ───────────────────────────────────────────────────────────
    # Solid, not outlined. An outline at 48 pixels turns into a grey smudge;
    # a silhouette keeps its shape all the way down.
    bw, bh = W*0.345*scale, W*0.295*scale
    left, top = cx - bw/2, cy - bh/2
    rad = W*0.022*scale
    draw.rounded_rectangle([left, top, left+bw, top+bh], radius=rad, fill=CREAM)

    # The lid, knocked out rather than drawn — one line doing the work of a
    # second shape.
    band = bh*0.30
    draw.rectangle([left, top+band, left+bw, top+band+W*0.018*scale], fill=bg)

    # And the handle slot.
    sw, sh = bw*0.28, band*0.34
    draw.rounded_rectangle([cx-sw/2, top+band*0.5-sh/2, cx+sw/2, top+band*0.5+sh/2],
                           radius=sh/2, fill=bg)

def build(bg, scale, transparent=False):
    img = Image.new("RGBA", (W, W), (0,0,0,0) if transparent else bg)
    art(ImageDraw.Draw(img), W/2, W/2, scale, bg)
    return img.resize((S, S), Image.LANCZOS)

full = build(INK, 1.0)
full.save("/tmp/icon/icon.png")
full.resize((512,512), Image.LANCZOS).save("/tmp/icon/icon-512.png")

# Adaptive foreground: Android crops hard to a circle or squircle, so the
# artwork lives inside the middle two thirds and the rest is padding.
build(INK, 0.62, transparent=True).save("/tmp/icon/icon-foreground.png")
print("ok")
