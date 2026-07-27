"""Scrape team-event relay data for a target country from an FTL eventSchedule.

Given a FencingTimeLive championship ``eventSchedule`` UUID this walks every team
tournament in the championship (weapon x gender x {Veteran, Grand Veteran}),
finds the target country's team in the pool round and in every elimination
bracket, and extracts the full relay (per-leg) detail of each of that team's
matches. It reuses the repo's authenticated FTL pipeline
(:mod:`python.scrapers.ftl_auth`) — see the ``ftl-scrape`` skill for the endpoint
map this is built on.

The output is a JSON data store (see :func:`empty_championship` for the shape):
championship -> tournaments[] -> matches[] -> legs[], plus a per-fencer
contribution profile aggregated per tournament and across the championship.

Usage::

    set -a; source .env; set +a
    python -m python.tools.scrape_team_events \\
        --schedule AEABBE82DD3A40C4B34F71492B60647D \\
        --name "MEW Cognac 2026" --country Poland \\
        --out doc/reports/team-events/mew-cognac-2026.json
"""

from __future__ import annotations

import argparse
import datetime as dt
import html as _html
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

import httpx
from python.scrapers.ftl_auth import get_authed_ftl_client, normalize_ftl_url

FTL = "https://www.fencingtimelive.com"

_TAG_RE = re.compile(r"<[^>]+>")
_ROW_RE = re.compile(r"<tr.*?</tr>", re.S)
_CELL_RE = re.compile(r"<t[dh].*?</t[dh]>", re.S)
_VD_RE = re.compile(r"\b([VD])(\d+)\b")


# --------------------------------------------------------------------------- #
# Pure parsers (no network — unit-testable against captured fixtures)
# --------------------------------------------------------------------------- #
def _text(s: str) -> str:
    t = _html.unescape(_TAG_RE.sub("", s))
    return re.sub(r"\s+", " ", t.replace("\xa0", " ")).strip()


def _cells(row_html: str) -> list[str]:
    return [_text(c) for c in _CELL_RE.findall(row_html)]


def parse_event_list(schedule_html: str) -> list[dict[str, str]]:
    """Extract the championship's tournaments: [{eid, name}] in page order."""
    out: list[dict[str, str]] = []
    seen: set[str] = set()
    for m in re.finditer(
        r'href=["\']/events/view/([0-9A-Fa-f]{32})["\'][^>]*>(.*?)</a>',
        schedule_html,
        re.S,
    ):
        eid = m.group(1).upper()
        if eid in seen:
            continue
        seen.add(eid)
        name = re.sub(r"^\d{1,2}:\d{2}\s*(?:AM|PM)?\s*", "", _text(m.group(2)))
        out.append({"eid": eid, "name": name})
    return out


def classify_event(name: str) -> dict[str, str]:
    """Parse 'Grand Veterans Women's Epee' -> category/weapon/gender."""
    low = name.lower()
    category = "Grand Veteran" if "grand vet" in low else "Veteran"
    weapon = (
        "Epee"
        if "epee" in low or "épée" in low
        else "Foil"
        if "foil" in low or "fleuret" in low
        else "Sabre"
        if "sabre" in low or "saber" in low
        else "?"
    )
    gender = "Women" if "women" in low or "female" in low else "Men"
    return {"category": category, "weapon": weapon, "gender": gender}


def parse_round_ids(results_html: str, eid: str) -> dict[str, str | None]:
    """From an event page, find the pool-round and tableau-round rids."""
    pool = re.search(rf"/pools/scores/{eid}/([0-9A-Fa-f]{{32}})", results_html, re.I)
    tab = re.search(rf"/tableaus/scores/{eid}/([0-9A-Fa-f]{{32}})", results_html, re.I)
    return {
        "pool_rid": pool.group(1).upper() if pool else None,
        "tableau_rid": tab.group(1).upper() if tab else None,
    }


def parse_pool_guids(pool_scores_html: str) -> list[str]:
    return sorted(
        {g.upper() for g in re.findall(r'id=["\']pool_([0-9A-Fa-f]{32})', pool_scores_html)}
    )


def parse_match_links(html: str, eid: str) -> list[tuple[str, str]]:
    """Return [(rid, match_id)] for every /teammatches/details link for ``eid``."""
    out: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for rid, mid in re.findall(
        rf"/teammatches/details/{eid}/([0-9A-Fa-f]{{32}})/([0-9A-Fa-f]{{32}})",
        html,
        re.I,
    ):
        key = (rid.upper(), mid.upper())
        if key not in seen:
            seen.add(key)
            out.append(key)
    return out


def parse_stage(match_page_html: str) -> str:
    """The round label from a match page's <h4 class="tmName"> (e.g. 'Bronze Medal')."""
    m = re.search(r'class="tmName">(.*?)</h4>', match_page_html, re.S)
    if not m:
        return ""
    label = _text(m.group(1))
    label = re.sub(r",?\s*Bout #\d+ of \d+\s*$", "", label).strip(" ,")
    return label


def parse_relay(fragment_html: str) -> dict[str, Any] | None:
    """Parse a /teammatches/details/.../data relay fragment.

    Returns team names, final scores (with V/D result flags) and the ordered
    list of legs, or ``None`` if the fragment is not a scored relay table.
    """
    rows = [c for c in (_cells(r) for r in _ROW_RE.findall(fragment_html)) if c]
    if not rows or len(rows[0]) < 8:
        return None
    hdr = rows[0]
    team_a, team_b = hdr[1], hdr[6]

    def _i(x: str) -> int | None:
        return int(x) if x.isdigit() else None

    legs: list[dict[str, Any]] = []
    for r in rows[1:]:
        # A leg row has a fencer name in col 1 and numeric cumulative scores in
        # cols 3-4. This tolerates FTL variants where the position columns are
        # blank (MSW World Champs) vs numbered (MEW / EVF).
        if len(r) >= 8 and r[1] and (r[3] or "").isdigit() and (r[4] or "").isdigit():
            legs.append(
                {
                    "pos_a": r[0], "name_a": r[1], "ts_a": _i(r[2]),
                    "cum_a": _i(r[3]), "cum_b": _i(r[4]), "ts_b": _i(r[5]),
                    "name_b": r[6], "pos_b": r[7],
                }
            )
    if not legs:
        return _parse_walkover(rows, team_a, team_b)
    toks = _VD_RE.findall(" ".join(rows[-1]))
    if len(toks) < 2:
        toks = _VD_RE.findall(" ".join(sum(rows, [])))[-2:]
    if len(toks) >= 2:
        res_a, score_a = toks[0][0], int(toks[0][1])
        res_b, score_b = toks[1][0], int(toks[1][1])
    else:
        # No V/D footer (bye / forfeit): fall back to the last leg's cumulative.
        score_a, score_b = legs[-1]["cum_a"], legs[-1]["cum_b"]
        res_a = "V" if (score_a or 0) > (score_b or 0) else "D"
        res_b = "V" if (score_b or 0) > (score_a or 0) else "D"
    return {
        "team_a": team_a, "team_b": team_b,
        "result_a": res_a, "score_a": score_a,
        "result_b": res_b, "score_b": score_b,
        "walkover": False, "note": "", "legs": legs,
    }


def _parse_walkover(
    rows: list[list[str]], team_a: str, team_b: str
) -> dict[str, Any] | None:
    """Handle a match with named line-ups but no fenced bouts (withdrawal / walkover).

    Reads the result from bare ``V``/``D`` flags and any status note, returning
    no legs — so a forfeited match is kept as context without inventing 0-0 legs
    that would pollute per-fencer statistics.
    """
    has_names = any(len(r) >= 7 and r[1] and r[6] for r in rows[1:])
    bare = [
        (r[3], r[4])
        for r in rows
        if len(r) >= 5 and r[3] in ("V", "D") and r[4] in ("V", "D")
    ]
    if not (has_names and bare):
        return None
    res_a, res_b = bare[-1]
    note = ""
    for r in rows:
        for cell in r:
            if re.search(r"withdrew|forfeit|walkover|excluded", cell, re.I):
                note = cell
    return {
        "team_a": team_a, "team_b": team_b,
        "result_a": res_a, "score_a": None,
        "result_b": res_b, "score_b": None,
        "walkover": True, "note": note, "legs": [],
    }


def relay_for_country(relay: dict[str, Any], country: str) -> dict[str, Any] | None:
    """Re-orient a parsed relay to the target country's perspective."""
    a = _name_is_country(relay["team_a"], country)
    b = _name_is_country(relay["team_b"], country)
    if not (a or b):
        return None
    opp = (relay["team_b"] if a else relay["team_a"]).replace(" Team", "").strip()
    legs: list[dict[str, Any]] = []
    src = relay["legs"]
    for i, lg in enumerate(src):
        pos = lg["pos_a"] if a else lg["pos_b"]
        fencer = lg["name_a"] if a else lg["name_b"]
        scored = (lg["ts_a"] if a else lg["ts_b"]) or 0
        conceded = (lg["ts_b"] if a else lg["ts_a"]) or 0
        legs.append(
            {
                "leg": i + 1, "pos": pos, "fencer": fencer,
                "scored": scored, "conceded": conceded, "diff": scored - conceded,
                "anchor": i == len(src) - 1,
            }
        )
    return {
        "opponent": opp,
        "country_score": relay["score_a"] if a else relay["score_b"],
        "opp_score": relay["score_b"] if a else relay["score_a"],
        "won": (relay["result_a"] if a else relay["result_b"]) == "V",
        "walkover": relay.get("walkover", False),
        "note": relay.get("note", ""),
        "legs": legs,
    }


def parse_seeding(seeding_json: list[dict[str, Any]], country: str) -> dict[str, Any]:
    """Detect a team event and the target team from /rounds/seeding/data."""
    is_team = any(t.get("mem") for t in seeding_json)
    tgt = next(
        (
            t
            for t in seeding_json
            if country.lower() in str(t.get("name", "")).lower()
            or str(t.get("country", "")).upper() in _country_codes(country)
        ),
        None,
    )
    return {
        "is_team": is_team,
        "present": tgt is not None,
        "roster": list(tgt.get("mem", [])) if tgt else [],
        "seed": tgt.get("seed") if tgt else None,
    }


def _country_codes(country: str) -> set[str]:
    return {"poland": {"POL"}}.get(country.lower(), set())


def _name_is_country(name: str, country: str) -> bool:
    """Match a team label that may be a full name ('Poland Team') or IOC code ('POL')."""
    if country.lower() in name.lower():
        return True
    return any(re.search(rf"\b{code}\b", name, re.I) for code in _country_codes(country))


def _html_has_country(html: str, country: str) -> bool:
    if country.lower() in html.lower():
        return True
    return any(re.search(rf"\b{code}\b", html, re.I) for code in _country_codes(country))


def blank_fencer() -> dict[str, Any]:
    return {"matches": 0, "legs": 0, "net": 0, "scored": 0, "conceded": 0,
            "anchor_legs": 0, "anchor_net": 0}


def fold_fencers(profile: dict[str, dict[str, Any]], matches: list[dict[str, Any]]) -> None:
    """Accumulate a per-fencer contribution profile from a list of country matches."""
    seen_match: dict[str, set[int]] = defaultdict(set)
    for mi, m in enumerate(matches):
        for lg in m["legs"]:
            f = profile.setdefault(lg["fencer"], blank_fencer())
            f["legs"] += 1
            f["net"] += lg["diff"]
            f["scored"] += lg["scored"]
            f["conceded"] += lg["conceded"]
            if lg["anchor"]:
                f["anchor_legs"] += 1
                f["anchor_net"] += lg["diff"]
            if mi not in seen_match[lg["fencer"]]:
                seen_match[lg["fencer"]].add(mi)
                f["matches"] += 1


# --------------------------------------------------------------------------- #
# Fetch + orchestration
# --------------------------------------------------------------------------- #
def _get(client: httpx.Client, url: str) -> httpx.Response:
    return client.get(normalize_ftl_url(url))


def scrape_event(
    client: httpx.Client, eid: str, name: str, country: str
) -> dict[str, Any]:
    """Scrape one tournament: the target country's pool + bracket relays."""
    rec: dict[str, Any] = {"eid": eid, "name": name, **classify_event(name)}
    rids = parse_round_ids(_get(client, f"{FTL}/events/results/{eid}").text, eid)
    rec["pool_rid"] = rids["pool_rid"]
    rec["tableau_rid"] = rids["tableau_rid"]

    seed_rid = rids["pool_rid"] or rids["tableau_rid"]
    if not seed_rid:
        rec.update(is_team=False, present=False, matches=[])
        return rec
    try:
        seeding = _get(client, f"{FTL}/rounds/seeding/data/{eid}/{seed_rid}").json()
    except (ValueError, httpx.HTTPError):
        seeding = []
    info = parse_seeding(seeding, country)
    rec.update(is_team=info["is_team"], present=info["present"],
               roster=info["roster"], seed=info["seed"])
    if not (info["is_team"] and info["present"]):
        rec["matches"] = []
        return rec

    matches: list[dict[str, Any]] = []

    # --- pool phase: only the pool that contains the target team ---
    if rids["pool_rid"]:
        prid = rids["pool_rid"]
        pool_html = _get(client, f"{FTL}/pools/scores/{eid}/{prid}").text
        for pg in parse_pool_guids(pool_html):
            bout = _get(client, f"{FTL}/pools/details/{eid}/{prid}/{pg}/data").text
            if not _html_has_country(bout, country):
                continue
            for rid, mid in parse_match_links(bout, eid):
                m = _scrape_match(client, eid, rid, mid, country, phase="Pool", stage="Pool")
                if m:
                    matches.append(m)

    # --- bracket phase: only trees that contain the target team ---
    if rids["tableau_rid"]:
        trid = rids["tableau_rid"]
        try:
            trees = _get(client, f"{FTL}/tableaus/scores/{eid}/{trid}/trees").json()
        except (ValueError, httpx.HTTPError):
            trees = []
        for tree in trees:
            guid, ntab = tree.get("guid"), tree.get("numTables", 0)
            if not guid:
                continue
            table = _get(
                client,
                f"{FTL}/tableaus/scores/{eid}/{trid}/trees/{guid}/tables/0/{ntab + 1}",
            ).text
            if not _html_has_country(table, country):
                continue
            for rid, mid in parse_match_links(table, eid):
                m = _scrape_match(client, eid, rid, mid, country,
                                  phase="Tableau", stage=str(tree.get("name", "")))
                if m:
                    matches.append(m)

    # de-dupe by match_id, aggregate
    uniq: dict[str, dict[str, Any]] = {m["match_id"]: m for m in matches}
    rec["matches"] = list(uniq.values())
    prof: dict[str, dict[str, Any]] = {}
    fold_fencers(prof, rec["matches"])
    rec["fencer_profile"] = prof
    return rec


def _scrape_match(
    client: httpx.Client, eid: str, rid: str, mid: str, country: str,
    *, phase: str, stage: str,
) -> dict[str, Any] | None:
    frag = _get(client, f"{FTL}/teammatches/details/{eid}/{rid}/{mid}/data").text
    relay = parse_relay(frag)
    if not relay:
        return None
    oriented = relay_for_country(relay, country)
    if not oriented:
        return None
    label = stage
    if phase == "Tableau":
        page = _get(client, f"{FTL}/teammatches/details/{eid}/{rid}/{mid}").text
        label = parse_stage(page) or stage
    return {"match_id": mid, "rid": rid, "phase": phase, "stage": label, **oriented}


def empty_championship(name: str, sched: str, country: str) -> dict[str, Any]:
    return {
        "championship": name,
        "schedule_uuid": sched,
        "source_url": f"{FTL}/tournaments/eventSchedule/{sched}",
        "country": country,
        "scraped_at": dt.datetime.now(dt.UTC).isoformat(),
        "tournaments": [],
        "country_profile": {},
    }


def scrape_championship(
    client: httpx.Client, sched: str, name: str, country: str
) -> dict[str, Any]:
    out = empty_championship(name, sched, country)
    events = parse_event_list(_get(client, f"{FTL}/tournaments/eventSchedule/{sched}").text)
    print(f"{name}: {len(events)} tournaments", file=sys.stderr)
    champ_profile: dict[str, dict[str, Any]] = {}
    for ev in events:
        rec = scrape_event(client, ev["eid"], ev["name"], country)
        tag = "team" if rec.get("is_team") else "individual"
        if rec.get("is_team") and rec.get("present"):
            wins = sum(1 for m in rec["matches"] if m["won"])
            print(
                f"  ✓ {ev['name']:34s} {len(rec['matches'])} match(es), "
                f"{wins}W-{len(rec['matches']) - wins}L",
                file=sys.stderr,
            )
            fold_fencers(champ_profile, rec["matches"])
        else:
            reason = "no PL team" if rec.get("is_team") else tag
            print(f"  – {ev['name']:34s} skipped ({reason})", file=sys.stderr)
        out["tournaments"].append(rec)
    out["country_profile"] = champ_profile
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--schedule", required=True, help="eventSchedule UUID (32 hex)")
    ap.add_argument("--name", required=True, help="Human label, e.g. 'MEW Cognac 2026'")
    ap.add_argument("--country", default="Poland")
    ap.add_argument("--out", required=True, help="Output JSON path")
    args = ap.parse_args()

    with get_authed_ftl_client(timeout=30.0) as client:
        data = scrape_championship(client, args.schedule.upper(), args.name, args.country)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    teams = [t for t in data["tournaments"] if t.get("present") and t.get("is_team")]
    total = sum(len(t["matches"]) for t in teams)
    print(
        f"\nWrote {out} — {len(teams)} {args.country} team(s), {total} matches, "
        f"{len(data['country_profile'])} fencers.",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
