"""CERT starts from PROD's master data, with identical fencer ids (ADR-108 §2–§3).

The administrator's rule: the fencer id is the same on LOCAL, CERT and PROD, and
nothing is guessed. Before every CERT ingestion this module:

1. reads PROD's roster, sequence and the event's registrations, only ever inside
   a read-only transaction, which PostgreSQL itself enforces;
2. pairs every target fencer with its PROD row (`pair_rosters`), per folded
   surname and first name:
     - one fencer of the name on each side: the same person, PROD's values win;
     - namesakes: paired only by an equal confirmed birth year. A leftover on one
       side only cannot be anyone on the other, so a PROD leftover is created and
       an unreferenced target leftover deleted; leftovers on both sides might be
       one person under two years, so they stop the refresh;
     - a name only on PROD: created at PROD's id;
     - a name only on the target: deleted when nothing refers to it;
     - anything else stops the refresh before it writes, listed for a decision
       recorded in doc/overrides/fencer-alignment.yaml;
3. writes LOCAL or CERT only — never PROD — through `fn_align_fencers_to`, after
   a database dry run of the very same call, then `fn_replace_event_registrations`;
4. drains the target's recompute queue to empty and re-reads the roster, which
   must equal PROD's.

    python -m python.pipeline.promotion.refresh --target cert --mode plan
    python -m python.pipeline.promotion.refresh --target local --mode apply --event PPW1-2026-2027
"""

from __future__ import annotations

import argparse
import functools
import json
import os
import re
import secrets
import subprocess
import sys
from collections import defaultdict
from collections.abc import Callable, Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Protocol
from urllib.parse import urlparse

import httpx
import yaml

from python.pipeline.promotion import identity as idn
from python.tools._backends import CERT_REF, PROD_REF

TARGETS = ("local", "cert")
RECORDED_PAIRS_FILE = Path("doc/overrides/fencer-alignment.yaml")
MAX_DRAIN_ROUNDS = 20

# The fields a refresh makes equal. Timestamps are each database's own.
COMPARED_FIELDS: tuple[str, ...] = (
    "txt_surname",
    "txt_first_name",
    "int_birth_year",
    "bool_birth_year_estimated",
    "enum_gender",
    "txt_nationality",
    "txt_club",
    "json_name_aliases",
    "json_revoked_aliases",
    "json_user_confirmed_aliases",
)

# What the ingestion reads from a registration. The e-mail hash, the edit token
# and the consent stamp never leave PROD (data minimisation).
REGISTRATION_COLUMNS: tuple[str, ...] = (
    "txt_surname",
    "txt_first_name",
    "enum_gender",
    "int_birth_year",
    "arr_weapons",
    "txt_ftl_name",
    "txt_club",
    "id_fencer",
)

ROSTER_SQL = "SELECT coalesce(jsonb_agg(to_jsonb(f) ORDER BY f.id_fencer), '[]'::jsonb) AS j FROM tbl_fencer f"
SEQUENCE_SQL = "SELECT last_value AS j FROM tbl_fencer_id_fencer_seq"
REFERENCE_CATALOGUE_SQL = (
    "SELECT coalesce(jsonb_agg(jsonb_build_object('tbl', c.conrelid::regclass::text, 'col', a.attname)), "
    "'[]'::jsonb) AS j FROM pg_constraint c "
    "JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1] "
    "WHERE c.contype = 'f' AND c.confrelid = 'tbl_fencer'::regclass"
)
SOFT_REFERENCES: tuple[tuple[str, str], ...] = (("tbl_result_draft", "id_fencer"),)

_EVENT_CODE = re.compile(r"^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$")
_IDENT = re.compile(r'^(?:[a-z_][a-z0-9_]*|"[^"]+")(?:\.(?:[a-z_][a-z0-9_]*|"[^"]+"))?$')


class RefreshError(RuntimeError):
    """The refresh stops; nothing it has not yet written will be written."""


class SqlError(RuntimeError):
    """A database answered with an error; the message is the server's."""


# --------------------------------------------------------------------- pairing


@dataclass(frozen=True)
class Pair:
    cert_id: int
    prod_id: int
    rule: str  # "one_each" | "namesake_birth_year" | "recorded"


@dataclass(frozen=True)
class Unpaired:
    side: str  # "target" | "prod"
    id_fencer: int
    name: str
    why: str


@dataclass(frozen=True)
class RecordedPair:
    """A written decision pairing a target fencer the rules could not pair.

    The target row is named by id and identity: ids change after an alignment,
    so a record whose identity no longer matches its row is refused.
    """

    cert_id: int
    surname: str
    first_name: str
    birth_year: int | None
    prod_id: int


@dataclass(frozen=True)
class AlignmentPlan:
    pairs: tuple[Pair, ...]
    creates: tuple[int, ...]
    deletes: tuple[int, ...]
    unpaired: tuple[Unpaired, ...]

    @property
    def ready(self) -> bool:
        return not self.unpaired

    @property
    def renumbered(self) -> tuple[Pair, ...]:
        return tuple(p for p in self.pairs if p.cert_id != p.prod_id)

    def payload(
        self, prod_rows: Sequence[Mapping[str, Any]], prod_sequence: int | None
    ) -> dict[str, Any]:
        """The arguments of fn_align_fencers_to."""
        return {
            "p_pairs": [{"cert_id": p.cert_id, "prod_id": p.prod_id} for p in self.pairs],
            "p_prod_roster": prod_rows,
            "p_deletes": list(self.deletes),
            "p_prod_sequence": prod_sequence,
        }


def load_recorded_pairs(path: Path) -> tuple[RecordedPair, ...]:
    """Read the written pairing decisions; a missing file holds none."""
    if not path.exists():
        return ()
    raw = yaml.safe_load(path.read_text()) or {}
    if not isinstance(raw, dict) or set(raw) - {"pair"}:
        raise RefreshError(f"{path}: only a 'pair' list is allowed")
    entries = raw.get("pair") or []
    if not isinstance(entries, list):
        raise RefreshError(f"{path}: 'pair' must be a list")
    keys = {"cert_id", "surname", "first_name", "birth_year", "prod_id"}
    out: list[RecordedPair] = []
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != keys:
            raise RefreshError(f"{path}: each pair needs exactly {sorted(keys)}, got {entry!r}")
        out.append(
            RecordedPair(
                cert_id=int(entry["cert_id"]),
                surname=str(entry["surname"]),
                first_name=str(entry["first_name"]),
                birth_year=None if entry["birth_year"] is None else int(entry["birth_year"]),
                prod_id=int(entry["prod_id"]),
            )
        )
    return tuple(out)


def _name(row: Mapping[str, Any]) -> str:
    year = row.get("int_birth_year")
    return f"{row.get('txt_surname')} {row.get('txt_first_name')} ({'?' if year is None else year})"


def _name_key(row: Mapping[str, Any]) -> tuple[str, str]:
    return (idn.fold(row.get("txt_surname")), idn.fold(row.get("txt_first_name")))


def _confirmed_year(row: Mapping[str, Any]) -> int | None:
    if row.get("bool_birth_year_estimated") or row.get("int_birth_year") is None:
        return None
    return int(row["int_birth_year"])


def pair_rosters(
    target_rows: Sequence[Mapping[str, Any]],
    prod_rows: Sequence[Mapping[str, Any]],
    references: Mapping[int, int],
    recorded: Iterable[RecordedPair] = (),
) -> AlignmentPlan:
    """Pair every target fencer with its PROD row by the ADR-108 §3 rules."""
    target_by_id = {int(r["id_fencer"]): r for r in target_rows}
    prod_by_id = {int(r["id_fencer"]): r for r in prod_rows}
    pairs: list[Pair] = []
    creates: list[int] = []
    deletes: list[int] = []
    unpaired: list[Unpaired] = []
    used_target: set[int] = set()
    used_prod: set[int] = set()

    for rec in recorded:
        row = target_by_id.get(rec.cert_id)
        want = idn.Identity.of(rec.surname, rec.first_name, rec.birth_year)
        if row is None or idn.Identity.from_row(row) != want:
            shown = _name(row) if row is not None else f"{rec.surname} {rec.first_name}"
            unpaired.append(
                Unpaired(
                    "target",
                    rec.cert_id,
                    shown,
                    "the recorded decision no longer matches the target row",
                )
            )
            used_target.add(rec.cert_id)
            continue
        if rec.prod_id not in prod_by_id or rec.prod_id in used_prod or rec.cert_id in used_target:
            unpaired.append(
                Unpaired(
                    "target",
                    rec.cert_id,
                    _name(row),
                    f"the recorded PROD id {rec.prod_id} is unknown or already paired",
                )
            )
            used_target.add(rec.cert_id)
            continue
        pairs.append(Pair(rec.cert_id, rec.prod_id, "recorded"))
        used_target.add(rec.cert_id)
        used_prod.add(rec.prod_id)

    groups: dict[tuple[str, str], tuple[list[Mapping[str, Any]], list[Mapping[str, Any]]]] = (
        defaultdict(lambda: ([], []))
    )
    for r in target_rows:
        if int(r["id_fencer"]) not in used_target:
            groups[_name_key(r)][0].append(r)
    for r in prod_rows:
        if int(r["id_fencer"]) not in used_prod:
            groups[_name_key(r)][1].append(r)

    for key in sorted(groups):
        t_rows, p_rows = groups[key]
        if len(t_rows) == 1 and len(p_rows) == 1:
            pairs.append(Pair(int(t_rows[0]["id_fencer"]), int(p_rows[0]["id_fencer"]), "one_each"))
            continue
        left_t, left_p = list(t_rows), list(p_rows)
        if t_rows and p_rows:  # namesakes on at least one side
            for p in sorted(p_rows, key=lambda r: int(r["id_fencer"])):
                year = _confirmed_year(p)
                if year is None or sum(1 for q in p_rows if q.get("int_birth_year") == year) != 1:
                    continue
                candidates = [t for t in left_t if _confirmed_year(t) == year]
                if len(candidates) == 1:
                    pairs.append(
                        Pair(
                            int(candidates[0]["id_fencer"]),
                            int(p["id_fencer"]),
                            "namesake_birth_year",
                        )
                    )
                    left_t.remove(candidates[0])
                    left_p.remove(p)
        if left_t and left_p:
            for t in left_t:
                unpaired.append(
                    Unpaired(
                        "target",
                        int(t["id_fencer"]),
                        _name(t),
                        "namesakes: no PROD fencer of the name with the same confirmed birth year",
                    )
                )
            for p in left_p:
                unpaired.append(
                    Unpaired(
                        "prod",
                        int(p["id_fencer"]),
                        _name(p),
                        "namesakes: no target fencer of the name with the same confirmed birth year",
                    )
                )
            continue
        creates.extend(int(p["id_fencer"]) for p in left_p)
        for t in left_t:
            n = int(references.get(int(t["id_fencer"]), 0))
            if n == 0:
                deletes.append(int(t["id_fencer"]))
            else:
                unpaired.append(
                    Unpaired(
                        "target",
                        int(t["id_fencer"]),
                        _name(t),
                        f"only on the target, and still referenced by {n} rows",
                    )
                )

    return AlignmentPlan(
        pairs=tuple(sorted(pairs, key=lambda p: p.prod_id)),
        creates=tuple(sorted(creates)),
        deletes=tuple(sorted(deletes)),
        unpaired=tuple(sorted(unpaired, key=lambda u: (u.side, u.id_fencer))),
    )


# --------------------------------------------------------------------- report


@dataclass(frozen=True)
class Report:
    counts: dict[str, int]
    lines: list[str] = field(default_factory=list)


def describe(
    plan: AlignmentPlan,
    target_rows: Sequence[Mapping[str, Any]],
    prod_rows: Sequence[Mapping[str, Any]],
) -> Report:
    """Count and name every change the plan makes, for the dry run and sign-off."""
    prod_by_id = {int(r["id_fencer"]): r for r in prod_rows}
    target_by_id = {int(r["id_fencer"]): r for r in target_rows}

    def label(prod_id: int) -> str:
        return f"{prod_id} {idn.Identity.from_row(prod_by_id[prod_id]).label()}"

    mapped = [{**target_by_id[p.cert_id], "_key": label(p.prod_id)} for p in plan.pairs]
    theirs = [{**prod_by_id[p.prod_id], "_key": label(p.prod_id)} for p in plan.pairs]
    values = idn.diff(
        idn.normalise(mapped, lambda r: r["_key"], COMPARED_FIELDS),
        idn.normalise(theirs, lambda r: r["_key"], COMPARED_FIELDS),
    )
    changed_people = {c.key for c in values.changed}

    lines: list[str] = []
    lines += [f"UNPAIRED {u.side} {u.id_fencer} · {u.name} · {u.why}" for u in plan.unpaired]
    lines += [
        f"renumber {p.cert_id} → {p.prod_id} · {label(p.prod_id)} ({p.rule})"
        for p in plan.renumbered
    ]
    lines += values.lines(left="target", right="PROD")
    lines += [f"create {i} · {_name(prod_by_id[i])}" for i in plan.creates]
    lines += [f"delete {i} · {_name(target_by_id[i])}" for i in plan.deletes]
    counts = {
        "target_fencers": len(target_rows),
        "prod_fencers": len(prod_rows),
        "paired": len(plan.pairs),
        "renumbered": len(plan.renumbered),
        "same_id": len(plan.pairs) - len(plan.renumbered),
        "created": len(plan.creates),
        "deleted": len(plan.deletes),
        "values_changed": len(changed_people),
        "unpaired": len(plan.unpaired),
    }
    return Report(counts=counts, lines=lines)


# --------------------------------------------------------------------- transports


class Transport(Protocol):
    read_only: bool

    def fetch_json(self, sql: str) -> Any: ...


class ManagementTransport:
    """SQL over the Supabase Management API; one JSON value back, from column `j`.

    With `read_only`, every statement runs inside BEGIN TRANSACTION READ ONLY …
    COMMIT: the API returns the SELECT's rows from there, and PostgreSQL refuses
    any write.
    """

    def __init__(
        self,
        project_ref: str,
        token: str,
        *,
        read_only: bool,
        post: Callable[..., Any] | None = None,
    ):
        self.read_only = read_only
        self.endpoint = f"https://api.supabase.com/v1/projects/{project_ref}/database/query"
        self._headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        self._post = post or functools.partial(httpx.post, timeout=600)

    def fetch_json(self, sql: str) -> Any:
        statement = f"BEGIN TRANSACTION READ ONLY; {sql}; COMMIT;" if self.read_only else sql
        resp = self._post(self.endpoint, headers=self._headers, json={"query": statement})
        if resp.status_code >= 400:
            try:
                message = resp.json().get("message") or resp.text
            except ValueError:
                message = resp.text
            raise SqlError(str(message))
        rows = resp.json()
        return rows[0]["j"] if rows else None


class LocalTransport:
    """SQL against LOCAL through `docker exec psql`, the statement on stdin."""

    read_only = False

    def __init__(self, container: str = "supabase_db_SPWSranklist"):
        self.container = container

    def fetch_json(self, sql: str) -> Any:
        cmd = [
            "docker",
            "exec",
            "-i",
            self.container,
            "psql",
            "-U",
            "postgres",
            "-d",
            "postgres",
            "-At",
            "-v",
            "ON_ERROR_STOP=1",
        ]
        done = subprocess.run(cmd, input=_as_text(sql), capture_output=True, text=True, check=False)
        if done.returncode != 0:
            raise SqlError(done.stderr.strip())
        out = done.stdout.strip()
        return json.loads(out) if out else None


def _as_text(sql: str) -> str:
    """Wrap a one-column `j` query so psql prints the value as JSON text."""
    return f"SELECT to_jsonb(q.j)::text FROM ({sql.strip().rstrip(';')}) q;"


def _literal(payload: Any) -> str:
    """A JSON value as a dollar-quoted jsonb literal; the tag never occurs inside."""
    text = json.dumps(payload, ensure_ascii=False, default=str)
    while True:
        tag = f"$r{secrets.token_hex(6)}$"
        if tag not in text:
            return f"{tag}{text}{tag}::jsonb"


def registrations_sql(event_code: str) -> str:
    """PROD's entries for one event, only the columns the ingestion reads."""
    if not _EVENT_CODE.match(event_code or ""):
        raise RefreshError(f"not an exact event code: {event_code!r}")
    cols = ", ".join(f"'{c}', r.{c}" for c in REGISTRATION_COLUMNS)
    return (
        f"SELECT coalesce(jsonb_agg(jsonb_build_object({cols}) ORDER BY r.id_registration), '[]'::jsonb) AS j "
        f"FROM tbl_registration r JOIN tbl_event e ON e.id_event = r.id_event WHERE e.txt_code = '{event_code}'"
    )


class ProdReader:
    """Reads PROD. It cannot be built on a transport that could write."""

    def __init__(self, transport: Transport):
        if not getattr(transport, "read_only", False):
            raise RefreshError("the PROD reader needs a read-only transport")
        self.transport = transport

    def roster(self) -> list[dict[str, Any]]:
        return list(self.transport.fetch_json(ROSTER_SQL) or [])

    def sequence(self) -> int:
        return int(self.transport.fetch_json(SEQUENCE_SQL))

    def registrations(self, event_code: str) -> list[dict[str, Any]]:
        return list(self.transport.fetch_json(registrations_sql(event_code)) or [])


class TargetDb:
    """LOCAL or CERT, the only databases a refresh writes."""

    def __init__(self, name: str, transport: Transport):
        if name not in TARGETS:
            raise RefreshError(f"a refresh writes only {TARGETS}, never {name!r}")
        self.name = name
        self.transport = transport

    def roster(self) -> list[dict[str, Any]]:
        return list(self.transport.fetch_json(ROSTER_SQL) or [])

    def references(self) -> dict[int, int]:
        """How many live rows refer to each fencer, over every reference."""
        refs = [
            (r["tbl"], r["col"]) for r in self.transport.fetch_json(REFERENCE_CATALOGUE_SQL) or []
        ]
        refs += list(SOFT_REFERENCES)
        parts = []
        for tbl, col in refs:
            if not _IDENT.match(tbl) or not re.match(r"^[a-z_][a-z0-9_]*$", col):
                raise RefreshError(f"unexpected reference {tbl}.{col}")
            parts.append(
                f'SELECT "{col}" AS id, count(*) AS n FROM {tbl} WHERE "{col}" IS NOT NULL GROUP BY "{col}"'
            )
        sql = (
            "SELECT coalesce(jsonb_object_agg(id::text, n), '{}'::jsonb) AS j "
            f"FROM (SELECT id, sum(n) AS n FROM ({' UNION ALL '.join(parts)}) u GROUP BY id) s"
        )
        return {int(k): int(v) for k, v in (self.transport.fetch_json(sql) or {}).items()}

    def align(self, payload: Mapping[str, Any], *, dry_run: bool) -> dict[str, Any]:
        seq = payload.get("p_prod_sequence")
        sql = (
            "SELECT fn_align_fencers_to("
            f"p_pairs => {_literal(payload['p_pairs'])}, "
            f"p_prod_roster => {_literal(payload['p_prod_roster'])}, "
            f"p_deletes => {_literal(payload['p_deletes'])}, "
            f"p_prod_sequence => {'NULL' if seq is None else int(seq)}, "
            f"p_dry_run => {'true' if dry_run else 'false'}) AS j"
        )
        try:
            out = self.transport.fetch_json(sql)
        except SqlError as e:
            message = str(e)
            marker = message.find("ALIGN_DRY_RUN_OK")
            if dry_run and marker >= 0:
                start = message.find("{", marker)
                summary, _ = json.JSONDecoder().raw_decode(message, start)
                return summary
            raise RefreshError(message) from e
        if dry_run:
            raise RefreshError("the database dry run returned instead of raising ALIGN_DRY_RUN_OK")
        return dict(out or {})

    def replace_registrations(
        self, event_code: str, rows: Sequence[Mapping[str, Any]]
    ) -> dict[str, Any]:
        if not _EVENT_CODE.match(event_code or ""):
            raise RefreshError(f"not an exact event code: {event_code!r}")
        clean = [{c: r.get(c) for c in REGISTRATION_COLUMNS} for r in rows]
        sql = f"SELECT fn_replace_event_registrations('{event_code}', {_literal(clean)}) AS j"
        try:
            return dict(self.transport.fetch_json(sql) or {})
        except SqlError as e:
            raise RefreshError(str(e)) from e


def check_drain_target(target: str, supabase_url: str) -> None:
    """The queue drained is the target's: refuse any other database's URL."""
    host = urlparse(supabase_url or "").hostname or ""
    if target == "local" and host in ("127.0.0.1", "localhost"):
        return
    if target == "cert" and host.startswith(f"{CERT_REF}.") and PROD_REF not in host:
        return
    raise RefreshError(
        f"SUPABASE_URL {supabase_url!r} is not the {target} database; the drain would run elsewhere"
    )


# --------------------------------------------------------------------- the run


@dataclass(frozen=True)
class RefreshOutcome:
    status: str  # "stopped_unpaired" | "planned" | "dry_run" | "applied"
    plan: AlignmentPlan
    report: Report
    align_summary: dict[str, Any] | None = None
    registrations: dict[str, Any] | None = None


def run_refresh(
    prod: ProdReader,
    target: TargetDb,
    *,
    mode: str,
    event_code: str | None = None,
    recorded: Iterable[RecordedPair] = (),
    drain: Callable[[], list[int]] | None = None,
    snapshot: Callable[[dict[str, Any]], None] | None = None,
) -> RefreshOutcome:
    """plan: pair and report. dry-run: also the database dry run. apply: write.

    Before the real alignment, `snapshot` receives the restore point: the
    target's roster as it was and the pairing, which `run_restore` reverses.
    """
    if mode not in ("plan", "dry-run", "apply"):
        raise RefreshError(f"unknown mode {mode!r}")
    target_rows = target.roster()
    prod_rows = prod.roster()
    plan = pair_rosters(target_rows, prod_rows, target.references(), recorded)
    report = describe(plan, target_rows, prod_rows)
    if not plan.ready:
        return RefreshOutcome("stopped_unpaired", plan, report)
    if mode == "plan":
        return RefreshOutcome("planned", plan, report)

    payload = plan.payload(prod_rows, prod.sequence())
    dry = target.align(payload, dry_run=True)
    if mode == "dry-run":
        return RefreshOutcome("dry_run", plan, report, align_summary=dry)

    if snapshot is not None:
        snapshot(
            {
                "target": target.name,
                "taken": datetime.now(UTC).isoformat(),
                "target_roster": target_rows,
                "pairs": payload["p_pairs"],
                "created": list(plan.creates),
                "deleted": list(plan.deletes),
            }
        )
    summary = target.align(payload, dry_run=False)
    registrations = (
        target.replace_registrations(event_code, prod.registrations(event_code))
        if event_code
        else None
    )
    if drain is not None:
        for _ in range(MAX_DRAIN_ROUNDS):
            if not drain():
                break
        else:
            raise RefreshError(f"the recompute queue was not empty after {MAX_DRAIN_ROUNDS} drains")

    after = roster_diff(target.roster(), prod_rows)
    if not after.equal:
        raise RefreshError(
            "after the refresh the roster differs from PROD's:\n"
            + "\n".join(after.lines("target", "PROD"))
        )
    return RefreshOutcome(
        "applied", plan, report, align_summary=summary, registrations=registrations
    )


def roster_diff(target_rows: list[dict], prod_rows: list[dict]) -> idn.IdentityDiff:
    """Two rosters compared id for id on every compared field."""
    return idn.diff(
        idn.normalise(target_rows, lambda r: int(r["id_fencer"]), COMPARED_FIELDS),
        idn.normalise(prod_rows, lambda r: int(r["id_fencer"]), COMPARED_FIELDS),
    )


class HasRoster(Protocol):
    def roster(self) -> list[dict]: ...


def run_verify(prod: HasRoster, target: HasRoster) -> idn.IdentityDiff:
    """ADR-036 §1: a database's roster against PROD's, id for id.

    scripts/mirror-prod-local.sh runs it after LOCAL is rebuilt from the seed.
    The same two people at swapped ids are a difference.
    """
    return roster_diff(target.roster(), prod.roster())


def run_restore(target: TargetDb, point: Mapping[str, Any]) -> dict[str, Any]:
    """Undo an alignment with the same function: the inverse pairing, the saved roster.

    The fencers the alignment created are deleted, so they must still be
    unreferenced; the ones it deleted come back from the saved roster. Valid
    until anything else writes the target (an ingestion refers to new ids).
    """
    if point.get("target") != target.name:
        raise RefreshError(
            f"the restore point was taken on {point.get('target')}, not {target.name}"
        )
    payload = {
        "p_pairs": [{"cert_id": p["prod_id"], "prod_id": p["cert_id"]} for p in point["pairs"]],
        "p_prod_roster": point["target_roster"],
        "p_deletes": list(point.get("created") or []),
        "p_prod_sequence": None,
    }
    target.align(payload, dry_run=True)
    summary = target.align(payload, dry_run=False)
    after = roster_diff(target.roster(), point["target_roster"])
    if not after.equal:
        raise RefreshError(
            "after the restore the roster differs from the restore point:\n"
            + "\n".join(after.lines("target", "saved"))
        )
    return summary


# --------------------------------------------------------------------- CLI


def _drain_target_queue() -> list[int]:
    from python.pipeline.db_connector import create_db_connector
    from python.pipeline.recompute.worker import drain_recompute_queue

    return drain_recompute_queue(create_db_connector(), debounce_window=0)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Refresh LOCAL or CERT master data from PROD (ADR-108)."
    )
    parser.add_argument("--target", required=True, choices=TARGETS)
    parser.add_argument(
        "--mode", default="plan", choices=("plan", "dry-run", "apply", "restore", "verify")
    )
    parser.add_argument(
        "--event", help="exact event code whose registrations are copied (apply only)"
    )
    parser.add_argument("--recorded", type=Path, default=RECORDED_PAIRS_FILE)
    parser.add_argument("--report", type=Path, help="also write the report to this file")
    parser.add_argument(
        "--snapshot",
        type=Path,
        help="restore point: written before an apply (a new file), read by a restore",
    )
    args = parser.parse_args(argv)

    if args.mode in ("apply", "restore") and args.snapshot is None:
        print(f"--mode {args.mode} needs --snapshot PATH (the restore point)", file=sys.stderr)
        return 1
    if args.mode == "apply" and args.snapshot.exists():
        print(f"{args.snapshot} exists; a restore point is never overwritten", file=sys.stderr)
        return 1

    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    if not token:
        print("SUPABASE_ACCESS_TOKEN is required to read PROD", file=sys.stderr)
        return 1
    prod = ProdReader(ManagementTransport(PROD_REF, token, read_only=True))
    # A plan and a verify only read, so on CERT they run read-only as well.
    transport: Transport = (
        LocalTransport()
        if args.target == "local"
        else ManagementTransport(CERT_REF, token, read_only=args.mode in ("plan", "verify"))
    )
    target = TargetDb(args.target, transport)
    if args.mode == "verify":
        diff = run_verify(prod, target)
        if diff.equal:
            print(f"{args.target} roster equals PROD's, id for id")
            return 0
        print(f"VERIFY FAILED: the {args.target} roster differs from PROD's:", file=sys.stderr)
        for line in diff.lines(args.target, "PROD"):
            print(line, file=sys.stderr)
        return 1
    drain = None
    if args.mode in ("apply", "restore"):
        try:
            check_drain_target(args.target, os.environ.get("SUPABASE_URL", ""))
        except RefreshError as e:
            print(f"REFRESH STOPPED: {e}", file=sys.stderr)
            return 1
        drain = _drain_target_queue

    if args.mode == "restore":
        try:
            summary = run_restore(target, json.loads(args.snapshot.read_text()))
            for _ in range(MAX_DRAIN_ROUNDS):
                if not drain or not drain():
                    break
        except RefreshError as e:
            print(f"RESTORE STOPPED: {e}", file=sys.stderr)
            return 1
        print(f"restored {args.target} from {args.snapshot}: {json.dumps(summary)}")
        return 0

    def save_point(point: dict[str, Any]) -> None:
        args.snapshot.parent.mkdir(parents=True, exist_ok=True)
        with args.snapshot.open("x") as fh:  # never overwrite a restore point
            json.dump(point, fh, ensure_ascii=False, default=str)

    try:
        out = run_refresh(
            prod,
            target,
            mode=args.mode,
            event_code=args.event,
            recorded=load_recorded_pairs(args.recorded),
            drain=drain,
            snapshot=save_point if args.mode == "apply" else None,
        )
    except RefreshError as e:
        print(f"REFRESH STOPPED: {e}", file=sys.stderr)
        return 1

    stamp = datetime.now(UTC).strftime("%Y-%m-%d %H:%M UTC")
    text = "\n".join(
        [
            f"# Refresh {args.target} from PROD · {args.mode} · {stamp}",
            "",
            f"status: {out.status}",
            f"counts: {json.dumps(out.report.counts)}",
            f"database: {json.dumps(out.align_summary) if out.align_summary else '-'}",
            f"registrations: {json.dumps(out.registrations) if out.registrations else '-'}",
            "",
        ]
        + out.report.lines
    )
    print(text)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(text + "\n")
    return 2 if out.status == "stopped_unpaired" else 0


if __name__ == "__main__":
    raise SystemExit(main())
