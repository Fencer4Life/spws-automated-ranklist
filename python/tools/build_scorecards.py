"""Render selection scorecards — ONE CARD PER FENCER PER WEAPON.

Consumes everything the other tools in this directory gathered and renders a
single HTML file of per-weapon scorecards:

* ``doc/reports/evf-individual/``   individual results, EVF circuit + Europeans
* ``doc/reports/ftl-individual/``   individual results at World Championships
* ``doc/reports/spws-domestic/``    domestic PPW/MPW results
* ``doc/reports/team-events/``      team relays, bout by bout
* ``doc/reports/ranking-positions/`` current EVF + SPWS standings

Each card carries two charts. The **ladder** shows how far the fencer went at
each level of event authority — a win fills the bar, an early exit leaves a stub
— so a points total can be read as a shape rather than a single figure. The
**team roles** chart shows which bout of the relay they were trusted with and
what they did there, per bout so a role fenced 30 times cannot look better than
one fenced 8 times simply by being more frequent.

A card is per weapon because the evidence for a foil nomination says nothing
about an epee nomination. A fencer active in three weapons gets three cards.

Roster input is a JSON list of ``{name, weapons, status}``. Names are resolved to
``tbl_fencer`` through the repo's fuzzy matcher, so roster spellings need not
match the scrapers' spellings.

Usage::

    python -m python.tools.build_scorecards \\
        --roster roster.json --out cards.html --title "MŚW Tbilisi 2026"
"""

from __future__ import annotations

import argparse
import datetime as dt
import glob
import html
import json
import math
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path
from typing import Any

FTL = "https://www.fencingtimelive.com"

LADDER = ["MSW", "MEW", "EVF-64+", "EVF-32+", "EVF-16+", "EVF-8+", "EVF-4+",
          "MPW", "SPWS-16+", "SPWS-8+", "SPWS-4+", "SPWS-4-"]
RENAME = {"WORLD": "MSW", "EUROPEAN": "MEW", "EVF-4-": "EVF-4+"}
ROLES = ["Walka 9", "Walka 8", "Walka 7", "Walki 2-6", "Walka 1"]
ROLE_ORDER = {r: i for i, r in enumerate(ROLES)}
WEAPON_PL = {"EPEE": "SZPADA", "FOIL": "FLORET", "SABRE": "SZABLA"}

RUNG_COL = {
    "MSW": "#12704a", "MEW": "#2e9155", "EVF-64+": "#4f9e4a", "EVF-32+": "#79a742",
    "EVF-16+": "#a3ad3c", "EVF-8+": "#c2a33a", "EVF-4+": "#d18f36", "MPW": "#c96a2e",
    "SPWS-16+": "#d75c33", "SPWS-8+": "#cf4e33", "SPWS-4+": "#c43f31", "SPWS-4-": "#b93636",
}
WEAPON_COL = {"EPEE": "#173f70", "FOIL": "#12704a", "SABRE": "#8a4b1f"}
GOLD, SILVER, BRONZE, GREY = "#d4af37", "#a8b0b8", "#b0793f", "#8a8f98"
GREEN, RED = "#12704a", "#c0392b"
RIGHT = 462


# --------------------------------------------------------------------------- #
# Shared helpers
# --------------------------------------------------------------------------- #
def fold(name: str) -> str:
    s = (name or "").replace("Ł", "L").replace("ł", "l")
    return "".join(c for c in unicodedata.normalize("NFD", s)
                   if unicodedata.category(c) != "Mn").upper().strip()


def weapon_of(raw: str | None) -> str | None:
    """Normalise every source's weapon spelling to EPEE / FOIL / SABRE."""
    s = (raw or "").strip().upper()
    if not s:
        return None
    if s in ("ME", "WE") or "EPEE" in s or "ÉPÉE" in s or "SZPAD" in s:
        return "EPEE"
    if s in ("MF", "WF") or "FOIL" in s or "FLORET" in s:
        return "FOIL"
    if s in ("MS", "WS") or "SABRE" in s or "SABER" in s or "SZABL" in s:
        return "SABRE"
    return None


def reach(place: int | None, entry: int | None) -> float:
    """How deep the fencer went, 0..1, in elimination rounds survived."""
    if not place or place < 1:
        return 0.04
    if place == 1:
        return 1.0
    e = max(entry or 2, 2)
    return max(0.04, min(1.0, 1 - math.log2(place) / math.log2(max(e, place + 1))))


def starts_label(n: int) -> str:
    """Polish plural for 'start': 1 start, 2–4 starty, 5+ startów."""
    if n == 1:
        return "1 start"
    if n % 10 in (2, 3, 4) and n % 100 not in (12, 13, 14):
        return f"{n} starty"
    return f"{n} startów"


def medal_col(place: int | None) -> str:
    return {1: GOLD, 2: SILVER, 3: BRONZE, 4: BRONZE}.get(place or 0, GREY)


def esc(s: Any) -> str:
    return html.escape(str(s if s is not None else ""))


# --------------------------------------------------------------------------- #
# Data assembly
# --------------------------------------------------------------------------- #
def _blank_tier() -> dict[str, Any]:
    return {"n": 0, "best": None, "reach": 0.0, "medal": 0}


def _add(rec: dict, place, entry) -> None:
    rec["n"] += 1
    rec["reach"] = max(rec["reach"], reach(place, entry))
    if place and (rec["best"] is None or place < rec["best"]):
        rec["best"] = place
    if place and place <= 3:
        rec["medal"] += 1


def collect(reports: Path) -> dict[str, Any]:
    """Read every report directory into per-fencer, per-weapon structures."""
    ind: Any = defaultdict(lambda: defaultdict(lambda: defaultdict(_blank_tier)))
    team: Any = defaultdict(lambda: defaultdict(
        lambda: {r: {"legs": 0, "net": 0, "sc": 0, "co": 0} for r in ROLES}))
    rez: Any = defaultdict(lambda: defaultdict(
        lambda: {"legs": 0, "net": 0, "sc": 0, "co": 0}))
    matches: Any = defaultdict(lambda: defaultdict(dict))
    ranks: Any = defaultdict(lambda: defaultdict(lambda: {"evf": [], "spws": []}))

    def load_individual(pattern: str, tier_of) -> None:
        for f in glob.glob(str(reports / pattern)):
            for fe in json.loads(Path(f).read_text(encoding="utf-8")).get("fencers", []):
                k = fold(fe["name"])
                for r in fe["results"]:
                    w = weapon_of(r.get("weapon"))
                    if w:
                        _add(ind[k][w][tier_of(r)], r.get("place"), r.get("entry"))

    load_individual("evf-individual/*.json", lambda r: RENAME.get(r["tier"], r["tier"]))
    load_individual("ftl-individual/*.json", lambda r: RENAME.get(r["tier"], r["tier"]))
    load_individual("spws-domestic/*.json",
                    lambda r: "MPW" if r.get("type") == "MPW" else r["tier"])

    for f in glob.glob(str(reports / "team-events/*.json")):
        d = json.loads(Path(f).read_text(encoding="utf-8"))
        if "tournaments" not in d:
            continue
        for t in d["tournaments"]:
            w = weapon_of(t.get("weapon"))
            if not w:
                continue
            for m in t.get("matches", []):
                n = len(m["legs"])
                url = f'{FTL}/teammatches/details/{t["eid"]}/{m["rid"]}/{m["match_id"]}'
                for lg in m["legs"]:
                    k = fold(lg["fencer"])
                    seq = n - lg["leg"]
                    role = ("Walka 1" if lg["leg"] == 1 else
                            "Walka 9" if seq == 0 else
                            "Walka 8" if seq == 1 else
                            "Walka 7" if seq == 2 else "Walki 2-6")
                    is_r = str(lg["pos"]).upper() == "R"
                    targets = [team[k][w][role]] + ([rez[k][w]] if is_r else [])
                    for tgt in targets:
                        tgt["legs"] += 1
                        tgt["net"] += lg["diff"]
                        tgt["sc"] += lg["scored"]
                        tgt["co"] += lg["conceded"]
                    row = matches[k][w].setdefault(url, {
                        "ch": d["championship"],
                        "tn": f'{t["category"]} {t["gender"]} {t["weapon"]}',
                        "opp": m["opponent"], "sc": m["country_score"],
                        "os": m["opp_score"], "won": m["won"], "stage": m["stage"],
                        "roles": set(), "legs": 0, "diff": 0, "u": url,
                        "date": t.get("date", ""), "rez": False})
                    row["roles"].add(role)
                    row["legs"] += 1
                    row["diff"] += lg["diff"]
                    row["rez"] = row["rez"] or is_r

    rp = reports / "ranking-positions/pol.json"
    if rp.exists():
        for fe in json.loads(rp.read_text(encoding="utf-8")).get("fencers", []):
            k = fold(fe["name"])
            for src in ("evf", "spws"):
                for row in fe.get(src) or []:
                    w = weapon_of(row.get("weapon"))
                    if w:
                        ranks[k][w][src].append(row)

    return {"ind": ind, "team": team, "rez": rez, "matches": matches, "ranks": ranks}


def build_cards(roster: list[dict], data: dict, fencer_db: list[dict]) -> list[dict]:
    """One card per (fencer, weapon) named in the roster."""
    from python.matcher.fuzzy_match import find_best_match

    cards: list[dict] = []
    unresolved: list[str] = []
    for person in roster:
        name = person["name"]
        m = find_best_match(name, fencer_db, use_diacritic_folding=True,
                            use_token_set_ratio=True)
        canonical = name
        if m.id_fencer is not None and m.status == "AUTO_MATCHED":
            f = next((x for x in fencer_db if x["id_fencer"] == m.id_fencer), {})
            canonical = f"{f.get('txt_surname', '')} {f.get('txt_first_name', '')}".strip()
        else:
            unresolved.append(f"{name} ({m.status}, {float(m.confidence or 0):.0f})")
        k = fold(canonical)

        weapons = [w for w in (weapon_of(x) for x in person.get("weapons") or []) if w]
        weapons = sorted(set(weapons)) or sorted(set(data["ind"][k]) | set(data["team"][k]))
        for w in weapons:
            ladder = {t: dict(data["ind"][k][w][t]) for t in LADDER
                      if data["ind"][k][w].get(t) and data["ind"][k][w][t]["n"]}
            troles = {r: data["team"][k][w][r] for r in ROLES
                      if data["team"][k][w][r]["legs"]}
            rows = sorted(data["matches"][k][w].values(),
                          key=lambda r: (r["date"], r["ch"]), reverse=True)
            for r in rows:
                r["roles"] = " + ".join(sorted(r["roles"], key=lambda x: ROLE_ORDER[x]))
            cards.append({
                "fencer": canonical, "roster_name": name, "weapon": w,
                "weapon_pl": WEAPON_PL[w], "status": person.get("status", ""),
                "ladder": ladder, "team": troles,
                "rez": dict(data["rez"][k][w]) if data["rez"][k][w]["legs"] else None,
                "ranks": data["ranks"][k][w], "matches": rows,
                "starts": sum(v["n"] for v in ladder.values()),
                "legs": sum(v["legs"] for v in troles.values()),
            })
    if unresolved:
        print(f"  unresolved roster names ({len(unresolved)}): "
              f"{', '.join(unresolved[:8])}", file=sys.stderr)
    return cards


# --------------------------------------------------------------------------- #
# Rendering
# --------------------------------------------------------------------------- #
def per_bout(v: dict) -> tuple[float, float]:
    n = max(v.get("legs", 0), 1)
    return v.get("sc", 0) / n, v.get("co", 0) / n


def ladder_svg(card: dict, idx: int) -> str:
    rows, defs, y = [], [], 0
    RH, LBL, BARW = 23, 78, 250
    for t in LADDER:
        d = card["ladder"].get(t)
        rows.append(f'<text x="{LBL - 8}" y="{y + 15}" text-anchor="end" class="rl" '
                    f'fill="{RUNG_COL[t]}">{t}</text>')
        rows.append(f'<rect x="{LBL}" y="{y + 4}" width="{BARW}" height="15" class="track"/>')
        if d:
            mc = medal_col(d["best"])
            gid = f'g{idx}{t.replace("+", "p").replace("-", "m")}'
            defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="0">'
                        f'<stop offset="0%" stop-color="{RUNG_COL[t]}" stop-opacity=".5"/>'
                        f'<stop offset="100%" stop-color="{mc}"/></linearGradient>')
            w = max(7, d["reach"] * BARW)
            rows.append(f'<rect x="{LBL}" y="{y + 4}" width="{w:.0f}" height="15" rx="2" '
                        f'fill="url(#{gid})"/>')
            x = LBL + w + 8
            rows.append(f'<text x="{x}" y="{y + 15}" class="star" fill="{mc}">★</text>')
            rows.append(f'<text x="{x + 13}" y="{y + 15}" class="pl">{d["best"] or "—"}</text>')
            rows.append(f'<text x="{RIGHT}" y="{y + 15}" text-anchor="end" class="cnt">'
                        f'{starts_label(d["n"])}</text>')
        else:
            rows.append(f'<text x="{LBL + 7}" y="{y + 15}" class="brak">BRAK</text>')
        y += RH
    return (f'<svg viewBox="0 0 {RIGHT + 6} {y}" class="chart"><defs>{"".join(defs)}</defs>'
            f'{"".join(rows)}</svg>')


def _row(label: str, d: dict, y: int, scale: float, faint: bool = False) -> list[str]:
    GL, GR, MAXW, H = 150, 268, 118, 16
    op = ' opacity=".7"' if faint else ""
    sc_pb, co_pb = per_bout(d)
    out = [f'<text x="{(GL + GR) / 2:.0f}" y="{y + 17}" text-anchor="middle" '
           f'class="rl2"{op}>{label}</text>']
    if d["co"]:
        w = min(1.0, co_pb / scale) * MAXW
        out.append(f'<rect x="{GL - w:.0f}" y="{y + 5}" width="{w:.0f}" height="{H}" '
                   f'rx="2" fill="{RED}"{op}/>')
        out.append(f'<text x="{GL - w - 6:.0f}" y="{y + 18}" text-anchor="end" '
                   f'class="cnt neg">−{d["co"]}</text>')
    if d["sc"]:
        w = min(1.0, sc_pb / scale) * MAXW
        out.append(f'<rect x="{GR}" y="{y + 5}" width="{w:.0f}" height="{H}" rx="2" '
                   f'fill="{GREEN}"{op}/>')
        out.append(f'<text x="{GR + w + 6:.0f}" y="{y + 18}" class="cnt pos">+{d["sc"]}</text>')
    out.append(f'<line x1="{GL - 2}" y1="{y + 3}" x2="{GL - 2}" y2="{y + H + 7}" class="axis"/>')
    out.append(f'<line x1="{GR + 2}" y1="{y + 3}" x2="{GR + 2}" y2="{y + H + 7}" class="axis"/>')
    out.append(f'<text x="{(GL + GR) / 2:.0f}" y="{y + 29}" text-anchor="middle" '
               f'class="legs">{d["legs"]}× walk · bilans {d["net"]:+d}</text>')
    return out


def team_svg(card: dict, scale: float) -> str:
    if not card["team"]:
        return (f'<svg viewBox="0 0 {RIGHT + 6} 40" class="chart"><text x="8" y="24" '
                f'class="brak">BRAK STARTÓW DRUŻYNOWYCH</text></svg>')
    rows, y, RH = [], 0, 38
    for r in ROLES:
        d = card["team"].get(r)
        if d:
            rows += _row(r, d, y, scale)
        else:
            cx = (150 + 268) / 2
            rows.append(f'<text x="{cx:.0f}" y="{y + 17}" text-anchor="middle" class="rl2" '
                        f'opacity=".45">{r}</text>')
            rows.append(f'<text x="{cx:.0f}" y="{y + 29}" text-anchor="middle" '
                        f'class="brak">BRAK</text>')
        y += RH
    if card.get("rez"):
        rows += _row("z REZERWY", card["rez"], y, scale, faint=True)
        y += RH
    return f'<svg viewBox="0 0 {RIGHT + 6} {y}" class="chart">{"".join(rows)}</svg>'


def rank_chips(card: dict) -> str:
    out = []
    for src, rows in (("EVF", card["ranks"].get("evf") or []),
                      ("SPWS", card["ranks"].get("spws") or [])):
        if not rows:
            out.append(f'<span class="rank rank-none">{src} — brak</span>')
            continue
        top = rows[0]
        dup = (' <span class="dup" title="EVF prowadzi dwa rekordy tego zawodnika '
               '— punkty rozbite">⚠</span>') if top.get("duplicate_records") else ""
        out.append(f'<span class="rank"><b>{src} #{top["pos"]}</b>'
                   f'<span class="of">/{top["of"]}</span> '
                   f'<span class="bkt">{esc(top["bucket"])}</span>{dup}</span>')
    return "".join(out)


def render(cards: list[dict], title: str, subtitle: str) -> str:
    scale = max([0.5] + [m for c in cards
                         for v in list(c["team"].values()) + ([c["rez"]] if c["rez"] else [])
                         for m in per_bout(v)])
    blocks, toc = [], []
    for i, c in enumerate(cards):
        anchor = f"k{i}"
        toc.append(f'<a class="tocitem" href="#{anchor}">'
                   f'<i style="background:{WEAPON_COL[c["weapon"]]}"></i>'
                   f'{esc(c["fencer"])} <span>{c["weapon_pl"]}</span></a>')
        rows = "".join(
            f'<tr><td class="d">{esc(m["ch"])}</td><td>{esc(m["tn"])}</td>'
            f'<td>{esc(m["stage"])}</td><td>{esc(m["opp"])}</td>'
            f'<td class="n">{esc(m["sc"])}–{esc(m["os"])}</td>'
            f'<td><span class="st {"s-ok" if m["won"] else "s-bad"}">'
            f'{"W" if m["won"] else "P"}</span></td>'
            f'<td class="rr">{esc(m["roles"])}{" · rez." if m["rez"] else ""}</td>'
            f'<td class="n">{m["legs"]}</td>'
            f'<td class="n"><span class="{"tpos" if m["diff"] > 0 else "tneg" if m["diff"] < 0 else ""}">'
            f'{m["diff"]:+d}</span></td>'
            f'<td><a href="{esc(m["u"])}" target="_blank">mecz ↗</a></td></tr>'
            for m in c["matches"][:20])
        tbl = (f'<h3>Mecze drużynowe — pełny zapis ze źródłem</h3><div class="tw"><table>'
               f'<thead><tr><th>Impreza</th><th>Turniej</th><th>Faza</th><th>Rywal</th>'
               f'<th>Wynik</th><th></th><th>Rola</th><th>Walk</th><th>Bilans</th>'
               f'<th>Źródło</th></tr></thead><tbody>{rows}</tbody></table></div>'
               ) if rows else '<p class="note">Brak startów drużynowych w analizowanym okresie.</p>'
        status = (f'<span class="tag">{esc(c["status"])}</span>' if c.get("status") else "")
        blocks.append(f"""
<section class="card" id="{anchor}">
  <div class="ch"><span class="wpn" style="background:{WEAPON_COL[c["weapon"]]}">{c["weapon_pl"]}</span>
    <h2>{esc(c["fencer"])}</h2>{status}{rank_chips(c)}</div>
  <div class="two">
    <div><h3>Zakres wyników — indywidualnie</h3>{ladder_svg(c, i)}
      <p class="note">Długość słupka = jak daleko zawodnik zaszedł w turnieju danej rangi:
      zwycięstwo wypełnia słupek, wczesne odpadnięcie zostawia go krótkim. Gwiazdka i liczba =
      najlepsze zajęte miejsce. Po prawej — liczba startów na tym poziomie,
      w wybranym oknie czasowym.</p></div>
    <div><h3>Role w drużynie</h3>{team_svg(c, scale)}
      <p class="note">W lewo (czerwone) — trafienia stracone, w prawo (zielone) — trafienia
      zdobyte. Liczby to trafienia łącznie, długość słupka — średnia na jedną walkę.
      Wejścia z rezerwy nakładają się na walki powyżej.</p></div>
  </div>
  {tbl}
</section>""")

    return f"""<!doctype html>
<html lang="pl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(title)}</title>
<style>
:root{{--navy:#173f70;--paper:#f4f7fb;--ink:#142033;--muted:#5b6b82;--line:#d5dfeb;--card:#fff;
--serif:"Iowan Old Style",Charter,Palatino Linotype,Georgia,serif;
--sans:Inter,system-ui,-apple-system,"Segoe UI",sans-serif;
--mono:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}}
@media(prefers-color-scheme:dark){{:root{{--paper:#131a24;--ink:#e8eef7;--muted:#95a6bd;
--line:#2a3748;--card:#1a2330;--navy:#7aa5da}}}}
*{{box-sizing:border-box}}
body{{margin:0;background:var(--paper);color:var(--ink);font-family:var(--sans);
font-size:14px;line-height:1.55}}
.page{{max-width:1180px;margin:0 auto;padding:0 18px 70px}}
.hd{{background:var(--card);border:1px solid var(--line);border-left:6px solid var(--navy);
padding:22px 24px;margin:26px 0 0}}
.eyebrow{{font-family:var(--mono);font-size:10px;letter-spacing:.13em;
text-transform:uppercase;color:var(--muted)}}
h1{{font-family:var(--serif);font-size:clamp(22px,4.6vw,31px);margin:8px 0 6px;
font-weight:600;letter-spacing:-.015em}}
.dek{{font-family:var(--serif);font-style:italic;color:var(--muted);margin:0;max-width:76ch}}
.keyrow{{display:flex;flex-wrap:wrap;gap:16px;margin:12px 0 0;font-family:var(--mono);
font-size:10px;color:var(--muted);align-items:center}}
.keyrow b{{font-size:13px}}
.toc{{background:var(--card);border:1px solid var(--line);border-radius:7px;
padding:14px 18px;margin:18px 0 0}}
.toclist{{display:flex;flex-wrap:wrap;gap:6px 14px}}
.tocitem{{font-family:var(--mono);font-size:10.5px;color:var(--ink);text-decoration:none;
white-space:nowrap}}
.tocitem span{{color:var(--muted);font-size:9px}}
.tocitem i{{display:inline-block;width:8px;height:8px;border-radius:2px;margin-right:5px}}
.tocitem:hover{{text-decoration:underline}}
.card{{background:var(--card);border:1px solid var(--line);border-radius:7px;
padding:18px 20px;margin:20px 0;scroll-margin-top:12px}}
.ch{{display:flex;align-items:center;gap:10px;flex-wrap:wrap;
border-bottom:1px solid var(--line);padding-bottom:10px;margin-bottom:14px}}
h2{{font-family:var(--serif);font-size:20px;margin:0;font-weight:600}}
.wpn{{font-family:var(--mono);font-size:11px;letter-spacing:.14em;font-weight:700;
color:#fff;padding:5px 12px;border-radius:3px}}
.tag{{font-family:var(--mono);font-size:9px;letter-spacing:.06em;color:var(--muted);
border:1px solid var(--line);background:var(--paper);padding:3px 8px;border-radius:3px}}
.rank{{font-family:var(--mono);font-size:10px;border:1px solid var(--line);border-radius:3px;
padding:3px 8px;color:var(--muted);background:var(--paper);white-space:nowrap}}
.rank b{{color:var(--ink)}} .rank .of{{opacity:.65}}
.rank .bkt{{font-size:8.5px;letter-spacing:.06em;opacity:.75}}
.rank-none{{opacity:.55}} .dup{{color:#c96a2e;font-weight:700}}
h3{{font-family:var(--mono);font-size:10.5px;letter-spacing:.12em;text-transform:uppercase;
color:var(--navy);margin:14px 0 8px;font-weight:600}}
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
.pos{{fill:{GREEN};font-weight:700}} .neg{{fill:{RED};font-weight:700}}
.note{{font-size:11px;color:var(--muted);margin:8px 0 0;line-height:1.5}}
.tw{{overflow-x:auto;border:1px solid var(--line);border-radius:5px}}
table{{border-collapse:collapse;width:100%;min-width:860px}}
th{{font-family:var(--mono);font-size:8.5px;letter-spacing:.1em;text-transform:uppercase;
color:var(--muted);text-align:left;padding:8px 10px;border-bottom:1px solid var(--line);
background:var(--paper)}}
td{{padding:7px 10px;border-bottom:1px solid var(--line);font-size:12px}}
td.d{{font-family:var(--mono);font-size:10px;color:var(--navy);white-space:nowrap}}
td.n{{font-family:var(--mono);text-align:right;white-space:nowrap}}
td.rr{{font-family:var(--mono);font-size:9.5px;color:var(--muted)}}
.st{{font-family:var(--mono);font-size:8.5px;padding:2px 6px;border-radius:2px;font-weight:600}}
.s-ok{{background:#cfe8d9;color:#1c5a3e}} .s-bad{{background:#f7d9d3;color:#9e3a29}}
.tpos{{color:{GREEN};font-weight:700}} .tneg{{color:{RED};font-weight:700}}
a{{color:var(--navy)}}
</style></head><body><div class="page">

<div class="hd">
  <div class="eyebrow">SPWS · {esc(subtitle)}</div>
  <h1>{esc(title)}</h1>
  <p class="dek">Jedna karta na zawodnika i broń. Pierwszy wykres pokazuje, <b>jak daleko</b>
  zawodnik zaszedł na każdym poziomie rangi zawodów; drugi — jakie <b>role</b> powierzano mu
  w meczu drużynowym i z jakim skutkiem. Każdy mecz drużynowy ma odnośnik do źródła.</p>
  <div class="keyrow">
    <span><b style="color:{GOLD}">★</b> 1. miejsce</span>
    <span><b style="color:{SILVER}">★</b> 2. miejsce</span>
    <span><b style="color:{BRONZE}">★</b> 3.–4. miejsce</span>
    <span><b style="color:{GREY}">★</b> pozostałe</span>
    <span>MSW = mistrzostwa świata · MEW = mistrzostwa Europy · MPW = mistrzostwa Polski</span>
  </div>
</div>

<div class="toc"><div class="toclist">{"".join(toc)}</div></div>

{"".join(blocks)}

</div></body></html>"""


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--roster", required=True, help="JSON: [{name, weapons, status}]")
    ap.add_argument("--reports", default="doc/reports")
    ap.add_argument("--title", default="Karty zawodników")
    ap.add_argument("--subtitle", default="karty zawodników")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    roster = json.loads(Path(args.roster).read_text(encoding="utf-8"))
    data = collect(Path(args.reports))

    from python.pipeline.db_connector import create_db_connector

    fencer_db = create_db_connector().fetch_fencer_db()
    cards = build_cards(roster, data, fencer_db)
    cards.sort(key=lambda c: (c["fencer"], c["weapon"]))

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render(cards, args.title, args.subtitle), encoding="utf-8")
    print(f"Wrote {out} — {len(cards)} card(s) for {len(roster)} fencer(s), "
          f"generated {dt.date.today().isoformat()}.", file=sys.stderr)


if __name__ == "__main__":
    main()
