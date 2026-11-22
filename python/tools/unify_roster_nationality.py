"""Keeps the roster's nationality to the EVF ranking (FR-172).

Plan doc/plans/roster-nationality-from-evf-2026-11-22.html (rev 3, N1–N9 signed
22 Nov 2026). The monthly EVF read (evf-ranking-sync.yml) keeps every ranked
fencer in tbl_evf_ranking_fencer (FR-171); then, in each environment, a roster
fencer takes EVF's country when:

* exactly one ranked fencer has the fencer's name (case and diacritics folded),
* of the same gender,
* whose EVF category is the one the fencer's birth year gives in the active
  season or the season before (the ranking may be a season behind),
* and EVF's code is a fencing code (EVF's OTH never is).

A fencer without a birth year is never changed (identity rests on it), and a
stored PL reads as POL. Each write names the fencer's id and the value it holds,
so a fencer changed in the meantime is left alone. Nothing that scores reads
the column, so a change queues no recompute (FR-172 N8).

Without --apply the tool only reads and prints what it would change.

Usage::

    python -m python.tools.unify_roster_nationality --env prod            # dry run
    python -m python.tools.unify_roster_nationality --env local --apply
"""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Callable, Iterable, Mapping, Sequence
from dataclasses import dataclass
from typing import Any

from python.matcher.fuzzy_match import normalize_name

Query = Callable[[str], str]


@dataclass(frozen=True)
class Change:
    id: int
    name: str
    old: str
    new: str


def _fold(value: str | None) -> str:
    return normalize_name(value or "", use_diacritic_folding=True)


def _category(birth_year: int, season_end: int) -> int:
    """The veteran category number (0 = V0 … 4 = V4) a year gives in a season."""
    return min(4, max(0, (season_end - birth_year) // 10 - 3))


def _code(value: str | None) -> str:
    code = (value or "").strip().upper()
    return "POL" if code == "PL" else code


def decide(
    roster: Iterable[Mapping[str, Any]],
    ranked: Iterable[Mapping[str, Any]],
    codes: set[str],
    season_end: int,
) -> list[Change]:
    """Every roster fencer whose nationality differs from its one EVF match."""
    by_name: dict[tuple[str, str], list[Mapping[str, Any]]] = {}
    for e in ranked:
        by_name.setdefault((_fold(e["surname"]), _fold(e["first_name"])), []).append(e)

    out: list[Change] = []
    for f in roster:
        if f.get("birth_year") is None:
            continue
        by = int(f["birth_year"])
        ours = {_category(by, season_end), _category(by, season_end - 1)}
        found = [
            e
            for e in by_name.get((_fold(f["surname"]), _fold(f["first_name"])), [])
            if str(e["gender"]) == str(f["gender"])
        ]
        if len(found) != 1 or int(found[0]["category"]) not in ours:
            continue
        new = str(found[0]["country"])
        old = str(f["nationality"])
        if new not in codes or new == _code(old):
            continue
        out.append(Change(int(f["id"]), f"{f['surname']} {f['first_name']}", old, new))
    return out


def read_sql() -> str:
    """One row, one column `j`: the active season's end year, the roster, the
    ranked fencers and the fencing codes, as JSON text."""
    return (
        "SELECT jsonb_build_object("
        "'season_end', (SELECT substring(s.txt_code FROM '(\\d{4})$')::INT FROM tbl_season s "
        "WHERE s.id_season = fn_active_season_id()), "
        "'fencers', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', id_fencer, "
        "'surname', txt_surname, 'first_name', txt_first_name, 'gender', enum_gender, "
        "'birth_year', int_birth_year, 'nationality', txt_nationality) ORDER BY id_fencer), '[]') "
        "FROM tbl_fencer), "
        "'evf', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', id_evf, 'surname', txt_surname, "
        "'first_name', txt_first_name, 'gender', enum_gender, 'category', int_category, "
        "'country', txt_country)), '[]') FROM tbl_evf_ranking_fencer), "
        "'codes', (SELECT coalesce(jsonb_agg(txt_code), '[]') FROM tbl_fencing_country)"
        ")::TEXT AS j"
    )


def apply_sql(changes: Sequence[Change]) -> str | None:
    """One statement for every change; each row only while it still holds the
    value read. Returns the changed rows as JSON text in column `j`."""
    if not changes:
        return None
    values = ", ".join(f"({c.id}, '{c.old}', '{c.new}')" for c in changes)
    return (
        "WITH u AS (UPDATE tbl_fencer f SET txt_nationality = v.new "
        f"FROM (VALUES {values}) AS v(id, old, new) "
        "WHERE f.id_fencer = v.id AND f.txt_nationality = v.old "
        "RETURNING f.id_fencer, v.old, f.txt_nationality) "
        "SELECT coalesce(jsonb_agg(u ORDER BY u.id_fencer), '[]')::TEXT AS j FROM u"
    )


def unify(query: Query, *, apply: bool) -> tuple[list[Change], list[dict[str, Any]]]:
    """Read, decide and (with apply) write; returns the decisions and the rows changed."""
    data = json.loads(query(read_sql()))
    if not isinstance(data, dict) or data.get("season_end") is None:
        raise RuntimeError("no active season, or the roster could not be read")
    changes = decide(data["fencers"], data["evf"], set(data["codes"]), int(data["season_end"]))
    sql = apply_sql(changes) if apply else None
    changed: list[dict[str, Any]] = json.loads(query(sql)) if sql else []
    return changes, changed


def describe(changes: Sequence[Change], changed: Sequence[Mapping[str, Any]]) -> list[str]:
    """One line per changed fencer: id, name, old → new."""
    names = {c.id: c.name for c in changes}
    return [
        f"{row['id_fencer']} {names.get(int(row['id_fencer']), '')} {row['old']}→{row['txt_nationality']}"
        for row in changed
    ]


def main(argv: Sequence[str] | None = None) -> None:
    from python.tools.fill_registration_country import (  # pyright: ignore[reportPrivateUsage]
        _cloud,
        _local,
    )

    parser = argparse.ArgumentParser(
        description="Keep the roster's nationality to the EVF ranking (FR-172)."
    )
    _ = parser.add_argument("--env", choices=("local", "cert", "prod"), default="local")
    _ = parser.add_argument(
        "--apply", action="store_true", help="write; without it nothing is written"
    )
    args = parser.parse_args(argv)
    query = _local if args.env == "local" else _cloud(args.env)
    changes, changed = unify(query, apply=args.apply)
    for c in changes:
        print(f"{c.id} {c.name}: {c.old} → {c.new}")
    print(f"{args.env}: would change {len(changes)}")
    if args.apply:
        for line in describe(changes, changed):
            print(f"changed {line}")
        print(f"{args.env}: changed {len(changed)}")


if __name__ == "__main__":
    main(sys.argv[1:])
