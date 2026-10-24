"""HBFRAME.01–07 — handbook pages wear the ADR page frame, generated from the page itself.

doc/plans/docs-adr-look-2026-10-24.html, decision E2 (24 Oct 2026). Every handbook page
with page metadata gets the ADR masthead with a facts card built from its <meta> tags,
and the ADR contents column built from its own sections. scripts/render_handbook_frame.py
writes both, like render_adrs.py writes ADR pages, and `--check` keeps them current.
The page's own text is never touched, except the hand-written "Verified <date>" chip,
which disagreed with the page's last-verified metadata and is replaced by the facts card.
"""

from __future__ import annotations

import re
from pathlib import Path

from scripts.render_handbook_frame import frame_pages, render_page

ROOT = Path(__file__).resolve().parents[2]

PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="doc-id" content="HB-TEST"><meta name="doc-status" content="current"><meta name="doc-type" content="subsystem"><meta name="doc-owner" content="Pipeline"><meta name="last-verified" content="2026-10-24"><title>T</title></head>
<body><div class="page"><header class="handbook-header"><nav class="breadcrumb"><a href="../index.html">Handbook</a><span>Subsystems</span></nav><p class="eyebrow">Subsystem · Test</p><h1>Test</h1><p class="dek">Dek.</p><div class="doc-meta"><span>Draft paths</span><span>Verified 3 October 2026</span></div></header><main>
<section id="purpose"><p class="kicker">Why</p><h2>Purpose</h2><p>Body <b>one</b>.</p></section>
<section id="flow">
<h2>Current <code>flow</code></h2><p>Body two.</p></section>
</main><nav class="page-links"><a href="a.html">A</a></nav><footer class="freshness">Owner: Pipeline</footer></div></body></html>
"""


def _main_text(html: str) -> str:
    return html[html.index("<main>") : html.index("</main>") + len("</main>")]


def test_HBFRAME_01_facts_card_comes_from_the_page_metadata():
    out = render_page(PAGE)
    facts = re.search(r'<aside class="facts"[^>]*>(.*?)</aside>', out, re.S)
    assert facts, "the masthead must carry a facts card"
    card = facts.group(1)
    for label, value in [
        ("Status", "Current"),
        ("Owner", "Pipeline"),
        ("Type", "Subsystem"),
        ("Last verified", "24 October 2026"),
        ("Page id", "HB-TEST"),
    ]:
        assert re.search(rf"<dt>{label}</dt><dd[^>]*>{value}</dd>", card), (label, value, card)
    assert '<header class="handbook-header mast">' in out


def test_HBFRAME_02_contents_column_lists_the_page_sections_in_order():
    out = render_page(PAGE)
    toc = re.search(r'<nav class="toc"[^>]*>(.*?)</nav>', out, re.S)
    assert toc, "the page must carry a contents column"
    items = re.findall(r'<a href="#([^"]+)">([^<]*)</a>', toc.group(1))
    assert items == [("purpose", "Purpose"), ("flow", "Current flow")]
    assert re.search(r'<div class="layout"[^>]*><nav class="toc"', out)


def test_HBFRAME_03_rendering_is_idempotent():
    once = render_page(PAGE)
    assert render_page(once) == once


def test_HBFRAME_04_stale_verified_chip_goes_other_chips_stay():
    out = render_page(PAGE)
    meta = re.search(r'<div class="doc-meta">(.*?)</div>', out, re.S)
    assert meta and "Draft paths" in meta.group(1)
    assert "Verified 3 October 2026" not in out
    single = PAGE.replace("<span>Draft paths</span>", "")
    assert '<div class="doc-meta">' not in render_page(single), "an empty chip row goes too"


def test_HBFRAME_05_page_text_is_untouched():
    out = render_page(PAGE)
    assert _main_text(out) == _main_text(PAGE)
    for kept in [
        '<nav class="page-links">',
        '<footer class="freshness">Owner: Pipeline</footer>',
        "<h1>Test</h1>",
    ]:
        assert kept in out


def test_HBFRAME_06_every_handbook_page_is_current():
    pages = frame_pages()
    stale = [
        str(p.relative_to(ROOT))
        for p in pages
        if render_page(p.read_text(encoding="utf-8")) != p.read_text(encoding="utf-8")
    ]
    assert len(pages) >= 26
    assert stale == [], f"run python scripts/render_handbook_frame.py: {stale}"


def test_HBFRAME_07_preflight_and_ci_check_the_frame():
    preflight = (ROOT / "scripts" / "preflight.sh").read_text()
    ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text()
    assert "render_handbook_frame.py --check" in preflight
    assert "render_handbook_frame.py --check" in ci
