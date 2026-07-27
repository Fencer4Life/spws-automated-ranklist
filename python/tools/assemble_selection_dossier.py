"""Assemble the complete selection dossier into one HTML file.

Merges three documents that are maintained separately:

1. the proposal itself (``doc/plans/nominacje-kadry-narodowej-propozycja-*.html``),
2. **Załącznik A** — sections A and B of the campaign report, lifted verbatim from
   ``AB_raport.html`` so the proposed representation shown here is byte-identical
   to the report the campaign already publishes, and
3. **Załącznik B** — one scorecard per fencer per weapon, built by
   :mod:`python.tools.build_scorecards`.

The campaign report and the proposal were written independently and share class
names (``.body``, ``.note``, ``.chip``). Its stylesheet is therefore rewritten so
every rule is scoped under a ``.abr`` wrapper before being merged, which keeps
the annex looking exactly as published without leaking styles into the proposal.

Usage::

    python -m python.tools.assemble_selection_dossier \\
        --proposal doc/plans/nominacje-....html \\
        --ab-report doc/external_files/MSW-Tbilisi-2026/AB_raport.html \\
        --roster roster.json --out dossier.html
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

import python.tools.build_scorecards as bs

SCOPE = ".abr"


# --------------------------------------------------------------------------- #
# CSS scoping
# --------------------------------------------------------------------------- #
def scope_css(css: str, scope: str = SCOPE) -> str:
    """Prefix every rule in ``css`` with ``scope`` so it cannot escape the annex.

    ``:root`` and ``body`` become the scope element itself, so custom properties
    and base typography still apply inside the wrapper. ``@media`` blocks are
    rewritten recursively; other at-rules are dropped, since the annex needs none.
    """
    out: list[str] = []
    i, n = 0, len(css)
    while i < n:
        at = css.find("@", i)
        brace = css.find("{", i)
        if brace == -1:
            break
        if at != -1 and at < brace:
            # @media ... { ... }  — rewrite the inner block, keep the query.
            head_end = css.find("{", at)
            depth, j = 1, head_end + 1
            while j < n and depth:
                if css[j] == "{":
                    depth += 1
                elif css[j] == "}":
                    depth -= 1
                j += 1
            query = css[at:head_end].strip()
            inner = css[head_end + 1:j - 1]
            if query.lower().startswith("@media"):
                out.append(f"{query}{{{scope_css(inner, scope)}}}")
            i = j
            continue
        selectors = css[i:brace].strip()
        end = css.find("}", brace)
        if end == -1:
            break
        body = css[brace + 1:end]
        i = end + 1
        if not selectors:
            continue
        parts = []
        for sel in selectors.split(","):
            s = sel.strip()
            if not s:
                continue
            if s in (":root", "html", "body", "*"):
                parts.append(scope if s != "*" else f"{scope} *")
            else:
                parts.append(f"{scope} {s}")
        if parts:
            out.append(f'{",".join(parts)}{{{body}}}')
    return "".join(out)


def extract(path: Path) -> tuple[str, str]:
    """Return (stylesheet, body-inner-html) of a standalone HTML document."""
    html = path.read_text(encoding="utf-8")
    css = "\n".join(re.findall(r"<style>(.*?)</style>", html, re.S))
    m = re.search(r"<body[^>]*>(.*)</body>", html, re.S)
    return css, (m.group(1) if m else html)


def ab_sections(body: str) -> str:
    """Lift sections A and B out of the campaign report, verbatim.

    Starts at the 'A ·' heading and runs to the end of section B, so the
    dossier reproduces exactly what the campaign already publishes — no
    re-derivation, nothing that can drift apart from the source report.
    """
    start = body.find("<h3>A ·")
    if start == -1:
        raise SystemExit("nie znaleziono sekcji A w raporcie kampanii")
    tail = body[start:]
    # Section B is the last block we want; stop before the report's own footer
    # or legend-of-declarations section if either follows.
    for marker in ("<h3>C ·", "<footer", "</div>\n</div>"):
        cut = tail.find(marker)
        if cut != -1:
            tail = tail[:cut]
            break
    return _balance_divs(tail)


def _balance_divs(html: str) -> str:
    """Make the lifted fragment self-contained.

    The cut lands mid-structure, so the slice carries a surplus or shortfall of
    </div>. Left alone, a surplus closes the wrapper early and then the page
    container itself — everything after the annex would escape the column and
    slide under the fixed rail. Balancing here keeps the fragment sealed.
    """
    opens = len(re.findall(r"<div\b", html))
    closes = len(re.findall(r"</div>", html))
    if closes > opens:
        surplus = closes - opens
        for _ in range(surplus):
            idx = html.rfind("</div>")
            if idx == -1:
                break
            html = html[:idx] + html[idx + len("</div>"):]
    elif opens > closes:
        html += "</div>" * (opens - closes)
    return html


# --------------------------------------------------------------------------- #
# Card blocks (reuses the scorecard renderer's parts)
# --------------------------------------------------------------------------- #
# Pseudonymised entries the campaign report carries, mapped to the real fencer so
# the annex links to the right card. Kept here rather than edited into the report,
# which stays the campaign's own artefact.
PSEUDONYMS = {"TK": "KOŃCZYŁO Tomasz"}

_WEAPON_PL = {"SZPADA": "EPEE", "FLORET": "FOIL", "SZABLA": "SABRE"}
_WEAPON_CTX = re.compile(
    r'<h4>\s*(Szpada|Floret|Szabla)\b|<div class="ttl">\s*(Szpada|Floret|Szabla)\b',
    re.I)
_NAME_LI = re.compile(r'(<li class="[a-z]+">)([^<]+)')


def linkify_ab(
    block: str, anchors: dict[tuple[str, str], str]
) -> tuple[str, int, int, set[str]]:
    """Turn every fencer name in the campaign annex into a link to their card.

    The report lists a fencer once per category, so which card to link depends on
    the surrounding weapon heading — the same person may have three cards. The
    weapon context is tracked while scanning, and a name only becomes a link when
    a card exists for that exact (fencer, weapon) pair.

    The first reference to each card also carries ``id="ref-<anchor>"``, so the
    card can link back to the exact line the reader came from rather than to the
    top of a very long annex.

    Returns (html, linked, unlinked, refs-created).
    """
    for pseudo, real in PSEUDONYMS.items():
        block = re.sub(rf'(<li class="[a-z]+">){re.escape(pseudo)}(?=<)',
                       rf'\g<1>{real}', block)

    out: list[str] = []
    pos, weapon, linked, missed = 0, None, 0, 0
    seen_ref: set[str] = set()
    events = sorted(
        [(m.start(), m.end(), "ctx", m) for m in _WEAPON_CTX.finditer(block)]
        + [(m.start(), m.end(), "li", m) for m in _NAME_LI.finditer(block)]
    )
    for start, end, kind, m in events:
        out.append(block[pos:start])
        pos = end
        if kind == "ctx":
            word = (m.group(1) or m.group(2) or "").upper()
            weapon = _WEAPON_PL.get(word)
            out.append(m.group(0))
            continue
        tag, name = m.group(1), m.group(2)
        clean = name.strip()
        anchor = anchors.get((bs.fold(clean), weapon or ""))
        if anchor and clean.lower() != "brak zawodników":
            linked += 1
            back = ""
            if anchor not in seen_ref:
                seen_ref.add(anchor)
                back = f' id="ref-{anchor}"'
            out.append(f'{tag}<a class="pl-link"{back} href="#{anchor}">{name}</a>')
        else:
            if clean.lower() != "brak zawodników":
                missed += 1
            out.append(m.group(0))
    out.append(block[pos:])
    return "".join(out), linked, missed, seen_ref


def build_anchors(cards: list[dict[str, Any]]) -> dict[tuple[str, str], str]:
    """Map (fencer, weapon) -> card anchor, indexing both name spellings."""
    anchors: dict[tuple[str, str], str] = {}
    for i, c in enumerate(cards):
        anchors[(bs.fold(c["fencer"]), c["weapon"])] = f"karta{i}"
        anchors.setdefault((bs.fold(c["roster_name"]), c["weapon"]), f"karta{i}")
    return anchors


def card_blocks(
    cards: list[dict[str, Any]], refs: set[str] | None = None,
) -> tuple[str, str]:
    """Return (toc html, cards html) for the annex.

    ``refs`` are the back-anchors Załącznik A actually created. A fencer in play
    may not appear in the annex's shown lists, so their card would otherwise
    carry a link to an id that does not exist; those fall back to the annex top.
    """
    refs = refs or set()
    scale = max([0.5] + [m for c in cards
                         for v in list(c["team"].values()) + ([c["rez"]] if c["rez"] else [])
                         for m in bs.per_bout(v)])
    toc, blocks = [], []
    for i, c in enumerate(cards):
        anchor = f"karta{i}"
        back_href = f"#ref-{anchor}" if anchor in refs else "#zA"
        toc.append(f'<a class="tocitem" href="#{anchor}">'
                   f'<i style="background:{bs.WEAPON_COL[c["weapon"]]}"></i>'
                   f'{bs.esc(c["fencer"])} <span>{c["weapon_pl"]}</span></a>')
        rows = "".join(
            f'<tr><td class="d">{bs.esc(m["ch"])}</td><td>{bs.esc(m["tn"])}</td>'
            f'<td>{bs.esc(m["stage"])}</td><td>{bs.esc(m["opp"])}</td>'
            f'<td class="n">{bs.esc(m["sc"])}–{bs.esc(m["os"])}</td>'
            f'<td><span class="st {"s-ok" if m["won"] else "s-bad"}">'
            f'{"W" if m["won"] else "P"}</span></td>'
            f'<td class="rr">{bs.esc(m["roles"])}{" · rez." if m["rez"] else ""}</td>'
            f'<td class="n">{m["legs"]}</td>'
            f'<td class="n"><span class="{"tpos" if m["diff"] > 0 else "tneg" if m["diff"] < 0 else ""}">'
            f'{m["diff"]:+d}</span></td>'
            f'<td><a href="{bs.esc(m["u"])}" target="_blank">mecz ↗</a></td></tr>'
            for m in c["matches"][:20])
        tbl = (f'<h3>Mecze drużynowe — pełny zapis ze źródłem</h3><div class="tw"><table>'
               f'<thead><tr><th>Impreza</th><th>Turniej</th><th>Faza</th><th>Rywal</th>'
               f'<th>Wynik</th><th></th><th>Rola</th><th>Walk</th><th>Bilans</th>'
               f'<th>Źródło</th></tr></thead><tbody>{rows}</tbody></table></div>'
               ) if rows else '<p class="note">Brak startów drużynowych w analizowanym okresie.</p>'
        status = f'<span class="tag">{bs.esc(c["status"])}</span>' if c.get("status") else ""
        blocks.append(f"""
<section class="card" id="{anchor}">
  <div class="ch"><span class="wpn" style="background:{bs.WEAPON_COL[c["weapon"]]}">{c["weapon_pl"]}</span>
    <h2>{bs.esc(c["fencer"])}</h2>{status}{bs.rank_chips(c)}
    <a class="back" href="{back_href}" title="Powrót do Załącznika A">↑ Załącznik A</a></div>
  <div class="two">
    <div><h3>Zakres wyników — indywidualnie</h3>{bs.ladder_svg(c, i)}
      <p class="note">Długość słupka = jak daleko zawodnik zaszedł w turnieju danej rangi:
      zwycięstwo wypełnia słupek, wczesne odpadnięcie zostawia go krótkim. Gwiazdka i liczba =
      najlepsze zajęte miejsce. Po prawej — liczba startów na tym poziomie,
      w wybranym oknie czasowym.</p></div>
    <div><h3>Role w drużynie</h3>{bs.team_svg(c, scale)}
      <p class="note">W lewo (czerwone) — trafienia stracone, w prawo (zielone) — trafienia
      zdobyte. Liczby to trafienia łącznie, długość słupka — średnia na jedną walkę.
      Wejścia z rezerwy nakładają się na walki powyżej.</p></div>
  </div>
  {tbl}
</section>""")
    return "".join(toc), "".join(blocks)


CARD_CSS = f"""
.card{{background:var(--card);border:1px solid var(--line);border-radius:7px;
padding:18px 20px;margin:20px 22px;scroll-margin-top:12px}}
.card .ch{{display:flex;align-items:center;gap:10px;flex-wrap:wrap;
border-bottom:1px solid var(--line);padding-bottom:10px;margin-bottom:14px}}
.card h2{{font-family:var(--serif);font-size:20px;margin:0;font-weight:600;
border:none;padding:0}}
.wpn{{font-family:var(--mono);font-size:11px;letter-spacing:.14em;font-weight:700;
color:#fff;padding:5px 12px;border-radius:3px}}
.tag{{font-family:var(--mono);font-size:9px;letter-spacing:.06em;color:var(--muted);
border:1px solid var(--line);background:var(--paper);padding:3px 8px;border-radius:3px}}
.rank{{font-family:var(--mono);font-size:10px;border:1px solid var(--line);border-radius:3px;
padding:3px 8px;color:var(--muted);background:var(--paper);white-space:nowrap}}
.rank b{{color:var(--ink)}} .rank .of{{opacity:.65}}
.rank .bkt{{font-size:8.5px;letter-spacing:.06em;opacity:.75}}
.rank-none{{opacity:.55}} .dup{{color:#c96a2e;font-weight:700}}
.two{{display:grid;grid-template-columns:1fr 1fr;gap:26px}}
@media(max-width:900px){{.two{{grid-template-columns:1fr}}}}
.chart{{width:100%;height:auto}}
.rl{{font-family:var(--mono);font-size:9.5px;font-weight:700}}
.rl2{{font-family:var(--mono);font-size:9px;fill:var(--ink);font-weight:700;letter-spacing:.04em}}
.cnt{{font-family:var(--mono);font-size:9.5px;fill:var(--muted)}}
.legs{{font-family:var(--mono);font-size:8.5px;fill:var(--muted);opacity:.8}}
.pl{{font-family:var(--mono);font-size:10px;fill:var(--ink);font-weight:700}}
.brak{{font-family:var(--mono);font-size:9px;fill:var(--muted);opacity:.5}}
.star{{font-size:12px}} .track{{fill:var(--line);opacity:.38}} .axis{{stroke:var(--line)}}
.pos{{fill:{bs.GREEN};font-weight:700}} .neg{{fill:{bs.RED};font-weight:700}}
.card .note{{font-size:11px;color:var(--muted);margin:8px 0 0;line-height:1.5}}
td.rr{{font-family:var(--mono);font-size:9.5px;color:var(--muted)}}
.tpos{{color:{bs.GREEN};font-weight:700}} .tneg{{color:{bs.RED};font-weight:700}}
.toclist{{display:flex;flex-wrap:wrap;gap:6px 14px}}
.tocitem{{font-family:var(--mono);font-size:10.5px;color:var(--ink);text-decoration:none;
white-space:nowrap}}
.tocitem span{{color:var(--muted);font-size:9px}}
.tocitem i{{display:inline-block;width:8px;height:8px;border-radius:2px;margin-right:5px}}
.tocitem:hover{{text-decoration:underline}}
.annex{{background:var(--card);border:1px solid var(--line);border-left:6px solid var(--navy);
padding:20px 24px;margin:44px 22px 0}}
.annex .lbl{{font-family:var(--mono);font-size:11px;letter-spacing:.14em;
text-transform:uppercase;color:var(--navy);font-weight:700}}
.annex h2{{font-family:var(--serif);font-size:24px;margin:8px 0 8px;font-weight:600;
border:none;padding:0}}
.annex p{{margin:0;color:var(--muted);font-size:13px;max-width:84ch}}
.back{{margin-left:auto;font-family:var(--mono);font-size:9.5px;color:var(--muted);
text-decoration:none;border:1px solid var(--line);border-radius:3px;padding:3px 8px;
white-space:nowrap}}
.back:hover{{color:var(--navy);border-color:var(--navy)}}
/* Fixed contents rail, pinned right. The dossier runs to ~800 kB across 96
   cards, so scrolling back to the table of contents is impractical. It is
   deliberately inverted — a dark navy panel — so it reads as chrome rather than
   as part of the document, and its colours are fixed rather than themed so it
   looks the same in light and dark mode.

   It appears only once the viewport can hold it beside the text column. Below
   that threshold it is hidden entirely and the inline table of contents serves
   instead, so nothing is lost on a phone. */
.rail{{display:none}}
@media(min-width:1200px){{
  .rail{{display:block;position:fixed;right:14px;top:24px;bottom:24px;width:200px;
  overflow-y:auto;background:#12304f;border:1px solid #24435f;border-radius:6px;
  padding:13px 13px 15px;z-index:60;
  box-shadow:0 2px 14px rgba(8,20,36,.18)}}
  .page{{margin-right:232px}}
}}
.rail .rt{{font-family:var(--mono);font-size:9px;letter-spacing:.12em;text-transform:uppercase;
color:#8fa6c0;margin:0 0 9px;font-weight:600}}
.rail a{{display:block;font-family:var(--mono);font-size:10px;line-height:1.32;
color:#ccd7e6;text-decoration:none;padding:4px 0}}
.rail a:hover{{color:#fff}}
.rail a .no{{color:#7690ae;margin-right:6px}}
.rail .sep{{border-top:1px solid #24435f;margin:10px 0 8px}}
/* Names in Załącznik A link to that fencer's card. Underlined on hover only, so
   a page of 200 names does not turn into a wall of blue. */
{SCOPE} a.pl-link{{color:inherit;text-decoration:none;border-bottom:1px dotted currentColor;
opacity:.95}}
{SCOPE} a.pl-link:hover{{border-bottom-style:solid;opacity:1}}
"""


VERDICT_CLASS = {"OBSADZONA": "s-ok", "NIEPEŁNA": "s-wip", "BRAK OBSADY": "s-bad"}


def viability_annex(via: dict[str, Any]) -> str:
    """Załącznik B — can each of the 24 categories actually field a squad?"""
    squad = via["squad"]
    s = via["summary"]
    rows = "".join(
        f'<tr><td class="d">{bs.esc(r["weapon"])} {bs.esc(r["gender_pl"])} '
        f'{bs.esc(r["vcat"])}</td>'
        f'<td class="n">{r["ranked"]}</td><td class="n">{r["inplay"]}</td>'
        f'<td class="n">{r["confirmed"]}</td>'
        f'<td><span class="st {VERDICT_CLASS[r["verdict"]]}">{r["verdict"]}</span></td>'
        f'<td class="n">{r["missing"] or "—"}</td></tr>'
        for r in via["rows"])
    total_needed = len(via["rows"]) * squad
    total_have = sum(r["inplay"] for r in via["rows"])
    return f"""
<div class="annex" id="zB">
  <div class="lbl">Załącznik B</div>
  <h2>Przegląd obsady reprezentacji w poszczególnych kategoriach wiekowych</h2>
  <p>Skład to {squad} zawodników (4 + 1 rezerwowy).</p>
</div>
<div class="body">
<div class="call stop">
  <span class="lb">Wynik zestawienia</span>
  Pełną obsadę ma <b class="k">{s["obsadzona"]} z 24</b> kategorii.
  <b class="k">{s["niepelna"]}</b> jest niepełnych, a <b class="k">{s["brak"]}</b> nie ma
  ani jednego kandydata. Komplet wymagałby {total_needed} zawodników — dysponujemy
  {total_have}. <b class="k">Szpada i szabla mężczyzn są obsadzone w każdej kategorii;
  floret kobiet i szabla kobiet nie mają pełnego składu w żadnej.</b>
</div>
<div class="tw"><table><thead><tr>
  <th>Kategoria</th><th>Ogółem</th><th>Zaproponowano</th><th>Wyraziło chęć</th>
  <th>Stan</th><th>Brakuje</th></tr></thead>
<tbody>{rows}</tbody></table></div>
</div>"""


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--proposal", required=True)
    ap.add_argument("--ab-report", required=True)
    ap.add_argument("--roster", required=True)
    ap.add_argument("--viability", default=None,
                    help="JSON z wykonalnością obsady 24 kategorii (Załącznik B)")
    ap.add_argument("--reports", default="doc/reports")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    prop_css, prop_body = extract(Path(args.proposal))
    ab_css, ab_body = extract(Path(args.ab_report))
    ab_block = ab_sections(ab_body)

    roster = json.loads(Path(args.roster).read_text(encoding="utf-8"))
    data = bs.collect(Path(args.reports))
    from python.pipeline.db_connector import create_db_connector

    cards = bs.build_cards(roster, data, create_db_connector().fetch_fencer_db())
    cards.sort(key=lambda c: (c["fencer"], c["weapon"]))
    anchors = build_anchors(cards)
    ab_block, linked, missed, refs = linkify_ab(ab_block, anchors)
    card_toc, card_html = card_blocks(cards, refs)
    print(f"  Załącznik A: {linked} nazwisk z odnośnikiem do karty, "
          f"{missed} bez karty", file=sys.stderr)

    # The proposal ships its own <title>/header; reuse its page wrapper and drop
    # its closing tags so the annexes sit inside the same column.
    inner = prop_body.strip()
    inner = re.sub(r"</div>\s*$", "", inner, count=1)

    # The rail mirrors the document's own contents, so the two can never disagree.
    toc_items = re.findall(r'<li><a href="(#s\d+)">(.*?)</a></li>', inner, re.S)
    rail_links = "".join(
        f'<a href="{h}"><span class="no">{i:02d}</span>'
        f'{re.sub(r"<[^>]+>", "", t).split("—")[0].strip()}</a>'
        for i, (h, t) in enumerate(toc_items))
    rail = (
        '<nav class="rail"><p class="rt">Spis treści</p>'
        + rail_links
        + '<div class="sep"></div>'
        + '<a href="#zA"><span class="no">A</span>Propozycje reprezentacji</a>'
        + '<a href="#zB"><span class="no">B</span>Przegląd obsady</a>'
        + '<a href="#zE"><span class="no">C</span>Karty zawodników</a>'
        + '</nav>')

    # Extend the proposal's table of contents with the two annexes.
    inner = inner.replace(
        '<li><a href="#s08">Załączniki i słownik</a></li>',
        '<li><a href="#s11">Załączniki i słownik</a></li>\n'
        '  <li><a href="#zA"><b>Załącznik A</b> — propozycje reprezentacji</a></li>\n'
        '  <li><a href="#zB"><b>Załącznik B</b> — przegląd obsady reprezentacji</a></li>\n'
        '  <li><a href="#zC"><b>Załącznik C</b> — jak czytać protokół meczu</a></li>\n'
        '  <li><a href="#zE"><b>Załącznik E</b> — karty zawodników</a></li>')

    via_html = ""
    if args.viability:
        via_html = viability_annex(
            json.loads(Path(args.viability).read_text(encoding="utf-8")))

    annexes = f"""
<div class="annex" id="zA">
  <div class="lbl">Załącznik A</div>
  <h2>Propozycje reprezentacji</h2>
  <p><b>Sekcja A — start indywidualny.</b> Czterech zawodników i rezerwowy w każdej
  z 24 kategorii, wyłonieni z rankingu SPWS. To jest właściwa propozycja obsady
  indywidualnej, którą SPWS przedkłada Polskiemu Związkowi Szermierczemu.<br>
  <b>Sekcja B — drużyny.</b> Dla każdej drużyny (Veteran: V1+V2, Grand Veteran: V3+V4)
  podajemy <b>pulę ośmiu zawodników</b>, z której PZSz wybiera skład. Pula jest szersza
  niż skład celowo — pozwala uwzględnić formę, dostępność i ustawienie drużyny bez
  wracania po nowe dane.<br>
  Kolory oznaczają <b>stan deklaracji</b> zawodnika, nie ocenę sportową.
  <b>Każde nazwisko jest odnośnikiem do karty zawodnika</b> w załączniku C — do karty
  dla tej broni, w której zawodnik występuje w danej kategorii. Podstawą jest raport
  kampanii ankietowej; pseudonim <code>TK</code> zastąpiono pełnym nazwiskiem, żeby
  odnośnik prowadził do właściwej karty.</p>
</div>
<div class="abr">{ab_block}</div>
{via_html}
<div class="annex" id="zC">
  <div class="lbl">Załącznik C</div>
  <h2>Karty zawodników — {len(cards)} kart</h2>
  <p>Po jednej karcie na zawodnika i broń, dla wszystkich kandydatów pozostających
  w grze. Metodę czytania obu wykresów opisuje §06; gradację rangi zawodów — §03.
  Każdy mecz drużynowy ma odnośnik do protokołu źródłowego.</p>
</div>
<div class="toc"><div class="toclist">{card_toc}</div></div>
{card_html}
</div>"""

    html = (f"<!doctype html>\n<html lang=\"pl\">\n<head>\n<meta charset=\"utf-8\">\n"
            f"<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n"
            f"<title>Nominacje kadry narodowej — propozycja SPWS z załącznikami</title>\n"
            f"<style>{prop_css}\n{CARD_CSS}\n"
            f"/* --- Załącznik A: styl raportu kampanii, ograniczony do .abr --- */\n"
            f"{scope_css(ab_css)}\n"
            f"/* The campaign report paints a navy stripe down the left of its own\n"
            f"   <body>; scoped onto the wrapper it would sit under the headings and\n"
            f"   clip their first letter. Neutralised here, after the scoped rules. */\n"
            f"{SCOPE}{{display:block;margin:0 22px;padding:0;background:none;"
            f"min-height:0;max-width:none}}</style>\n"
            f"</head>\n<body>\n{rail}\n{inner}\n{annexes}\n</body>\n</html>\n")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    print(f"Wrote {out} — proposal + Załącznik A + {len(cards)} kart "
          f"({len(html) // 1024} KB).", file=sys.stderr)


if __name__ == "__main__":
    main()
