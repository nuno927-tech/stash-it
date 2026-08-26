# The two faces

Bricolage Grotesque for display, Inter for body — the same pair the PWA loads
from Google Fonts, bundled here because this app has no network at all.

Two files are expected in this folder, and the build will fail without them:

    BricolageGrotesque.ttf
    Inter.ttf

## Getting them

Both are open licensed (SIL Open Font License 1.1), so they can be redistributed
inside an app.

1. Go to <https://fonts.google.com/specimen/Bricolage+Grotesque> and
   <https://fonts.google.com/specimen/Inter>
2. Use **Get font → Download all**, which gives a zip of each
3. From each zip take the **variable** file — the one in `static/` is a single
   weight and is not what this wants:
   - `BricolageGrotesque-VariableFont_opsz,wdth,wght.ttf`
   - `Inter-VariableFont_opsz,wght.ttf`
4. Rename them to `BricolageGrotesque.ttf` and `Inter.ttf` and drop them here

Then:

    flutter pub get
    flutter run

## Why one file per family

Both are **variable fonts**: one file carries every weight from thin to extra
bold as a continuous axis. `pubspec.yaml` lists the same file several times
under different `weight:` values, which is how Flutter is told that this file
can answer for all of them.

Without those declarations Flutter reads only the font's default instance, and
every `FontWeight.w200` in the app — the ring's percentage, the four counts, the
subscription figures — would render at regular weight. Which is the same
outcome as not bundling the font, arrived at more expensively.

## What it fixes

Until these files exist Flutter falls back to Roboto, silently. Roboto has no
200 weight either, so it snaps to the nearest it has — which is why the numbers
currently look heavier and squarer than the PWA's, and why the greeting under
the wordmark does not read as the lighter line it is meant to be.
