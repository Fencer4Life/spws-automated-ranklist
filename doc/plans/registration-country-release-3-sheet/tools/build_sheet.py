"""Builds the FR-169 release 3 pixel sheet (usage: python3 build_sheet.py <repo dir>)."""

import json
import re
import sys
from pathlib import Path
from typing import Any

REPO = Path(sys.argv[1])
SRC = REPO / "doc/plans/i7-admin-reaches-remove-on-prod-pixel-sheet-2026-11-18.html"
OUT = REPO / "doc/plans/registration-country-release-3-pixel-sheet-2026-11-21.html"
D = "registration-country-release-3-sheet"
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
    head = re.sub(
        r"<title>.*?</title>",
        "<title>FR-169 · Country, release 3 · pixel sheet</title>",
        head,
        flags=re.S,
    )
    f2, f2n = same("form-two-before-runs.json")
    fb, fbn = same("form-before-after.json")
    lp, lpn = same("list-plain.json")
    walk = load("walk/walk-report.json")
    after = load("after-form/form-report.json")
    a = after[0]
    clist = load("after-clist/list-report.json")[0]
    filt = load("after-filter/filter-report.json")[0]
    errs = sum(
        len(r["errors"])
        for name in (
            "after-form/form-report.json",
            "after-clist/list-report.json",
            "after-filter/filter-report.json",
            "before-clist/list-report.json",
        )
        for r in load(name)
    )
    body = f"""<div class="wrap">

  <p class="eyebrow">Registration form · Country · Release 3 of 4 · Pixel sheet</p>
  <h1>A country chosen from a list, shown as a flag, filtered by its code</h1>
  <p class="dek">Captured on the WordPress calendar page body (<code>doc/wordpress/znajdz-zawody.html</code>) with the bundle built from main and from this branch, LOCAL standing in for PROD. <b>An entry list without countries is pixel-identical; the form gains one row and one consent line.</b> The new states are below for your approval, with the ADR-079 and ADR-080 amendment drafts. Nothing is pushed.</p>
  <div class="meta">
    <span class="pill warn"><span class="dot"></span>Awaiting your approval</span>
    <span class="pill">plan: registration-form-names-year-country-2026-11-21.html, rev 10, release 3</span>
    <span class="pill">FR-169 · RFCTRY.01–27</span>
  </div>

  <hr class="rule">

  <section>
    <p class="kicker">01 · Nothing else changed</p>
    <h2>Before against after</h2>
    <ul>
      <li><b>Noise floor first.</b> Two runs of main's build: {f2} of {f2n} form captures identical.</li>
      <li><b>The entry list as PROD holds it today</b> (no entry has a country yet), desktop 1280 and phone 375, PL and EN: <b>{lp} of {lpn} identical</b>. No flag column, no „Kraj” filter: the list looks exactly as before until someone picks a country.</li>
      <li><b>The form</b>: {fb} of {fbn} identical. The four identical captures are the name check. The others differ only from the new „Kraj” row down (the empty and typed form) and from the consent table down (the consent screen, its new line); above those the pixels are equal.</li>
      <li>No page errors in any run ({errs} across every report in <code>{D}/*/</code>).</li>
    </ul>
    <p class="mkcap">The empty form, main against the branch: the „Kraj” row, Polska chosen, sits below the birth year</p>
    {row([("before-form/form__desktop__pl__1-empty.png", "before · desktop · PL"), ("after-form/form__desktop__pl__1-empty.png", "after · desktop · PL"), ("before-form/form__phone__pl__1-empty.png", "before · phone · PL"), ("after-form/form__phone__pl__1-empty.png", "after · phone · PL")])}
    <p class="mkcap">The list with no countries: identical</p>
    {row([("before-list/list__desktop__pl.png", "before · desktop · PL"), ("after-list/list__desktop__pl.png", "after · desktop · PL"), ("after-list/list__phone__pl.png", "after · phone · PL")])}
  </section>

  <section>
    <p class="kicker">02 · The new states</p>
    <h2>For your approval</h2>
    <p class="mkcap">1 · the form opens with {a["default"]["box"]} ({a["default"]["code"]}) chosen; „wiel” typed finds {a["found"][0].splitlines()[0]} ({a["found"][0].splitlines()[1]}); also by English name, by code, and by Anglia, England, Great Britain, Holandia, Holland, Czech Republic</p>
    {row([("after-form/form__desktop__pl__5-country-list.png", "desktop · PL"), ("after-form/form__phone__pl__5-country-list.png", "phone · PL"), ("after-form/form__phone__en__5-country-list.png", "phone · EN")])}
    <p class="mkcap">2 · picked: the box reads the name, the code stands beside it</p>
    {row([("after-form/form__desktop__pl__6-country-picked.png", "desktop · PL"), ("after-form/form__phone__pl__6-country-picked.png", "phone · PL"), ("after-form/form__desktop__en__6-country-picked.png", "desktop · EN")])}
    <p class="mkcap">3 · consent v1.2: a row for the country (contract, Art. 6(1)(b)) and the line „Kraj jest widoczny na publicznej liście zgłoszonych.”</p>
    {row([("before-form/form__desktop__pl__4-consent.png", "before · desktop · PL"), ("after-form/form__desktop__pl__4-consent.png", "after · desktop · PL"), ("after-form/form__phone__en__4-consent.png", "after · phone · EN")])}
    <p class="mkcap">4 · the list with countries: the flag alone at the end of the line, 18 px; AIN, which has no flag, shows its letters (D1); an entry without a country shows nothing. Main's build shows the same rows without the column.</p>
    {row([("before-clist/list__desktop__pl.png", "before · desktop · PL"), ("after-clist/list__desktop__pl.png", "after · desktop · PL"), ("after-clist/list__phone__pl.png", "after · phone · PL"), ("after-clist/list__phone__en.png", "after · phone · EN")])}
    <p class="mkcap">5 · „Kraj” offers only the codes present ({", ".join(clist["filter"][1:])}); with „Szpada” it narrows to {", ".join(filt["names"])}</p>
    {row([("after-filter/filter__desktop__pl.png", "desktop · PL · Szpada + GER"), ("after-filter/filter__phone__pl.png", "phone · PL · two rows of two filters")])}
  </section>

  <section>
    <p class="kicker">03 · LOCAL walk-through</p>
    <h2>A British entrant registers and finds her flag</h2>
    <ol class="steps">
      <li>Typed „wiel” in the country box and picked from the list: the box reads {walk[0]["box"]}, code {walk[0]["code"]}.</li>
      <li>Name check, consent, submitted: „{walk[1]["confirmation"]}”. LOCAL stored ZZBROWN Emily, 1975, <code>txt_country</code> GBR, consent v1.2; the anonymous view returns GBR.</li>
      <li>On „Lista zgłoszonych” her row carries the flag labelled „{walk[2]["flag"]}”; „Kraj” offers {", ".join(walk[2]["filterChoices"][1:])}. Every entry was removed afterwards; LOCAL holds 0 entries.</li>
      <li><b>The organizer's file</b> takes <code>Nation</code> from the entry: GER for MÜLLER, POL for an entry with no country, with the same literal asserted by the TypeScript and Python exporters (RFCTRY.24–26) and the database function returning the column (RFCTRY.22).</li>
    </ol>
    {row([("walk/walk-1-country-list.png", "„wiel” typed"), ("walk/walk-2-consent.png", "consent v1.2"), ("walk/walk-3-list.png", "on the list")])}
  </section>

  <section>
    <p class="kicker">04 · What the release changes in the data</p>
    <h2>One new column, empty; one new code table</h2>
    <ul>
      <li><b>Nothing stored changes.</b> <code>tbl_registration.txt_country</code> is added empty; every existing entry stays without a country and shows as today.</li>
      <li><b>Every start file for an existing entry is byte-identical</b>: no country writes POL, as every file did before (RFCTRY.25).</li>
      <li><b>The code table</b> <code>tbl_fencing_country</code> holds 207 three-letter fencing codes, each with its flag's two-letter code or none (AIN, TPE); the column refers to it, so no other value can be stored. The table is read by no visitor: the form carries the same list, and a test compares the two (RFCTRY.01).</li>
      <li><b>The PROD → CERT copy</b> carries the country (RFCTRY.21).</li>
    </ul>
  </section>

  <section>
    <p class="kicker">05 · For your sign-off</p>
    <h2>ADR-079 and ADR-080 amendment drafts</h2>
    <div class="note accent"><p class="lede">ADR-079 · Amendment (2026-11-21, release 3) — the entrant declares a country; the list shows its flag</p>
      <p><b>Context.</b> Foreign veterans register for SPWS events, and the organizer's start files wrote every entrant as POL. The form had no country, so a German entrant reached the fencing software as Polish and had to be corrected by hand.</p>
      <p><b>Decision.</b> (1) The form asks for a country from a pick-list of the 207 fencing codes, Polska chosen at the start; it searches the Polish and English names, the code and a few common other names (Anglia, England, Great Britain, Holandia, Holland, Czech Republic); nothing else can be typed in. (2) The entry stores the three-letter code in <code>tbl_registration.txt_country</code>, which refers to <code>tbl_fencing_country</code>; an entry may have none. Every write path carries it: create, edit, the event's replacement and the PROD → CERT copy. (3) The entry list shows the flag alone at the end of the line, 18 px, labelled with the country's name; a code without a flag shows its letters in small type (D1); no country, nothing. The flag column and the „Kraj” filter appear only when an entry has a country. (4) „Kraj” lists the codes present, and works together with the other filters. (5) The consent text becomes v1.2: the country is processed under the contract (Art. 6(1)(b)) and is shown on the public list.</p>
      <p><b>Consequences.</b> A list without countries is unchanged to the pixel. Migrations <code>20261121000004</code> (the table and the column) and <code>20261121000005</code> (the write paths and the view). Tests: Vitest RFCTRY.01–17, 24–27 (<code>fencingCountries.test.ts</code>, <code>CountryPicker.test.ts</code>, <code>RegistrationForm.test.ts</code>, <code>EntryList.test.ts</code>, <code>api.registration.test.ts</code>); pgTAP RFCTRY.18–23 (<code>132_registration_country.sql</code>); pytest RFCTRY.21. FR-169.</p></div>
    <div class="note accent"><p class="lede">ADR-080 · Amendment (2026-11-21, release 3) — Nation comes from the entry</p>
      <p><b>Decision.</b> A Tireur's <code>Nation</code> is the entry's declared code; an entry without one writes POL, so the files of Polish entrants do not change by one byte. <code>Federation</code> stays POL: the organizer is SPWS. The TypeScript and Python exporters stay twins and assert the same mixed-list literal.</p>
      <p><b>Consequences.</b> <code>fn_ftl_export_entries</code> returns <code>txt_country</code>; the shared-link download and the Python export both write it. Tests RFCTRY.22, 24–26.</p></div>
  </section>

  <section>
    <p class="kicker">06 · Found on the way</p>
    <h2>Issues, each fixed here</h2>
    <ul>
      <li><b>„brit” found nothing.</b> Intl gives „Wielka Brytania” and "United Kingdom", so a search for Britain or England missed it. A short list of other names now covers GBR, NED and CZE (RFCTRY.05).</li>
      <li><b>A pick did not show its name</b> after the box was left: the chosen code was not bound back to the form. It is now (RFCTRY.04).</li>
      <li><b>The migration's safety lints</b> (postgrestools, a hard gate): the column is added last in its own file and the reference is added <code>NOT VALID</code>, so the table is not scanned under lock; the write paths are in a second file. Zero findings.</li>
      <li><b>LOCAL only:</b> while the migration was being shaped, a column drop with CASCADE removed the entry-list view and its grants on LOCAL. Both migrations were re-applied and the grants restored to match CERT; nothing outside LOCAL was touched, and the released migrations contain no drop of the column.</li>
      <li><b>The capture tool's own query</b> named <code>txt_country</code> bare, which is ambiguous against the event's own country column; it now names the table.</li>
    </ul>
  </section>

  <p class="foot">pixel sheet · FR-169 release 3 · 21 Nov 2026 · tools: {D}/tools/proof.cjs (form · list · filter · walk), seed-list.sql, diff.py, build_sheet.py</p>
</div>
"""
    _ = OUT.write_text(head + body, encoding="utf-8")
    print("ok", f2, f2n, fb, fbn, lp, lpn, errs)


main()
