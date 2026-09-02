"""Reading Dart source without being fooled by its prose.

Every checker in this folder has the same first problem: this repository's
comments are long, deliberately, and they quote code. A checker that greps the
raw text finds `File` in a paragraph explaining why something is not a file,
and reports it.

So each of them blanks comments and string bodies first, keeping the newlines
so that reported line numbers still mean something. That belonged in one place
the second time it was written.
"""


def blank_out(source: str) -> str:
    """Comments and string bodies replaced with spaces, newlines kept."""
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
