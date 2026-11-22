"""Builds doc/plans/registration-name-list-sheet-2026-11-22.html from the captures (FR-173).

usage: python build_sheet.py <repo> <runs dir>
The runs dir holds before-1, before-2, after, dialog-before, dialog-after and the diff reports
(written by reg.cjs, release 4's proof.cjs and diff.py). The captures used on the page are copied
next to it, under registration-name-list-sheet/.
"""

import html
import json
import re
import shutil
import sys
from pathlib import Path

REPO, RUNS = Path(sys.argv[1]), Path(sys.argv[2])
PLANS = REPO / "doc/plans"
SHEET = PLANS / "registration-name-list-sheet"
OUT = PLANS / "registration-name-list-sheet-2026-11-22.html"
TEMPLATE = PLANS / "registration-admin-edit-release-4-pixel-sheet-2026-11-21.html"

for sub in ("before", "after", "dialog-before", "dialog-after"):
    (SHEET / sub).mkdir(parents=True, exist_ok=True)


def take(src_dir: str, name: str, dst: str) -> str:
    shutil.copyfile(RUNS / src_dir / name, SHEET / dst / name)
    return f"registration-name-list-sheet/{dst}/{name}"


def img(src: str, alt: str) -> str:
    return f'<figure style="margin:0"><img src="{src}" alt="{html.escape(alt)}" loading="lazy" style="width:100%;border:1px solid rgba(128,128,128,.35);border-radius:6px"><figcaption style="font-size:12px;opacity:.75">{html.escape(alt)}</figcaption></figure>'


def pair(a: str, b: str) -> str:
    return f'<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:10px 0 22px">{a}{b}</div>'


two = json.loads((RUNS / "two-before-runs.json").read_text(encoding="utf-8"))
same = json.loads((RUNS / "before-after.json").read_text(encoding="utf-8"))
dialog = json.loads((RUNS / "dialog-before-after.json").read_text(encoding="utf-8"))
after = json.loads((RUNS / "after/report.json").read_text(encoding="utf-8"))
for r in (*two, *same):
    for k in ("name",):
        assert r[k]

rows = "".join(
    f"<tr><td>{html.escape(r['name'])}</td><td>{t['diff']}</td><td>{r['diff']}</td></tr>"
    for r, t in zip(same, two, strict=True)
)
drows = "".join(f"<tr><td>{html.escape(r['name'])}</td><td>{r['diff']}</td><td>{r['box']}</td></tr>" for r in dialog)

unchanged = ""
for state, label in (("1-empty", "the empty form"), ("2-typed", "the form filled by typing")):
    for w in ("desktop", "phone"):
        n = f"{state}__{w}__pl.png"
        unchanged += f"<h3>{label} · {w} · PL</h3>" + pair(img(take("before-1", n, "before"), f"before · {w}"), img(take("after", n, "after"), f"after · {w}"))
        e = f"{state}__{w}__en.png"
        take("before-1", e, "before")
        take("after", e, "after")

new = ""
for state, label in (("3-list", "the list open after „NOW”"), ("4-picked", "right after picking NOWAK Anna")):
    for lang in ("pl", "en"):
        a, b = f"{state}__desktop__{lang}.png", f"{state}__phone__{lang}.png"
        new += f"<h3>{label} · {lang.upper()}</h3>" + pair(img(take("after", a, "after"), f"desktop · {lang.upper()}"), img(take("after", b, "after"), f"phone · {lang.upper()}"))

dlg = ""
for name in ("dialog__desktop__pl__1-newcomer.png", "dialog__desktop__pl__3-linked.png", "dialog__phone__pl__3-linked.png"):
    dlg += f"<h3>{name.replace('.png', '')}</h3>" + pair(img(take("dialog-before", name, "dialog-before"), "before"), img(take("dialog-after", name, "dialog-after"), "after"))
for r in dialog:
    take("dialog-before", r["name"], "dialog-before")
    take("dialog-after", r["name"], "dialog-after")

pick = after[0]["afterPick"]
facts = "".join(
    f"<tr><td>{html.escape(r['tag'])}</td><td>{len(r['rows'])}</td><td>{r['afterPick']['birthYear'] or '(empty)'}</td>"
    f"<td>{r['afterPick']['focus']}</td><td>{html.escape(r['afterPick']['decade'])}</td><td>{r['afterPick']['weaponsTicked']}</td>"
    f"<td>{r['surnameAutocomplete']}</td><td>{len(r['errors'])}</td></tr>"
    for r in after
)

head = TEMPLATE.read_text(encoding="utf-8").split('<div class="wrap">')[0]
head = re.sub(r"<title>.*?</title>", "<title>Name list under SURNAME · picture sheet</title>", head, flags=re.S)
n_same = sum(1 for r in same if r["diff"] == 0)
n_two = sum(1 for r in two if r["diff"] == 0)
body = f"""<div class="wrap">
  <p class="eyebrow">Registration form · Name list under SURNAME (FR-173) · Picture sheet</p>
  <h1>Before and after, for your approval before any push</h1>
  <p class="dek">Two builds of the page, main and this branch, captured on LOCAL with software drawing. <b>The two runs of the before build agree on {n_two} of {len(two)} pictures, and the after build is identical to before on {n_same} of {len(same)}</b>: the form looks exactly as it does today until someone types two letters in SURNAME. The list and the form after a pick are new. The administrator's dialog gains one line. Every name in the list is invented and served by the capture tool; no real person's name is on this page.</p>
  <div class="meta"><span class="pill warn"><span class="dot"></span>Awaits your approval in chat</span><span class="pill">LOCAL · software raster</span></div>
  <hr class="rule">

  <section>
    <p class="kicker">01 · Unchanged</p>
    <h2>The form as everyone sees it today</h2>
    <table><thead><tr><th>Picture</th><th>Two before runs: differing pixels</th><th>Before vs after: differing pixels</th></tr></thead><tbody>{rows}</tbody></table>
    {unchanged}
  </section>

  <section>
    <p class="kicker">02 · New</p>
    <h2>The list, and the form after a pick</h2>
    <table><thead><tr><th>Capture</th><th>Rows</th><th>Year after the pick</th><th>Focus</th><th>Grid opens on</th><th>Weapons ticked</th><th>Browser list on SURNAME</th><th>Page errors</th></tr></thead><tbody>{facts}</tbody></table>
    <p>After the pick: {html.escape(pick['surname'])} {html.escape(pick['firstName'])}, gender {pick['gender']}, club „{html.escape(pick['club'])}”; <b>the year stays empty</b> and the grid opens on the decade of her category (V1 in 2026/27).</p>
    {new}
  </section>

  <section>
    <p class="kicker">03 · The administrator's dialog</p>
    <h2>One line more: how the name arrived</h2>
    <p>Captured with release 4's tool on LOCAL's throwaway ZZ entries (seeded and removed by the run). The dialog is one line taller, so it sits a few pixels higher; every difference is inside the dialog's box, and the page behind it is unchanged.</p>
    <table><thead><tr><th>Picture</th><th>Differing pixels</th><th>Box</th></tr></thead><tbody>{drows}</tbody></table>
    {dlg}
  </section>
  <p class="foot">picture sheet · FR-173 · 22 Nov 2026 · tools in registration-name-list-sheet/tools (reg.cjs, build_sheet.py) and release 4's proof.cjs and diff.py · after build = branch claude/registration-name-list-under-surname, before = main fbfe20f7</p>
</div>
"""
OUT.write_text(head + body, encoding="utf-8")
print(OUT)
