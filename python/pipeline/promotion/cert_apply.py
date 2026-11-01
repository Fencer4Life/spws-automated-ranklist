"""The CERT ingest is plan + apply (ADR-119 §3: D3, D4, R2.1 C, B1–B10).

A recorded run (`ingest_cli --from-url --record-run cert`, as ingest-event.yml
runs it; `local` for the LOCAL rehearsal) takes promote's own path against its
own database, so ingest and promote write through one function:

  1. read every final listing (ingest_cli.read_event); a read failure opens
     no run and writes nothing (B1);
  2. save a link given with the command, the administrator's write (B2);
  3. read what the event holds: its result fingerprint is the apply's prior,
     NULL while it holds no result (B3);
  4. open the run (fn_ingest_run_open records the inputs, the roster and the
     prior the plan starts from; promote accepts PROD holding that prior, G17);
  5. plan the ingestion against the database, a new fencer taking a reserved
     id (plan.plan_event, B6); a refused listing closes the run FAILED, and
     nothing is written;
  6. write it with one fn_promote_event_apply call: no expected fingerprint
     (compute and return), the prior, the run's inputs, the plan's status. It
     deletes the event's tournaments the plan does not name (D4). A refusal
     rolls everything back; a call that ends without an answer is settled by
     reading the database again (B5);
  7. close the run FINISHED: the database records the fingerprint the apply
     reached;
  8. drain the recompute queue, run the gate (its outcome lands on the run
     row), send the staging report and run the joining check (B7).

A run in which no listing is final writes nothing: FINISHED while the event
holds no result, FAILED while it does (R2.1 C).

The gate's findings name fencers, so they go to Telegram; the log carries the
verdict and the counts only (B7, D12's rule). The apply, the drain and the gate
are module functions, so the tests replace them (python/tests/cert_apply_fakes.py).
"""

from __future__ import annotations

import json
from collections import Counter
from dataclasses import dataclass, field
from typing import Any

from python.pipeline.promotion.replay import MAX_DRAIN_ROUNDS, TIME_LIMIT, ApplyError
from python.supabase_token import supabase_access_token

NOTHING_FINAL = "nothing_final"


class RecordedRunError(ValueError):
    """A recorded run stopped. `reported` is True once Telegram was told, so
    the CLI does not say it twice (B7)."""

    reported = False


class NothingFinal(RecordedRunError):
    """R2.1 C: no listing is final, and the event holds an earlier run's results."""


class ApplyRefused(RecordedRunError):
    """The database refused the apply and rolled it back: nothing was written."""


class ApplyUnanswered(RecordedRunError):
    """The apply's call ended without an answer, and the database holds what it held."""


class GateUnavailable(RecordedRunError):
    """The gate cannot read PROD, so the run does not start."""


class GateBlocked(RecordedRunError):
    """CERT holds the run; the gate blocks its promote. Telegram has the findings."""

    reported = True


@dataclass
class Recorded:
    """What a recorded run did."""

    run_id: int
    status: str | None
    fingerprint: str | None
    writes: int | None = 0
    contexts: list = field(default_factory=list)
    drained: list[int] = field(default_factory=list)
    gate_passed: bool | None = None


# ---------------------------------------------------------------- the seams


def applier_for(db: Any) -> Any:
    """fn_promote_event_apply as one call of the database's service-role API."""
    from python.pipeline.promotion.replay import ApiApplier

    return ApiApplier(db)


def drain(db: Any) -> list[int]:
    """The database's recompute queue, drained to empty (ADR-072); the events recomputed."""
    from python.pipeline.recompute.worker import drain_recompute_queue

    ids: list[int] = []
    for _ in range(MAX_DRAIN_ROUNDS):
        batch = drain_recompute_queue(db, debounce_window=0)
        if not batch:
            return ids
        ids += batch
    print(
        f"(the recompute queue was not empty after {MAX_DRAIN_ROUNDS} drains; "
        "the scheduled drain continues)"
    )
    return ids


def require_gate(environment: str) -> None:
    """The gate reads PROD after the apply; without the access token the run
    does not start, so it never writes and then stops short of the gate."""
    if not supabase_access_token():
        raise GateUnavailable(
            "SUPABASE_ACCESS_TOKEN is required: the gate reads PROD after the apply "
            f"({environment} run). Nothing was read or written."
        )


def gate_for(event_code: str, environment: str) -> Any:
    """The gate on the run just recorded: the database writable (its outcome
    lands on the run row), PROD read-only (ADR-108 §5). The run was made by
    this checkout, so the commit it is checked against is this checkout's;
    promote's own gate checks main's."""
    from python.pipeline.promotion.gate import run_gate
    from python.pipeline.promotion.refresh import (
        CERT_REF,
        PROD_REF,
        LocalTransport,
        ManagementTransport,
    )
    from python.pipeline.promotion.run_record import git_commit

    token = supabase_access_token()
    prod = ManagementTransport(PROD_REF, token, read_only=True)
    target = (
        LocalTransport()
        if environment == "local"
        else ManagementTransport(CERT_REF, token, read_only=False)
    )
    return run_gate(event_code, target, prod, main_commit=git_commit(), environment=environment)


def _lift_pause(db: Any, event_code: str) -> None:
    """D8: a finished run lifts the results sync's pause of its event. A
    failure to lift it is said, never a failure of the run."""
    try:
        if db.resume_results_sync(event_code):
            print(f"the results sync's pause of {event_code} is lifted")
    except Exception as e:
        print(f"(the results sync's pause of {event_code} was not lifted: {type(e).__name__})")


# ---------------------------------------------------------------- the run


def ingest_recorded(
    event: dict,
    event_code: str,
    season_end_year: int,
    url_event: str | None,
    url_event_override: str | None,
    *,
    db: Any,
    environment: str,
    notifier: Any = None,
    send_telegram: bool = False,
    md_target: str = "local",
) -> Recorded:
    """One recorded run of `event_code` on `db` (CERT, or LOCAL), steps 1–8 above."""
    from python.pipeline import ingest_cli
    from python.pipeline.core.contract import ListingRefused
    from python.pipeline.promotion.plan import plan_event
    from python.pipeline.promotion.run_record import RunRecord

    require_gate(environment)
    target = environment.upper()

    # 1) Read every final listing. A failure here opens no run.
    read = ingest_cli.read_event(
        event, event_code, season_end_year, url_event, url_event_override, db=db
    )

    # 2) A link given with the command is the administrator's write (N15),
    # saved once the listings it names were read.
    if url_event_override and (event.get("url_event") or "").strip() != url_event_override:
        db.set_event_url_event(event["id_event"], url_event_override)
        event["url_event"] = url_event_override

    # 3) What the event holds: the prior the apply checks (B3).
    state = db.event_result_state(event_code)
    prior = state.get("fingerprint") if state.get("has_results") else None

    # 4) The run opens on the inputs the plan reads, with the prior it starts
    # from, which promote accepts PROD holding (G17).
    run = RunRecord.open(
        db,
        event_code=event_code,
        environment=environment,
        season_end_year=season_end_year,
        url_event=url_event or "",
        prior_fingerprint=prior,
    )
    ingest_cli._github_output(run_id=str(run.run_id))

    # 5) The plan: every write recorded, none made.
    try:
        plan = plan_event(
            event_code,
            season_end_year,
            db,
            url_event=url_event or "",
            created=None,
            read=read,
            log=run,
            target=target,
        )
    except BaseException as e:
        kind = e.kind if isinstance(e, ListingRefused) else None
        public = e.summary if isinstance(e, ListingRefused) else None
        if isinstance(e, ListingRefused):
            e.listing = run.current  # the CLI's log names the listing, never the fencer (D12)
        run.fail(f"{type(e).__name__}: {e}", kind=kind, message=str(e), public=public)
        ingest_cli._github_output(finished="false", gate="")
        raise

    # R2.1 C: nothing final writes nothing, and never empties an event.
    if plan.status is None:
        if state.get("has_results"):
            message = (
                f"No listing of {event_code} is final now, but {target} holds the results of "
                "an earlier run; nothing was deleted. Look at the source, then ingest again."
            )
            run.fail(f"NothingFinal: {message}", kind=NOTHING_FINAL, message=message)
            ingest_cli._github_output(finished="false", gate="")
            raise NothingFinal(message)
        run.finish()
        ingest_cli._github_output(finished="true", gate="")
        _lift_pause(db, event_code)
        print(f"nothing is final yet in {event_code}: nothing was written (run {run.run_id})")
        return Recorded(run.run_id, None, state.get("fingerprint"), contexts=plan.contexts)

    # 6) One apply.
    params = {
        "p_event_code": event_code,
        "p_plan": json.loads(json.dumps(plan.to_json(), default=str)),
        "p_expected_fingerprint": None,
        "p_expected_inputs": db.ingest_run_input_parts(run.run_id),
        "p_prior_fingerprint": prior,
        "p_status": plan.status,
        "p_dry_run": False,
    }
    try:
        result = applier_for(db).apply(params) or {}
    except ApplyError as e:
        if not e.uncertain:
            message = f"The apply of {event_code} on {target} refused, and nothing was written: {e}"
            if TIME_LIMIT.search(str(e)):
                message += (
                    " The API's time limit cut the call off and PostgreSQL rolled it back; an "
                    "event too large for the limit needs a direct database connection "
                    "(ADR-108 §6, option A)."
                )
            run.fail(f"ApplyRefused: {message}", message=message)
            ingest_cli._github_output(finished="false", gate="")
            raise ApplyRefused(message) from e
        # B5: only the apply writes the event inside the cert-write lane, so an
        # event that moved from the prior is the apply's commit.
        now = db.event_result_state(event_code)
        if (now.get("fingerprint"), bool(now.get("has_results"))) == (
            state.get("fingerprint"),
            bool(state.get("has_results")),
        ):
            message = (
                f"The apply of {event_code} ended without an answer ({e}), and {target} holds "
                "what it held before: run the ingest again."
            )
            run.fail(f"ApplyUnanswered: {message}", message=message)
            ingest_cli._github_output(finished="false", gate="")
            raise ApplyUnanswered(message) from e
        print(f"the apply's call ended without an answer ({e}); {target} moved, so it committed")
        result = {"fingerprint": now.get("fingerprint"), "writes": None}

    # 7) The run closes on what the apply wrote; a finished run lifts the
    # results sync's pause of the event (D8).
    run.finish()
    ingest_cli._github_output(finished="true")
    _lift_pause(db, event_code)
    reached = result.get("fingerprint")
    print(
        f"applied: {result.get('writes')} write(s), "
        f"{result.get('deleted') or 0} tournament(s) the plan does not name deleted; "
        f"{target} holds {str(reached)[:12]}, status {plan.status}"
    )
    held = db.event_result_state(event_code).get("fingerprint")
    if held != reached:
        text = (
            f"{target} holds {str(held)[:12]} for {event_code} after run {run.run_id}, "
            f"not the {str(reached)[:12]} its apply reached: something else wrote the event."
        )
        print(text)
        if notifier is not None:
            notifier.error(text)

    # 8) After the commit: the drain, the gate, the report, the joining check.
    drained = drain(db)
    gate = gate_for(event_code, environment)
    counts = Counter(f.kind for f in gate.findings if f.blocking)
    summary = ", ".join(f"{n} {kind}" for kind, n in counts.items())
    print(f"gate: {'passed' if gate.passed else 'BLOCKED'}" + (f" ({summary})" if summary else ""))
    ingest_cli._github_output(gate="passed" if gate.passed else "blocked")

    current = db.find_event_by_code(event_code) or event
    sources = next(
        (op["sources"] for op in plan.ops if op.get("op") == "set_event_ingest_sources"), None
    )
    post = ingest_cli._fire_staging_report(
        current,
        plan.contexts,
        db,
        schedule_skips=read.skipped,
        source_decisions=sources,
        notifier=notifier,
        md_target=md_target,
    )  # ADR-075
    if send_telegram:
        ingest_cli._send_staging_via_telegram(
            notifier,
            event_code,
            post,
            n_tournaments=len(plan.contexts),
            hint="" if gate.passed else None,
        )
    if not gate.passed and notifier is not None:
        notifier.error(
            "\n".join(
                [
                    f"⛔ The gate blocks promote of {event_code}: {target} holds run "
                    f"{run.run_id}, and PROD keeps what it holds.",
                    *gate.lines(),
                ]
            )
        )
    ingest_cli._after_event_run(current, db, notifier)

    if not gate.passed:
        blocked = GateBlocked(f"The gate blocks promote of {event_code}: {summary}")
        blocked.reported = notifier is not None
        raise blocked
    return Recorded(
        run.run_id,
        plan.status,
        reached,
        writes=result.get("writes"),
        contexts=plan.contexts,
        drained=drained,
        gate_passed=True,
    )
