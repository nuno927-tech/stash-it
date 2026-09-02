"""Names used without the import that supplies them.

    python3 tool/check_imports.py

── Why a checker this narrow is worth having ────────────────────────────────
There is no Dart analyzer available here, so the cost of a missing import is a
full Android build — Gradle, kernel snapshot, the lot — to be told a name is
undefined. That has now happened three times in one session, and each one was
a symbol the author assumed `package:flutter/material.dart` re-exported.

`PlatformDispatcher` is the one that keeps catching people out. It lives in
`dart:ui`, which material does NOT re-export, and it reads exactly like the
other bindings that are available without thinking about it.

── Deliberately a very short list ───────────────────────────────────────────
This is not an import resolver and must never grow into one. It carries only
symbols whose home is unambiguous and which are not re-exported by anything
this app imports — because a false positive here trains people to ignore the
output, and a checker nobody reads is worse than no checker.
"""

import re
import sys
from pathlib import Path

from dartsource import blank_out

# symbol -> (the import that supplies it, why it is easy to get wrong)
SUPPLIED_BY = {
    "PlatformDispatcher": ("dart:ui", "material does not re-export dart:ui"),
    "jsonEncode": ("dart:convert", None),
    "jsonDecode": ("dart:convert", None),
    "LineSplitter": ("dart:convert", None),
    "utf8": ("dart:convert", None),
    "Directory": ("dart:io", None),
    "RandomAccessFile": ("dart:io", None),
    "Random": ("dart:math", None),
}

# Searched in the RAW source, not the blanked one.
#
# This is the mistake this checker made on its own first run: `blank_out`
# erases string bodies, and the name of a library in an import IS a string
# body — so every import in the app looked absent and seventeen correct files
# were reported. Usage is read from the blanked text; imports are read from the
# text as written.
def imports(source: str, library: str) -> bool:
    return re.search(rf"""import\s+['"]{re.escape(library)}['"]""", source) is not None


def declares(source: str, symbol: str) -> bool:
    """The file defines it itself, so no import is needed."""
    return (
        re.search(rf"\b(?:class|enum|mixin|extension|typedef)\s+{symbol}\b", source)
        is not None
    )


def check(path: Path) -> list:
    raw = path.read_text(encoding="utf-8")
    source = blank_out(raw)
    found = []

    for symbol, (library, why) in SUPPLIED_BY.items():
        if imports(raw, library) or declares(source, symbol):
            continue

        # Not after a dot: `prefix.Random` is somebody else's Random.
        hit = re.search(rf"(?<![\w.$]){symbol}\b", source)
        if hit is None:
            continue

        line = source.count("\n", 0, hit.start()) + 1
        found.append((path, line, symbol, library, why))

    return found


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    problems = []

    for path in sorted((root / "lib").rglob("*.dart")):
        problems.extend(check(path))

    for path, line, symbol, library, why in problems:
        note = f" — {why}" if why else ""
        print(f"{path.relative_to(root)}:{line}: "
              f"'{symbol}' needs `import '{library}';'{note}")

    print(f"  {len(SUPPLIED_BY)} names checked, "
          f"{'all supplied' if not problems else f'{len(problems)} missing'}")

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
