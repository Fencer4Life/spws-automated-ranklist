"""Promote: replay a verified CERT ingestion on PROD (ADR-108 §6, build step 12).

Promote copies nothing from CERT. For one exact event code it:

1. takes the latest CERT run of the event (tbl_ingest_run), whose commit must be
   the one checked out: `promote.yml` checks out the commit the run recorded;
2. runs the gate again, reading CERT and PROD only;
3. checks what PROD holds for the event: nothing, an earlier FINISHED CERT run's
   result (day 2 of a multi-day event, or a correction), or this run's result,
   in which case the apply skips its writes. Anything else refuses;
4. plans the same ingestion against PROD (`plan_event`, reads only) and compares
   the plan with the run: every listing's hash, the created fencers and the
   birth-year moves, id for id;
5. applies the plan through `fn_promote_event_apply`, one call of the target's
   service-role API each (decision B, 3 Oct 2026): a dry run, which must report
   the run's result fingerprint, then the apply in one transaction. The API's
   time limit is the `authenticator` role's (8 s statement and lock timeouts on
   LOCAL and PROD); a call cut off by it is rolled back and refused;
6. after the commit sends the PROD staging report and the joining check, drains
   PROD's recompute queue to empty (promote holds `prod-write`, so it drains the
   queue itself rather than wait for the drain workflow queued behind it), and
   compares every drained event and the promoted one with CERT. A difference
   there cannot be rolled back, so it is reported loudly.

Every refusal before step 5's apply writes nothing. A call that ends without an
answer (the network, not the database) is not called a refusal: promote reads
PROD again and says what it holds.

    python -m python.pipeline.promotion.replay --resolve --event PPW1-2026-2027
    python -m python.pipeline.promotion.replay --event PPW1-2026-2027 [--dry-run]
    python -m python.pipeline.promotion.replay --event PPW1-2026-2027 --prod-target local

`--prod-target local` is the rehearsal: CERT is the source and LOCAL stands in for
PROD. `--resolve` prints the commit of the latest CERT run, for `promote.yml`.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections.abc import Callable, Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from typing import Any, Protocol
from urllib.parse import urlparse

from python.tools._backends import CERT_REF, PROD_REF

_CODE = re.compile(r"^[A-Za-z0-9_-]+$")
_SHA = re.compile(r"^[0-9a-f]{40}$")
PROMOTABLE = ("PLANNED", "IN_PROGRESS", "COMPLETED")
DRY_RUN_OK = "PROMOTE_DRY_RUN_OK "
MAX_DRAIN_ROUNDS = 20
TIME_LIMIT = re.compile(r"(statement|lock) timeout", re.I)
LOCAL_HOSTS = ("127.0.0.1", "localhost")


class PromoteRefused(Exception):
    """Promote stops; nothing has been written. `lines` lists the details."""

    def __init__(self, message: str, lines: Sequence[str] = ()):
        super().__init__(message)
        self.lines = list(lines)


class ApplyError(Exception):
    """fn_promote_event_apply raised, and PostgreSQL rolled its transaction back; or,
    with `uncertain`, the call ended without an answer, so nobody knows yet."""

    def __init__(self, message: str, detail: str | None = None, *, uncertain: bool = False):
        super().__init__(message)
        self.detail = detail
        self.uncertain = uncertain


class Transport(Protocol):
    read_only: bool

    def fetch_json(self, sql: str) -> Any: ...


class Side(Protocol):
    name: str
    transport: Any

    def codes(self, text: str) -> tuple[bool, list[str]]: ...

    def latest_run(self, code: str) -> dict | None: ...

    def earlier_fingerprints(self, code: str, before: int) -> list[str]: ...

    def event_state(self, code: str) -> dict | None: ...

    def codes_of(self, ids: list[int]) -> list[str]: ...

    def fingerprints(self, codes: list[str]) -> dict[str, str]: ...


class Applier(Protocol):
    def apply(self, params: dict) -> dict: ...


class After(Protocol):
    def report(self, plan: Any, code: str) -> None: ...

    def drain(self) -> list[int]: ...


@dataclass
class Outcome:
    event_code: str
    run_id: int
    fingerprint: str
    status: str
    applied: bool = False
    skipped: bool = False
    writes: int = 0
    drained: list[str] = field(default_factory=list)
    differences: list[str] = field(default_factory=list)


# --------------------------------------------------------------------- rules


def resolve_code(text: str, exact: bool, matches: Sequence[str]) -> str:
    """The exact event code, or a refusal that lists the codes `text` starts."""
    if exact:
        return text
    if matches:
        raise PromoteRefused(
            f"{text} is not an exact event code. Promote one of: {', '.join(matches)}."
        )
    raise PromoteRefused(f"There is no event {text} on CERT.")


def prior_fingerprint(
    code: str, *, run_fp: str, state: Mapping[str, Any] | None, earlier: Sequence[str]
) -> str | None:
    """What PROD must hold for the apply to replace it: None for nothing (or for
    this run's own result, which the apply skips), or an earlier FINISHED CERT
    run's result fingerprint. Anything else refuses."""
    if state is None:
        raise PromoteRefused(
            f"{code} does not exist on PROD. Promote the calendar first (promote.py --mode calendar)."
        )
    status = state.get("status")
    if status not in PROMOTABLE:
        raise PromoteRefused(f"{code} is {status} on PROD; promote writes {', '.join(PROMOTABLE)}.")
    held = state.get("fingerprint")
    if held == run_fp or not state.get("has_results"):
        return None
    if held in earlier:
        return held
    raise PromoteRefused(
        f"PROD holds results for {code} that no FINISHED CERT run produced "
        f"(fingerprint {str(held)[:12]}). Promote never overwrites them: find where they came "
        "from, then decide on PROD."
    )


def _round_key(r: Mapping[str, Any]) -> str:
    return str(r.get("uuid") or r.get("name"))


def source_differences(run: Mapping[str, Any], plan: Mapping[str, Any]) -> list[str]:
    """Each listing whose hash differs from the CERT run's, was added or is gone,
    and a schedule that changed."""
    out: list[str] = []
    before = (run.get("schedule") or {}).get("sha256")
    now = (plan.get("schedule") or {}).get("sha256")
    if before != now:
        out.append(
            "The event's schedule changed since the CERT run (listings added, removed, renamed or finished)."
        )
    cert = {_round_key(r): r for r in run.get("rounds") or []}
    prod = {_round_key(r): r for r in plan.get("rounds") or []}
    for key in sorted(set(cert) | set(prod)):
        a, b = cert.get(key), prod.get(key)
        if b is None:
            out.append(f"{(a or {}).get('name')}: read by the CERT run, not found now.")
        elif a is None:
            out.append(f"{b.get('name')}: found now, not read by the CERT run.")
        elif a.get("sha256") != b.get("sha256"):
            out.append(f"{a.get('name')}: the listing changed since the CERT run.")
        elif a.get("start_list_sha256") != b.get("start_list_sha256"):
            # ADR-111 §6: a PZSz listing's birth years come from its start list.
            out.append(f"{a.get('name')}: the PZSz start list changed since the CERT run.")
    return out


def _text(v: Any) -> str:
    return "" if v is None else str(v)


def master_differences(
    master: Mapping[str, Any], plan: Any, before: Mapping[int, Mapping[str, Any]]
) -> list[str]:
    """The plan's created fencers and birth-year moves against the CERT run's,
    id for id. `before` is PROD's row of each fencer whose birth year the plan
    writes; a write that leaves PROD's value is not a move."""
    out: list[str] = []
    cert_new = {
        int(c["id_fencer"]): (_text(c.get("surname")), _text(c.get("first_name")))
        for c in master.get("created") or []
    }
    plan_new = {
        int(c["id_fencer"]): (_text(c.get("surname")), _text(c.get("first_name")))
        for c in plan.created
    }
    for i in sorted(set(cert_new) | set(plan_new)):
        if cert_new.get(i) != plan_new.get(i):
            out.append(
                f"Fencer #{i}: the CERT run created {' '.join(cert_new.get(i, ('nobody',)))}, "
                f"the plan creates {' '.join(plan_new.get(i, ('nobody',)))}."
            )
    last: dict[int, tuple[Any, bool]] = {}
    for op in plan.ops:
        if op.get("op") == "update_fencer_birth_year" and int(op["id_fencer"]) not in plan_new:
            last[int(op["id_fencer"])] = (op["birth_year"], bool(op.get("estimated")))
    plan_moved = {
        i: v
        for i, v in last.items()
        if (
            (before.get(i) or {}).get("int_birth_year"),
            bool((before.get(i) or {}).get("bool_birth_year_estimated")),
        )
        != v
    }
    cert_moved = {
        int(m["id_fencer"]): (m.get("to"), bool(m.get("estimated_to")))
        for m in master.get("birth_year_moved") or []
    }
    for i in sorted(set(cert_moved) | set(plan_moved)):
        if cert_moved.get(i) != plan_moved.get(i):
            out.append(
                f"Fencer #{i}: the CERT run moved the birth year to {cert_moved.get(i, 'nothing')}, "
                f"the plan to {plan_moved.get(i, 'nothing')} (year, estimated)."
            )
    return out


def check_target(target: str, url: str) -> None:
    """The API the apply calls is the target's."""
    api = urlparse(url or "").hostname or ""
    if target == "local":
        ok = api in LOCAL_HOSTS
    elif target == "prod":
        ok = api.startswith(f"{PROD_REF}.") and CERT_REF not in api
    else:
        ok = False
    if not ok:
        raise PromoteRefused(f"SUPABASE_URL is not {target}'s API (host {api or 'unset'}).")


# --------------------------------------------------------------------- the run


def replay(
    event_code: str,
    *,
    cert: Side,
    prod: Side,
    prod_db: Any,
    applier: Applier,
    commit: str,
    after: After | None = None,
    write: bool = True,
    gate_fn: Callable[..., Any] | None = None,
    plan_fn: Callable[..., Any] | None = None,
    log: Callable[[str], None] = print,
) -> Outcome:
    """Replay the latest CERT run of `event_code` on PROD. `write=False` stops
    after the dry apply."""
    from python.pipeline.promotion.gate import run_gate
    from python.pipeline.promotion.plan import PlanRefused, plan_event

    gate_call = gate_fn or run_gate
    plan_call = plan_fn or plan_event

    code = resolve_code(event_code, *cert.codes(event_code))
    run = cert.latest_run(code)
    if run is None:
        raise PromoteRefused(
            f"No recorded CERT run of {code}. Run ingest-event.yml with target cert first."
        )
    run_id = int(run["id_ingest_run"])
    if run.get("txt_git_commit") != commit:
        raise PromoteRefused(
            f"The CERT run {run_id} used commit {run.get('txt_git_commit')}, but {commit} is checked "
            "out. Promote runs the code the CERT run ran: promote.yml checks that commit out."
        )
    gate = gate_call(code, cert.transport, prod.transport, main_commit=commit, environment="cert")
    if not gate.passed:
        raise PromoteRefused(
            f"The gate blocks promote of {code} (CERT run {run_id}).", gate.lines()
        )
    log(f"gate: passed for CERT run {run_id}")
    fingerprint = run.get("txt_result_fingerprint")
    if not fingerprint:
        raise PromoteRefused(
            f"The CERT run {run_id} recorded no result fingerprint; re-ingest CERT."
        )
    prior = prior_fingerprint(
        code,
        run_fp=fingerprint,
        state=prod.event_state(code),
        earlier=cert.earlier_fingerprints(code, run_id),
    )

    master = run.get("jsonb_master_data") or {}
    try:
        plan = plan_call(
            code,
            int(run["int_season_end_year"]),
            prod_db,
            url_event=run["url_event"],
            created=master.get("created") or [],
        )
    except PlanRefused as e:
        raise PromoteRefused(f"[{e.kind}] {e}") from e
    diffs = source_differences(run.get("jsonb_listings") or {}, plan.listings)
    if diffs:
        raise PromoteRefused(
            f"The source of {code} changed since the CERT run: re-ingest CERT and promote again.",
            diffs,
        )
    created = {int(c["id_fencer"]) for c in plan.created}
    moved = sorted(
        {
            int(op["id_fencer"])
            for op in plan.ops
            if op.get("op") == "update_fencer_birth_year" and int(op["id_fencer"]) not in created
        }
    )
    before = prod_db.fetch_fencer_basics_batch(moved) if moved else {}
    diffs = master_differences(master, plan, before)
    if diffs:
        raise PromoteRefused(f"The plan of {code} differs from the CERT run's master data.", diffs)
    if plan.status is None:
        raise PromoteRefused(f"The plan of {code} commits nothing; there is nothing to promote.")
    log(f"plan: {len(plan.ops)} operation(s), status {plan.status}, prior {prior or 'none'}")

    params = {
        "p_event_code": code,
        "p_plan": json.loads(json.dumps(plan.to_json(), default=str)),
        "p_expected_fingerprint": fingerprint,
        "p_expected_inputs": run.get("jsonb_input_parts") or {},
        "p_prior_fingerprint": prior,
        "p_status": plan.status,
        "p_dry_run": True,
    }
    try:
        applier.apply(params)
    except ApplyError as e:
        message = str(e)
        if message != DRY_RUN_OK + fingerprint:
            raise PromoteRefused(
                f"The dry run of {code} did not end on the CERT run's fingerprint: {message}",
                [e.detail] if e.detail else [],
            ) from e
    else:
        raise PromoteRefused(
            f"The dry run of {code} returned instead of raising {DRY_RUN_OK.strip()}."
        )
    log(f"dry run: {fingerprint[:12]}")
    outcome = Outcome(code, run_id, fingerprint, plan.status)
    if not write:
        return outcome

    try:
        result = applier.apply({**params, "p_dry_run": False}) or {}
    except ApplyError as e:
        if e.uncertain:
            held = (prod.event_state(code) or {}).get("fingerprint")
            if held != fingerprint:
                raise PromoteRefused(
                    f"The apply of {code} ended without an answer ({e}). PROD's event now holds "
                    f"{str(held)[:12]}, not the CERT run's {fingerprint[:12]}. Run promote again: "
                    "it skips what PROD already holds and refuses anything else."
                ) from e
            log(f"the apply's call ended without an answer ({e}); PROD holds the CERT run's result")
            result = {"skipped": False, "writes": 0}
        else:
            lines = (
                [
                    "The API's time limit cut the call off (the authenticator role's statement "
                    "and lock timeouts) and PostgreSQL rolled it back. Retry when PROD is quiet; "
                    "an event too large for the limit needs a direct database connection "
                    "(ADR-108 §6, option A)."
                ]
                if TIME_LIMIT.search(str(e))
                else []
            )
            raise PromoteRefused(
                f"The apply of {code} refused, and nothing was written: {e}", lines
            ) from e
    outcome.applied = True
    outcome.skipped = bool(result.get("skipped"))
    outcome.writes = int(result.get("writes") or 0)
    log(
        f"applied: {outcome.writes} write(s){' (PROD already held the run)' if outcome.skipped else ''}"
    )

    if after is not None:
        try:
            after.report(plan, code)
        except Exception as e:  # the apply has committed; a report never undoes it
            log(f"(PROD staging report skipped: {e})")
        ids: list[int] = []
        for _ in range(MAX_DRAIN_ROUNDS):
            batch = after.drain()
            if not batch:
                break
            ids += batch
        else:
            outcome.differences.append(
                f"PROD's recompute queue was not empty after {MAX_DRAIN_ROUNDS} drains."
            )
        outcome.drained = prod.codes_of(sorted(set(ids)))
    codes = sorted({code, *outcome.drained})
    a, b = cert.fingerprints(codes), prod.fingerprints(codes)
    for c in codes:
        if a.get(c) != b.get(c):
            outcome.differences.append(
                f"{c}: CERT holds {str(a.get(c))[:12]}, PROD holds {str(b.get(c))[:12]} after the drain."
            )
    return outcome


# --------------------------------------------------------------------- I/O


class SqlSide:
    """One database, read only, through a transport (Management API or LOCAL psql)."""

    def __init__(self, name: str, transport: Transport):
        if not getattr(transport, "read_only", False):
            raise PromoteRefused(f"{name} is read through a read-only transport only.")
        self.name = name
        self.transport = transport

    @staticmethod
    def _code(code: str) -> str:
        if not _CODE.match(code or ""):
            raise PromoteRefused(f"not an event code: {code!r}")
        return code

    def codes(self, text: str) -> tuple[bool, list[str]]:
        t = self._code(text)
        got = (
            self.transport.fetch_json(
                "SELECT jsonb_build_object("
                f"'exact', EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = '{t}'), "
                "'matches', coalesce((SELECT jsonb_agg(e.txt_code ORDER BY e.txt_code) FROM tbl_event e "
                "JOIN tbl_season s ON s.id_season = e.id_season "
                f"WHERE s.bool_active AND starts_with(e.txt_code, '{t}')), '[]'::jsonb)) AS j"
            )
            or {}
        )
        return bool(got.get("exact")), list(got.get("matches") or [])

    def latest_run(self, code: str) -> dict | None:
        return self.transport.fetch_json(
            "SELECT to_jsonb(r) AS j FROM tbl_ingest_run r "
            f"WHERE r.txt_event_code = '{self._code(code)}' AND r.txt_environment = 'cert' "
            "ORDER BY r.id_ingest_run DESC LIMIT 1"
        )

    def earlier_fingerprints(self, code: str, before: int) -> list[str]:
        return list(
            self.transport.fetch_json(
                "SELECT coalesce(jsonb_agg(r.txt_result_fingerprint ORDER BY r.id_ingest_run DESC), "
                "'[]'::jsonb) AS j FROM tbl_ingest_run r "
                f"WHERE r.txt_event_code = '{self._code(code)}' AND r.txt_environment = 'cert' "
                f"AND r.txt_status = 'FINISHED' AND r.id_ingest_run < {int(before)} "
                "AND r.txt_result_fingerprint IS NOT NULL"
            )
            or []
        )

    def event_state(self, code: str) -> dict | None:
        return self.transport.fetch_json(
            "SELECT jsonb_build_object('status', e.enum_status, "
            "'fingerprint', fn_event_result_fingerprint(e.txt_code), "
            "'has_results', EXISTS (SELECT 1 FROM tbl_result r JOIN tbl_tournament t "
            "ON t.id_tournament = r.id_tournament WHERE t.id_event = e.id_event)) AS j "
            f"FROM tbl_event e WHERE e.txt_code = '{self._code(code)}'"
        )

    def codes_of(self, ids: list[int]) -> list[str]:
        if not ids:
            return []
        array = "ARRAY[" + ", ".join(str(int(i)) for i in ids) + "]::INT[]"
        return list(
            self.transport.fetch_json(
                "SELECT coalesce(jsonb_agg(txt_code ORDER BY txt_code), '[]'::jsonb) AS j "
                f"FROM tbl_event WHERE id_event = ANY ({array})"
            )
            or []
        )

    def fingerprints(self, codes: list[str]) -> dict[str, str]:
        if not codes:
            return {}
        array = "ARRAY[" + ", ".join(f"'{self._code(c)}'" for c in codes) + "]"
        return dict(
            self.transport.fetch_json(
                "SELECT coalesce(jsonb_object_agg(e.txt_code, fn_event_result_fingerprint(e.txt_code)), "
                f"'{{}}'::jsonb) AS j FROM tbl_event e WHERE e.txt_code = ANY ({array})"
            )
            or {}
        )


class ApiApplier:
    """fn_promote_event_apply as one call of the target's service-role API (PostgREST).
    The function is one transaction: a raise rolls everything back. A database error
    is certain; a call that ends without an answer is `uncertain`."""

    def __init__(self, db: Any):
        self._sb = db._sb

    def apply(self, params: dict) -> dict:
        from postgrest.exceptions import APIError

        try:
            return self._sb.rpc("fn_promote_event_apply", params).execute().data or {}
        except APIError as e:
            raise ApplyError(e.message or str(e), e.details) from e
        except Exception as e:  # the network, not the database: nobody knows yet
            raise ApplyError(f"{type(e).__name__}: {e}", uncertain=True) from e


class ProdAfter:
    """After the commit, on the target: the staging report and joining check, and
    one round of PROD's recompute drain."""

    def __init__(self, db: Any, notifier: Any, *, md_target: str, label: str):
        self.db = db
        self.notifier = notifier
        self.md_target = md_target
        self.label = label

    def report(self, plan: Any, code: str) -> None:
        from python.pipeline import ingest_cli

        event = self.db.find_event_by_code(code)
        sources = next(
            (op["sources"] for op in plan.ops if op.get("op") == "set_event_ingest_sources"), None
        )
        post = ingest_cli._fire_staging_report(
            event, plan.contexts, self.db, source_decisions=sources, md_target=self.md_target
        )
        ingest_cli._send_staging_via_telegram(
            self.notifier,
            code,
            post,
            n_tournaments=len(plan.contexts),
            reason=f"promoted to {self.label}",
            hint=None,
        )
        ingest_cli._after_event_run(event, self.db, self.notifier)

    def drain(self) -> list[int]:
        from python.pipeline.recompute.worker import drain_recompute_queue

        return drain_recompute_queue(self.db, debounce_window=0)


def _head() -> str:
    return subprocess.run(
        ["git", "rev-parse", "HEAD"], check=True, capture_output=True, text=True
    ).stdout.strip()


def _output(**values: str) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as f:
        for k, v in values.items():
            f.write(f"{k}={v}\n")


def main(argv: Iterable[str] | None = None) -> int:
    from python.pipeline.notifications import TelegramNotifier
    from python.pipeline.promotion.refresh import LocalTransport, ManagementTransport

    ap = argparse.ArgumentParser(description="Promote: replay a verified CERT run (ADR-108 §6).")
    ap.add_argument("--event", required=True, help="exact event code")
    ap.add_argument("--prod-target", choices=("prod", "local"), default="prod")
    ap.add_argument("--dry-run", action="store_true", help="plan, compare and dry-apply only")
    ap.add_argument("--resolve", action="store_true", help="print the latest CERT run's commit")
    args = ap.parse_args(list(argv) if argv is not None else None)

    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    if not token:
        print("SUPABASE_ACCESS_TOKEN is required to read CERT", file=sys.stderr)
        return 1
    notifier = TelegramNotifier(
        os.environ.get("TELEGRAM_BOT_TOKEN"), os.environ.get("TELEGRAM_CHAT_ID")
    )
    label = "PROD" if args.prod_target == "prod" else "LOCAL (rehearsal)"
    try:
        cert = SqlSide("cert", ManagementTransport(CERT_REF, token, read_only=True))
        if args.resolve:
            code = resolve_code(args.event, *cert.codes(args.event))
            run = cert.latest_run(code)
            commit = str((run or {}).get("txt_git_commit") or "")
            if run is None or not _SHA.match(commit):
                raise PromoteRefused(
                    f"No recorded CERT run of {code}. Run ingest-event.yml with target cert first."
                )
            print(f"{code}: CERT run {run['id_ingest_run']} ({run['txt_status']}), commit {commit}")
            _output(commit=commit, event=code)
            return 0
        prod_transport: Transport = (
            ManagementTransport(PROD_REF, token, read_only=True)
            if args.prod_target == "prod"
            else LocalTransport(read_only=True)
        )
        check_target(args.prod_target, os.environ.get("SUPABASE_URL", ""))
        prod = SqlSide(args.prod_target, prod_transport)
        from python.pipeline.db_connector import create_db_connector

        prod_db = create_db_connector()
        outcome = replay(
            args.event,
            cert=cert,
            prod=prod,
            prod_db=prod_db,
            applier=ApiApplier(prod_db),
            commit=_head(),
            after=ProdAfter(
                prod_db,
                notifier,
                md_target="storage" if args.prod_target == "prod" else "local",
                label=label,
            ),
            write=not args.dry_run,
        )
    except PromoteRefused as e:
        text = "\n".join([f"Promote of {args.event} to {label} refused: {e}", *e.lines])
        print(text, file=sys.stderr)
        notifier.error(text)
        _output(applied="false")
        return 1
    _output(applied="true" if outcome.applied else "false", event=outcome.event_code)
    if not outcome.applied:
        print(
            f"Dry run of {outcome.event_code} on {label}: would end on {outcome.fingerprint[:12]}"
        )
        return 0
    summary = (
        f"Promoted {outcome.event_code} to {label}: CERT run {outcome.run_id}, "
        f"{outcome.writes} write(s){', PROD already held it' if outcome.skipped else ''}, "
        f"status {outcome.status}; drained {len(outcome.drained)} event(s)."
    )
    print(summary)
    if outcome.differences:
        text = "\n".join(
            [f"{summary}\nAFTER THE DRAIN {label} DIFFERS FROM CERT:", *outcome.differences]
        )
        print(text, file=sys.stderr)
        notifier.error(text)
        return 2
    notifier.success(summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
