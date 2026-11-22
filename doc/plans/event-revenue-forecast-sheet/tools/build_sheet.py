"""Build the FR-176 picture sheet from the captures.

usage: python build_sheet.py <captures dir> <sheet dir> <output .html>

<captures dir> holds, each captured twice (suffix -a / -b):
  el-main / el-branch   the entry list (FR-175's capture.cjs), must not change
  pg-main / pg-branch   capture.cjs pages: registration step 1 and the visitor's
                        card (must not change), the report page (branch only)
  fm-main / fm-branch   capture.cjs form: the event form's three states
  cd-branch             capture.cjs card: the card as administrator and visitor
  ods/                  ods_check.sh's output (with DIST_CE): png/pdf LibreOffice's
                        pages, png/chrome Chrome's print of the page, print_check.out
Every verdict on the sheet is computed here from the images: run-to-run
equality of each build, main = branch for what must not change, and a row map
of the event form at the inserted height.
"""

import html
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops

CAP, SHEET, OUT = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
IMG = SHEET / "images"

REPORT_TEXT = {
    "1-full": "Every tier set (200 / 250 / 300 PLN), 14 entries",
    "2-missing-tier": "No price for two weapons: 2 × 200 PLN, with its note",
    "3-no-entries": "A live key, no entries yet",
    "4-not-active": "A replaced or wrong key: „link not active”",
}
FORM_TEXT = {
    "a-registration-on-no-key": "Our registration stored on, no key yet: „Utwórz link”",
    "b-registration-on-key": "Our registration stored on, a key: the link, „Kopiuj”, „Otwórz”, „Nowy link”",
    "c-registration-off": "Our registration not stored on: the muted line",
}


def differing(a: Path, b: Path) -> int | None:
    ia, ib = Image.open(a).convert("RGBA"), Image.open(b).convert("RGBA")
    if ia.size != ib.size:
        return None
    return sum(1 for v in ImageChops.difference(ia, ib).convert("L").tobytes() if v)


def stable(name: str) -> int:
    a, b = CAP / f"{name}-a", CAP / f"{name}-b"
    names = sorted(p.name for p in a.glob("*.png"))
    bad = [n for n in names if differing(a / n, b / n) != 0]
    if bad:
        raise SystemExit(f"{name}: run-to-run differences in {bad}")
    return len(names)


def first_changed_row(before: Path, after: Path) -> int:
    ia, ib = Image.open(before).convert("RGBA"), Image.open(after).convert("RGBA")
    for y in range(min(ia.height, ib.height)):
        if ia.crop((0, y, ia.width, y + 1)).tobytes() != ib.crop((0, y, ib.width, y + 1)).tobytes():
            return y
    return ia.height


def row_map(before: Path, after: Path, at: int, shift: int) -> tuple[int, int, int]:
    """(rows of `before` breaking the rule, pixels differing in them, largest
    channel difference). The rule: identical in place above `at`, identical
    `shift` px lower from `at` on."""
    ia, ib = Image.open(before).convert("RGBA"), Image.open(after).convert("RGBA")
    rows = px = worst = 0
    for y in range(ia.height):
        ay = y if y < at else y + shift
        if ay >= ib.height:
            rows += 1
            continue
        ra, rb = ia.crop((0, y, ia.width, y + 1)), ib.crop((0, ay, ib.width, ay + 1))
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


def fig(src: str, cap: str) -> str:
    return f'<figure><img src="{html.escape(src)}" alt="{html.escape(cap)}" loading="lazy"><figcaption>{cap}</figcaption></figure>'


def main() -> None:
    if IMG.exists():
        shutil.rmtree(IMG)
    counts = {k: stable(k) for k in ("el-main", "el-branch", "pg-main", "pg-branch", "fm-main", "fm-branch", "cd-branch")}

    # --- must not change ------------------------------------------------------
    same_rows: list[str] = []
    total = same = 0
    for surface, d_main, d_branch, prefix in (
        ("Entry list: standalone page and calendar modal, six states", "el-main-a", "el-branch-a", ""),
        ("Registration form, first step", "pg-main-a", "pg-branch-a", "reg__"),
        ("The visitor's event card on the public calendar", "pg-main-a", "pg-branch-a", "card__"),
    ):
        names = sorted(p.name for p in (CAP / d_main).glob(f"{prefix}*.png"))
        ok = sum(1 for n in names if differing(CAP / d_main / n, CAP / d_branch / n) == 0)
        total += len(names)
        same += ok
        chip = '<span class="chip never">identical · 0 px</span>' if ok == len(names) else f'<span class="chip over">{len(names) - ok} differ</span>'
        same_rows.append(f"<tr><td>{html.escape(surface)}</td><td>{ok} of {len(names)}</td><td>{chip}</td></tr>")
    if same != total:
        raise SystemExit(f"only {same} of {total} must-not-change images are identical")
    same_figs = [
        fig(copy(CAP / "el-main-a" / "standalone__desktop__pl__1-no-filter-box-on.png", "same-entry-list-desktop.png"), "Entry list · desktop · identical to main"),
        fig(copy(CAP / "el-main-a" / "standalone__phone__pl__1-no-filter-box-on.png", "same-entry-list-phone.png"), "Entry list · phone · identical to main"),
        fig(copy(CAP / "pg-main-a" / "reg__desktop__pl__step1.png", "same-reg-desktop.png"), "Registration, step 1 · desktop · identical to main"),
        fig(copy(CAP / "pg-main-a" / "reg__phone__pl__step1.png", "same-reg-phone.png"), "Registration, step 1 · phone · identical to main"),
        fig(copy(CAP / "pg-main-a" / "card__desktop__pl__visitor.png", "same-card-desktop.png"), "Visitor's card · desktop · identical to main (no pill)"),
        fig(copy(CAP / "pg-main-a" / "card__phone__pl__visitor.png", "same-card-phone.png"), "Visitor's card · phone · identical to main (no pill)"),
    ]

    # --- the report page --------------------------------------------------------
    report: list[str] = []
    for state, text in REPORT_TEXT.items():
        figs = []
        for width in ("desktop", "phone"):
            for lang in ("pl", "en"):
                n = f"report__{width}__{lang}__{state}.png"
                figs.append(fig(copy(CAP / "pg-branch-a" / n, n), f"{width} · {'Polish' if lang == 'pl' else 'English'}"))
        report.append(f'<div class="pair"><p class="pairhead">{html.escape(text)}</p><div class="cols">{"".join(figs)}</div></div>')

    # --- the page's print beside the file's (change plan rev 2) ----------------
    # <captures>/ods: ods_check.sh with DIST_CE set; pdf/ LibreOffice, chrome/ Chrome.
    ods = CAP / "ods" / "png"
    printed: list[str] = []
    checks = [json.loads(line) for line in (CAP / "ods" / "print_check.out").read_text().splitlines() if line.startswith("{")]
    pages_of = {c["case"]: c for c in checks if "case" in c}
    shows_link = next(c["browser_footer_shows_link"] for c in checks if "browser_footer_shows_link" in c)

    def side(case: str, label: str) -> str:
        page = [fig(copy(ods / "chrome" / f"{case}-p{i}.png", f"print-page-{case}-p{i}.png"), f"The page, printed by Chrome · page {i}")
                for i in range(1, pages_of[case]["page_pages"] + 1)]
        f_pages = [fig(copy(ods / "pdf" / f"{case}-forecast-p1.png", f"print-file-{case}-forecast.png"), "The file, printed by LibreOffice · tab 1")]
        f_pages += [fig(copy(ods / "pdf" / f"{case}-entries-p{i}.png", f"print-file-{case}-entries-p{i}.png"), f"The file · tab 2 · page {i}")
                    for i in range(1, pages_of[case]["file_entries_pages"] + 1)]
        return (f'<div class="pair"><p class="pairhead">{html.escape(label)} — page: {pages_of[case]["page_pages"]} pages, '
                f'file: {pages_of[case]["file_pages"]} pages</p>'
                f'<h3>The page</h3><div class="cols3">{"".join(page)}</div>'
                f'<h3>The file</h3><div class="cols3">{"".join(f_pages)}</div></div>')

    printed.append(side("full-pl", "12 entries, Polish"))
    printed.append(side("full-en", "12 entries, English"))
    printed.append(side("big-pl", "105 entries, Polish"))
    missing = fig(copy(ods / "pdf" / "missing-pl-forecast-p1.png", "ods-missing-pl-forecast.png"), "The file: missing tiers, the formula 2 × C11 and its note")
    empty = fig(copy(ods / "chrome" / "empty-pl-p2.png", "print-page-empty-p2.png"), "The page, no entries: page 2")
    empty_f = fig(copy(ods / "pdf" / "empty-pl-entries-p1.png", "print-file-empty-entries.png"), "The file, no entries: tab 2")
    printed.append(f'<div class="pair"><p class="pairhead">Edge cases</p><div class="cols3">{missing}{empty}{empty_f}</div></div>')
    count_rows = "\n".join(
        f"<tr><td>{html.escape(c)}</td><td>{v['page_pages']}</td><td>{v['file_forecast_pages']} + {v['file_entries_pages']}</td></tr>"
        for c, v in pages_of.items())

    # --- the event form -------------------------------------------------------------
    form_rows: list[str] = []
    form_pairs: list[str] = []
    for p in sorted((CAP / "fm-main-a").glob("*.png")):
        _, width, _lang, state = p.stem.split("__")
        after = CAP / "fm-branch-a" / p.name
        shift = Image.open(after).height - Image.open(p).height
        at = first_changed_row(p, after)
        bad, px, worst = row_map(p, after, at, shift)
        if bad == 0:
            verdict = f'<span class="chip never">rows 0–{at - 1} identical in place; every row below identical {shift} px lower</span>'
        elif worst <= 3:
            verdict = (f'<span class="chip warn">rows 0–{at - 1} identical in place; below, identical {shift} px lower except '
                       f'{px} pixels in {bad} rows, at most {worst}/255 in one colour channel (anti-aliasing of native controls)</span>')
        else:
            verdict = f'<span class="chip over">{bad} rows break the rule ({px} pixels, up to {worst}/255)</span>'
            raise SystemExit(f"event form {p.name}: {bad} rows break the row map, up to {worst}/255")
        form_rows.append(f"<tr><td>{html.escape(FORM_TEXT[state])}</td><td>{width}</td><td>+{shift} px</td><td>{verdict}</td></tr>")
        b = copy(p, f"form-main-{width}-{state}.png")
        a = copy(after, f"form-branch-{width}-{state}.png")
        form_pairs.append(f'<div class="pair"><p class="pairhead">{html.escape(FORM_TEXT[state])} · {width}</p>'
                          f'<div class="cols">{fig(b, "Before (main)")}{fig(a, "After (this branch)")}</div></div>')

    # --- the signed-in card -------------------------------------------------------------
    cards = []
    for width in ("desktop", "phone"):
        for who, label in (("admin", "signed-in administrator: the pill"), ("visitor", "visitor: no pill")):
            n = f"cardh__{width}__pl__{who}.png"
            cards.append(fig(copy(CAP / "cd-branch-a" / n, n), f"{width} · {label}"))

    body = (Path(__file__).parent / "sheet_body.html").read_text(encoding="utf-8")
    for k, v in {
        "@@SAME@@": str(same), "@@TOTAL@@": str(total),
        "@@N_EL@@": str(counts["el-main"]), "@@N_PG_MAIN@@": str(counts["pg-main"]), "@@N_PG_BRANCH@@": str(counts["pg-branch"]),
        "@@N_FM@@": str(counts["fm-main"]), "@@N_CD@@": str(counts["cd-branch"]),
        "@@ROWS_SAME@@": "\n".join(same_rows), "@@FIGS_SAME@@": "\n".join(same_figs),
        "@@REPORT@@": "\n".join(report), "@@PRINTED@@": "\n".join(printed),
        "@@COUNTS@@": count_rows, "@@SHOWS_LINK@@": "printed the link" if shows_link else "did not print the link",
        "@@COUNTS@@": count_rows, "@@SHOWS_LINK@@": "printed the link" if shows_link else "did not print the link",
        "@@ROWS_FORM@@": "\n".join(form_rows), "@@PAIRS_FORM@@": "\n".join(form_pairs), "@@CARDS@@": "\n".join(cards),
    }.items():
        body = body.replace(k, v)
    template = (Path(__file__).parent / "sheet_template.html").read_text(encoding="utf-8")
    OUT.write_text(template.replace("@@BODY@@", body), encoding="utf-8")
    print(f"wrote {OUT}: {same}/{total} identical; stable runs {counts}")


if __name__ == "__main__":
    main()
