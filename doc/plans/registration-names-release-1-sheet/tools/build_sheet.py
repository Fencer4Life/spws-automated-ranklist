"""Builds the FR-167 release 1 pixel sheet (usage: python3 build_sheet.py <repo dir>)."""

import json
import re
import sys
from pathlib import Path
from typing import Any

REPO = Path(sys.argv[1])
SRC = REPO / "doc/plans/i7-admin-reaches-remove-on-prod-pixel-sheet-2026-11-18.html"
OUT = REPO / "doc/plans/registration-names-release-1-pixel-sheet-2026-11-21.html"
D = "registration-names-release-1-sheet"
SHEET = REPO / "doc/plans" / D


def load(name: str) -> list[dict[str, Any]]:
    data: list[dict[str, Any]] = json.loads((SHEET / name).read_text(encoding="utf-8"))
    return data


def same(name: str) -> tuple[int, int]:
    rows = load(name)
    return sum(1 for r in rows if r["diff"] == 0), len(rows)


def fig(path: str, cap: str, alt: str) -> str:
    return (
        f'<figure class="shot"><a href="{D}/{path}"><img src="{D}/{path}" alt="{alt}" loading="lazy"></a>'
        f"<figcaption>{cap}</figcaption></figure>"
    )


def row(items: list[tuple[str, str, str]]) -> str:
    return '<div class="shots">' + "".join(fig(*i) for i in items) + "</div>"


def pair(folder_a: str, folder_b: str, name: str, what: str) -> str:
    return row([
        (f"{folder_a}/{name}", f"before · {what}", f"Before: {what}"),
        (f"{folder_b}/{name}", f"after · {what}", f"After: {what}"),
    ])


def main() -> None:
    head = SRC.read_text(encoding="utf-8").split('<div class="wrap">')[0]
    head = re.sub(r"<title>.*?</title>", "<title>FR-167 · Names, release 1 · pixel sheet</title>", head, flags=re.S)
    f2, f2n = same("form-two-before-runs.json")
    l2, l2n = same("list-plain-two-before-runs.json")
    fb, fbn = same("form-before-after.json")
    lb, lbn = same("list-plain-before-after.json")
    walk = load("walk/walk-report.json")
    body = f"""<div class="wrap">

  <p class="eyebrow">Registration form · Names · Release 1 of 4 · Pixel sheet</p>
  <h1>Names in one form, titles apart, reversed fields asked about</h1>
  <p class="dek">Captured on the WordPress calendar page body (<code>doc/wordpress/znajdz-zawody.html</code>) with the bundle built from main and from this branch, LOCAL standing in for PROD. <b>Everything that should not change is pixel-identical; the four new states are below for your approval</b>, with the two ADR amendment drafts. Nothing is pushed.</p>
  <div class="meta">
    <span class="pill warn"><span class="dot"></span>Awaiting your approval</span>
    <span class="pill">plan: registration-form-names-year-country-2026-11-21.html, rev 10, release 1</span>
    <span class="pill">FR-167 · RFNAME.01–27</span>
  </div>

  <hr class="rule">

  <section>
    <p class="kicker">01 · Nothing else changed</p>
    <h2>Before against after</h2>
    <ul>
      <li><b>Noise floor first.</b> Two runs of main's build: form {f2} of {f2n} identical, entry list {l2} of {l2n}.</li>
      <li><b>The form</b>, empty and with a name typed, desktop 1280 and phone 375, PL and EN: <b>{fb} of {fbn} captures identical</b> — every one except the newcomer's name check, which differs only in its button row, where „Popraw” is added (box 246–286 px on desktop).</li>
      <li><b>The entry list without a title</b>, desktop and phone, PL and EN: <b>{lb} of {lbn} identical</b>.</li>
      <li><b>The entry list with a titled entry</b> differs only where it should: „Dr. ZZVERESS” moves from the top of the list to its place under V.</li>
      <li>No page errors in any run (<code>{D}/*/form-report.json</code>, <code>list-report.json</code>).</li>
    </ul>
  </section>

  <section>
    <p class="kicker">02 · The new states</p>
    <h2>For your approval</h2>
    <p class="mkcap">1 · the newcomer's name check: „Popraw” added beside the two existing buttons</p>
    {pair("before-form", "after-form", "form__desktop__pl__3-name-check.png", "desktop · PL")}
    {pair("before-form", "after-form", "form__phone__pl__3-name-check.png", "phone · PL")}
    <p class="mkcap">2 · a title written on leaving the box: „dr kovács” + „péter” → „Dr. KOVÁCS” + „Péter”</p>
    {row([("after-form/form__desktop__pl__4-title.png", "desktop · PL", "Title written, desktop"), ("after-form/form__phone__en__4-title.png", "phone · EN", "Title written, phone")])}
    <p class="mkcap">3 · the reversed-fields question: „annalisa” + „zzbellandi”</p>
    {row([("after-form/form__desktop__pl__5-reversed.png", "desktop · PL", "Reversed question, desktop"), ("after-form/form__phone__pl__5-reversed.png", "phone · PL", "Reversed question, phone"), ("after-form/form__phone__en__5-reversed.png", "phone · EN", "Reversed question, English")])}
    <p class="mkcap">4 · the entry list: a titled entry stands under its surname</p>
    {pair("before-list-titled", "after-list-titled", "list__desktop__pl.png", "desktop · PL")}
    {pair("before-list-titled", "after-list-titled", "list__phone__pl.png", "phone · PL")}
  </section>

  <section>
    <p class="kicker">03 · LOCAL walk-through</p>
    <h2>A reversed, titled newcomer, from the first box to the entry list</h2>
    <ol class="steps">
      <li>Typed „orsolya” in the surname box and „zzszabo dr.” in the given-name box. The form asked „{walk[0]["heading"]}” and proposed „{walk[0]["proposed"]}”.</li>
      <li>After „Tak, zamień” the lookup ran again on the swapped pair; as a newcomer she read her name back: „{walk[1]["name"]}”.</li>
      <li>Confirmed and submitted: „{walk[2]["confirmation"]}”. LOCAL stored and listed „Dr. ZZSZABO Orsolya”. The entry was removed afterwards; LOCAL holds 0 entries.</li>
    </ol>
    {row([("walk/walk-1-question.png", "the question", "Walk: question"), ("walk/walk-2-read-back.png", "the read-back", "Walk: read-back"), ("walk/walk-3-done.png", "submitted", "Walk: submitted")])}
  </section>

  <section>
    <p class="kicker">04 · Measured on PROD and CERT, read-only</p>
    <h2>What the release changes in the data</h2>
    <ul>
      <li><b>The one-off rewrite</b> (<code>fn_registration_realign_names</code>, run by the migration) changes <b>12 of PROD's 66 newcomers' entries</b>: 10 given names into title case, and 2 titles moved in front of the surname. On CERT it changes 1 entry. No two entries collide on the unmatched-entry key. Linked entries are not touched.</li>
      <li><b>The four reversed entries already on PROD stay reversed.</b> The question works at entry; correcting stored rows is the administrator's edit in release 4.</li>
      <li><b>The EVF names</b>: 1,392 given names, read on 21 Nov 2026, loaded by the second migration; the monthly job adds new ones.</li>
      <li><b>On the old cached page</b> (10 minutes after a release), a newcomer's name is still written in the name form by the database; only the question and „Popraw” are missing until the page reloads.</li>
    </ul>
  </section>

  <section>
    <p class="kicker">05 · For your sign-off</p>
    <h2>ADR amendment drafts</h2>
    <div class="note accent"><p class="lede">ADR-079 · Amendment (2026-11-21) — a declared name is stored in one form, a title is kept apart, reversed fields are asked about</p>
      <p><b>Context.</b> On 21 Nov 2026 PROD held 193 entries. Eleven newcomers' given names were not in the form the organizer's files use, two carried a title the Austrian and Hungarian way, and four newcomers had typed their given name into the surname box. The 2026-10-03 amendment kept an unlinked registration's name „as typed”.</p>
      <p><b>Decision.</b> (1) A newcomer's name is stored in one form: surname in capitals, given name in title case by the rule the organizer's files use, spaces trimmed and collapsed. The letters remain the fencer's; only case and spacing are written. This replaces „as typed” in the 2026-10-03 amendment for unlinked registrations. The form writes it when a box is left and on „Dalej”; the trigger writes it on every write of a newcomer's row. (2) A title (dr, ddr, prof, ing, mag, mgr, dipl-ing, doc) at either end of either box is moved in front of the surname in one written form and is ignored by every name comparison. (3) When nobody matches and the surname box holds a known given name while the given-name box does not, the form asks once whether the fields are reversed; either answer is believed. Known given names are the fencer table's, read live, and the EVF ranking's, held in <code>tbl_common_given_name</code>, given names only, insert-only, refreshed monthly. A visitor receives two yes/no answers and never the lists. (4) The newcomer's name check offers „Popraw”; the name boxes carry autofill marks.</p>
      <p><b>Not done, on evidence.</b> A spelling question: on the EVF ranking it would wrongly ask 5 to 9 in 100 correctly spelled foreign fencers. A hand-written names list: it changed no answer on PROD's 193 entries.</p>
      <p><b>Consequences.</b> The entry list shows one form for every newcomer; a titled fencer stands under the surname; a fencer we hold is unaffected, since a linked entry takes the roster's name. FR-167; RFNAME.01–27.</p></div>
    <div class="note accent"><p class="lede">ADR-080 · Amendment (2026-11-21) — the surname goes into the file without its title</p>
      <p><b>Decision.</b> <code>toCanonicalName</code> (TypeScript) and <code>to_canonical_name</code> (Python) leave a title written with the surname out of the file's surname, so the organizer's software sorts and matches the fencer by the surname. Every name without a title is written exactly as before, byte for byte. Tests: RFNAME.27 in both languages.</p></div>
  </section>

  <section>
    <p class="kicker">06 · Found on the way</p>
    <h2>Issues</h2>
    <ul>
      <li><b>The read-back already existed.</b> The newcomer's screen already showed the name „as on the entry list” with a swap button, so the plan's read-back is that screen plus „Popraw”; the reversed-fields question is a variant of the same screen.</li>
      <li><b>I13 · the documentation search</b> failed only because Docker was down when this session started; its configuration and container are correct now. Reconnecting <code>spws-docs</code> through <code>/mcp</code> restores it.</li>
      <li><b>I16 fixed</b> (autofill marks). <b>I17 fixed</b>: the EVF client gained a public ranking call, and the ranking-positions tool uses it.</li>
      <li><b>Real names out of the repository.</b> My first tests quoted real entrants from PROD as examples of mistakes. They now use invented names (VERESS, SZABÓ, BELLANDI, MARLOW); the earlier tests are as they were.</li>
      <li><b>Not captured:</b> the signed-in administrator's list. Its order and search use the same code as the visitor's, pinned by RFNAME.09.</li>
    </ul>
  </section>

  <p class="foot">pixel sheet · FR-167 release 1 · 21 Nov 2026 · tools: {D}/tools/proof.cjs (form · list · walk), diff.py, seed-list.sql, build_sheet.py</p>
</div>
"""
    _ = OUT.write_text(head + body, encoding="utf-8")
    print("ok", f2, f2n, l2, l2n, fb, fbn, lb, lbn)


main()
