"""Builds the FR-168 release 2 pixel sheet (usage: python3 build_sheet.py <repo dir>)."""

import json
import re
import sys
from pathlib import Path
from typing import Any

REPO = Path(sys.argv[1])
SRC = REPO / "doc/plans/i7-admin-reaches-remove-on-prod-pixel-sheet-2026-11-18.html"
OUT = REPO / "doc/plans/registration-birth-year-release-2-pixel-sheet-2026-11-21.html"
D = "registration-birth-year-release-2-sheet"
SHEET = REPO / "doc/plans" / D


def load(name: str) -> Any:
    return json.loads((SHEET / name).read_text(encoding="utf-8"))


def same(name: str) -> tuple[int, int]:
    rows: list[dict[str, Any]] = load(name)
    return sum(1 for r in rows if r["diff"] == 0), len(rows)


def fig(path: str, cap: str) -> str:
    return (
        f'<figure class="shot"><a href="{D}/{path}"><img src="{D}/{path}" alt="{cap}" loading="lazy"></a>'
        f"<figcaption>{cap}</figcaption></figure>"
    )


def row(items: list[tuple[str, str]]) -> str:
    return '<div class="shots">' + "".join(fig(*i) for i in items) + "</div>"


def main() -> None:
    head = SRC.read_text(encoding="utf-8").split('<div class="wrap">')[0]
    head = re.sub(r"<title>.*?</title>", "<title>FR-168 · Birth year, release 2 · pixel sheet</title>", head, flags=re.S)
    f2, f2n = same("form-two-before-runs.json")
    fb, fbn = same("form-before-after.json")
    walk = load("walk/walk-report.json")
    after = load("after-form/form-report.json")
    a = after[0]
    body = f"""<div class="wrap">

  <p class="eyebrow">Registration form · Birth year · Release 2 of 4 · Pixel sheet</p>
  <h1>A birth year chosen from the years that give a category</h1>
  <p class="dek">Captured on the WordPress calendar page body (<code>doc/wordpress/znajdz-zawody.html</code>) with the bundle built from main and from this branch, LOCAL standing in for PROD. <b>The form is unchanged until the year box is touched; the new states are below for your approval</b>, with the ADR-079 amendment draft. Nothing is pushed.</p>
  <div class="meta">
    <span class="pill warn"><span class="dot"></span>Awaiting your approval</span>
    <span class="pill">plan: registration-form-names-year-country-2026-11-21.html, rev 10, release 2</span>
    <span class="pill">FR-168 · RFYEAR.01–10</span>
  </div>

  <hr class="rule">

  <section>
    <p class="kicker">01 · Nothing else changed</p>
    <h2>Before against after</h2>
    <ul>
      <li><b>Noise floor first.</b> Two runs of main's build: {f2} of {f2n} captures identical.</li>
      <li><b>The form</b>, empty, with a name typed, and at a newcomer's name check, desktop 1280 and phone 375, PL and EN: <b>{fb} of {fbn} identical</b>.</li>
      <li><b>The two that differ</b> are desktop „name typed” (PL and EN), by at most <b>1 of 255</b> in one colour channel, on anti-aliased edges below the year row: 2,332 and 2,055 pixels, none visible. The empty form is identical on both builds, so nothing moved; the difference repeats run after run, so it is how the new box repaints after typing, not noise. The amplified difference is shown below.</li>
      <li>No page errors in any run (<code>{D}/*/form-report.json</code>).</li>
    </ul>
    {row([("before-form/form__desktop__pl__2-typed.png", "before · desktop · PL · name typed"), ("after-form/form__desktop__pl__2-typed.png", "after · desktop · PL · name typed"), ("diff/desktop-pl-2-typed-amplified.png", "difference, every changed pixel white (max 1/255)")])}
  </section>

  <section>
    <p class="kicker">02 · The new states</p>
    <h2>For your approval</h2>
    <p class="mkcap">1 · the box focused: the grid opens on the decade of a 50-year-old ({a["grid"]["decade"]})</p>
    {row([("after-form/form__desktop__pl__4-grid.png", "desktop · PL"), ("after-form/form__phone__pl__4-grid.png", "phone · PL"), ("after-form/form__phone__en__4-grid.png", "phone · EN")])}
    <p class="mkcap">2 · „47” typed and the box left: „{a["refused"]["line"]}”, and „Dalej” stays off</p>
    {row([("after-form/form__desktop__pl__5-refused.png", "desktop · PL"), ("after-form/form__phone__pl__5-refused.png", "phone · PL"), ("after-form/form__desktop__en__5-refused.png", "desktop · EN")])}
    <p class="mkcap">3 · 1995 in the box: the grid opens on its decade ({a["picked"]["decade"]}), 1998 and 1999 greyed out, category {a["picked"]["category"]}</p>
    {row([("after-form/form__desktop__pl__6-year-in-grid.png", "desktop · PL"), ("after-form/form__phone__pl__6-year-in-grid.png", "phone · PL")])}
  </section>

  <section>
    <p class="kicker">02b · It moves with the season and the year</p>
    <h2>Nothing is a fixed year: five years on, every number changes</h2>
    <p>The youngest year is the event's season's later year minus 30, read from the season; the oldest is today's year minus 120, read from the clock. The form and the database compute both every time. Tests now pin it five years on, both halves:</p>
    <table><thead><tr><th>Season, opened on</th><th>Range</th><th>Grid opens on</th><th>V0 edge</th><th>First refused</th></tr></thead><tbody>
      <tr><td>2026/27, 21 Nov 2026</td><td>1906 … 1997</td><td>1970 – 1979</td><td>1997</td><td>1998</td></tr>
      <tr><td>2031/32, 21 Nov 2031</td><td>1911 … 2002</td><td>1980 – 1989</td><td>2002</td><td>2003</td></tr>
    </tbody></table>
    <ul>
      <li><b>The form</b> (RFYEAR.01, Vitest, the clock set to 21 Nov 2031 and a 2031/32 event): range 1911 … 2002, the grid on the 1980s, 2002 gives V0, 2003 greyed out, 1910 refused with „1911–2002”.</li>
      <li><b>The database</b> (RFYEAR.07, pgTAP): <code>fn_registration_birth_year_bounds(2032, 2031-11-21)</code> returns 1911 and 2002; the table rule passes it today's date, checked against <code>current_date</code>; a real 2031/32 event accepts 2002 and refuses 2003.</li>
    </ul>
  </section>

  <section>
    <p class="kicker">03 · LOCAL walk-through</p>
    <h2>A newcomer picks her year from the grid and registers</h2>
    <ol class="steps">
      <li>Focused the year box and paged twice: {walk[0]["decade"]}; greyed out: {", ".join(walk[0]["disabled"])}.</li>
      <li>Tapped 1995: the box reads {walk[1]["box"]} and the category {walk[1]["category"]}.</li>
      <li>Name check, consent, submitted: „{walk[2]["confirmation"]}”. LOCAL stored ZZROKOWSKA Ewa, 1995, shown as V0 on the public view; the entry was removed afterwards, LOCAL holds 0 entries.</li>
      <li><b>An old cached page</b> sending „47” the way the page sends it (an anon call to LOCAL's API) gets <code>23514 REG_BIRTH_YEAR_OUT_OF_RANGE: 47 outside 1906–1997</code>; the new form shows that refusal as its range line (RFYEAR.06).</li>
    </ol>
    {row([("walk/walk-1-grid.png", "the grid, paged"), ("walk/walk-2-picked.png", "1995 picked, V0"), ("walk/walk-3-done.png", "submitted")])}
  </section>

  <section>
    <p class="kicker">04 · Measured on PROD and CERT, read-only</p>
    <h2>What the release changes in the data</h2>
    <ul>
      <li><b>Nothing stored changes.</b> No entry on PROD (195) or CERT (90) is outside the range: the youngest year is 1996, the oldest 1947, every event in 2026/27.</li>
      <li><b>The rule judges a write, never a stored row.</b> It fires when the year or the event is written, so an entry of a past season is never re-judged.</li>
    </ul>
  </section>

  <section>
    <p class="kicker">05 · For your sign-off</p>
    <h2>ADR-079 amendment draft</h2>
    <div class="note accent"><p class="lede">ADR-079 · Amendment (2026-11-21, release 2) — a declared birth year lies inside its season's range</p>
      <p><b>Context.</b> On 21 Nov 2026 PROD held two impossible declared years, 47 (the entrant typed her age) and −1972 (a minus sign the number box accepted), both shown as V4; they were corrected by hand the same day. The box accepted any integer, and nothing below the form refused one.</p>
      <p><b>Decision.</b> (1) A declared birth year lies between this year minus 120 and the event's season's later year minus 30, the V0 rule itself: 1906–1997 for 2026/27. (2) The form offers only those years: focusing or clicking the box opens a decade grid on the decade of the year in the box, else of a 50-year-old; it pages by decade as far as the range reaches, greys out years outside it, shows the range and the chosen year's category, and keeps focus in the box while pressed. Typing still works, digits only, four at most, and closes the grid; a year outside the range shows a line under the box naming the range, and „Dalej” stays off. (3) Both edges are computed on every use, never stored or fixed: the form from the season and the clock, the table from <code>fn_registration_birth_year_bounds(season end year, today)</code>; 2031/32 in 2031 gives 1911–2002. (4) The table refuses any other year on every write path, the visitor's create and edit, an administrator's direct update and the PROD → CERT copy (<code>trg_registration_birth_year_range</code>, migration <code>20261121000003</code>), naming the range in its refusal, which the form shows as the same line.</p>
      <p><b>Consequences.</b> An impossible year can no longer reach the entry list or the organizer's files. Stored rows are not re-judged; on release none is outside the range. Two older tests change their fixtures: 75.15 declares 1910 instead of 1902, and 76.9 writes its below-V0 row with the rule switched off, because the export must still leave such a stored row out. Tests: Vitest RFYEAR.01–06 (<code>birthYearRange.test.ts</code>, <code>RegistrationForm.test.ts</code>), pgTAP RFYEAR.07–10 (<code>131_registration_birth_year.sql</code>), each range pinned for 2026/27 and five years on. FR-168.</p></div>
  </section>

  <section>
    <p class="kicker">06 · Found on the way</p>
    <h2>Issues, each fixed here, test first</h2>
    <ul>
      <li><b>I22 · the grid covered „Szpada”.</b> After a year was typed the grid stayed open over the weapon boxes, so the next click picked a year instead. Typing now closes it; a click on the box or Escape reopens or closes it (RFYEAR.04).</li>
      <li><b>I23 · paging to the last decade closed the grid.</b> Chrome blurs a pager it disables, and Safari never focuses a pressed button, so either closed the grid mid-choice. A press on the grid now keeps focus in the box (RFYEAR.05).</li>
      <li><b>Two older fixtures</b> held years the rule refuses (75.15's 1902, 76.9's below-V0 1995); both are changed as the ADR draft says, keeping what each test proves.</li>
      <li><b>The box's look:</b> Svelte scopes styles per component, so the new year box carries the form's own input and label rules; the empty form is pixel-identical.</li>
    </ul>
  </section>

  <p class="foot">pixel sheet · FR-168 release 2 · 21 Nov 2026 · tools: {D}/tools/proof.cjs (form · walk), diff.py, build_sheet.py</p>
</div>
"""
    _ = OUT.write_text(head + body, encoding="utf-8")
    print("ok", f2, f2n, fb, fbn)


main()
