"""Names declared inside a `try` and used in its `catch` or `finally`.

    python3 tool/check_finally_scope.py

── Why this is its own checker ──────────────────────────────────────────────
A variable declared inside `try { }` does not exist in the `finally { }` that
follows it. Dart says so plainly at compile time, so this is not a subtle bug —
it is a bug that costs a full Android build to find, and this repository has no
Dart analyzer available to it. Every proxy check here exists for that reason:
the bracket balancer, the required-argument check, the font weights.

The bracket balancer cannot see this one, because the brackets are perfectly
balanced. That is exactly why it is worth a few dozen lines.

The failure that prompted it: a scratch file holding a 185 MB restore was
declared beside the code that filled it and deleted in the `finally`, which is
the natural place to write it and does not compile.
"""

import re
import sys
from pathlib import Path

DECLARATION = re.compile(
    r"(?:^|[;{}\(]|\bawait\s|\breturn\s)\s*"
    r"(?:final|var|late\s+final|late)\s+"
    r"(?:[\w<>,\.\s\?\[\]]+?\s+)?"
    r"([a-z_$][\w$]*)\s*(?:=|;|\bin\b)",
    re.MULTILINE,
)

# `File? scratch;` and `String opening = '';` — a type, then a name.
TYPED = re.compile(
    r"(?:^|;|\{|\})\s*"
    r"([A-Z][\w<>,\.\?\[\]]*)\s+"
    r"([a-z_$][\w$]*)\s*(?:=[^=]|;)",
    re.MULTILINE,
)


def blank_out(source: str) -> str:
    """Comments and string bodies replaced with spaces, newlines kept.

    Everything here is matched with regexes, so prose in a doc comment that
    happens to read like a declaration would otherwise be a finding.
    """
    out = []
    i, n = 0, len(source)

    while i < n:
        two = source[i : i + 2]

        if two == "//":
            while i < n and source[i] != "\n":
                out.append(" ")
                i += 1
            continue

        if two == "/*":
            while i < n and source[i - 1 : i + 1] != "*/":
                out.append("\n" if source[i] == "\n" else " ")
                i += 1
            continue

        if source[i] in "'\"":
            quote = source[i]
            triple = source[i : i + 3] == quote * 3
            width = 3 if triple else 1
            out.append(" " * width)
            i += width

            while i < n:
                if source[i] == "\\":
                    out.append("  ")
                    i += 2
                    continue
                if triple and source[i : i + 3] == quote * 3:
                    out.append("   ")
                    i += 3
                    break
                if not triple and source[i] == quote:
                    out.append(" ")
                    i += 1
                    break
                out.append("\n" if source[i] == "\n" else " ")
                i += 1
            continue

        out.append(source[i])
        i += 1

    return "".join(out)


def matching(source: str, opened: int) -> int:
    """The index of the `}` closing the `{` at `opened`, or -1."""
    depth = 0

    for i in range(opened, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return i

    return -1


def declared_in(body: str) -> set:
    names = {m.group(1) for m in DECLARATION.finditer(body)}
    names |= {m.group(2) for m in TYPED.finditer(body)}

    return {n for n in names if n not in {"if", "for", "while", "return"}}


def handlers_after(source: str, at: int):
    """Every `catch`/`finally` block chained onto a try that ended at `at`."""
    blocks = []
    i = at + 1

    while i < len(source):
        rest = source[i:]
        step = re.match(r"\s*(?:on\s+[\w<>\.]+\s*)?(?:catch\s*\([^)]*\)\s*)?"
                        r"(?:finally\s*)?\{", rest)

        if not step or not re.match(r"\s*(on\s|catch\b|finally\b)", rest):
            break

        opened = i + step.end() - 1
        closed = matching(source, opened)
        if closed < 0:
            break

        blocks.append(source[opened : closed + 1])
        i = closed + 1

    return blocks


def check(path: Path) -> list:
    source = blank_out(path.read_text(encoding="utf-8"))
    found = []

    for hit in re.finditer(r"\btry\s*\{", source):
        opened = hit.end() - 1
        closed = matching(source, opened)
        if closed < 0:
            continue

        body = source[opened : closed + 1]
        names = declared_in(body)
        if not names:
            continue

        for block in handlers_after(source, closed):
            for name in sorted(names):
                if re.search(rf"\b{re.escape(name)}\b", block):
                    line = source.count("\n", 0, opened) + 1
                    found.append((path, line, name))

    return found


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    problems = []

    for path in sorted((root / "lib").rglob("*.dart")):
        problems.extend(check(path))

    for path, line, name in problems:
        print(f"{path.relative_to(root)}:{line}: "
              f"'{name}' is declared inside this try and used in its "
              f"catch or finally")

    print(f"  {'no' if not problems else len(problems)} "
          f"out-of-scope use{'' if len(problems) == 1 else 's'} "
          f"in a catch or finally")

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
