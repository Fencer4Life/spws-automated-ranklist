"""FR-176 — the page prints basically as the file does (change plan rev 2).

usage: python print_check.py <ods out dir>

Reads LibreOffice's print of the file (pdf/<case>-forecast.pdf and
pdf/<case>-entries.pdf, from ods_check.sh) and Chrome's print of the page
(chrome/<case>.pdf, from print_check.cjs) for the same data, and checks:
every page A4; the page's summary alone on page 1; the entries from page 2,
their header on every page, the total at the end; the file's footer on every
page of the page's print; the entries' header on every page of the file's
print; the two page counts within one page of each other. Prints a JSON line
per case for the picture sheet and exits 1 on any failure.
"""

import json
import sys
from pathlib import Path

from pypdf import PdfReader

OUT = Path(sys.argv[1])
WORDS = {
    "pl": {"title": "Prognoza przychodu", "head": "Nazwisko i imię", "total": "Razem", "page": "Strona {k} z {n}"},
    "en": {"title": "Revenue forecast", "head": "Surname and name", "total": "Total", "page": "Page {k} of {n}"},
}
failures: list[str] = []


def check(label: str, ok: bool) -> None:
    if not ok:
        failures.append(label)
        print("  FAIL", label)


def pages(path: Path) -> list[tuple[float, float, str]]:
    r = PdfReader(str(path))
    return [(float(p.mediabox.width), float(p.mediabox.height), p.extract_text() or "") for p in r.pages]


def a4(ps: list[tuple[float, float, str]]) -> bool:
    return all(abs(w - 595.3) < 1.5 and abs(h - 841.9) < 1.5 for w, h, _ in ps)


for case in ("full-pl", "full-en", "big-pl", "big-en", "empty-pl"):
    lang = case.split("-")[1]
    w = WORDS[lang]
    chrome = pages(OUT / "chrome" / f"{case}.pdf")
    lo_f = pages(OUT / "pdf" / f"{case}-forecast.pdf")
    lo_e = pages(OUT / "pdf" / f"{case}-entries.pdf")
    n = len(chrome)
    check(f"{case}: page print is A4", a4(chrome))
    check(f"{case}: file print is A4", a4(lo_f) and a4(lo_e))
    check(f"{case}: page 1 holds the summary", w["title"] in chrome[0][2])
    check(f"{case}: page 1 holds no entries", w["head"] not in chrome[0][2])
    if case != "empty-pl":
        check(f"{case}: entries from page 2", n >= 2)
        for k in range(1, n):
            check(f"{case}: page {k + 1} repeats the entries header", w["head"] in chrome[k][2])
        for k, (_, _, text) in enumerate(lo_e):
            check(f"{case}: file entries page {k + 1} repeats the header", w["head"] in text)
        check(f"{case}: the page's entries end with the total", w["total"] in chrome[-1][2])
        check(f"{case}: page counts within one (page {n}, file {len(lo_f) + len(lo_e)})", abs(n - (len(lo_f) + len(lo_e))) <= 1)
    for k in range(n):
        check(f"{case}: footer on page {k + 1}", w["page"].format(k=k + 1, n=n) in chrome[k][2] and "PEW5 Łomianki" in chrome[k][2])
    print(json.dumps({"case": case, "page_pages": n, "file_pages": len(lo_f) + len(lo_e),
                      "file_forecast_pages": len(lo_f), "file_entries_pages": len(lo_e)}))

# With Chrome's own header and footer switched on, as the print dialog's
# „Headers and footers” box does: does the link, with its key, appear?
own = pages(OUT / "chrome" / "full-pl-browser-footer.pdf")
shows_link = any("register.html" in t for _, _, t in own)
print(json.dumps({"browser_footer_shows_link": shows_link}))

print(f"\n{len(failures)} failures" if failures else "\nall print checks passed")
sys.exit(1 if failures else 0)
