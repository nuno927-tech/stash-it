# The two faces

Bricolage Grotesque for display, Inter for body — the same pair the PWA loads
from Google Fonts, bundled here because this app has no network at all.

Both are open licensed (SIL Open Font License 1.1), so they can be redistributed
inside an app. The files in this folder are committed, so a fresh clone builds
without downloading anything.

## Nine files, not two

    BricolageGrotesque-200.ttf   the ring's percentage
    BricolageGrotesque-300.ttf   the four figures under it
    BricolageGrotesque-700.ttf   a card heading
    BricolageGrotesque-800.ttf   the wordmark, and every screen title

    Inter-300.ttf  Inter-400.ttf  Inter-500.ttf  Inter-600.ttf  Inter-700.ttf

Each is a single static weight, cut from the upstream variable font.

## Why not the variable files

They were the variable files, and `pubspec.yaml` named each one several times
under different `weight:` values. The note that used to sit here said that was
"how Flutter is told that this file can answer for all of them". It is not.

`weight:` chooses BETWEEN assets. With one asset there is nothing to choose
between, so what renders is the file's own default instance — and Bricolage's
default is 800. Every `FontWeight.w200` in the app was drawing at extra bold.

The old note even described the symptom correctly, in the next paragraph: "the
numbers currently look heavier and squarer than the PWA's, and the greeting
under the wordmark does not read as the lighter line it is meant to be." It
blamed the fonts being absent. They were present, and it was this.

The alternative fix is `fontVariations: [FontVariation('wght', 200)]` on every
style in the app. Static instances put it in one place, and mean `fontWeight`
keeps meaning what it says in anything written later.

## Cutting them again

Only if the upstream fonts are updated, or a new weight is needed.

1. Download the **variable** file for each family from
   <https://fonts.google.com/specimen/Bricolage+Grotesque> and
   <https://fonts.google.com/specimen/Inter> — `Get font → Download all`, then
   take `*-VariableFont_*.ttf` rather than anything in `static/`.
2. Cut one file per weight, pinning every other axis to its own default so
   nothing but the weight changes:

```python
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

for weight in [200, 300, 700, 800]:
    font = TTFont('BricolageGrotesque-VariableFont_opsz,wdth,wght.ttf')
    axes = {a.axisTag: a.defaultValue for a in font['fvar'].axes}
    axes['wght'] = weight
    instancer.instantiateVariableFont(font, axes, inplace=True)
    font.save(f'BricolageGrotesque-{weight}.ttf')
```

3. Declare each in `pubspec.yaml`, and run `python3 tool/check_font_weights.py`
   — it fails if the app asks for a weight nobody cut. That check exists
   because Flutter does not: it snaps to the nearest declared weight and draws
   that, silently, which is how `w300` went unnoticed on the widget face.

## What it costs

About 750 KB more than the two variable files. Bricolage got smaller — four
instances weigh less than one variable original — and Inter got larger. Worth
it for type that is the weight it claims to be.
