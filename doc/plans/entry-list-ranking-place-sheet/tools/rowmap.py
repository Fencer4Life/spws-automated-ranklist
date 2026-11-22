"""Row-by-row map of a before/after pair where a block was inserted.

usage: python rowmap.py <before.png> <after.png> <inserted-at-row> <shift>

Every before row above <inserted-at-row> must equal the after row at the same
y; every before row from there on must equal the after row at y + <shift>.
Prints the before rows that break the rule, as ranges, with the x-extent of
their differing pixels, so a difference is located rather than assumed.
"""

import sys

from PIL import Image


def main() -> None:
    before = Image.open(sys.argv[1]).convert("RGBA")
    after = Image.open(sys.argv[2]).convert("RGBA")
    at, shift = int(sys.argv[3]), int(sys.argv[4])
    w = before.width
    assert after.width == w, "widths differ"
    bp, ap = before.load(), after.load()
    assert bp is not None and ap is not None
    bad: list[tuple[int, int, int]] = []
    for y in range(before.height):
        ay = y if y < at else y + shift
        if ay >= after.height:
            bad.append((y, -1, -1))
            continue
        xs = [x for x in range(w) if bp[x, y] != ap[x, ay]]
        if xs:
            bad.append((y, min(xs), max(xs)))
    ranges: list[list[int]] = []
    for y, x0, x1 in bad:
        if ranges and ranges[-1][1] == y - 1:
            ranges[-1][1] = y
            ranges[-1][2] = min(ranges[-1][2], x0)
            ranges[-1][3] = max(ranges[-1][3], x1)
        else:
            ranges.append([y, y, x0, x1])
    print(f"{len(bad)} of {before.height} before rows break the rule")
    for y0, y1, x0, x1 in ranges:
        print(f"  rows {y0}-{y1}, x {x0}-{x1}")


if __name__ == "__main__":
    main()
