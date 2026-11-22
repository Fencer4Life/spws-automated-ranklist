"""The read of the EVF ranking: given names (FR-167), ranked fencers (FR-171), places (FR-174).

The registration form asks a newcomer whether the two name fields are reversed
when the surname box holds a known given name and the given-name box does not.
Known given names are our fencer table's, read live, and the EVF ranking's,
held in tbl_common_given_name: insert-only, never deleted or updated (ON
CONFLICT DO NOTHING on the folded-name key), and that statement carries given
names only.

Since FR-171 the same read also keeps each ranked fencer's EVF id, surname,
given name, gender, category and country in tbl_evf_ranking_fencer (inserted or
updated by EVF id, never deleted), so an entry without a country can be filled
from it (python/tools/fill_registration_country.py). Never a birth date.

Since FR-174 it also keeps each ranked fencer's place and points per weapon in
tbl_evf_ranking_place, replaced in full by a read that brought all 24 lists and
untouched otherwise; an event EVF organises is seeded from them
(fn_event_seed_ranks). .github/workflows/evf-ranking-sync.yml runs it every
morning with --if-due: it reads only when fn_evf_ranking_read_due names a
reason (seven days after an EVF event, the day before an EVF event with our
registration, or 31 days after the last read).

Since FR-172, after the ranked fencers each environment's roster is kept to them:
a roster fencer with exactly one EVF match takes EVF's country
(python/tools/unify_roster_nationality.py), and every change is reported.

Usage::

    python -m python.tools.extract_evf_given_names            # CERT and PROD
    python -m python.tools.extract_evf_given_names --env prod # one environment
    python -m python.tools.extract_evf_given_names --env prod --if-due  # only when a read is due
    python -m python.tools.extract_evf_given_names --local    # LOCAL only (rehearsal)
    python -m python.tools.extract_evf_given_names --dry-run  # print the SQL only
    python -m python.tools.extract_evf_given_names --migration PATH  # given names as a migration
"""

from __future__ import annotations

import argparse
import json
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

# EVF weapon_id 1-3 men's foil, épée, sabre; 4-6 women's (FR-174).
WEAPON_OF = {1: "FOIL", 2: "EPEE", 3: "SABRE", 4: "FOIL", 5: "EPEE", 6: "SABRE"}

# FR-174: NULL when no read is due; otherwise the reason.
DUE_SQL = "SELECT fn_evf_ranking_read_due() AS due"

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


def ranking_places(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """One row per fencer and weapon: the place and points on that list (FR-174).

    Raises ValueError unless all 24 lists are present and every row has a place
    of 1 or more and a number of points: a partial read must change nothing."""
    out: list[dict[str, Any]] = []
    lists: set[tuple[str, str, int]] = set()
    for row in rows:
        weapon = WEAPON_OF[int(row["weapon"])]
        gender, category = str(row["gender"]), int(row["cat"])
        place, points = int(row["pos"]), float(row["points"])
        if place < 1:
            raise ValueError(f"place {place} on {weapon}/{gender}/{category}")
        lists.add((weapon, gender, category))
        out.append(
            {
                "id": str(row["id"]),
                "weapon": weapon,
                "gender": gender,
                "category": category,
                "place": place,
                "points": points,
            }
        )
    if len(lists) != 24:
        raise ValueError(f"{len(lists)} of 24 lists")
    return out


def build_places_sql(places: Sequence[Mapping[str, Any]]) -> str:
    """One call that replaces every stored place, or none: the database checks
    the 24 lists again (fn_replace_evf_ranking_places)."""
    payload = json.dumps(list(places), ensure_ascii=False)
    return f"SELECT fn_replace_evf_ranking_places({_q(payload)}::jsonb) AS n"


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
) -> tuple[list[str], list[dict[str, Any]], str, str, str]:
    try:
        rows = read_ranking(client)
    except Exception as exc:  # noqa: BLE001 — any refusal is reported, never swallowed
        _fail(notify, f"the EVF ranking could not be read ({exc})")
    names = given_names(rows)
    if not names:
        _fail(notify, "the EVF ranking returned no names")
    fencers = ranking_fencers(rows)
    # FR-174: an incomplete read writes nothing at all, not even the names.
    try:
        places = ranking_places(rows)
    except ValueError as exc:
        _fail(notify, f"the EVF ranking is incomplete ({exc})")
    return (
        names,
        fencers,
        build_insert_sql(names),
        build_fencer_upsert_sql(fencers),
        build_places_sql(places),
    )


def _one_n(rows: list[dict[str, Any]]) -> int:
    """The `n` column of fn_replace_evf_ranking_places' one-row answer."""
    return int(rows[0].get("n") or 0) if rows else 0


def _one_j(rows: list[dict[str, Any]]) -> str:
    """The `j` column of a one-row answer (the roster rule's statements)."""
    if not rows or "j" not in rows[0]:
        raise RuntimeError("no answer")
    return str(rows[0]["j"])


def run(
    client: RankingClient,
    query: Query,
    token: str,
    refs: Mapping[str, str],
    notify: Notify,
    reason: str | None = None,
) -> dict[str, dict[str, int]]:
    """Read the 24 lists; send each environment the unseen given names, then the
    ranked fencers, then their places (FR-174), then keep its roster's
    nationality to them (FR-172); report once, with the counts per environment,
    every roster change and, when given, why the read ran."""
    names, fencers, names_sql, fencers_sql, places_sql = _statements(client, notify)
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
        try:
            placed = _one_n(query(ref, token, places_sql))
        except Exception as exc:  # noqa: BLE001
            _fail(notify, f"{env} refused the places ({exc})")

        def env_query(sql: str, ref: str = ref) -> str:
            return _one_j(query(ref, token, sql))

        try:
            changes, changed = roster.unify(env_query, apply=True)
        except Exception as exc:  # noqa: BLE001
            _fail(notify, f"{env} refused the roster's countries ({exc})")
        report[env] = {
            "names": added,
            "fencers": kept,
            "places": placed,
            "roster": len(changed),
        }
        lines += [f"{env}: {line}" for line in roster.describe(changes, changed)]
    new = ", ".join(f"{env}: {r['names']}" for env, r in report.items())
    kept_all = ", ".join(f"{env}: {r['fencers']}" for env, r in report.items())
    placed_all = ", ".join(f"{env}: {r['places']}" for env, r in report.items())
    unified = ", ".join(f"{env}: {r['roster']}" for env, r in report.items())
    head = f"EVF ranking read ({reason}):" if reason else "EVF ranking:"
    notify(
        f"{head} {len(names)} given names, {len(fencers)} fencers read; "
        f"new given names — {new}; fencers kept — {kept_all}; places kept — {placed_all}; "
        f"roster countries changed — {unified}" + "".join(f"\n{line}" for line in lines)
    )
    return report


def run_local(client: RankingClient, query: LocalQuery) -> dict[str, dict[str, int]]:
    """The same two statements against LOCAL only, for a rehearsal (no Telegram)."""

    def say(message: str) -> None:
        print(message)

    _names, _fencers, names_sql, fencers_sql, places_sql = _statements(client, say)
    report = {
        "names": len(query(names_sql)),
        "fencers": len(query(fencers_sql)),
        "places": _one_n(query(places_sql)),
    }

    def local_j(sql: str) -> str:
        return _one_j(query(sql))

    changes, changed = roster.unify(local_j, apply=True)
    for line in roster.describe(changes, changed):
        print(f"LOCAL: {line}")
    report["roster"] = len(changed)
    return {"LOCAL": report}


def run_if_due(
    make_client: Callable[[], RankingClient],
    query: Query,
    token: str,
    refs: Mapping[str, str],
    notify: Notify,
) -> dict[str, dict[str, int]] | None:
    """FR-174: ask each environment whether a read is due; when none says so,
    stop before EVF is asked anything, without a message. Otherwise read, and
    report why."""
    reasons: list[str] = []
    for env, ref in refs.items():
        try:
            rows = query(ref, token, DUE_SQL)
        except Exception as exc:  # noqa: BLE001
            _fail(notify, f"{env} could not say whether a read is due ({exc})")
        due = rows[0].get("due") if rows else None
        if due:
            reasons.append(str(due))
    if not reasons:
        print("not due")
        return None
    return run(make_client(), query, token, refs, notify, reason="; ".join(reasons))


def _local_query(sql: str) -> list[dict[str, Any]]:
    """LOCAL through its container (never a host psql); one JSON row per returned row."""
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
        description=(
            "The EVF ranking's given names (FR-167), ranked fencers (FR-171) and places (FR-174) "
            "into CERT and PROD."
        )
    )
    _ = parser.add_argument("--dry-run", action="store_true", help="print the SQL; write nothing")
    _ = parser.add_argument("--local", action="store_true", help="write LOCAL only (a rehearsal)")
    _ = parser.add_argument(
        "--env", choices=("cert", "prod"), help="write one environment (default: both)"
    )
    _ = parser.add_argument(
        "--migration", type=Path, help="write the names as a migration file and stop"
    )
    _ = parser.add_argument(
        "--if-due",
        action="store_true",
        help="read only when the environment says a read is due (FR-174; needs --env)",
    )
    args = parser.parse_args(argv)
    if args.if_due and not args.env:
        parser.error("--if-due needs --env")

    from python.scrapers._supabase import _management_query, _telegram
    from python.scrapers.evf_results import EvfApiClient
    from python.supabase_token import supabase_access_token

    bot, chat = os.environ.get("TELEGRAM_BOT_TOKEN", ""), os.environ.get("TELEGRAM_CHAT_ID", "")

    def notify(message: str) -> None:
        _telegram(bot, chat, message)

    def make_client() -> RankingClient:
        return EvfApiClient(request_delay=1.0)

    client = make_client()
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
    if args.if_due:
        print(run_if_due(make_client, _management_query, token, refs, notify))
        return
    added = run(client, _management_query, token, refs, notify)
    print(added)


if __name__ == "__main__":
    main(sys.argv[1:])
