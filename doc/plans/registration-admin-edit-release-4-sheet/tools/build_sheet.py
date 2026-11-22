"""Builds the FR-170 release 4 pixel sheet (usage: python3 build_sheet.py <repo dir>)."""

import json
import re
import sys
from pathlib import Path
from typing import Any

REPO = Path(sys.argv[1])
SRC = REPO / "doc/plans/i7-admin-reaches-remove-on-prod-pixel-sheet-2026-11-18.html"
OUT = REPO / "doc/plans/registration-admin-edit-release-4-pixel-sheet-2026-11-21.html"
D = "registration-admin-edit-release-4-sheet"
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
        "<title>FR-170 · Administrator's edit, release 4 · pixel sheet</title>",
        head,
        flags=re.S,
    )
    v2, v2n = same("visitor-two-before-runs.json")
    vb, vbn = same("visitor-before-after.json")
    a2, a2n = same("admin-two-before-runs.json")
    ab, abn = same("admin-before-after.json")
    adm_before = load("before-admin/admin-report.json")[0]
    adm_after = load("after-admin/admin-report.json")[0]
    dlg = load("after-dialog/dialog-report.json")
    d0 = dlg[0]
    walk = load("walk/walk-report.json")
    errs = sum(
        len(r.get("errors", []))
        for name in (
            "after-visitor/visitor-report.json",
            "after-admin/admin-report.json",
            "after-dialog/dialog-report.json",
            "walk/walk-report.json",
            "before-admin/admin-report.json",
        )
        for r in load(name)
    )
    body = f"""<div class="wrap">

  <p class="eyebrow">Registration form · Administrator's edit · Release 4 of 4 · Pixel sheet, amended 22 Nov</p>
  <h1>A signed-in administrator edits an entry, and a linked entry's correction reaches the roster</h1>
  <p class="dek">Captured on the WordPress page bodies (<code>doc/wordpress/ranking.html</code> signed in on <code>/ranking/?admin=1</code>, and <code>znajdz-zawody.html</code> as a visitor), with bundles built from main and from this branch and LOCAL standing in for PROD. <b>You approved this sheet on 22 Nov: I25 A, and R1–R3 A for your addition.</b> Both are now built test-first and captured again. <b>A visitor's list changes in one place only: a phone name too long for its row now ends in „…”.</b> The signed-in list gains „Edytuj”, the ≠ mark, and on a phone its own line for the actions. A save on a linked entry now writes the fencer's year, gender and country to the roster in the same transaction. Nothing is pushed.</p>
  <div class="meta">
    <span class="pill warn"><span class="dot"></span>Awaiting your approval of the amended captures</span>
    <span class="pill">plan: registration-form-names-year-country-2026-11-21.html, rev 10, release 4</span>
    <span class="pill">FR-170 · RFADM.01–25 · D2 A, D5 A · I25 A · R1–R3 A</span>
  </div>

  <hr class="rule">

  <section>
    <p class="kicker">01 · Nothing else changed</p>
    <h2>Before against after</h2>
    <ul>
      <li><b>Noise floor first.</b> Two runs of main's build were identical: the visitor's list {v2} of {v2n}, the signed-in list {a2} of {a2n}.</li>
      <li><b>A visitor's list</b> (four throwaway entries on Łomianki), at desktop 1280 and phone 375, in PL and EN: <b>{vb} of {vbn} identical</b>. The two phone captures differ only in a 14 × 12 px box: the end of ZZVAN DER BRUGGEN-SCHOONHOVEN, which main cuts mid-letter and the branch ends with „…” (I25). No „Edytuj” and no ≠ appear, and a visitor's list reads no entry details (RFADM.01).</li>
      <li><b>The signed-in list</b>: {ab} of {abn} identical, as expected, because every difference lies in the action column, plus on a phone the line that column now takes. Main shows {adm_before["removeButtons"]} „Usuń”. The branch shows {adm_after["editButtons"]} „Edytuj” beside {adm_after["removeButtons"]} „Usuń”, and ≠ on {", ".join(adm_after["marks"])} only.</li>
      <li><b>Measured on the phone, every row:</b> each name cell is one where the browser draws „…”; the one name too long is cut with „…”; the category, weapon and flag stay on the name's line; and a signed-in row's actions sit on the line below (<code>rows</code> in <code>after-*/…-report.json</code>).</li>
      <li>No page errors in any run ({errs} across every report in <code>{D}/*/</code>).</li>
    </ul>
    <p class="mkcap">The signed-in list, main against the branch</p>
    {row([("before-admin/admin__desktop__pl.png", "before · desktop · PL"), ("after-admin/admin__desktop__pl.png", "after · desktop · PL"), ("before-admin/admin__phone__pl.png", "before · phone · PL"), ("after-admin/admin__phone__pl.png", "after · phone · PL")])}
    <p class="mkcap">A visitor's list: the phone's long name ends in „…”, nothing else moves</p>
    {row([("before-visitor/visitor__phone__pl.png", "before · phone · PL"), ("after-visitor/visitor__phone__pl.png", "after · phone · PL"), ("after-visitor/visitor__desktop__pl.png", "after · desktop · PL (identical)")])}
  </section>

  <section>
    <p class="kicker">02 · The dialog</p>
    <h2>Its states</h2>
    <p class="mkcap">1 · „Edytuj” on a newcomer: every declared field can be edited — {d0["newcomer"]["surname"]}, {d0["newcomer"]["year"]}, {d0["newcomer"]["club"]}, {d0["newcomer"]["country"]}</p>
    {row([("after-dialog/dialog__desktop__pl__1-newcomer.png", "desktop · PL"), ("after-dialog/dialog__phone__pl__1-newcomer.png", "phone · PL"), ("after-dialog/dialog__desktop__en__1-newcomer.png", "desktop · EN")])}
    <p class="mkcap">2 · a linked entry: the name is locked („{d0["linked"]["note"]}”), and the roster's year is shown beside the declared one: „{d0["linked"]["roster"]}”</p>
    {row([("after-dialog/dialog__desktop__pl__3-linked.png", "desktop · PL"), ("after-dialog/dialog__phone__pl__3-linked.png", "phone · PL"), ("after-dialog/dialog__desktop__en__3-linked.png", "desktop · EN")])}
    <p class="mkcap">3 · new: a changed year on a linked entry shows what the roster will get before „Zapisz”: „{d0["linked"]["change"]}”, then „{d0["linked"]["category"]}”</p>
    {row([("after-dialog/dialog__desktop__pl__4-roster-change.png", "desktop · PL"), ("after-dialog/dialog__phone__pl__4-roster-change.png", "phone · PL"), ("after-dialog/dialog__desktop__en__4-roster-change.png", "desktop · EN")])}
    <p class="mkcap">4 · a refused save keeps the dialog open with the typed values and the reason. Renaming ZZSMITH into ZZNOWICKA Ewa 1970 gives „{d0["refused"]}”</p>
    {row([("after-dialog/dialog__desktop__pl__2-refused.png", "desktop · PL"), ("after-dialog/dialog__phone__pl__2-refused.png", "phone · PL")])}
    <p>A year outside the season's range shows the form's own line („Rok spoza zakresu …”) and keeps „Zapisz” disabled. Any other failure says „Nie udało się zapisać zmian. Spróbuj ponownie.” (RFADM.06). Escape, „Anuluj” and the backdrop close the dialog without saving, and signing out closes an open dialog (RFADM.07–08). A year set back to the roster's own shows that year with no arrow and no ≠. A newcomer's changed year says nothing about the roster (RFADM.24).</p>
  </section>

  <section>
    <p class="kicker">03 · LOCAL walk-through</p>
    <h2>The administrator corrects two entries, one of them on the roster too</h2>
    <ol class="steps">
      <li>Signed in on <code>/ranking/?admin=1</code>, then „Znajdź zawody”, Łomianki, „Lista zgłoszonych”: {walk[0]["editButtons"]} „Edytuj”, and ≠ on {", ".join(walk[0]["marks"])} (declared 1979, roster 1975).</li>
      <li>ZZSMITH John, a newcomer: year 1990 → 1988, club London FC → Dublin FC, country „irl” → Irlandia. After „Zapisz”: „{walk[1]["done"]}”, and the row shows the flag „{walk[1]["flag"]}”. No roster row is written (R1).</li>
      <li>ZZROSTER Maria, linked: year 1979 → 1965 and country Polska → Ukraina. Before the save the dialog reads „{walk[2]["roster"]}” and „{walk[2]["category"]}”. After the save: „{walk[3]["done"]}”, and the list has no ≠ left, because the entry and the roster now agree.</li>
      <li><b>The database afterwards.</b> The roster fencer ZZROSTER holds 1965, not marked as estimated. Her 2026/27 nationality row holds UKR with source ADMIN, and <code>tbl_fencer.txt_nationality</code> is untouched (R3). The audit log holds one row for her change. The entry is still linked and keeps its edit token. ZZSMITH holds 1988, IRL, Dublin FC, unlinked. Every throwaway entry and the throwaway fencer, with her nationality row, were then removed: LOCAL holds 0 entries.</li>
    </ol>
    {row([("walk/walk-1-edited.png", "ZZSMITH edited"), ("walk/walk-2-saved.png", "saved: the Irish flag"), ("walk/walk-3a-linked-edited.png", "ZZROSTER: what the roster will get"), ("walk/walk-3-linked-saved.png", "saved: no ≠ left")])}
  </section>

  <section>
    <p class="kicker">04 · I25 A, built</p>
    <h2>A name too long for a phone row ends in „…”</h2>
    <p><b>The cause.</b> On a phone each cell of a row was an inline flex box, and a browser draws no „…” inside a flex box, so a name that did not fit was cut mid-letter. The name cell is now a block, the one display that gets the „…”. A visitor's only visible change is the end of a long name.</p>
    <p><b>Signed in, on a phone,</b> the row wraps: ≠, „Edytuj” and „Usuń” sit on their own line under the name. The name starts from no width and takes whatever room the category, weapon and flag leave. The first capture of A had let a long name push those three onto a line of their own; a test now pins that they stay beside the name, and the second capture shows them there. Desktop is unchanged.</p>
    {row([("after-admin/admin__phone__pl.png", "signed in · phone"), ("after-visitor/visitor__phone__pl.png", "a visitor · phone")])}
  </section>

  <section>
    <p class="kicker">05 · Your addition, R1–R3 A, built</p>
    <h2>A linked entry's correction also reaches the fencers table</h2>
    <p class="mkcap">What PROD holds today (read 22 Nov, counts only)</p>
    <ul>
      <li><b>127 entries are linked</b> to a roster fencer. Against the roster, the declared birth year differs on <b>6</b> (none of those six roster years is marked estimated), the country on <b>4</b>, the gender on <b>0</b> and the club on <b>69</b>.</li>
      <li><b>Nothing reads the roster's club.</b> The 13 Sep migration says the entry's club is „not the same column as tbl_fencer.txt_club, and never synchronised with it”. Most of the 69 are an empty roster club against a typed one.</li>
      <li><b>A birth year on the roster moves results.</b> <code>trg_fencer_change_enqueue</code> puts every event the fencer has a result in on the recompute queue, and the PROD drain re-brackets them within 15 minutes (ADR-072).</li>
      <li><b>CERT follows PROD.</b> The CERT refresh copies PROD's fencer values before a CERT ingest, so a correction made from PROD's list reaches CERT with no second write.</li>
    </ul>
    <p class="mkcap">What was built</p>
    <ol class="steps">
      <li><b>One database function, <code>fn_update_registration_as_admin</code></b> (migration <code>20261122000003</code>, SECURITY DEFINER, executable by signed-in users only). It updates the entry, then, for a linked entry only (R1), copies to the roster what this save changed: the birth year, marked as confirmed, through <code>fn_update_fencer_birth_year</code>; the gender, through <code>fn_update_fencer_gender</code>; and the country, as the event season's ADMIN row in <code>tbl_fencer_nationality</code> (R2, R3). The club stays the entry's own, and a field the save left as it was is never copied. It is one transaction: a refused write anywhere refuses the whole save.</li>
      <li><b>The dialog saves through it</b> (<code>updateRegistrationAsAdmin</code> calls the function instead of updating the table), and shows the roster's old and new year, plus a category change, before „Zapisz”.</li>
      <li><b>Each roster change is logged</b> by the existing <code>trg_audit_fencer</code>, with old and new values.</li>
    </ol>
    <p><b>Tests, red first:</b></p>
    <ul>
      <li><b>pgTAP RFADM.16–22</b> (<code>135_registration_admin_edit_roster.sql</code>, 12 assertions) failed on the missing function before the migration. They cover the year reaching the roster confirmed and queueing every event of the fencer; an unchanged year not copied; the club kept; a newcomer writing no roster row and staying unlinked; the gender; the season's ADMIN nationality, with <code>txt_nationality</code> untouched; a refused save moving neither the entry nor the roster; and a visitor refused.</li>
      <li><b>Vitest RFADM.23</b> (the save calls the function) and <b>RFADM.24</b> (the dialog's two lines, in PL and EN) failed first.</li>
      <li><b>RFADM.25</b> (I25's phone rules and the signed-in row's own action line) failed first, then failed again for the pushed chips before their fix.</li>
    </ul>
  </section>

  <section>
    <p class="kicker">06 · For your sign-off</p>
    <h2>ADR-079 amendment, as built</h2>
    <div class="note accent"><p class="lede">ADR-079 · Amendment (2026-11-21, release 4) — a signed-in administrator edits an entry, and a linked entry's correction reaches the roster</p>
      <p><b>Context.</b> On 21 Nov 2026 two entries' impossible birth years (47 and −1972) were corrected on PROD by hand, through the database. FR-166 had given the administrator „Usuń” but nothing to correct an entry. Six of PROD's 127 linked entries declare a year other than the roster's, and nothing showed it. On 22 Nov the user asked that a correction of a linked entry also reach the fencers table.</p>
      <p><b>Decision.</b></p>
      <ol>
        <li>On the entry list reached from the admin calendar (the route of FR-166), each row carries „Edytuj” beside „Usuń”. A visitor sees neither, and a visitor's list reads no entry details.</li>
        <li>The dialog edits every declared field: surname, given name, gender, birth year, weapons, club and country (D2 A). A linked entry's name is locked, because the database keeps the roster's name for it.</li>
        <li>For a linked entry the dialog shows the roster's birth year beside the declared one, and the signed-in list marks an entry where they differ with ≠ (D5 A).</li>
        <li>For a linked entry only, what the save changed reaches the roster in the same transaction: the birth year, marked as confirmed; the gender; and the country, as the event season's ADMIN nationality, never <code>tbl_fencer.txt_nationality</code> (R1–R3 A). The club stays the entry's own. Before „Zapisz” the dialog shows the roster's new year and any category change. A birth-year change queues the fencer's events for recompute (ADR-072), and the audit trigger logs the roster change.</li>
        <li>One SECURITY DEFINER function, <code>fn_update_registration_as_admin</code>, writes both, for signed-in users only. The table's own rules hold: the name form, the roster's name, the season's year range and the country code.</li>
        <li>A refused save keeps the dialog open with the reason: the year's range line, „Takie zgłoszenie już istnieje.” for a rename into another newcomer's identity, or a general failure otherwise. An edit never links or unlinks, and never touches the consent record or the fencer's edit link.</li>
        <li>On a phone, a name too long for its row ends in „…”, and a signed-in row puts its actions on a line of their own (I25 A).</li>
      </ol>
      <p><b>Consequences.</b> An entry, and with it the fencer's roster record, is corrected from the list in one dialog, without a visit to the database. New: migration <code>20261122000003</code> with <code>fn_update_registration_as_admin</code>; <code>EntryEdit.svelte</code>; and <code>fetchAdminEntryDetails</code>, <code>updateRegistrationAsAdmin</code> and <code>fetchEventSeasonEndYear</code> in <code>api.ts</code>. Tests: Vitest RFADM.01–08, 13–15 and 23–25 (<code>EntryEdit.test.ts</code>, <code>EntryList.test.ts</code>, <code>api.registration.test.ts</code>); pgTAP RFADM.09–12 (<code>133_registration_admin_edit.sql</code>) and 16–22 (<code>135_registration_admin_edit_roster.sql</code>). FR-170. Relates to ADR-072 (recompute on a birth-year change) and ADR-033 (the roster's gender is authoritative; an administrator's correction is not an import).</p></div>
  </section>

  <section>
    <p class="kicker">07 · Found on the way</p>
    <h2>Issues</h2>
    <ul>
      <li><b>I25</b>: built as A (section 04).</li>
      <li><b>The first build of I25 A</b> let a long name push its chips onto a second line on a signed-in phone. It was caught in the capture, pinned by a test, and fixed before this sheet.</li>
      <li><b>The capture tool</b> first looked for the dialog by <code>role="dialog"</code>, which the calendar's own modal also has. It now finds the edit dialog by its class, and it measures each phone row (cut, „…”, chips, actions).</li>
      <li><b>Two older test files</b> (<code>CalendarView.test.ts</code>, <code>RegistrationModal.test.ts</code>) mock the API by name. A signed-in list now also reads the entry details and the season, so both mocks list the two new calls with empty answers. No assertion changed.</li>
      <li><b>postgrestools</b> cannot see the helper functions that test 134 creates in its own transaction, so that file marks the region with a reasoned <code>pgt-ignore</code>, as test 02 does. The file checks with zero findings.</li>
      <li><b>Test 133's header</b> said „no new function”. It now says the dialog saves through the function of test 134, and that 133 pins the table rules the function relies on.</li>
    </ul>
  </section>

  <p class="foot">pixel sheet · FR-170 release 4 · 21 Nov 2026, amended 22 Nov · tools: {D}/tools/proof.cjs (visitor · admin · dialog · walk), seed-admin.sql, diff.py, build_sheet.py</p>
</div>
"""
    _ = OUT.write_text(head + body, encoding="utf-8")
    print("ok", v2, v2n, vb, vbn, a2, a2n, ab, abn, errs)


main()
