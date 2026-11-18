"""Builds the I7 pixel sheet from the captures and reports (usage: python3 build_sheet.py <repo dir>)."""

import json
import re
import sys
from pathlib import Path
from typing import Any

REPO = Path(sys.argv[1])
SRC = REPO / "doc/plans/entry-list-admin-removes-entry-pixel-sheet-2026-11-17.html"
OUT = REPO / "doc/plans/i7-admin-reaches-remove-on-prod-pixel-sheet-2026-11-18.html"
D = "i7-admin-reaches-remove-on-prod-sheet"
SHEET = REPO / "doc/plans" / D


def load(name: str) -> list[dict[str, Any]]:
    data: list[dict[str, Any]] = json.loads((SHEET / name).read_text(encoding="utf-8"))
    return data


def fig(path: str, cap: str, alt: str) -> str:
    return (
        f'<figure class="shot"><a href="{D}/{path}"><img src="{D}/{path}" alt="{alt}" loading="lazy"></a>'
        f"<figcaption>{cap}</figcaption></figure>"
    )


def row(items: list[tuple[str, str, str]]) -> str:
    return '<div class="shots">' + "".join(fig(*i) for i in items) + "</div>"


def geo_rows(rep: list[dict[str, Any]]) -> str:
    out = ""
    for x in rep:
        own = "yes" if "site-own-height" in x["appClasses"] else "no"
        out += (
            f"<tr><td>{x['tag']} · {x['w']} · {x['lang'].upper()}</td><td><code>{x['element']}</code></td>"
            f"<td>{x['appHeight']}</td><td>{x['calendarHeight'] or '—'}</td><td>{x['viewport']}</td><td>{own}</td></tr>"
        )
    return out


def admin_rows(rep: list[dict[str, Any]], label: str) -> str:
    out = ""
    for x in rep:
        if "calendarInPlace" not in x:
            continue
        g = x["calendarInPlace"]
        s = x.get("afterSignOut")
        after = "—"
        if s:
            section = "shown" if s["adminSection"] else "gone"
            after = f"stays on {s['path']}, calendar {s['calendarHeight']} px, admin section {section}"
        signed = "yes" if g["adminSection"] else "<b>no</b>"
        out += (
            f"<tr><td>{label} · {x['w']}</td><td><code>{g['path']}</code> · <code>{g['element']}</code></td>"
            f"<td>{signed}</td><td>{g['calendarHeight']} of {g['viewport']}</td><td>{x['entryRows']}</td>"
            f"<td>{x['removeButtons']}</td><td>{after}</td><td>{len(x['errors'])}</td></tr>"
        )
    return out


def main() -> None:
    head = SRC.read_text(encoding="utf-8").split('<div class="wrap">')[0]
    head = re.sub(r"<title>.*?</title>", "<title>I7 · Removing an entry on PROD · pixel sheet</title>", head, flags=re.S)
    diff = load("visitor-before-after-diff.json")
    twice = load("visitor-two-before-runs-diff.json")
    nd = sum(1 for x in diff if x.get("diff") == 0)
    nt = sum(1 for x in twice if x.get("diff") == 0)
    aa = load("admin-after/admin-report.json")
    ab = load("admin-before/admin-report.json")
    vr = load("visitor-after/visitor-report.json")
    body = f"""<div class="wrap">

  <p class="eyebrow">Entry list · Administrator · I7 · Pixel sheet</p>
  <h1>„Znajdź zawody” in place on /ranking/: before and after</h1>
  <p class="dek">Captured on the <b>WordPress page bodies themselves</b> (<code>doc/wordpress/ranking.html</code>, <code>znajdz-zawody.html</code>), with the published bundle built from main and from this branch and LOCAL standing in for PROD. Visitors: <b>{nd} of {len(diff)} captures pixel-identical</b>. The administrator now stays signed in and reaches „Usuń”.</p>
  <div class="meta">
    <span class="pill warn"><span class="dot"></span>Awaiting your approval</span>
    <span class="pill">plan: i7-admin-reaches-remove-on-prod-2026-11-18.html</span>
  </div>

  <hr class="rule">

  <section>
    <p class="kicker">01 · Visitors</p>
    <h2>Nothing changes for a visitor</h2>
    <ul>
      <li><b>Noise floor first.</b> Two identical runs of main's build gave {nt} of {len(twice)} pixel-identical captures. The first attempt did not match: the drawer slides in on a <code>left</code> transition, and its text rasterised differently from run to run. For the drawer captures, transitions are switched off inside the element, identically for both builds. Neither build changes how the drawer looks.</li>
      <li><b>Before against after</b>, for the Ranking page and the calendar page, with the drawer closed and open, on desktop 1280 × 900 and phone 375 × 812, in PL and EN: <b>{nd} of {len(diff)} identical</b>. There are no page errors and no sideways scroll (<code>{D}/visitor-before-after-diff.json</code>).</li>
      <li><b>The new height class never appears for a visitor</b>, and the calendar page keeps its own height:</li>
    </ul>
    <div class="tablewrap"><table>
      <thead><tr><th>Page</th><th>Element</th><th>App px</th><th>Calendar px</th><th>Viewport</th><th>Height class</th></tr></thead>
      <tbody>{geo_rows(vr)}</tbody>
    </table></div>
  </section>

  <section>
    <p class="kicker">02 · The administrator, before and after</p>
    <h2>Signed in on /ranking/?admin=1, then „Znajdź zawody”</h2>
    <p>The LOCAL test administrator signs in on the Ranking page body, opens the drawer and chooses „Znajdź zawody”. They then open Łomianki's „Lista zgłoszonych”, which holds one throwaway entry registered through the visitor form, and finally sign out.</p>
    <div class="tablewrap"><table>
      <thead><tr><th>Build</th><th>Where the menu led</th><th>Still signed in</th><th>Calendar height</th><th>Rows</th><th>„Usuń”</th><th>After sign-out</th><th>Errors</th></tr></thead>
      <tbody>{admin_rows(ab, "main (before)")}{admin_rows(aa, "this branch")}</tbody>
    </table></div>
    <div class="note danger"><p class="lede">Before: the defect, reproduced</p><p>The menu loads <code>/znajdz-zawody/</code>. The fresh element there resets the sign-in, so the list shows no „Usuń”.</p></div>
    {row([("admin-before/admin__desktop__2-calendar.png", "before · desktop · the calendar page, signed out", "Before: calendar page after the menu, desktop"), ("admin-before/admin__desktop__4-entry-list.png", "before · desktop · no „Usuń”", "Before: entry list without Usuń, desktop"), ("admin-before/admin__phone__4-entry-list.png", "before · phone · no „Usuń”", "Before: entry list without Usuń, phone")])}
    <h3>After: the new states, for your approval</h3>
    <p class="mkcap">1 · signed in on /ranking/: the drawer with the admin section</p>
    {row([("admin-after/admin__desktop__1-drawer.png", "desktop", "Drawer signed in, desktop"), ("admin-after/admin__phone__1-drawer.png", "phone", "Drawer signed in, phone")])}
    <p class="mkcap">2 · „Znajdź zawody” opened in place, using the full height (WP.ADM.05)</p>
    {row([("admin-after/admin__desktop__2-calendar.png", "desktop", "Calendar in place, desktop"), ("admin-after/admin__phone__2-calendar.png", "phone", "Calendar in place, phone")])}
    <p class="mkcap">3 · the Łomianki card</p>
    {row([("admin-after/admin__desktop__3-card.png", "desktop", "Łomianki card, desktop"), ("admin-after/admin__phone__3-card.png", "phone", "Łomianki card, phone")])}
    <p class="mkcap">4 · „Lista zgłoszonych” with „Usuń”</p>
    {row([("admin-after/admin__desktop__4-entry-list.png", "desktop", "Entry list with Usuń, desktop"), ("admin-after/admin__phone__4-entry-list.png", "phone", "Entry list with Usuń, phone")])}
    <p class="mkcap">5 · signed out: the calendar stays, now a visitor's view (Q1)</p>
    {row([("admin-after/admin__desktop__5-signed-out.png", "desktop", "Signed out, calendar stays, desktop"), ("admin-after/admin__phone__5-signed-out.png", "phone", "Signed out, calendar stays, phone")])}
  </section>

  <section>
    <p class="kicker">03 · LOCAL walk-through on the page bodies</p>
    <h2>Registered as a visitor, removed by the administrator</h2>
    <ol class="steps">
      <li>A visitor registered ZZWALKITRZY Ewa through the form on the calendar page body and saw „✓ Zgłoszenie potwierdzone”.</li>
      <li>The administrator signed in on the Ranking page body and chose „Znajdź zawody”. The address stayed <code>/ranking/</code>.</li>
      <li>The confirmation read: „Usunąć zgłoszenie? ZZWALKITRZY Ewa · szpada · V2 · EVF Circuit – Łomianki (POL) · Tej operacji nie można cofnąć. Zawodniczka może zgłosić się ponownie przed końcem terminu zapisów.”</li>
      <li>After confirming, the list showed „✓ Usunięto zgłoszenie: ZZWALKITRZY Ewa”, and no row with that name remained. The capture entry ZZPOKAZ Anna was removed the same way.</li>
      <li>The LOCAL database then held 0 rows for the event in <code>tbl_registration</code> and 0 in <code>vw_registration_entry_list</code>, as before the run.</li>
    </ol>
    {row([("walk/walk-1-confirm.png", "the confirmation", "Walk-through confirmation"), ("walk/walk-2-done.png", "done", "Walk-through done")])}
  </section>

  <section>
    <p class="kicker">04 · Found on the way</p>
    <h2>Issues</h2>
    <ul>
      <li><b>I8 · An unused variable in <code>Sidebar.test.ts</code>.</b> The closed-drawer test computed <code>sidebar</code> and never checked it. Fixed: the test now asserts the closed drawer is present without <code>.open</code>.</li>
      <li><b>I9 · Escape does not close „Lista zgłoszonych”.</b> The calendar's modal stops key events, so only the × closes the list, and a keyboard user cannot leave it with Escape. Not changed here, because this plan touches only what you approved. I propose it as a separate small fix.</li>
    </ul>
  </section>

  <p class="foot">pixel sheet · i7-admin-reaches-remove-on-prod · 18 Nov 2026 · tools: {D}/tools/proof.cjs (visitor · admin · walk), mutate.py, build_sheet.py</p>
</div>
"""
    _ = OUT.write_text(head + body, encoding="utf-8")
    print("ok", nd, len(diff), nt, len(twice))


main()
