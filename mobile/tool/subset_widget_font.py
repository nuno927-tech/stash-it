"""Cut the widget's copy of Bricolage down to the seven letters it draws.

    python3 tool/subset_widget_font.py

Android resources cannot read Flutter's assets, so the font a widget uses has
to exist a second time under res/font/. The whole family is ~400 KB and the
widget sets exactly one string — "Stash it" — so the second copy is 400 KB to
draw seven distinct glyphs.

This writes that copy as a subset. Re-run it if the font is ever replaced; the
source of truth stays assets/fonts/BricolageGrotesque.ttf.

Variable axes are kept. Android picks the default instance from XML, but
dropping the axes would bake in whichever instance fontTools chose, and a font
that quietly changed weight is worse than one that is slightly larger.
"""

import pathlib
import subprocess
import sys

SOURCE = pathlib.Path('assets/fonts/BricolageGrotesque.ttf')
TARGET = pathlib.Path('android/app/src/main/res/font/bricolage_grotesque.ttf')

# Everything the widget wordmark can draw, and nothing else.
TEXT = 'Stash it'


def main() -> int:
    if not SOURCE.exists():
        print(f'  {SOURCE} is missing')
        return 1

    before = SOURCE.stat().st_size

    subprocess.run(
        [
            sys.executable, '-m', 'fontTools.subset', str(SOURCE),
            f'--text={TEXT}',
            f'--output-file={TARGET}',
            '--layout-features=*',
            '--name-IDs=*',
            '--notdef-outline',
        ],
        check=True,
    )

    after = TARGET.stat().st_size
    print(f'  {SOURCE.name}  {before / 1024:.0f} KB')
    print(f'  {TARGET.name}  {after / 1024:.0f} KB   '
          f'({100 - after * 100 // before}% smaller, for "{TEXT}")')
    return 0


if __name__ == '__main__':
    sys.exit(main())
