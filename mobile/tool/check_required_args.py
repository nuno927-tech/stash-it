"""Every required named parameter, supplied at every construction site.

    python3 tool/check_required_args.py

The Dart compiler catches this. It is here because it catches it MINUTES
later, at the end of a build, and because the way it gets introduced is
specific and repeatable: a field is added to a class as `required`, and one of
the two or three places that build the class is missed.

Twice now that miss has been the same mechanical fault — a find-and-replace
written with the wrong indentation, which matches nothing, changes nothing,
and reports success. A search that finds nothing looks exactly like a search
that worked.

Only checks classes declared in the file being scanned, and only sites written
as `ClassName(` with named arguments. That is enough for the case it exists
for.
"""

import pathlib
import re
import sys

ROOTS = [pathlib.Path('lib'), pathlib.Path('test')]


def constructors(source: str) -> dict[str, set[str]]:
    """Class name to the set of names its constructor requires."""
    found: dict[str, set[str]] = {}

    for match in re.finditer(r'\bconst\s+(_?\w+)\(\{', source):
        name = match.group(1)
        body = source[match.end():]
        close = body.find('});')
        if close < 0:
            continue

        required = set(re.findall(r'required this\.(\w+)', body[:close]))
        if required:
            found[name] = required

    return found


def _call(source: str, opened: int) -> str:
    """The text between a `(` and its matching `)`.

    A fixed window was the first attempt and it reported a false positive
    immediately: `defaultPrefs` has three paragraphs of comment inside its
    argument list, so the last two arguments fell outside any window short
    enough to be useful. A checker that cries wolf is one nobody runs.
    """
    depth = 0
    for i in range(opened, len(source)):
        if source[i] in '([{':
            depth += 1
        elif source[i] in ')]}':
            depth -= 1
            if depth == 0:
                return source[opened + 1:i]

    return source[opened + 1:]


def main() -> int:
    problems: list[str] = []
    checked = 0

    for root in ROOTS:
        for path in sorted(root.rglob('*.dart')):
            if path.name.endswith('.g.dart'):
                continue

            source = path.read_text(encoding='utf-8')
            wanted = constructors(source)
            if not wanted:
                continue

            for name, required in wanted.items():
                for site in re.finditer(rf'(?<![\w.]){re.escape(name)}\(\s*\n',
                                        source):
                    chunk = _call(source, source.index('(', site.start()))
                    given = set(re.findall(r'^\s*(\w+):', chunk, re.M))

                    missing = required - given
                    if missing:
                        line = source[:site.start()].count('\n') + 1
                        problems.append(
                            f'{path}:{line} {name}( is missing '
                            f'{sorted(missing)}')
                    checked += 1

    print(f'  {checked} construction sites checked')

    if problems:
        print()
        for problem in problems:
            print(f'  {problem}')
        return 1

    print('  every required argument is supplied')
    return 0


if __name__ == '__main__':
    sys.exit(main())
