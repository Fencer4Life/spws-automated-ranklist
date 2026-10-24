"""Give every handbook page the ADR page frame, generated from the page itself.

The masthead gets a facts card built from the page's <meta> tags, and the page gets
the ADR contents column built from its own <section id> headings. Both are generated
here and never edited by hand; the page's own text is not touched, except that the
hand-written "Verified <date>" chip is dropped because the facts card shows the date
from `last-verified` (the chip had drifted from it on most pages).

Usage:
    python scripts/render_handbook_frame.py          # rewrite pages in place
    python scripts/render_handbook_frame.py --check  # exit 1 if any page is stale

Decision: doc/plans/docs-adr-look-2026-10-24.html (E2). Tests: HBFRAME.01–07.
"""

from __future__ import annotations

import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HANDBOOK = ROOT / "doc" / "handbook"

FRAME = 'data-frame="handbook"'
META = re.compile(r'<meta name="([a-z-]+)" content="([^"]*)">')
HEADER = re.compile(r'<header class="handbook-header(?: mast)?">(.*?)</header>', re.S)
FACTS = re.compile(rf'<aside class="facts" {FRAME}[^>]*>.*?</aside>', re.S)
MAST_MAIN = re.compile(r'^<div class="mast-main">(.*)</div>$', re.S)
VERIFIED_CHIP = re.compile(r"<span>Verified [^<]*</span>")
EMPTY_META_ROW = re.compile(r'<div class="doc-meta">\s*</div>')
LAYOUT = re.compile(
    rf'<div class="layout" {FRAME}><nav class="toc"[^>]*>.*?</nav>(<main>.*?</main>)</div>', re.S
)
MAIN = re.compile(r"<main>.*?</main>", re.S)
SECTION = re.compile(r'<section id="([^"]+)"[^>]*>')
H2 = re.compile(r"<h2[^>]*>(.*?)</h2>", re.S)
TAG = re.compile(r"<[^>]+>")


def frame_pages() -> list[Path]:
    """Handbook pages that carry page metadata and the handbook header."""
    return sorted(
        p
        for p in HANDBOOK.rglob("*.html")
        if '<meta name="doc-id"' in (text := p.read_text(encoding="utf-8"))
        and '<header class="handbook-header' in text
    )


def _verified(value: str) -> str:
    try:
        d = date.fromisoformat(value)
    except ValueError:
        return value
    return f"{d.day} {d.strftime('%B')} {d.year}"


def _title(value: str) -> str:
    return value[:1].upper() + value[1:]


def facts_html(meta: dict[str, str]) -> str:
    rows = [
        ("Status", _title(meta.get("doc-status", "")), meta.get("doc-status", "")),
        ("Owner", meta.get("doc-owner", ""), ""),
        ("Type", _title(meta.get("doc-type", "")), ""),
        ("Last verified", _verified(meta.get("last-verified", "")), ""),
        ("Page id", meta.get("doc-id", ""), ""),
    ]
    body = "".join(
        f'<div><dt>{label}</dt><dd class="{css}">{value}</dd></div>'
        for label, value, css in rows
        if value
    )
    return f'<aside class="facts" {FRAME} aria-label="Page metadata"><dl>{body}</dl></aside>'


def toc_html(main: str) -> str:
    starts = list(SECTION.finditer(main))
    items: list[str] = []
    for i, m in enumerate(starts):
        segment = main[m.end() : starts[i + 1].start() if i + 1 < len(starts) else len(main)]
        h2 = H2.search(segment)
        if h2:
            title = " ".join(TAG.sub("", h2.group(1)).split())
            items.append(f'<li class="depth-2"><a href="#{m.group(1)}">{title}</a></li>')
    if not items:
        return ""
    return f'<nav class="toc" aria-label="Contents"><p class="kicker">On this page</p><ol>{"".join(items)}</ol></nav>'


def render_page(page: str) -> str:
    meta = dict(META.findall(page))

    header = HEADER.search(page)
    if header:
        inner = FACTS.sub("", header.group(1))
        unwrapped = MAST_MAIN.match(inner)
        if unwrapped:
            inner = unwrapped.group(1)
        inner = EMPTY_META_ROW.sub("", VERIFIED_CHIP.sub("", inner))
        new_header = f'<header class="handbook-header mast"><div class="mast-main">{inner}</div>{facts_html(meta)}</header>'
        page = page[: header.start()] + new_header + page[header.end() :]

    page = LAYOUT.sub(lambda m: m.group(1), page)
    main = MAIN.search(page)
    if main:
        toc = toc_html(main.group(0))
        if toc:
            page = (
                page[: main.start()]
                + f'<div class="layout" {FRAME}>{toc}{main.group(0)}</div>'
                + page[main.end() :]
            )
    return page


def main() -> int:
    check = "--check" in sys.argv[1:]
    stale: list[str] = []
    for path in frame_pages():
        current = path.read_text(encoding="utf-8")
        rendered = render_page(current)
        if rendered != current:
            stale.append(str(path.relative_to(ROOT)))
            if not check:
                _ = path.write_text(rendered, encoding="utf-8")
    if check:
        if stale:
            print("Stale handbook frame (run python scripts/render_handbook_frame.py):")
            for name in stale:
                print(f"  - {name}")
            return 1
        print(f"Validated handbook frame on {len(frame_pages())} pages")
        return 0
    print(f"Rendered handbook frame: {len(stale)} page(s) updated, {len(frame_pages())} checked")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
