"""The monthly read of the EVF ranking: given names (FR-167) and ranked fencers (FR-171).

The registration form asks a newcomer whether the two name fields are reversed
when the surname box holds a known given name and the given-name box does not.
Known given names are our fencer table's, read live, and the EVF ranking's,
held in tbl_common_given_name: insert-only, never deleted or updated (ON
CONFLICT DO NOTHING on the folded-name key), and that statement carries given
names only.

Since FR-171 the same read also keeps each ranked fencer's EVF id, surname,
given name, gender, category and country in tbl_evf_ranking_fencer (inserted or
updated by EVF id, never deleted), so an entry without a country can be filled
from it (python/tools/fill_registration_country.py). Never points, place or
birth date. Run monthly by .github/workflows/evf-ranking-sync.yml; a new EVF
name appears only when a new fencer first scores at a circuit event.

Since FR-172, after the ranked fencers each environment's roster is kept to them:
a roster fencer with exactly one EVF match takes EVF's country
(python/tools/unify_roster_nationality.py), and every change is reported.

Usage::

    python -m python.tools.extract_evf_given_names            # CERT and PROD
    python -m python.tools.extract_evf_given_names --env prod # one environment
    python -m python.tools.extract_evf_given_names --local    # LOCAL only (rehearsal)
    python -m python.tools.extract_evf_given_names --dry-run  # print the SQL only
    python -m python.tools.extract_evf_given_names --migration PATH  # given names as a migration
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import unicodedata
from collections import Counter
from collections.abc import Callable, Mapping, Sequence
from pathlib import Path
from typing import Any, NoReturn, Protocol

from python.tools import unify_roster_nationality as roster

# EVF weapon_id 1-6 (men's foil, épée, sabre; women's foil, épée, sabre) ×
# category_id 1-4: the 24 lists of the EVF ranking.
WEAPON_IDS = range(1, 7)
CATEGORY_IDS = range(1, 5)

Query = Callable[[str, str, str], list[dict[str, Any]]]
LocalQuery = Callable[[str], list[dict[str, Any]]]
Notify = Callable[[str], None]


class RankingClient(Protocol):
    def connect(self) -> None: ...

    def get_ranking_list(self, weapon_id: int, category_id: int) -> list[dict[str, Any]]: ...


def _fold(value: str) -> str:
    value = (
        value.replace("ł", "l")
        .replace("Ł", "L")
        .replace("ß", "ss")
        .replace("ø", "o")
        .replace("đ", "d")
    )
    nfd = unicodedata.normalize("NFD", value)
    return "".join(c for c in nfd if unicodedata.category(c) != "Mn").casefold().strip()


def _clean(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def _is_initials(value: str) -> bool:
    return all(len(word.rstrip(".")) <= 1 for word in value.split())


def given_names(rows: Sequence[Mapping[str, Any]]) -> list[str]:
    """The distinct given names of the ranking rows, in title case, sorted.

    Each fencer counts once. Left out: entries that are only initials, entries
    with digits or symbols, and strings that occur in the same rows more often
    as a surname than as a given name (the list only ever says „this is a
    given name”).
    """
    people: dict[object, Mapping[str, Any]] = {}
    for row in rows:
        _ = people.setdefault(row.get("id"), row)

    surnames: Counter[str] = Counter(
        _fold(_clean(str(p.get("name") or ""))) for p in people.values()
    )
    counts: Counter[str] = Counter()
    spellings: dict[str, Counter[str]] = {}
    for person in people.values():
        given = _clean(str(person.get("firstname") or ""))
        if not given or _is_initials(given) or re.search(r"[\d_,;/()]", given):
            continue
        key = _fold(given)
        counts[key] += 1
        spellings.setdefault(key, Counter())[given.title()] += 1

    kept = [spellings[k].most_common(1)[0][0] for k, n in counts.items() if surnames.get(k, 0) <= n]
    return sorted(kept, key=lambda n: (_fold(n), n))


def build_insert_sql(names: Sequence[str]) -> str:
    """One insert-only statement; RETURNING tells how many were new."""
    values = ", ".join("('{}', 'EVF')".format(n.replace("'", "''")) for n in names)
    return (
        f"INSERT INTO tbl_common_given_name (txt_name, txt_source) VALUES {values} "
        "ON CONFLICT (txt_name_key) DO NOTHING RETURNING txt_name"
    )


def ranking_fencers(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Each ranked fencer once (a fencer stands on one list per weapon), with
    exactly what FR-171 keeps: EVF id, names, gender, category, country as read."""
    people: dict[str, dict[str, Any]] = {}
    for row in rows:
        fid = str(row["id"])  # a UUID on every EVF row
        if fid in people:
            continue
        people[fid] = {
            "id": fid,
            "surname": _clean(str(row.get("name") or "")),
            "first_name": _clean(str(row.get("firstname") or "")),
            "gender": str(row.get("gender") or "").upper()[:1],
            "category": int(row["cat"]),
            "country": str(row.get("country") or "").upper(),
        }
    return list(people.values())


def _q(value: str) -> str:
    return "'{}'".format(value.replace("'", "''"))


def build_fencer_upsert_sql(fencers: Sequence[Mapping[str, Any]]) -> str:
    """One statement: a new fencer is inserted, a known one (by EVF id) updated;
    nothing is deleted. RETURNING tells how many rows were written."""
    values = ", ".join(
        f"({_q(str(f['id']))}, {_q(f['surname'])}, {_q(f['first_name'])}, {_q(f['gender'])}, "
        f"{int(f['category'])}, {_q(f['country'])})"
        for f in fencers
    )
    return (
        "INSERT INTO tbl_evf_ranking_fencer (id_evf, txt_surname, txt_first_name, enum_gender, "
        f"int_category, txt_country) VALUES {values} "
        "ON CONFLICT (id_evf) DO UPDATE SET txt_surname = EXCLUDED.txt_surname, "
        "txt_first_name = EXCLUDED.txt_first_name, enum_gender = EXCLUDED.enum_gender, "
        "int_category = EXCLUDED.int_category, txt_country = EXCLUDED.txt_country, ts_read = now() "
        "RETURNING id_evf"
    )


def read_ranking(client: RankingClient) -> list[dict[str, Any]]:
    """The 24 lists' rows, each tagged with its list: EVF rows carry no gender
    or category, so both come from the list read (weapon_id 1-3 men's, 4-6
    women's; category_id 1-4)."""
    client.connect()
    rows: list[dict[str, Any]] = []
    for weapon_id in WEAPON_IDS:
        gender = "M" if weapon_id <= 3 else "F"
        for category_id in CATEGORY_IDS:
            rows.extend(
                {**row, "weapon": weapon_id, "gender": gender, "cat": category_id}
                for row in client.get_ranking_list(weapon_id, category_id)
            )
    return rows


def _fail(notify: Notify, why: str) -> NoReturn:
    notify(f"EVF ranking sync FAILED: {why}")
    raise SystemExit(1)


def _statements(
    client: RankingClient, notify: Notify
) -> tuple[list[str], list[dict[str, Any]], str, str]:
    try:
        rows = read_ranking(client)
    except Exception as exc:  # noqa: BLE001 — any refusal is reported, never swallowed
        _fail(notify, f"the EVF ranking could not be read ({exc})")
    names = given_names(rows)
    if not names:
        _fail(notify, "the EVF ranking returned no names")
    fencers = ranking_fencers(rows)
    return names, fencers, build_insert_sql(names), build_fencer_upsert_sql(fencers)


def _one_j(rows: list[dict[str, Any]]) -> str:
    """The `j` column of a one-row answer (the roster rule's statements)."""
    if not rows or "j" not in rows[0]:
        raise RuntimeError("no answer")
    return str(rows[0]["j"])


def run(
    client: RankingClient, query: Query, token: str, refs: Mapping[str, str], notify: Notify
) -> dict[str, dict[str, int]]:
    """Read the 24 lists; send each environment the unseen given names, then the
    ranked fencers, then keep its roster's nationality to them (FR-172); report
    once, with the counts per environment and every roster change."""
    names, fencers, names_sql, fencers_sql = _statements(client, notify)
    report: dict[str, dict[str, int]] = {}
    lines: list[str] = []
    for env, ref in refs.items():
        try:
            added = len(query(ref, token, names_sql))
        except Exception as exc:  # noqa: BLE001
            _fail(notify, f"{env} refused the given names ({exc})")
        try:
            kept = len(query(ref, token, fencers_sql))
        except Exception as exc:  # noqa: BLE001
            _fail(notify, f"{env} refused the ranked fencers ({exc})")

        def env_query(sql: str, ref: str = ref) -> str:
            return _one_j(query(ref, token, sql))

        try:
            changes, changed = roster.unify(env_query, apply=True)
        except Exception as exc:  # noqa: BLE001
            _fail(notify, f"{env} refused the roster's countries ({exc})")
        report[env] = {"names": added, "fencers": kept, "roster": len(changed)}
        lines += [f"{env}: {line}" for line in roster.describe(changes, changed)]
    new = ", ".join(f"{env}: {r['names']}" for env, r in report.items())
    kept_all = ", ".join(f"{env}: {r['fencers']}" for env, r in report.items())
    unified = ", ".join(f"{env}: {r['roster']}" for env, r in report.items())
    notify(
        f"EVF ranking: {len(names)} given names, {len(fencers)} fencers read; "
        f"new given names — {new}; fencers kept — {kept_all}; "
        f"roster countries changed — {unified}" + "".join(f"\n{line}" for line in lines)
    )
    return report


def run_local(client: RankingClient, query: LocalQuery) -> dict[str, dict[str, int]]:
    """The same two statements against LOCAL only, for a rehearsal (no Telegram)."""

    def say(message: str) -> None:
        print(message)

    _names, _fencers, names_sql, fencers_sql = _statements(client, say)
    report = {"names": len(query(names_sql)), "fencers": len(query(fencers_sql))}

    def local_j(sql: str) -> str:
        return _one_j(query(sql))

    changes, changed = roster.unify(local_j, apply=True)
    for line in roster.describe(changes, changed):
        print(f"LOCAL: {line}")
    report["roster"] = len(changed)
    return {"LOCAL": report}


def _local_query(sql: str) -> list[dict[str, Any]]:
    """LOCAL through its container (never a host psql); one JSON row per returned row."""
    import json
    import subprocess

    wrapped = f"WITH w AS ({sql}) SELECT coalesce(jsonb_agg(w), '[]')::text FROM w;"
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
        input=wrapped,
        capture_output=True,
        text=True,
        check=False,
    )
    if done.returncode != 0:
        raise RuntimeError(done.stderr.strip())
    return json.loads(done.stdout.strip() or "[]")


def migration_text(names: Sequence[str]) -> str:
    return (
        "-- FR-167: the EVF ranking's given names, read on the date in this file's name\n"
        "-- by python -m python.tools.extract_evf_given_names --migration. Given names\n"
        "-- only. Kept up to date monthly by given-names-sync.yml (insert-only).\n"
        f"-- {len(names)} names.\n\n"
        + build_insert_sql(names)
        .replace(" RETURNING txt_name", "")
        .replace("VALUES (", "VALUES\n  (")
        .replace("), (", "),\n  (")
        + ";\n"
    )


def refs_for(env: str | None, environ: Mapping[str, str]) -> dict[str, str]:
    """The environments one run writes: --env cert or prod names one (its job
    holds that environment's write lane); without it, both."""
    names = {"cert": ["CERT"], "prod": ["PROD"]}.get(env or "", ["CERT", "PROD"])
    return {n: environ.get(f"SUPABASE_{n}_REF", "") for n in names}


def main(argv: Sequence[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="The EVF ranking's given names (FR-167) and ranked fencers (FR-171) into CERT and PROD."
    )
    _ = parser.add_argument("--dry-run", action="store_true", help="print the SQL; write nothing")
    _ = parser.add_argument("--local", action="store_true", help="write LOCAL only (a rehearsal)")
    _ = parser.add_argument(
        "--env", choices=("cert", "prod"), help="write one environment (default: both)"
    )
    _ = parser.add_argument(
        "--migration", type=Path, help="write the names as a migration file and stop"
    )
    args = parser.parse_args(argv)

    from python.scrapers._supabase import _management_query, _telegram
    from python.scrapers.evf_results import EvfApiClient
    from python.supabase_token import supabase_access_token

    bot, chat = os.environ.get("TELEGRAM_BOT_TOKEN", ""), os.environ.get("TELEGRAM_CHAT_ID", "")

    def notify(message: str) -> None:
        _telegram(bot, chat, message)

    client = EvfApiClient(request_delay=1.0)
    if args.local:
        print(run_local(client, _local_query))
        return
    if args.dry_run or args.migration:
        names = given_names(read_ranking(client)) if args.migration else []
        if args.migration:
            _ = args.migration.write_text(migration_text(names), encoding="utf-8")
            print(f"wrote {len(names)} names to {args.migration}")
        else:
            rows = read_ranking(client)
            print(build_insert_sql(given_names(rows)))
            print(build_fencer_upsert_sql(ranking_fencers(rows)))
        return

    refs = refs_for(args.env, os.environ)
    token = supabase_access_token()
    if not token or not all(refs.values()):
        need = ", ".join(f"SUPABASE_{n}_REF" for n in refs)
        _fail(notify, f"SUPABASE_ACCESS_TOKEN and {need} are required")
    added = run(client, _management_query, token, refs, notify)
    print(added)


if __name__ == "__main__":
    main(sys.argv[1:])
