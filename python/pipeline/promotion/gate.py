"""The CERT gate: may promote replay this CERT run on PROD? (ADR-108 §5)

The gate reads three things and writes one:

  - the latest run record of the event on the target (tbl_ingest_run);
  - the target's committed state, through fn_promote_gate_checks;
  - PROD, read-only: its input fingerprint and which fencer ids it holds.

It writes only its outcome, on the run row (fn_ingest_run_gate).

Three kinds of issue block, each fixed at its source, after which CERT is
re-ingested and the gate runs again: identity, scoring and joined bracket.
Preconditions are always required. Information never blocks. There is no
acknowledge step. ADR-074 is unchanged: CERT commits automatically, and the
gate blocks only the PROD write.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections.abc import Mapping, Sequence
from dataclasses import asdict, dataclass
from typing import Any, Protocol

from python.pipeline.name_classify import classify_alias_pair

# The input-fingerprint parts compared value by value, in reporting order. The
# lock has its own rule (G1 A).
INPUT_PARTS = ("schema", "roster", "registrations", "season", "event")
DECLARED = "declared at registration"
_EVENT_CODE = re.compile(r"^[A-Za-z0-9_-]+$")

IDENTITY = "identity"
SCORING = "scoring"
JOINED = "joined_bracket"
PRECONDITION = "precondition"
INFORMATION = "information"


class GateError(Exception):
    """The gate cannot run as asked."""


class Transport(Protocol):
    read_only: bool

    def fetch_json(self, sql: str) -> Any: ...


@dataclass(frozen=True)
class Finding:
    check: str
    kind: str
    message: str

    @property
    def blocking(self) -> bool:
        return self.kind != INFORMATION


@dataclass(frozen=True)
class ProdState:
    parts: Mapping[str, Any]
    taken_ids: frozenset[int]


@dataclass(frozen=True)
class GateResult:
    findings: list[Finding]

    @property
    def passed(self) -> bool:
        return not any(f.blocking for f in self.findings)

    def to_json(self) -> dict[str, Any]:
        return {"passed": self.passed, "findings": [asdict(f) for f in self.findings]}

    def lines(self) -> list[str]:
        if not self.findings:
            return ["No finding: promote may replay this run."]
        return [f"[{f.kind}] {f.check}: {f.message}" for f in self.findings]


def _who(row: Mapping[str, Any]) -> str:
    name = " ".join(str(row.get(k) or "").strip() for k in ("surname", "first_name")).strip()
    name = name or str(row.get("scraped_name") or "?")
    return f"{name} (#{row['id_fencer']})" if row.get("id_fencer") is not None else name


def _reingest(fix: str) -> str:
    return f"{fix}, then re-ingest CERT and run the gate again."


def evaluate(
    run: Mapping[str, Any] | None,
    checks: Mapping[str, Any],
    prod: ProdState,
    *,
    main_commit: str,
    roster: Sequence[Mapping[str, Any]],
) -> GateResult:
    """Every finding for one run; pure, so each check is tested on its own."""
    if run is None:
        return GateResult(
            [
                Finding(
                    "run.missing",
                    PRECONDITION,
                    f"No recorded CERT run of {checks.get('event')}. "
                    "Run ingest-event.yml with target cert first.",
                )
            ]
        )
    out: list[Finding] = []
    listings = run.get("jsonb_listings") or {}
    rounds = [r for r in listings.get("rounds") or [] if isinstance(r, Mapping)]
    master = run.get("jsonb_master_data") or {}

    _preconditions(out, run, listings, rounds, master, checks, prod, main_commit)
    _identity(out, rounds, master, checks, roster)
    _scoring(out, checks)
    _joined(out, rounds, checks)
    for j in checks.get("joining") or []:
        out.append(
            Finding(
                "info.joining",
                INFORMATION,
                f"{j.get('weapon')} {j.get('gender')}: the organiser joined {j.get('fenced')}, "
                f"the scoring table's § 2 says {j.get('rule')}. Scored as fenced (ADR-104 §7).",
            )
        )
    return GateResult(out)


def _preconditions(out, run, listings, rounds, master, checks, prod, main_commit) -> None:
    status = run.get("txt_status")
    if status != "FINISHED":
        refusal = listings.get("refusal") or {}
        where = refusal.get("listing") or "a listing"
        if refusal.get("kind") == IDENTITY:
            out.append(
                Finding(
                    "identity.listing_refused",
                    IDENTITY,
                    _reingest(
                        f"{where} was not written: {refusal.get('message')}. Resolve the identity"
                    ),
                )
            )
        elif refusal.get("kind") == JOINED:
            out.append(
                Finding(
                    "joined.listing_refused",
                    JOINED,
                    _reingest(
                        f"{where} was not written: {refusal.get('message')}. "
                        "Get the fenced order from the organiser"
                    ),
                )
            )
        else:
            out.append(
                Finding(
                    "run.finished",
                    PRECONDITION,
                    _reingest(
                        f"The CERT run {run.get('id_ingest_run')} is {status}: "
                        f"{run.get('txt_error') or 'no error recorded'}. Fix the cause"
                    ),
                )
            )
    for r in rounds:
        if r.get("status") != "committed":
            continue
        outcome = r.get("outcome")
        if not outcome or outcome.get("skipped"):
            out.append(
                Finding(
                    "run.listing_not_committed",
                    PRECONDITION,
                    _reingest(f"{r.get('name')} was kept but not committed"),
                )
            )
        elif "rows" not in r:
            out.append(
                Finding(
                    "run.listing_without_rows",
                    PRECONDITION,
                    _reingest(f"The run record holds no source rows for {r.get('name')}"),
                )
            )
    queue = checks.get("queue") or []
    if queue:
        events = ", ".join(f"{q.get('event')} ({q.get('status')})" for q in queue)
        out.append(
            Finding(
                "queue.drained",
                PRECONDITION,
                f"CERT's recompute queue is not drained for {events}. Let the drain finish, "
                "then run the gate again.",
            )
        )
    recorded = run.get("jsonb_input_parts") or {}
    for part in INPUT_PARTS:
        if recorded.get(part) != prod.parts.get(part):
            message = (
                "The schemas of CERT's run and PROD differ. Release the same migrations to both."
                if part == "schema"
                else f"PROD's {part} changed since the CERT run. Refresh CERT from PROD"
            )
            out.append(
                Finding(
                    f"input.{part}",
                    PRECONDITION,
                    message if part == "schema" else _reingest(message),
                )
            )
    if prod.parts.get("lock") == "locked" and recorded.get("lock") != "locked":
        out.append(
            Finding(
                "input.lock",
                PRECONDITION,
                _reingest(
                    "PROD's season is locked and CERT's was not when it ran: PROD holds scored "
                    "results CERT never had. Refresh CERT from PROD"
                ),
            )
        )
    if main_commit != run.get("txt_git_commit"):
        out.append(
            Finding(
                "code.commit",
                PRECONDITION,
                _reingest(
                    f"main is at {main_commit}, but the CERT run used "
                    f"{run.get('txt_git_commit')}. CERT must run the code promote runs"
                ),
            )
        )
    for c in master.get("created") or []:
        if c.get("id_fencer") in prod.taken_ids:
            out.append(
                Finding(
                    "fencer.id_taken",
                    PRECONDITION,
                    _reingest(
                        f"The CERT run created {_who(c)}, but PROD already uses id {c['id_fencer']}. "
                        "Refresh CERT from PROD"
                    ),
                )
            )


def _identity(out, rounds, master, checks, roster) -> None:
    fitting = checks.get("fitting_years") or {}
    for r in rounds:
        ident = r.get("identity") or {}
        for p in ident.get("pending") or []:
            out.append(
                Finding(
                    "identity.pending",
                    IDENTITY,
                    _reingest(
                        f"{p.get('scraped_name')} (place {p.get('place')}) in {r.get('name')} is PENDING: "
                        f"{p.get('notes') or 'unresolved identity'}. Resolve it on the roster or in the override file"
                    ),
                )
            )
        for c in ident.get("conflicts") or []:
            if c.get("reason") == "declared_vs_bracket":
                out.append(
                    Finding(
                        "identity.declared_vs_bracket",
                        IDENTITY,
                        _reingest(
                            f"{_who(c)} declared {c.get('declared_birth_year')} ({c.get('first_vcat')}) "
                            f"but fenced {c.get('second_vcat')} in {r.get('name')}. Decide the year"
                        ),
                    )
                )
        for m in ident.get("reconciled") or []:
            _reconciled(out, m, fitting)
        for c in ident.get("created") or []:
            near = c.get("near_miss") or {}
            if near.get("name"):
                out.append(
                    Finding(
                        "info.near_miss",
                        INFORMATION,
                        f"New fencer {c.get('scraped_name')} resembles {near.get('name')} "
                        f"(#{near.get('id_fencer')}, similarity {near.get('confidence')}).",
                    )
                )
    for p in checks.get("pending_candidates") or []:
        out.append(
            Finding(
                "identity.pending",
                IDENTITY,
                _reingest(
                    f"{p.get('scraped_name')} in {p.get('tournament')} has a PENDING match candidate. "
                    "Decide it"
                ),
            )
        )
    for f in checks.get("estimated_years") or []:
        out.append(
            Finding(
                "identity.estimated_year",
                IDENTITY,
                _reingest(
                    f"{_who(f)} has birth year {f.get('birth_year') or 'unknown'}, an estimate. "
                    "Confirm the year on PROD in the Birth-year review tab, refresh CERT"
                ),
            )
        )
    _duplicates(out, master, roster)


def _reconciled(out, m, fitting) -> None:
    """G2 A (decided 3 Oct): a declaration overwrites a confirmed year only when
    the fencer's results leave no other year; any other overwrite blocks."""
    move = f"{_who(m)} moved from {m.get('old_birth_year')} to {m.get('new_birth_year')}"
    if not m.get("was_confirmed"):
        if m.get("anchor") == DECLARED:
            out.append(
                Finding("info.declared_move", INFORMATION, f"{move}, as declared at registration.")
            )
        return
    if m.get("anchor") != DECLARED:
        out.append(
            Finding(
                "identity.confirmed_moved_by_bracket",
                IDENTITY,
                _reingest(
                    f"{move}: a confirmed year moved by the bracket alone ({m.get('anchor')}). "
                    "Decide the year on PROD"
                ),
            )
        )
        return
    years = fitting.get(str(m.get("id_fencer"))) or []
    if list(years) == [m.get("new_birth_year")]:
        out.append(
            Finding(
                "info.declaration_forced",
                INFORMATION,
                f"{move}, as declared: their results allow no other year.",
            )
        )
    else:
        span = f"{min(years)}–{max(years)}" if years else "none"
        out.append(
            Finding(
                "identity.declaration_over_confirmed",
                IDENTITY,
                _reingest(
                    f"{move}: a declaration overwrote a confirmed year, and their results allow {span}. "
                    "Decide the year by name on PROD"
                ),
            )
        )


def _told_apart(c: Mapping[str, Any], r: Mapping[str, Any]) -> bool:
    """Two different confirmed birth years are two people (identity always
    checks the birth year); an unknown or estimated year separates nobody."""
    a, b = c.get("birth_year"), r.get("int_birth_year")
    confirmed = c.get("estimated") is False and r.get("bool_birth_year_estimated") is False
    return a is not None and b is not None and confirmed and a != b


def _duplicates(out, master, roster) -> None:
    created = [c for c in master.get("created") or [] if c.get("id_fencer") is not None]
    new_ids = {c["id_fencer"] for c in created}
    for c in created:
        name = f"{c.get('surname') or ''} {c.get('first_name') or ''}".strip()
        similar = [
            r
            for r in roster
            if r.get("id_fencer") not in new_ids
            and (
                not c.get("gender")
                or not r.get("enum_gender")
                or r.get("enum_gender") == c.get("gender")
            )
            and classify_alias_pair(
                name, f"{r.get('txt_surname') or ''} {r.get('txt_first_name') or ''}".strip()
            )[0]
            == "✓"
        ]
        same = [r for r in similar if not _told_apart(c, r)]
        for r in similar:
            if r not in same:
                out.append(
                    Finding(
                        "info.typo_told_apart",
                        INFORMATION,
                        f"New fencer {_who(c)} ({c.get('birth_year')}) resembles {r.get('txt_surname')} "
                        f"{r.get('txt_first_name')} (#{r.get('id_fencer')}, {r.get('int_birth_year')}); "
                        "their confirmed birth years tell them apart.",
                    )
                )
        if same:
            existing = ", ".join(
                f"{r.get('txt_surname')} {r.get('txt_first_name')} (#{r.get('id_fencer')})"
                for r in same
            )
            out.append(
                Finding(
                    "identity.possible_duplicate",
                    IDENTITY,
                    _reingest(
                        f"The CERT run created {_who(c)}, whom the alias checker calls the same person as "
                        f"{existing}. Link the name in the override file or on the roster"
                    ),
                )
            )


def _scoring(out, checks) -> None:
    def rows(check: str, key: str, what: str) -> None:
        for x in checks.get(key) or []:
            out.append(
                Finding(
                    check,
                    SCORING,
                    _reingest(
                        f"Result of fencer #{x.get('id_fencer')} at place {x.get('place')} in "
                        f"{x.get('tournament')} {what}. Find the cause"
                    ),
                )
            )

    rows("scoring.unscored", "unscored", "has no score or misses a component")
    if checks.get("active_revisions") != 1:
        out.append(
            Finding(
                "scoring.revisions",
                SCORING,
                f"The season has {checks.get('active_revisions')} active scoring revisions; exactly one is required.",
            )
        )
    rows("scoring.unstamped", "unstamped", "is not stamped with the season's active revision")
    for x in checks.get("parity") or []:
        out.append(
            Finding(
                "scoring.parity",
                SCORING,
                _reingest(
                    f"Result of fencer #{x.get('id_fencer')} at place {x.get('place')} in {x.get('tournament')}: "
                    f"stored {json.dumps(x.get('stored'))}, the engine's preview gives {json.dumps(x.get('preview'))}. "
                    "Find the cause"
                ),
            )
        )
    for x in checks.get("type_code") or []:
        out.append(
            Finding(
                "scoring.type_code",
                SCORING,
                _reingest(
                    f"{x.get('tournament')} is typed {x.get('type')}, its code says {x.get('expected')}. Correct it"
                ),
            )
        )


def _joined(out, rounds, checks) -> None:
    stored = checks.get("stored") or []
    for r in rounds:
        if r.get("status") != "committed" or "rows" not in r or not r.get("url"):
            continue
        source = r["rows"]
        places: dict[str, set[int]] = {}
        for place, name in source:
            places.setdefault(name, set()).add(place)
        for t in (s for s in stored if s.get("url") == r["url"]):
            if t.get("n") != len(source):
                out.append(
                    Finding(
                        "joined.source_n",
                        JOINED,
                        _reingest(
                            f"{t.get('tournament')} stores N = {t.get('n')}, but the source listing "
                            f"{r.get('name')} has {len(source)} fencers. Find the cause"
                        ),
                    )
                )
            for res in t.get("results") or []:
                name, place = res.get("scraped_name"), res.get("place")
                if place not in places.get(name, set()):
                    seen = sorted(places.get(name, set()))
                    out.append(
                        Finding(
                            "joined.source_place",
                            JOINED,
                            _reingest(
                                f"{name} stands at place {place} in {t.get('tournament')}, but at "
                                f"{seen or 'no place'} in the source listing {r.get('name')}. Find the cause"
                            ),
                        )
                    )
    for x in checks.get("joined") or []:
        out.append(
            Finding(
                "joined.order",
                JOINED,
                _reingest(f"{x.get('tournament')}: {x.get('problem')}. Find the cause"),
            )
        )


# --------------------------------------------------------------------- I/O


def _int_array(ids: Sequence[int]) -> str:
    return "ARRAY[" + ", ".join(str(int(i)) for i in ids) + "]::INT[]"


def _literal(payload: Any) -> str:
    from python.pipeline.promotion.refresh import _literal as literal

    return literal(payload)


def run_gate(
    event_code: str,
    target: Transport,
    prod: Transport,
    *,
    main_commit: str,
    environment: str,
) -> GateResult:
    """Run the gate on the latest recorded run of the event and record its outcome."""
    if not getattr(prod, "read_only", False):
        raise GateError("PROD is read through a read-only transport only")
    if not _EVENT_CODE.match(event_code or "") or environment not in ("local", "cert"):
        raise GateError(f"not an exact event code and environment: {event_code!r}, {environment!r}")
    run = target.fetch_json(
        "SELECT to_jsonb(r) AS j FROM tbl_ingest_run r "
        f"WHERE r.txt_event_code = '{event_code}' AND r.txt_environment = '{environment}' "
        "ORDER BY r.id_ingest_run DESC LIMIT 1"
    )
    master = (run or {}).get("jsonb_master_data") or {}
    touched = sorted(
        {
            int(x["id_fencer"])
            for k in ("created", "birth_year_moved", "aliases_added", "other")
            for x in master.get(k) or []
            if x.get("id_fencer") is not None
        }
    )
    checks = target.fetch_json(
        f"SELECT fn_promote_gate_checks('{event_code}', {_int_array(touched)}) AS j"
    )
    roster = target.fetch_json("SELECT fn_roster_snapshot() AS j") or []
    fingerprint = prod.fetch_json(f"SELECT fn_event_input_fingerprint('{event_code}') AS j") or {}
    created = [
        int(c["id_fencer"]) for c in master.get("created") or [] if c.get("id_fencer") is not None
    ]
    taken = prod.fetch_json(
        "SELECT coalesce(jsonb_agg(id_fencer), '[]'::jsonb) AS j FROM tbl_fencer "
        f"WHERE id_fencer = ANY ({_int_array(created)})"
    )
    result = evaluate(
        run,
        checks or {"event": event_code},
        ProdState(parts=fingerprint.get("parts") or {}, taken_ids=frozenset(taken or [])),
        main_commit=main_commit,
        roster=roster,
    )
    if run and not target.read_only:
        target.fetch_json(
            "SELECT jsonb_build_object('recorded', TRUE) AS j FROM "
            f"(SELECT fn_ingest_run_gate({int(run['id_ingest_run'])}, {_literal(result.to_json())})) x"
        )
    return result


def _main_commit() -> str:
    sha = os.environ.get("GITHUB_SHA")
    if sha:
        return sha
    return subprocess.run(
        ["git", "rev-parse", "origin/main"], check=True, capture_output=True, text=True
    ).stdout.strip()


def main(argv: list[str] | None = None) -> int:
    from python.pipeline.promotion.refresh import (
        CERT_REF,
        PROD_REF,
        LocalTransport,
        ManagementTransport,
    )

    parser = argparse.ArgumentParser(description="The CERT gate for one event (ADR-108 §5).")
    parser.add_argument("--event", required=True, help="exact event code")
    parser.add_argument("--target", default="cert", choices=("cert", "local"))
    parser.add_argument(
        "--main-commit", default=None, help="the commit on main (default: origin/main)"
    )
    parser.add_argument(
        "--no-record", action="store_true", help="read only: do not record the outcome"
    )
    args = parser.parse_args(argv)

    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    if not token:
        print("SUPABASE_ACCESS_TOKEN is required to read PROD", file=sys.stderr)
        return 1
    prod = ManagementTransport(PROD_REF, token, read_only=True)
    target: Transport = (
        LocalTransport()
        if args.target == "local"
        else ManagementTransport(CERT_REF, token, read_only=args.no_record)
    )
    try:
        result = run_gate(
            args.event,
            target,
            prod,
            main_commit=args.main_commit or _main_commit(),
            environment=args.target,
        )
    except GateError as e:
        print(f"GATE STOPPED: {e}", file=sys.stderr)
        return 1
    print(f"Gate for {args.event} on {args.target}: {'PASSED' if result.passed else 'BLOCKED'}")
    for line in result.lines():
        print(f"  {line}")
    return 0 if result.passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
