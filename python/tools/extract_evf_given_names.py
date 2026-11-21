"""The EVF ranking's given names, kept up to date in tbl_common_given_name (FR-167).

The registration form asks a newcomer whether the two name fields are reversed
when the surname box holds a known given name and the given-name box does not.
Known given names are our fencer table's, read live, and the EVF ranking's,
held here. Run monthly by .github/workflows/given-names-sync.yml; a new EVF name
appears only when a new fencer first scores at a circuit event.

What leaves this tool is given names only: no surname, country, birth date or
ranking place. It inserts the names not yet held and never deletes or updates
one (ON CONFLICT DO NOTHING on the folded-name key).

Usage::

    python -m python.tools.extract_evf_given_names            # CERT and PROD
    python -m python.tools.extract_evf_given_names --dry-run  # print the SQL only
    python -m python.tools.extract_evf_given_names --migration PATH  # write a migration
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

# EVF weapon_id 1-6 (men's foil, épée, sabre; women's foil, épée, sabre) ×
# category_id 1-4: the 24 lists of the EVF ranking.
WEAPON_IDS = range(1, 7)
CATEGORY_IDS = range(1, 5)

Query = Callable[[str, str, str], list[dict[str, Any]]]
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


def read_ranking(client: RankingClient) -> list[dict[str, Any]]:
    client.connect()
    rows: list[dict[str, Any]] = []
    for weapon_id in WEAPON_IDS:
        for category_id in CATEGORY_IDS:
            rows.extend(client.get_ranking_list(weapon_id, category_id))
    return rows


def _fail(notify: Notify, why: str) -> NoReturn:
    notify(f"Given names from the EVF ranking FAILED: {why}")
    raise SystemExit(1)


def run(
    client: RankingClient, query: Query, token: str, refs: Mapping[str, str], notify: Notify
) -> dict[str, int]:
    """Read the 24 lists, insert the unseen names into each environment, report once."""
    try:
        rows = read_ranking(client)
    except Exception as exc:  # noqa: BLE001 — any refusal is reported, never swallowed
        _fail(notify, f"the EVF ranking could not be read ({exc})")
    names = given_names(rows)
    if not names:
        _fail(notify, "the EVF ranking returned no names")

    sql = build_insert_sql(names)
    added: dict[str, int] = {}
    for env, ref in refs.items():
        try:
            added[env] = len(query(ref, token, sql))
        except Exception as exc:  # noqa: BLE001
            _fail(notify, f"{env} refused the insert ({exc})")
    summary = ", ".join(f"{env}: {n}" for env, n in added.items())
    notify(f"Given names from the EVF ranking: {len(names)} read; new — {summary}")
    return added


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


def main(argv: Sequence[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="The EVF ranking's given names into tbl_common_given_name (FR-167)."
    )
    _ = parser.add_argument("--dry-run", action="store_true", help="print the SQL; write nothing")
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
    if args.dry_run or args.migration:
        names = given_names(read_ranking(client))
        if args.migration:
            _ = args.migration.write_text(migration_text(names), encoding="utf-8")
            print(f"wrote {len(names)} names to {args.migration}")
        else:
            print(build_insert_sql(names))
        return

    refs = {
        "CERT": os.environ.get("SUPABASE_CERT_REF", ""),
        "PROD": os.environ.get("SUPABASE_PROD_REF", ""),
    }
    token = supabase_access_token()
    if not token or not all(refs.values()):
        _fail(notify, "SUPABASE_ACCESS_TOKEN, SUPABASE_CERT_REF and SUPABASE_PROD_REF are required")
    added = run(client, _management_query, token, refs, notify)
    print(added)


if __name__ == "__main__":
    main(sys.argv[1:])
