"""Build the picture sheet for centring the entry list's „#” column.

usage: python build_sheet.py <captures dir> <sheet dir> <output .html>

<captures dir> holds before-a/-b (main) and after-a/-b (branch), captured by
../../entry-list-ranking-place-sheet/tools/capture.cjs. Computed here from the
images: run-to-run equality of each build; the states without „#” identical to
main; for the states with „#”, the same size and every differing pixel inside
the column's x-range.
"""

import html
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops

CAP, SHEET, OUT = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
IMG = SHEET / "images"
WITH_RANK = ("4-three-filters-evf", "5-three-filters-ours")
STATE_TEXT = {
    "1-no-filter-box-on": "No filter; the box ticked",
    "2-three-filters-box-off": "Épée, V2, men; the box not ticked",
    "3-two-filters-box-on": "Épée and V2, no gender; the box ticked",
    "6-v0-evf-box-on": "Épée, V0, men at an EVF event; the box ticked",
    "4-three-filters-evf": "Épée, V2, men at an EVF event; the box ticked",
    "5-three-filters-ours": "Épée, V2, men at an event of ours; the box ticked",
}
# Moving the place numbers inside their column changes only a narrow vertical
# strip; anything wider (a name, a chip, the tiles) would mean the change
# reached beyond the column.
STRIP = 24


def diff_box(a: Path, b: Path) -> tuple[str, int, tuple[int, int, int, int] | None]:
    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    if ia.size != ib.size:
        return f"{ia.size} vs {ib.size}", -1, None
    d = ImageChops.difference(ia, ib)
    n = sum(1 for v in d.convert("L").tobytes() if v)
    return f"{ia.width}x{ia.height}", n, d.getbbox()


def copy(src: Path, name: str) -> str:
    IMG.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, IMG / name)
    return f"{SHEET.name}/images/{name}"


def fig(src: str, cap: str) -> str:
    return f'<figure><img src="{html.escape(src)}" alt="{html.escape(cap)}" loading="lazy"><figcaption>{cap}</figcaption></figure>'


def main() -> None:
    if IMG.exists():
        shutil.rmtree(IMG)
    for side in ("before", "after"):
        for p in sorted((CAP / f"{side}-a").glob("*.png")):
            if diff_box(p, CAP / f"{side}-b" / p.name)[1] != 0:
                raise SystemExit(f"{side}: run-to-run difference in {p.name}")
    rows: list[str] = []
    pairs: list[str] = []
    same_ok = same_n = col_ok = col_n = 0
    for p in sorted((CAP / "before-a").glob("*.png")):
        surface, width, lang, state = p.stem.split("__")
        _, n, box = diff_box(p, CAP / "after-a" / p.name)
        where = f"{surface} · {width} · {lang}"
        if state not in WITH_RANK:
            same_n += 1
            same_ok += n == 0
            v = '<span class="chip never">identical · 0 px</span>' if n == 0 else f'<span class="chip over">{n} px differ</span>'
        else:
            col_n += 1
            if box is not None and n > 0 and box[2] - box[0] <= STRIP:
                col_ok += 1
                v = (f'<span class="chip fill">{n} px differ, all within x {box[0]}–{box[2] - 1} '
                     f'({box[2] - box[0]} px wide): the „#” column</span>')
            else:
                v = f'<span class="chip over">{n} px differ, box {box}</span>'
            if surface == "standalone":
                b = copy(p, "before-" + p.name)
                a = copy(CAP / "after-a" / p.name, "after-" + p.name)
                pairs.append(f'<div class="pair"><p class="pairhead">{html.escape(STATE_TEXT[state])} · {width} · {lang}</p>'
                             f'<div class="cols">{fig(b, "Before (main): right-aligned")}{fig(a, "After: centred")}</div></div>')
        rows.append(f"<tr><td>{html.escape(STATE_TEXT[state])}</td><td>{where}</td><td>{v}</td></tr>")
    if same_ok != same_n or col_ok != col_n:
        raise SystemExit(f"identical {same_ok}/{same_n}, column-only {col_ok}/{col_n}")
    page = (Path(__file__).parent / "sheet_template.html").read_text(encoding="utf-8")
    page = (page.replace("@@SAME@@", f"{same_ok} of {same_n}").replace("@@COL@@", f"{col_ok} of {col_n}")
            .replace("@@ROWS@@", "\n".join(rows)).replace("@@PAIRS@@", "\n".join(pairs)))
    OUT.write_text(page, encoding="utf-8")
    print(f"wrote {OUT}: identical {same_ok}/{same_n}, column-only {col_ok}/{col_n}, {len(pairs)} pairs")


if __name__ == "__main__":
    main()
