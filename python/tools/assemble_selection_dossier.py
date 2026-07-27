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
    return tail


# --------------------------------------------------------------------------- #
# Card blocks (reuses the scorecard renderer's parts)
# --------------------------------------------------------------------------- #
def card_blocks(cards: list[dict[str, Any]]) -> tuple[str, str]:
    """Return (table-of-contents html, cards html) for the scorecard annex."""
    scale = max([0.5] + [m for c in cards
                         for v in list(c["team"].values()) + ([c["rez"]] if c["rez"] else [])
                         for m in bs.per_bout(v)])
    toc, blocks = [], []
    for i, c in enumerate(cards):
        anchor = f"karta{i}"
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
    <h2>{bs.esc(c["fencer"])}</h2>{status}{bs.rank_chips(c)}</div>
  <div class="two">
    <div><h3>Zakres wyników — indywidualnie</h3>{bs.ladder_svg(c, i)}
      <p class="note">Długość słupka = jak daleko zawodnik zaszedł w turnieju danej rangi:
      zwycięstwo wypełnia słupek, wczesne odpadnięcie zostawia go krótkim. Gwiazdka i liczba =
      najlepsze zajęte miejsce. Po prawej — liczba startów na tym poziomie.</p></div>
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
"""


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--proposal", required=True)
    ap.add_argument("--ab-report", required=True)
    ap.add_argument("--roster", required=True)
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
    card_toc, card_html = card_blocks(cards)

    # The proposal ships its own <title>/header; reuse its page wrapper and drop
    # its closing tags so the annexes sit inside the same column.
    inner = prop_body.strip()
    inner = re.sub(r"</div>\s*$", "", inner, count=1)

    # Extend the proposal's table of contents with the two annexes.
    inner = inner.replace(
        '<li><a href="#s11">Załączniki i słownik</a></li>',
        '<li><a href="#s11">Załączniki i słownik</a></li>\n'
        '  <li><a href="#zA"><b>Załącznik A</b> — proponowana reprezentacja</a></li>\n'
        '  <li><a href="#zB"><b>Załącznik B</b> — karty zawodników</a></li>')

    annexes = f"""
<div class="annex" id="zA">
  <div class="lbl">Załącznik A</div>
  <h2>Proponowana reprezentacja — stan deklaracji</h2>
  <p>Sekcje A i B przeniesione bez zmian z raportu kampanii ankietowej
  (<code>AB_raport.html</code>). Sekcja A pokazuje proponowaną obsadę startu
  indywidualnego w 24 kategoriach, sekcja B — obsadę drużyn według rankingu.
  Kolory oznaczają stan deklaracji zawodnika, nie ocenę sportową.</p>
</div>
<div class="abr">{ab_block}</div>

<div class="annex" id="zB">
  <div class="lbl">Załącznik B</div>
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
            f"</head>\n<body>\n{inner}\n{annexes}\n</body>\n</html>\n")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    print(f"Wrote {out} — proposal + Załącznik A + {len(cards)} kart "
          f"({len(html) // 1024} KB).", file=sys.stderr)


if __name__ == "__main__":
    main()
