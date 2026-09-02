"""Every weight the app asks for is a weight the app ships.

    python3 tool/check_font_weights.py

── Why this needs checking at all ──────────────────────────────────────────

Flutter does not complain about a `fontWeight` you have not shipped. It picks
the nearest declared weight and draws that, so asking for a weight nobody cut
is not an error, not a warning, and not visible in a diff — it is one word
somewhere rendering a little heavier than it was meant to.

That already happened once. `widget_face.dart` asked the display face for w300
while pubspec declared 200, 400, 600, 700 and 800, and the four figures under
the ring had been drawn at whichever of those the engine felt was closest for
as long as the widget had existed.

── And the other half of the same problem ──────────────────────────────────

The fonts are cut from variable sources into one static file per weight — see
the note in pubspec.yaml. That makes `fontWeight` mean what it says, and it
also means the set of weights is now a FIXED list that somebody has to
remember to extend. This is the reminder.

Two checks:

  1. Every (family, weight) pair used in lib/ is declared in pubspec.yaml.
  2. Every declared weight points at a file that exists.
"""

import pathlib
import re
import sys

LIB = pathlib.Path('lib')
PUBSPEC = pathlib.Path('pubspec.yaml')

# The Dart constants, and the pubspec families they name. `fontMono` is an
# alias for the body face — see theme.dart — so it counts as that family.
FAMILY_OF = {
    'fontDisplay': 'BricolageGrotesque',
    'fontBody': 'Inter',
    'fontMono': 'Inter',
}

# What Flutter uses when a style names a family and no weight.
DEFAULT_WEIGHT = 400


def declared():
    """{family: {weight: asset}} out of pubspec.yaml, and the assets named."""
    text = PUBSPEC.read_text(encoding='utf-8')

    out = {}
    family = None
    asset = None

    for line in text.splitlines():
        got = re.match(r'\s*- family:\s*(\S+)', line)
        if got:
            family = got.group(1)
            out.setdefault(family, {})
            continue

        got = re.match(r'\s*- asset:\s*(\S+)', line)
        if got:
            asset = got.group(1)
            continue

        got = re.match(r'\s*weight:\s*(\d+)', line)
        if got and family:
            out[family][int(got.group(1))] = asset

    return out


def used():
    """{(family, weight): [where]} for every TextStyle in lib/."""
    out = {}

    for path in sorted(LIB.rglob('*.dart')):
        source = path.read_text(encoding='utf-8')

        for opened in re.finditer(r'TextStyle\(', source):
            # Walk to the matching bracket rather than regexing the block: a
            # TextStyle holds other constructors, and a lazy match stops at the
            # first `)` inside one of them.
            depth = 1
            i = opened.end()
            while i < len(source) and depth > 0:
                if source[i] == '(':
                    depth += 1
                elif source[i] == ')':
                    depth -= 1
                i += 1

            block = source[opened.end():i]

            named = re.search(r'fontFamily:\s*(\w+)', block)
            if named is None or named.group(1) not in FAMILY_OF:
                continue

            weighed = re.search(r'fontWeight:\s*FontWeight\.w(\d+)', block)
            weight = int(weighed.group(1)) if weighed else DEFAULT_WEIGHT

            line = source[:opened.start()].count('\n') + 1
            key = (FAMILY_OF[named.group(1)], weight)
            out.setdefault(key, []).append(f'{path}:{line}')

    return out


def main():
    have = declared()
    want = used()

    problems = []

    for (family, weight), where in sorted(want.items()):
        if weight not in have.get(family, {}):
            problems.append(
                f'  {family} w{weight} is asked for and not shipped\n'
                f'    first at {where[0]}'
                + (f' (and {len(where) - 1} more)' if len(where) > 1 else '')
            )

    for family, weights in sorted(have.items()):
        for weight, asset in sorted(weights.items()):
            if not pathlib.Path(asset).exists():
                problems.append(f'  {family} w{weight}: {asset} is not there')

    for family, weights in sorted(have.items()):
        shipped = ', '.join(str(w) for w in sorted(weights))
        asked = sorted(w for (f, w) in want if f == family)
        print(f'  {family}: ships {shipped}; asked for '
              f'{", ".join(str(w) for w in asked) or "nothing"}')

    if problems:
        print('\n' + '\n'.join(problems))
        return 1

    print('  every weight asked for is a weight that ships')
    return 0


if __name__ == '__main__':
    sys.exit(main())
