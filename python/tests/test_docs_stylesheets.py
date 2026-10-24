"""DOCSTYLE.01–04 — documentation pages render the same in html-preview as locally.

doc/plans/docs-adr-look-2026-10-24.html (24 Oct 2026). The README opens the HTML
documentation through https://html-preview.github.io/?url=<GitHub blob URL>. That
service loads each <link rel="stylesheet"> from GitHub, but an @import inside a
stylesheet is resolved against html-preview's own address and fails. handbook.css
pulled the whole ADR design in with `@import url("../../adr/assets/adr.css")`, so
every page on it opened unstyled in the preview while the ADR pages, which link
adr.css directly, looked right.

DOCSTYLE.04: on a phone the ADR "Decision" band pulled out 24 px each side while
the page margin there is 20 px, so every ADR page was 4 px wider than the screen.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / "doc"
HANDBOOK_CSS = DOC / "handbook" / "assets" / "handbook.css"
ADR_CSS = DOC / "adr" / "assets" / "adr.css"
LINK = re.compile(r'<link rel="stylesheet" href="([^"]+)">')


def _tracked_doc_files(suffix: str) -> list[Path]:
    out = subprocess.run(
        ["git", "ls-files", "--", f"doc/*{suffix}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.splitlines()
    return [ROOT / line for line in out if line]


def _stylesheets(page: Path) -> list[Path]:
    hrefs: list[str] = LINK.findall(page.read_text(encoding="utf-8"))
    return [(page.parent / href).resolve() for href in hrefs]


def test_DOCSTYLE_01_no_stylesheet_under_doc_imports_another():
    offenders = [
        str(css.relative_to(ROOT))
        for css in _tracked_doc_files(".css")
        if re.search(r"@import\b", css.read_text(encoding="utf-8"))
    ]
    assert offenders == [], (
        f"html-preview cannot resolve @import; link the file instead: {offenders}"
    )


def test_DOCSTYLE_02_handbook_pages_link_adr_css_first():
    pages = [p for p in _tracked_doc_files(".html") if HANDBOOK_CSS.resolve() in _stylesheets(p)]
    assert len(pages) >= 30, f"expected the handbook family, found {len(pages)} pages"
    for page in pages:
        sheets = _stylesheets(page)
        name = page.relative_to(ROOT)
        assert ADR_CSS.resolve() in sheets, f"{name} must link adr.css itself"
        assert sheets.index(ADR_CSS.resolve()) < sheets.index(HANDBOOK_CSS.resolve()), (
            f"{name}: adr.css must come before handbook.css (same cascade as the old import)"
        )


def test_DOCSTYLE_03_every_linked_stylesheet_exists():
    missing = [
        f"{page.relative_to(ROOT)} -> {sheet}"
        for page in _tracked_doc_files(".html")
        for sheet in _stylesheets(page)
        if not sheet.is_file()
    ]
    assert missing == [], missing


def _media_block(css: str, query: str) -> str:
    at = css.index(f"@media {query}")
    depth = 0
    for i in range(css.index("{", at), len(css)):
        if css[i] == "{":
            depth += 1
        elif css[i] == "}":
            depth -= 1
            if depth == 0:
                return css[at : i + 1]
    raise AssertionError(f"unterminated @media {query}")


def test_DOCSTYLE_04_adr_decision_band_stays_inside_a_phone_page():
    css = ADR_CSS.read_text(encoding="utf-8")
    narrow = _media_block(css, "(max-width: 820px)")
    page = re.search(r"\.page\s*\{\s*padding:\s*\d+px\s+(\d+)px", narrow)
    assert page, "the narrow-screen .page padding must stay explicit"
    gutter = int(page.group(1))
    band = re.search(r"\.section-card\.decision\s*\{([^}]*)\}", narrow)
    assert band, "the Decision band needs a narrow-screen rule"
    pull = re.search(r"margin-inline:\s*-(\d+)px", band.group(1))
    assert pull and int(pull.group(1)) <= gutter, (
        f"the band pulls out {pull.group(1) if pull else '?'} px; the page margin is {gutter} px"
    )
