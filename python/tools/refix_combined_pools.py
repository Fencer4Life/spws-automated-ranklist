"""Re-fix EVF combined-category tournament results using the EVF API.

Audit (2026-04-28) found 17 EVF combined-pool groups (16 PEW + 1 MEW) whose
`tbl_tournament` rows for one shared `url_results` cover multiple
`enum_age_category` values but contain a mix of fencers from BOTH categories
in each row, with duplicate (place, score) tuples. The original splitter
stripped the FTL category marker before partitioning, so every fencer landed
in every category row.

For EVF events we have a clean source of truth: the EVF API returns
results already split by competition (one row per fencer per weapon+category)
with authoritative `place` and `entry` (true field size including foreign
fencers). Only POL fencers are inserted into our DB (per ADR-038); foreign
fencers still count toward `entry` for participant scoring.

Domestic PPW/MPW groups are NOT handled here — different mechanics (no EVF
API, FTL marker / birth-year fallback). See Goal 4 plan.

Usage:
    python -m python.tools.refix_combined_pools --env LOCAL [--dry-run] [--only 462,456]
    python -m python.tools.refix_combined_pools --env CERT  [--dry-run]
    python -m python.tools.refix_combined_pools --env PROD  [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass

import httpx

from python.matcher.fuzzy_match import find_best_match
from python.scrapers.evf_results import (
    CATEGORY_MAP,
    EvfApiClient,
)


CERT_REF = "sdomfjncmfydlkygzpgw"
PROD_REF = "ywgymtgcyturldazcpmw"

# Wide scan window covering SPWS-2022-2023 through SPWS-2025-2026.
EVF_SCAN_START = "2022-09-01"
EVF_SCAN_END = "2026-09-01"
EVF_SCAN_RANGE = (1, 160)
EVF_DATE_TOLERANCE_DAYS = 3

# EVF weaponId → (weapon, gender). Men's: 1=FOIL, 2=EPEE, 3=SABRE.
# Women's: 4=FOIL, 5=EPEE, 6=SABRE. Verified empirically from get_results
# weapon_abbr (MF/ME/MS/WF/WE/WS).
EVF_WEAPON_GENDER = {
    1: ("FOIL", "M"), 2: ("EPEE", "M"), 3: ("SABRE", "M"),
    4: ("FOIL", "F"), 5: ("EPEE", "F"), 6: ("SABRE", "F"),
}


# ---------------------------------------------------------------------------
# Backend abstraction (LOCAL psql vs Management API)
# ---------------------------------------------------------------------------
class Backend:
    def query(self, sql: str) -> list:
        raise NotImplementedError

    def execute(self, sql: str) -> None:
        raise NotImplementedError


class LocalBackend(Backend):
    """Talk to LOCAL Supabase via docker exec psql."""

    def query(self, sql: str) -> list:
        import subprocess
        cmd = [
            "docker", "exec", "supabase_db_SPWSranklist",
            "psql", "-U", "postgres", "-d", "postgres", "-At", "-F\x1f", "-c", sql,
        ]
        out = subprocess.check_output(cmd, text=True)
        rows = []
        for line in out.strip().splitlines():
            if not line:
                continue
            rows.append(line.split("\x1f"))
        return rows

    def execute(self, sql: str) -> None:
        import subprocess
        cmd = [
            "docker", "exec", "-i", "supabase_db_SPWSranklist",
            "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1",
        ]
        subprocess.run(cmd, input=sql, text=True, check=True)


class ManagementBackend(Backend):
    """Talk to CERT/PROD via Supabase Management API /database/query."""

    def __init__(self, project_ref: str):
        self.project_ref = project_ref
        self.token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
        if not self.token:
            raise RuntimeError("SUPABASE_ACCESS_TOKEN not set")
        self.endpoint = (
            f"https://api.supabase.com/v1/projects/{project_ref}/database/query"
        )

    def _post(self, sql: str) -> list:
        r = httpx.post(
            self.endpoint,
            headers={"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"},
            json={"query": sql},
            timeout=120,
        )
        r.raise_for_status()
        return r.json()

    def query(self, sql: str) -> list:
        return self._post(sql)

    def execute(self, sql: str) -> None:
        self._post(sql)


# ---------------------------------------------------------------------------
# Domain logic
# ---------------------------------------------------------------------------
@dataclass
class GroupRow:
    url: str
    dt: str
    weapon: str
    gender: str
    tournaments: list[dict]  # [{id, code, cat}, ...]


def fetch_combined_groups(b: Backend) -> list[GroupRow]:
    sql = """
    WITH dup AS (
      SELECT t.url_results, t.dt_tournament,
             t.enum_weapon::TEXT AS w, t.enum_gender::TEXT AS g
        FROM tbl_tournament t
        JOIN tbl_event e ON e.id_event = t.id_event
       WHERE (e.txt_code LIKE 'PEW%' OR e.txt_code LIKE 'IMEW%')
         AND t.url_results IS NOT NULL AND t.url_results <> ''
       GROUP BY t.url_results, t.dt_tournament, t.enum_weapon, t.enum_gender
      HAVING COUNT(*) > 1 AND COUNT(DISTINCT t.enum_age_category) > 1
    )
    SELECT json_agg(row_to_json(x))
      FROM (
        SELECT d.url_results AS url, d.dt_tournament::TEXT AS dt, d.w, d.g,
               json_agg(json_build_object(
                 'id', t.id_tournament,
                 'code', t.txt_code,
                 'cat', t.enum_age_category::TEXT,
                 'evf_comp', t.id_evf_competition
               ) ORDER BY t.enum_age_category::TEXT) AS tournaments
          FROM dup d
          JOIN tbl_tournament t
            ON t.url_results = d.url_results
           AND t.dt_tournament = d.dt_tournament
           AND t.enum_weapon::TEXT = d.w
           AND t.enum_gender::TEXT = d.g
         GROUP BY d.url_results, d.dt_tournament, d.w, d.g
      ) x;
    """
    rows = b.query(sql)
    if not rows:
        return []
    if isinstance(rows[0], dict):
        payload = rows[0].get("json_agg")
    else:
        payload = json.loads(rows[0][0]) if rows[0][0] else None
    if not payload:
        return []
    out: list[GroupRow] = []
    for r in payload:
        out.append(GroupRow(
            url=r["url"], dt=r["dt"], weapon=r["w"], gender=r["g"],
            tournaments=[
                {"id": t["id"], "code": t["code"], "cat": t["cat"],
                 "evf_comp": t.get("evf_comp")}
                for t in r["tournaments"]
            ],
        ))
    return out


def fetch_fencer_db(b: Backend) -> list[dict]:
    sql = "SELECT id_fencer, txt_surname, txt_first_name, int_birth_year FROM tbl_fencer;"
    rows = b.query(sql)
    if not rows:
        return []
    if isinstance(rows[0], dict):
        return [
            {
                "id_fencer": r.get("id_fencer"),
                "txt_surname": r.get("txt_surname"),
                "txt_first_name": r.get("txt_first_name"),
                "int_birth_year": r.get("int_birth_year"),
            }
            for r in rows
        ]
    out = []
    for r in rows:
        out.append({
            "id_fencer": int(r[0]) if r[0] else None,
            "txt_surname": r[1],
            "txt_first_name": r[2],
            "int_birth_year": int(r[3]) if r[3] and r[3] != "" else None,
        })
    return out


# ---------------------------------------------------------------------------
# EVF resolution
# ---------------------------------------------------------------------------
class EvfCompCache:
    """One-shot ID scan that captures every competition's (date, weapon,
    gender, category) → comp_id mapping. EVF events span 1-3 days; matching
    is done at the competition level with ±3 day tolerance against our
    `dt_tournament`.
    """

    def __init__(self, client: EvfApiClient):
        self._client = client
        # entries: list of (date_str, weapon, gender, category, comp_id, total)
        self._entries: list[tuple] = []
        self._loaded = False

    def _load(self) -> None:
        if self._loaded:
            return
        lo, hi = EVF_SCAN_RANGE
        print(f"  … scanning EVF event IDs {lo}-{hi} (one-time)…", file=sys.stderr)
        for eid in range(lo, hi):
            try:
                comps = self._client.get_competitions(eid)
            except Exception:
                continue
            if not comps:
                continue
            # event-level filter: skip if all comps fall outside the season window
            keep = [c for c in comps if EVF_SCAN_START <= str(c.get("starts", "")) <= EVF_SCAN_END]
            if not keep:
                continue
            for c in comps:
                wid = c.get("weaponId")
                cat = CATEGORY_MAP.get(c.get("categoryId"))
                wg = EVF_WEAPON_GENDER.get(wid)
                if not wg or not cat:
                    continue
                weapon, gender = wg
                starts = str(c.get("starts", ""))
                if not starts or starts < EVF_SCAN_START or starts > EVF_SCAN_END:
                    continue
                self._entries.append((
                    starts, weapon, gender, cat,
                    int(c["id"]), int(c.get("total") or 0),
                ))
        self._loaded = True
        print(f"  … cached {len(self._entries)} EVF competitions", file=sys.stderr)

    def find_comp(self, date: str, weapon: str, gender: str, category: str) -> tuple[int, int] | None:
        """Return (comp_id, total) for the closest matching competition.

        Tolerance: |dt - starts| <= EVF_DATE_TOLERANCE_DAYS.
        """
        self._load()
        from datetime import date as date_cls
        try:
            target = date_cls.fromisoformat(date)
        except ValueError:
            return None
        best: tuple | None = None
        best_delta = 99
        for starts, w, g, cat, comp_id, total in self._entries:
            if w != weapon or g != gender or cat != category:
                continue
            try:
                d = date_cls.fromisoformat(starts)
            except ValueError:
                continue
            delta = abs((d - target).days)
            if delta <= EVF_DATE_TOLERANCE_DAYS and delta < best_delta:
                best = (comp_id, total)
                best_delta = delta
        return best


def resolve_via_evf(
    group: GroupRow,
    fencer_db: list[dict],
    client: EvfApiClient,
    cache: EvfCompCache,
) -> dict[str, dict] | None:
    """Resolve one group's per-category placements via EVF API.

    Returns {"V1": {"entry": int, "placements": [{id_fencer, place, scraped_name}]}}.
    None if no comp matches any tournament in the group.
    """
    out: dict[str, dict] = {}
    for t in group.tournaments:
        target_cat = t["cat"]
        # Prefer the FK on the tournament row when set — deterministic, no
        # date-window guessing. Fall back to the cache lookup when NULL
        # (legacy rows pre-backfill).
        comp_id: int | None = None
        comp_total = 0
        if t.get("evf_comp"):
            comp_id = int(t["evf_comp"])
        else:
            match = cache.find_comp(group.dt, group.weapon, group.gender, target_cat)
            if match is None:
                print(f"    ! no EVF comp for T#{t['id']} {group.weapon}/{group.gender}/{target_cat} on {group.dt}", file=sys.stderr)
                continue
            comp_id, comp_total = match

        try:
            results = client.get_results(comp_id)
        except Exception as e:
            print(f"    ! get_results({comp_id}) failed: {e}", file=sys.stderr)
            continue

        entry = comp_total or len(results)

        placements = []
        for r in results:
            if r.get("country_abbr", "") != "POL":
                continue
            surname = r.get("fencer_surname", "")
            firstname = r.get("fencer_firstname", "")
            name = f"{surname} {firstname}".strip()
            if not name:
                continue
            m = find_best_match(name, fencer_db, use_diacritic_folding=True)
            if not m or not m.id_fencer or m.confidence < 85:
                conf = m.confidence if m else "?"
                print(f"    skip (no match): {name} conf={conf}", file=sys.stderr)
                continue
            placements.append({
                "id_fencer": m.id_fencer,
                "place": int(r.get("place") or 0),
                "scraped_name": name,
            })

        out[target_cat] = {
            "entry": entry,
            "placements": placements,
            "tournament_id": t["id"],
            "comp_id": comp_id,
        }
    return out


def emit_sql(group: GroupRow, by_cat: dict[str, dict]) -> str:
    """One transaction per group: DELETE everything in the group, then
    UPDATE participant counts and INSERT placements per matched category."""
    parts = ["BEGIN;"]
    tids_csv = ",".join(str(t["id"]) for t in group.tournaments)
    parts.append(
        f"DELETE FROM tbl_match_candidate WHERE id_result IN "
        f"(SELECT id_result FROM tbl_result WHERE id_tournament IN ({tids_csv}));"
    )
    parts.append(f"DELETE FROM tbl_result WHERE id_tournament IN ({tids_csv});")
    for t in group.tournaments:
        bucket = by_cat.get(t["cat"])
        if not bucket:
            continue
        parts.append(
            f"UPDATE tbl_tournament SET int_participant_count = {bucket['entry']} "
            f"WHERE id_tournament = {t['id']};"
        )
        for p in bucket["placements"]:
            safe = p["scraped_name"].replace("$", "")
            parts.append(
                f"INSERT INTO tbl_result (id_fencer, id_tournament, int_place, "
                f"txt_scraped_name) VALUES ("
                f"{p['id_fencer']}, {t['id']}, {p['place']}, $tag${safe}$tag$);"
            )
        parts.append(f"SELECT fn_calc_tournament_scores({t['id']});")
    parts.append("COMMIT;")
    return "\n".join(parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--env", choices=["LOCAL", "CERT", "PROD"], required=True)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", help="Comma-separated tournament IDs to limit to")
    args = ap.parse_args()

    if args.env == "LOCAL":
        b: Backend = LocalBackend()
    elif args.env == "CERT":
        b = ManagementBackend(CERT_REF)
    else:
        b = ManagementBackend(PROD_REF)

    print(f"[{args.env}] fetching combined-pool groups…")
    groups = fetch_combined_groups(b)
    print(f"[{args.env}] {len(groups)} EVF combined-pool group(s) found")

    if args.only:
        keep = {int(x.lstrip("T#")) for x in args.only.split(",") if x.strip().lstrip("T#").isdigit()}
        groups = [g for g in groups if any(t["id"] in keep for t in g.tournaments)]
        print(f"[{args.env}] limited to {len(groups)} group(s) via --only")

    if not groups:
        print(f"[{args.env}] nothing to do")
        return

    print(f"[{args.env}] fetching fencer DB…")
    fencer_db = fetch_fencer_db(b)
    print(f"[{args.env}] {len(fencer_db)} fencers loaded")

    client = EvfApiClient()
    client.connect()
    cache = EvfCompCache(client)

    fixed = 0
    skipped = 0
    try:
        for i, g in enumerate(groups, start=1):
            print(f"[{args.env}] ({i}/{len(groups)}) {g.dt} {g.weapon} {g.gender}")
            for t in g.tournaments:
                print(f"    T#{t['id']} {t['code']} ({t['cat']})")
            by_cat = resolve_via_evf(g, fencer_db, client, cache)
            if by_cat is None or not by_cat:
                skipped += 1
                continue
            for cat, bucket in sorted(by_cat.items()):
                print(f"    {cat}: entry={bucket['entry']} placements={len(bucket['placements'])} (comp {bucket['comp_id']})")
            sql = emit_sql(g, by_cat)
            if args.dry_run:
                print("    --- SQL (dry-run) ---")
                print(sql)
                print("    --- end SQL ---")
            else:
                try:
                    b.execute(sql)
                    fixed += 1
                except Exception as e:
                    print(f"    ! apply failed: {e}", file=sys.stderr)
    finally:
        client.close()

    print(f"[{args.env}] done — {fixed} group(s) re-fixed, {skipped} skipped")


if __name__ == "__main__":
    main()
