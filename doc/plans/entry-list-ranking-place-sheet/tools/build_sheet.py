"""Build the FR-175 picture sheet from the captures.

usage: python build_sheet.py <captures dir> <sheet dir> <output .html>

<captures dir> holds before-a/-b, after-a/-b (entry list, capture.cjs) and
fbefore-a/-b, fafter-a/-b (event form, capture_form.cjs). Every verdict on the
sheet is computed here from the images: run-to-run equality of each build,
before = after for the states that must not change, and for the event form a
row map (rowmap.py's rule) at the inserted height. Images are copied into
<sheet dir>/images: one copy of a state proven identical, a before/after pair
of every state that changes.
"""

import html
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops

CAP, SHEET, OUT = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
IMG = SHEET / "images"

SAME = ["1-no-filter-box-on", "2-three-filters-box-off", "3-two-filters-box-on", "6-v0-evf-box-on"]
NEW = ["4-three-filters-evf", "5-three-filters-ours"]
STATE_TEXT = {
    "1-no-filter-box-on": "No filter; the box ticked",
    "2-three-filters-box-off": "Épée, V2, men; the box not ticked",
    "3-two-filters-box-on": "Épée and V2, no gender; the box ticked",
    "6-v0-evf-box-on": "Épée, V0, men at an EVF event; the box ticked (EVF ranks 40 and over)",
    "4-three-filters-evf": "Épée, V2, men at an EVF event; the box ticked",
    "5-three-filters-ours": "Épée, V2, men at an event of ours; the box ticked",
}
FORM_TEXT = {
    "a-registration-on-box-off": "Our registration on; the box stored off",
    "b-registration-on-box-on": "Our registration on; the box stored on",
    "c-registration-off": "Our registration off: the box is disabled",
}


def pixels_differing(a: Path, b: Path) -> int | None:
    ia, ib = Image.open(a).convert("RGBA"), Image.open(b).convert("RGBA")
    if ia.size != ib.size:
        return None
    diff = ImageChops.difference(ia, ib).convert("L").tobytes()
    return sum(1 for v in diff if v)


def stable(dir_a: Path, dir_b: Path) -> tuple[int, list[str]]:
    names = sorted(p.name for p in dir_a.glob("*.png"))
    return len(names), [n for n in names if pixels_differing(dir_a / n, dir_b / n) != 0]


def inserted_height(before: Path, after: Path) -> int:
    return Image.open(after).height - Image.open(before).height


def first_changed_row(before: Path, after: Path) -> int:
    ia, ib = Image.open(before).convert("RGBA"), Image.open(after).convert("RGBA")
    for y in range(ia.height):
        if ia.crop((0, y, ia.width, y + 1)).tobytes() != ib.crop((0, y, ib.width, y + 1)).tobytes():
            return y
    return ia.height


def row_map(before: Path, after: Path, at: int, shift: int) -> tuple[int, int, int]:
    """(rows breaking the rule, pixels differing in them, max channel delta)."""
    ia, ib = Image.open(before).convert("RGBA"), Image.open(after).convert("RGBA")
    rows = px = worst = 0
    for y in range(ia.height):
        ay = y if y < at else y + shift
        ra = ia.crop((0, y, ia.width, y + 1))
        rb = ib.crop((0, ay, ib.width, ay + 1))
        if ra.tobytes() == rb.tobytes():
            continue
        rows += 1
        d = ImageChops.difference(ra, rb).tobytes()
        for i in range(0, len(d), 4):
            m = max(d[i:i + 4])
            if m:
                px += 1
                worst = max(worst, m)
    return rows, px, worst


def copy(src: Path, name: str) -> str:
    IMG.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, IMG / name)
    return f"{SHEET.name}/images/{name}"


def fig(src: str, alt: str, cap: str) -> str:
    return (f'<figure><img src="{html.escape(src)}" alt="{html.escape(alt)}" loading="lazy">'
            f"<figcaption>{cap}</figcaption></figure>")


def main() -> None:
    if IMG.exists():
        shutil.rmtree(IMG)
    stab = {k: stable(CAP / f"{k}-a", CAP / f"{k}-b") for k in ("before", "after", "fbefore", "fafter")}
    for k, (n, bad) in stab.items():
        if bad:
            raise SystemExit(f"{k}: run-to-run differences in {bad}")

    # Entry list: every state on both surfaces, widths and languages.
    rows_same: list[str] = []
    rows_new: list[str] = []
    same_ok = 0
    same_total = 0
    for p in sorted((CAP / "before-a").glob("*.png")):
        surface, width, lang, state = p.stem.split("__")
        d = pixels_differing(p, CAP / "after-a" / p.name)
        label = f"{surface} · {width} · {lang}"
        if state in SAME:
            same_total += 1
            same_ok += d == 0
            verdict = '<span class="chip never">identical · 0 px</span>' if d == 0 else f'<span class="chip over">{d} px differ</span>'
            rows_same.append(f"<tr><td>{html.escape(STATE_TEXT[state])}</td><td>{label}</td><td>{verdict}</td></tr>")
        else:
            h = inserted_height(p, CAP / "after-a" / p.name)
            rows_new.append(f"<tr><td>{html.escape(STATE_TEXT[state])}</td><td>{label}</td>"
                            f'<td><span class="chip fill">new look · {h:+d} px tall</span></td></tr>')
    if same_ok != same_total:
        raise SystemExit(f"only {same_ok} of {same_total} unchanged states are identical")

    figs_same: list[str] = []
    for state in SAME:
        for width in ("desktop", "phone"):
            n = f"standalone__{width}__pl__{state}.png"
            figs_same.append(fig(copy(CAP / "before-a" / n, "same-" + n), f"{STATE_TEXT[state]}, {width}",
                                 f"{html.escape(STATE_TEXT[state])} · {width} · Polish · <b>identical to main</b>"))

    pairs_new: list[str] = []
    for state in NEW:
        for width in ("desktop", "phone"):
            for lang in ("pl", "en"):
                n = f"standalone__{width}__{lang}__{state}.png"
                b = copy(CAP / "before-a" / n, "before-" + n)
                a = copy(CAP / "after-a" / n, "after-" + n)
                pairs_new.append(
                    f'<div class="pair"><p class="pairhead">{html.escape(STATE_TEXT[state])} · {width} · {lang}</p>'
                    f'<div class="cols">{fig(b, "before", "Before (main)")}{fig(a, "after", "After (this branch)")}</div></div>')

    # Event form.
    form_rows: list[str] = []
    form_pairs: list[str] = []
    for p in sorted((CAP / "fbefore-a").glob("*.png")):
        _, width, lang, state = p.stem.split("__")
        after = CAP / "fafter-a" / p.name
        shift = inserted_height(p, after)
        at = first_changed_row(p, after)
        rows, px, worst = row_map(p, after, at, shift)
        verdict = (f"rows 0–{at - 1} identical in place; every row below identical {shift} px lower"
                   if rows == 0 else
                   f"rows 0–{at - 1} identical in place; below, identical {shift} px lower except {rows} row "
                   f"({px} pixels, at most {worst}/255 in one colour channel: anti-aliasing)")
        form_rows.append(f"<tr><td>{html.escape(FORM_TEXT[state])}</td><td>{width}</td><td>{verdict}</td></tr>")
        b = copy(p, "form-before-" + p.name)
        a = copy(after, "form-after-" + p.name)
        form_pairs.append(
            f'<div class="pair"><p class="pairhead">{html.escape(FORM_TEXT[state])} · {width}</p>'
            f'<div class="cols">{fig(b, "before", "Before (main)")}{fig(a, "after", "After (this branch)")}</div></div>')

    n_el = stab["before"][0]
    n_form = stab["fbefore"][0]
    template = (Path(__file__).parent / "sheet_template.html").read_text(encoding="utf-8")
    page = (template
            .replace("@@SAME_OK@@", str(same_ok)).replace("@@SAME_TOTAL@@", str(same_total))
            .replace("@@N_EL@@", str(n_el)).replace("@@N_FORM@@", str(n_form))
            .replace("@@ROWS_SAME@@", "\n".join(rows_same)).replace("@@ROWS_NEW@@", "\n".join(rows_new))
            .replace("@@FIGS_SAME@@", "\n".join(figs_same)).replace("@@PAIRS_NEW@@", "\n".join(pairs_new))
            .replace("@@ROWS_FORM@@", "\n".join(form_rows)).replace("@@PAIRS_FORM@@", "\n".join(form_pairs)))
    OUT.write_text(page, encoding="utf-8")
    print(f"wrote {OUT}: {same_ok}/{same_total} identical; {len(pairs_new)} new pairs; {len(form_pairs)} form pairs")


if __name__ == "__main__":
    main()
