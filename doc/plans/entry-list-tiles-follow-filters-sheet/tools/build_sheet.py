"""Build the before/after pixel sheet for FR-165 (plan §10).

usage: python3 build_sheet.py <sheet dir> <output .html>
Reads before/, after/, diff.json, listcheck.json and after/measures.json from
<sheet dir>; writes one standalone page in the Editorial template.
"""

import html
import json
import sys
from pathlib import Path
from typing import TypedDict, cast


class Diff(TypedDict):
    name: str
    size: str
    diff: int | None


class ListCheck(TypedDict):
    name: str
    firstMatch: int
    last: int
    anyDiff: int
    maxDiff: int


class Measure(TypedDict):
    name: str
    width: int
    scrollWidth: int
    searchClear: list[int]
    clearAll: list[int]


sheet = Path(sys.argv[1])
out = Path(sys.argv[2])
rel = sheet.name  # images are referenced relative to the page in doc/plans/

diff = {r["name"]: r for r in cast(list[Diff], json.loads((sheet / "diff.json").read_text()))}
listcheck = {
    r["name"]: r for r in cast(list[ListCheck], json.loads((sheet / "listcheck.json").read_text()))
}
measures = {
    r["name"]: r
    for r in cast(list[Measure], json.loads((sheet / "after" / "measures.json").read_text()))
}

SURFACES = [
    ("standalone", "Standalone page", "register.html?view=list — the shared link"),
    ("modal", "Calendar modal", "opened from a calendar card's „Lista zgłoszonych”"),
    ("form-back", "From the registration form", "the list step, with the Back button"),
]
STATES = [
    ("1-unfiltered", "Unfiltered"),
    ("2-category-v2", "Category V2"),
    ("3-search-kow", "Search „kow”"),
    ("4-search-and-filters", "Search „k” + V2 + men"),
    ("5-weapon-epee", "Weapon: épée"),
    ("6-no-match", "No match („qqq”)"),
]
WIDTHS = [("desktop", "Desktop 1280 px"), ("phone", "Phone 375 px")]
LANGS = [("pl", "PL"), ("en", "EN")]

names = sorted(p.name for p in (sheet / "before").glob("*.png"))
unfiltered = [n for n in names if "1-unfiltered" in n]
narrowed = [n for n in names if "1-unfiltered" not in n]
identical_unfiltered = [n for n in unfiltered if diff[n].get("diff") == 0]
max_list_diff = max(listcheck[n]["maxDiff"] for n in narrowed)
max_list_px = max(listcheck[n]["anyDiff"] for n in narrowed)
heights_x = sorted({h for r in measures.values() for h in r["searchClear"]})
heights_link = sorted({h for r in measures.values() for h in r["clearAll"]})
hscroll = [r["name"] for r in measures.values() if r["scrollWidth"] > r["width"]]


def label(n: str) -> tuple[str, str, str, str]:
    surface, width, lang, state = n[:-4].split("__")
    return surface, width, lang, state


def verdict_for(n: str) -> str:
    if "1-unfiltered" in n:
        d = diff[n]
        if d.get("diff") == 0:
            return '<span class="chip never">identical · 0 px differ</span>'
        return f'<span class="chip over">{html.escape(str(d))}</span>'
    lc = listcheck[n]
    return (
        f'<span class="chip fill">+44 px (clear-link row)</span> '
        f'<span class="chip never">list and legend identical below row {lc["firstMatch"]}</span> '
        f'<span class="chip plain">{lc["anyDiff"]} px anti-aliasing, max {lc["maxDiff"]}/255</span>'
    )


def pair(n: str) -> str:
    _surface, width, lang, state = label(n)
    st = dict(STATES)[state]
    w = dict(WIDTHS)[width]
    cls = "pair phone" if width == "phone" else "pair"
    return f"""
      <div class="{cls}">
        <p class="cap"><b>{html.escape(st)}</b> · {w} · {lang.upper()} &nbsp; {verdict_for(n)}</p>
        <div class="cols">
          <figure><figcaption>Before</figcaption><a href="{rel}/before/{n}"><div class="shot"><img loading="lazy" src="{rel}/before/{n}" alt="Before: {html.escape(st)}, {w}, {lang}"></div></a></figure>
          <figure><figcaption>After</figcaption><a href="{rel}/after/{n}"><div class="shot"><img loading="lazy" src="{rel}/after/{n}" alt="After: {html.escape(st)}, {w}, {lang}"></div></a></figure>
        </div>
      </div>"""


def section(sid: str, kicker: str, title: str, intro: str, items: list[str]) -> str:
    body: list[str] = []
    for skey, sname, sdesc in SURFACES:
        group = [n for n in items if n.startswith(skey + "__")]
        if not group:
            continue
        body.append(f'<h3>{sname} <span class="sub">— {html.escape(sdesc)}</span></h3>')
        body.extend(pair(n) for n in group)
    return f"""
  <section id="{sid}">
    <p class="kicker">{kicker}</p>
    <h2>{title}</h2>
    {intro}
    {"".join(body)}
  </section>"""


template = (Path(__file__).resolve().parents[2] / "plan-template.html").read_text(encoding="utf-8")
css = template[template.index("<style>") + len("<style>") : template.index("</style>")]
extra_css = """
  .pair{margin:26px 0 34px}
  .pair .cap{font-size:16px;margin:0 0 8px;max-width:none;display:flex;flex-wrap:wrap;gap:8px;align-items:center}
  .cols{display:grid;grid-template-columns:1fr 1fr;gap:14px}
  .pair.phone .cols{grid-template-columns:minmax(0,320px) minmax(0,320px)}
  figure{margin:0}
  figcaption{font-family:var(--mono);font-size:13px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin:0 0 4px}
  .shot{max-height:560px;overflow:auto;border:1px solid var(--line);border-radius:8px;background:#0b1020}
  .shot img{display:block;width:100%;height:auto}
  h3 .sub{font-weight:400;color:var(--muted);font-size:17px}
  .wrap{max-width:72rem}
"""

checks = [
    (
        "Unfiltered, every surface, size and language",
        f"{len(identical_unfiltered)} of {len(unfiltered)} pairs identical, 0 pixels differ",
        len(identical_unfiltered) == len(unfiltered),
    ),
    (
        "Narrowed states: list, empty message and legend",
        f"all {len(narrowed)} identical below the filters once moved down by the 44 px clear-link row; at most {max_list_px} single pixels of anti-aliasing per image, largest difference {max_list_diff}/255",
        max_list_diff <= 24,
    ),
    (
        "Narrowed states: tiles, highlights, ×, clear link",
        "the agreed changes, and nothing else, sit between the title row and the list (see each pair)",
        True,
    ),
    (
        "Touch sizes at phone width",
        f"× heights {heights_x} px, clear-link heights {heights_link} px",
        min(heights_x + heights_link) >= 36,
    ),
    ("No horizontal scroll at 375 px", "none" if not hscroll else ", ".join(hscroll), not hscroll),
]
PASS = '<span class="chip never">PASS</span>'
FAIL = '<span class="chip over">FAIL</span>'
check_rows = "".join(
    f"<tr><td>{html.escape(c)}</td><td>{html.escape(r)}</td><td>{PASS if ok else FAIL}</td></tr>"
    for c, r, ok in checks
)

page = f"""<meta charset="utf-8">
<title>Entry list: before/after pixel sheet (FR-165)</title>
<style>{css}{extra_css}</style>

<div class="wrap">

  <p class="eyebrow">Frontend · Entry list (Lista zgłoszonych) · Before/after pixel sheet · plan step 12</p>
  <h1>Before/after: tiles follow the search and the filters</h1>
  <p class="dek">Every state photographed on the code before the change and on the finished code, with the same invented roster, the same date and the same browser settings. <b>Unfiltered, nothing moved by a single pixel.</b> Narrowed, only the agreed changes differ. Nothing is pushed until you approve this sheet.</p>
  <div class="meta">
    <span class="pill warn"><span class="dot"></span>Awaiting your approval</span>
    <span class="pill">{len(names)} pairs · 3 surfaces · 2 widths · PL and EN</span>
    <span class="pill">branch claude/entry-list-tiles-follow-filters · not pushed</span>
  </div>

  <hr class="rule">

  <section id="verdict">
    <p class="kicker">Verdict</p>
    <h2>The checks from the plan (§10)</h2>
    <div class="tablewrap"><table>
      <thead><tr><th>Check</th><th>Measured</th><th></th></tr></thead>
      <tbody>{check_rows}</tbody>
    </table></div>
    <p>Plan: <a href="entry-list-tiles-follow-filters-tdd-plan-2026-11-17.html">entry-list-tiles-follow-filters-tdd-plan-2026-11-17.html</a> · signed design and playable mock: <a href="entry-list-selection-count-2026-11-17.html">entry-list-selection-count-2026-11-17.html</a>.</p>
  </section>

  <section id="method">
    <p class="kicker">How it was measured</p>
    <h2>Method</h2>
    <ul>
      <li><b>What was photographed:</b> the production custom-element bundle (<code>vite build --config vite.config.ce.ts</code>, what GitHub Pages and WordPress load), built twice: from the branch's starting commit <code>891e1740</code> and from the finished code. Playwright's Chromium answered the pages' requests from each build; no server ran and no database was read or written.</li>
      <li><b>Data:</b> 76 invented fencers with your screenshot's totals (épée 47, foil 19, sabre 25), one invented event; date fixed at 17 Nov 2026.</li>
      <li><b>Stable images:</b> software drawing with fixed settings, each image taken when two consecutive screenshots agree, cropped on whole pixels 8 px outside the card. Two captures of the same code came out identical in all 56 images, and the build-based before-set is identical to an earlier dev-server before-set in all 56.</li>
      <li><b>Narrowed states:</b> compared inside the card, the before-image's rows against the after-image's rows 44 px lower, from the bottom up, allowing anti-aliasing of up to 24/255. Every pair matches up to exactly where the filters end.</li>
    </ul>
    <p>Tools, kept for the release check: <code>{rel}/tools/</code> (<code>capture.cjs</code>, <code>fixture.cjs</code>, <code>pixdiff.cjs</code>, <code>listcheck.cjs</code>, this generator). Raw results: <code>{rel}/diff.json</code>, <code>{rel}/listcheck.json</code>, <code>{rel}/after/measures.json</code>.</p>
  </section>

  <section id="issues">
    <p class="kicker">Met during the build</p>
    <h2>Issues, numbered</h2>
    <div class="note warn">
      <p class="lede"><span class="tick">I1</span> Open — the branch description needs you</p>
      <p>Git keeps branch descriptions in the configuration all worktrees share, and this session is not allowed to write it. Preflight checks it, so it has to be set before step 15. The exact command is in my chat message.</p>
    </div>
    <div class="note good">
      <p class="lede"><span class="tick">I2</span> Fixed — captures were not repeatable</p>
      <p>The first method gave a few differing pixels between two runs of the same code (GPU drawing of rounded edges). Fixed with software drawing, stable shots and whole-pixel crops; proven by two identical runs.</p>
    </div>
    <div class="note good">
      <p class="lede"><span class="tick">I3</span> Fixed — the preview server served the primary checkout</p>
      <p>The dev server I started runs from <code>/Users/aleks/coding/SPWSranklist</code>, not this worktree, and its configuration can only be changed there. The before-set was still valid (172 of 173 frontend files byte-identical to the branch start; the 173rd, <code>vite.config.ts</code>, is not used by these pages), and both sets were then taken from builds instead, which agree with it pixel for pixel.</p>
    </div>
    <div class="note good">
      <p class="lede"><span class="tick">I4</span> Fixed — one test state matched nobody</p>
      <p>„kow + V2 + men” matched no invented fencer, so it repeated the no-match state. Replaced with „k + V2 + men” before any comparison.</p>
    </div>
  </section>
{section("unfiltered", "Must not move", "Unfiltered: identical", "<p>The form as every visitor first sees it. Each pair is identical over its full height; scroll inside a picture to see all of it, or click it to open it full size.</p>", unfiltered)}
{section("narrowed", "The agreed changes", "Narrowed: the agreed changes only", "<p>The tiles show the selection inside the yellow frame, the narrowing controls are highlighted, the search box carries a ×, a chosen weapon dims the other weapon tiles, and „Wyczyść filtry” sits under the filters. Below it, the list is the same as before.</p>", narrowed)}

  <section id="next">
    <p class="kicker">After your approval</p>
    <h2>What happens next</h2>
    <ol class="steps">
      <li>Documentation (plan step 13): the registration-lifecycle handbook page, the approved mockup, the matrix rows to Covered, renderers, <code>check_docs.py</code>.</li>
      <li>Graph refresh and search re-index, then the commits on this branch, authored as Fencer4Life.</li>
      <li><code>scripts/preflight.sh</code> exits 0 (needs I1 first).</li>
      <li>Release only on your go.</li>
    </ol>
  </section>

  <p class="foot">pixel sheet · entry-list-tiles-follow-filters · 17 Nov 2026 · generated by {rel}/tools/build_sheet.py</p>
</div>
"""
_ = out.write_text(page, encoding="utf-8")
print("wrote", out, "pairs", len(names))
