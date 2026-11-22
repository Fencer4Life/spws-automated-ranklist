"""Fills the country of an event's entries that have none, from the EVF ranking (FR-171).

Plan doc/plans/evf-ranking-country-lomianki-2026-11-21.html (rev 1, D1–D6 A).
The monthly read keeps each ranked fencer's EVF id, names, gender, category and
country in tbl_evf_ranking_fencer (evf-ranking-sync.yml). The public ranking
publishes no birth date, so an entry takes a country only when:

* exactly one ranked fencer has its name (titles, case and diacritics folded),
* that fencer's gender is the entry's, and
* the fencer's EVF category is the one the entry's declared year gives in the
  event's season or the season before (the ranking may be a season behind).

A code that is not a fencing code (EVF's OTH) is never written, and an entry
that already has a country keeps it. Setting a country links nothing: identity
still rests on the birth year.

Without --apply the tool only reads and prints, per entry, what it would do.
With --apply it sends one statement that sets the countries on the entries that
still have none, and prints each row it changed.

Usage::

    python -m python.tools.fill_registration_country --event PEW5efs-2026-2027 --env local
    python -m python.tools.fill_registration_country --event PEW5efs-2026-2027 --env prod
    python -m python.tools.fill_registration_country --event PEW5efs-2026-2027 --env prod --apply
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections.abc import Callable, Iterable, Mapping, Sequence
from dataclasses import dataclass
from typing import Any

from python.matcher.fuzzy_match import normalize_name

Query = Callable[[str], str]
_EVENT_CODE = re.compile(r"^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$")


@dataclass(frozen=True)
class Decision:
    id: int
    name: str
    country: str | None  # the code to set, or None
    why: str
    evf_id: str | None = None  # EVF's fencer UUID


def _fold(value: str | None) -> str:
    return normalize_name(value or "", use_diacritic_folding=True)


def _category(birth_year: int, season_end: int) -> int:
    """The veteran category number (0 = V0 … 4 = V4) a year gives in a season."""
    return min(4, max(0, (season_end - birth_year) // 10 - 3))


def decide(
    entries: Iterable[Mapping[str, Any]],
    fencers: Iterable[Mapping[str, Any]],
    codes: set[str],
    season_end: int,
) -> list[Decision]:
    by_name: dict[tuple[str, str], list[Mapping[str, Any]]] = {}
    for f in fencers:
        by_name.setdefault((_fold(f["surname"]), _fold(f["first_name"])), []).append(f)

    out: list[Decision] = []
    for e in entries:
        rid, name = int(e["id"]), f"{e['surname']} {e['first_name']}"
        if e.get("country"):
            out.append(Decision(rid, name, None, f"nothing: keeps {e['country']}"))
            continue
        found = by_name.get((_fold(e["surname"]), _fold(e["first_name"])), [])
        if not found:
            out.append(Decision(rid, name, None, "nothing: not on the EVF ranking"))
            continue
        if len(found) > 1:
            out.append(
                Decision(
                    rid, name, None, f"nothing: several ranked fencers of this name ({len(found)})"
                )
            )
            continue
        f = found[0]
        fid = str(f["id"])
        if str(f["gender"]) != str(e["gender"]):
            out.append(Decision(rid, name, None, "nothing: the gender differs", fid))
            continue
        ours = {
            _category(int(e["birth_year"]), season_end),
            _category(int(e["birth_year"]), season_end - 1),
        }
        if int(f["category"]) not in ours:
            out.append(
                Decision(
                    rid,
                    name,
                    None,
                    f"nothing: EVF category {f['category']} differs from the declared year",
                    fid,
                )
            )
            continue
        code = str(f["country"])
        if code not in codes:
            out.append(
                Decision(rid, name, None, f"nothing: EVF says {code}, not a fencing code", fid)
            )
            continue
        out.append(Decision(rid, name, code, f"set {code}", fid))
    return out


def read_sql(event_code: str) -> str:
    """One row, one column `j`: the event's season end, its entries, the ranked
    fencers and the fencing codes, as JSON text."""
    if not _EVENT_CODE.match(event_code or ""):
        raise ValueError(f"not an exact event code: {event_code!r}")
    code = event_code
    return (
        "SELECT jsonb_build_object("
        "'season_end', (SELECT substring(s.txt_code FROM '(\\d{4})$')::INT FROM tbl_event e "
        f"JOIN tbl_season s USING (id_season) WHERE e.txt_code = '{code}'), "
        "'entries', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', r.id_registration, "
        "'surname', fn_name_without_title(r.txt_surname), 'first_name', r.txt_first_name, "
        "'gender', r.enum_gender, 'birth_year', r.int_birth_year, 'country', r.txt_country) "
        "ORDER BY r.id_registration), '[]') FROM tbl_registration r JOIN tbl_event e USING (id_event) "
        f"WHERE e.txt_code = '{code}'), "
        "'fencers', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', id_evf, 'surname', txt_surname, "
        "'first_name', txt_first_name, 'gender', enum_gender, 'category', int_category, "
        "'country', txt_country)), '[]') FROM tbl_evf_ranking_fencer), "
        "'codes', (SELECT coalesce(jsonb_agg(txt_code), '[]') FROM tbl_fencing_country)"
        ")::TEXT AS j"
    )


def apply_sql(decisions: Sequence[Decision]) -> str | None:
    """One statement for every entry to set; each row only while it still has
    no country. Returns the changed rows as JSON text in column `j`."""
    pairs = [(d.id, d.country) for d in decisions if d.country]
    if not pairs:
        return None
    values = ", ".join(f"({rid}, '{code}')" for rid, code in pairs)
    return (
        "WITH u AS (UPDATE tbl_registration r SET txt_country = v.c "
        f"FROM (VALUES {values}) AS v(id, c) "
        "WHERE r.id_registration = v.id AND r.txt_country IS NULL "
        "RETURNING r.id_registration, r.txt_country) "
        "SELECT coalesce(jsonb_agg(u ORDER BY u.id_registration), '[]')::TEXT AS j FROM u"
    )


def run(event_code: str, query: Query, *, apply: bool) -> list[Decision]:
    data = json.loads(query(read_sql(event_code)))
    if data.get("season_end") is None:
        print(f"no event {event_code}", file=sys.stderr)
        raise SystemExit(2)
    decisions = decide(
        data["entries"], data["fencers"], set(data["codes"]), int(data["season_end"])
    )
    for d in decisions:
        print(f"{d.id} {d.name}: {d.why}")
    to_set = [d for d in decisions if d.country]
    print(
        f"{event_code}: {len(decisions)} entries, {len(data['fencers'])} ranked fencers; would set {len(to_set)}"
    )
    if apply:
        sql = apply_sql(decisions)
        changed = json.loads(query(sql)) if sql else []
        for row in changed:
            print(f"set {row['id_registration']} {row['txt_country']}")
        print(f"{event_code}: set {len(changed)}")
    return decisions


def _local(sql: str) -> str:
    """LOCAL through its container, never a host psql."""
    done = subprocess.run(
        [
            "docker",
            "exec",
            "-i",
            "supabase_db_SPWSranklist",
            "psql",
            "-U",
            "postgres",
            "-At",
            "-v",
            "ON_ERROR_STOP=1",
        ],
        input=sql + ";",
        capture_output=True,
        text=True,
        check=False,
    )
    if done.returncode != 0:
        raise RuntimeError(done.stderr.strip())
    return done.stdout.strip()


def _cloud(env: str) -> Query:
    from python.scrapers._supabase import _management_query
    from python.supabase_token import supabase_access_token

    ref = os.environ.get(f"SUPABASE_{env.upper()}_REF", "")
    token = supabase_access_token()
    if not ref or not token:
        raise SystemExit(f"SUPABASE_ACCESS_TOKEN and SUPABASE_{env.upper()}_REF are required")

    def query(sql: str) -> str:
        rows = _management_query(ref, token, sql)
        return str(rows[0]["j"]) if rows else "[]"

    return query


def main(argv: Sequence[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Fill entries without a country from the EVF ranking (FR-171)."
    )
    _ = parser.add_argument(
        "--event", required=True, help="the event's exact code, e.g. PEW5efs-2026-2027"
    )
    _ = parser.add_argument("--env", choices=("local", "cert", "prod"), default="local")
    _ = parser.add_argument(
        "--apply", action="store_true", help="write; without it nothing is written"
    )
    args = parser.parse_args(argv)
    query = _local if args.env == "local" else _cloud(args.env)
    _ = run(args.event, query, apply=args.apply)


if __name__ == "__main__":
    main(sys.argv[1:])
