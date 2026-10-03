"""PROMO.REPLAY.01–26 — promote replays a verified CERT run on PROD (ADR-108 §6, build step 12).

Promote copies nothing from CERT. It takes the exact event code, the latest CERT
run of the event (whose commit must be the one checked out), re-runs the gate,
checks what PROD holds, plans the same ingestion against PROD (reads only),
compares the plan with the CERT run (listing hashes, created fencers, birth-year
moves), and applies it through fn_promote_event_apply: a dry run that must report
the CERT run's result fingerprint, then the apply. After the commit it reports,
drains PROD's recompute queue and compares every event the drain touched with
CERT. A refusal names what to do and writes nothing.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest

from python.pipeline.promotion import replay
from python.pipeline.promotion.gate import Finding, GateResult
from python.pipeline.promotion.plan import Plan, PlanRefused

CODE = "PPW1-2026-2027"
COMMIT = "a" * 40
FP = "f" * 64
FP_DAY1 = "d" * 64
INPUTS = {"schema": "s", "roster": "r", "registrations": "g", "season": "n", "event": "e"}
ROOT = Path(__file__).parents[2]


def _listings(**hashes: str) -> dict:
    rounds = [
        {"name": n, "uuid": f"u-{n}", "status": "committed", "sha256": h} for n, h in hashes.items()
    ]
    return {"schedule": {"sha256": "sched", "kept": len(rounds), "skipped": []}, "rounds": rounds}


def _run(**over: Any) -> dict:
    run = {
        "id_ingest_run": 7,
        "txt_event_code": CODE,
        "txt_status": "FINISHED",
        "txt_git_commit": COMMIT,
        "int_season_end_year": 2027,
        "url_event": "https://www.fencingtimelive.com/tournaments/eventSchedule/X",
        "jsonb_input_parts": INPUTS,
        "jsonb_listings": _listings(A="h1", B="h2"),
        "jsonb_master_data": {
            "created": [{"id_fencer": 900, "surname": "NOWAK", "first_name": "Jan"}],
            "birth_year_moved": [
                {"id_fencer": 12, "from": 1970, "to": 1968, "estimated_to": False}
            ],
        },
        "txt_result_fingerprint": FP,
    }
    run.update(over)
    return run


def _plan(**over: Any) -> Plan:
    plan = Plan(
        event_code=CODE,
        url_event=_run()["url_event"],
        ops=[
            {"op": "insert_fencer", "id_fencer": 900, "fencer": {"txt_surname": "NOWAK"}},
            {
                "op": "update_fencer_birth_year",
                "id_fencer": 12,
                "birth_year": 1968,
                "estimated": False,
            },
            {"op": "ingest_results", "tournament": -1, "rows": []},
        ],
        created=[{"id_fencer": 900, "surname": "NOWAK", "first_name": "Jan"}],
        listings=_listings(A="h1", B="h2"),
        status="IN_PROGRESS",
    )
    for k, v in over.items():
        setattr(plan, k, v)
    return plan


class FakeSide:
    """One database as replay reads it, without SQL."""

    def __init__(self, name: str, **over: Any):
        self.name = name
        self.transport = object()
        self.events = over.pop("events", [CODE, "PPW2-2026-2027"])
        self.run = over.pop("run", _run())
        self.earlier = over.pop("earlier", [])
        self.state = over.pop(
            "state", {"status": "PLANNED", "fingerprint": "0" * 64, "has_results": False}
        )
        self.ids = over.pop("ids", {})
        self.fps = over.pop("fps", {})
        self.calls: list[str] = []

    def codes(self, text: str) -> tuple[bool, list[str]]:
        return text in self.events, sorted(c for c in self.events if c.startswith(text))

    def latest_run(self, code: str) -> dict | None:
        self.calls.append("latest_run")
        return self.run

    def earlier_fingerprints(self, code: str, before: int) -> list[str]:
        return list(self.earlier)

    def event_state(self, code: str) -> dict | None:
        return self.state

    def codes_of(self, ids: list[int]) -> list[str]:
        return sorted(self.ids[i] for i in ids if i in self.ids)

    def fingerprints(self, codes: list[str]) -> dict[str, str]:
        return {c: self.fps.get(c, FP if c == CODE else "x") for c in codes}


class FakeProdDb:
    def __init__(self, before: dict[int, tuple[int, bool]] | None = None):
        self.before = before if before is not None else {12: (1970, False)}

    def fetch_fencer_basics_batch(self, ids: list[int]) -> dict[int, dict]:
        return {
            i: {"int_birth_year": self.before[i][0], "bool_birth_year_estimated": self.before[i][1]}
            for i in ids
            if i in self.before
        }


class FakeApplier:
    def __init__(self, dry: str | None = f"PROMOTE_DRY_RUN_OK {FP}", real: Any = None):
        self.dry = dry
        self.real = (
            real if real is not None else {"skipped": False, "writes": 58, "fingerprint": FP}
        )
        self.calls: list[dict] = []

    def apply(self, params: dict) -> dict:
        self.calls.append(params)
        if params["p_dry_run"]:
            if self.dry is None:
                return {"returned": True}
            raise replay.ApplyError(self.dry)
        if isinstance(self.real, Exception):
            raise self.real
        return self.real


class FakeAfter:
    def __init__(self, rounds: list[list[int]] | None = None):
        self.rounds = list(rounds if rounds is not None else [[31, 32], []])
        self.order: list[str] = []

    def report(self, plan: Plan, code: str) -> None:
        self.order.append("report")

    def drain(self) -> list[int]:
        self.order.append("drain")
        return self.rounds.pop(0) if self.rounds else []


class _Gate:
    def __init__(self, passed: bool = True):
        self.passed = passed
        self.seen: list[dict] = []

    def __call__(self, code, target, prod, *, main_commit, environment):
        self.seen.append({"code": code, "main_commit": main_commit, "environment": environment})
        if self.passed:
            return GateResult([])
        return GateResult([Finding("identity.pending", "identity", "PENDING row for X")])


def _gate(passed: bool = True) -> _Gate:
    return _Gate(passed)


class _PlanFn:
    def __init__(self, plan: Plan | Exception | None = None):
        self.plan = plan
        self.calls: list[dict] = []

    def __call__(self, code, season_end_year, prod_db, *, url_event, created):
        self.calls.append(
            {"code": code, "season": season_end_year, "url": url_event, "created": created}
        )
        if isinstance(self.plan, Exception):
            raise self.plan
        return self.plan if self.plan is not None else _plan()


def _plan_fn(plan: Plan | Exception | None = None) -> _PlanFn:
    return _PlanFn(plan)


def _replay(**over: Any) -> tuple[replay.Outcome, dict]:
    parts = {
        "cert": over.pop("cert", FakeSide("cert")),
        "prod": over.pop("prod", FakeSide("prod", run=None)),
        "prod_db": over.pop("prod_db", FakeProdDb()),
        "applier": over.pop("applier", FakeApplier()),
        "after": over.pop("after", FakeAfter()),
        "gate_fn": over.pop("gate_fn", _gate()),
        "plan_fn": over.pop("plan_fn", _plan_fn()),
    }
    code = over.pop("code", CODE)
    outcome = replay.replay(code, commit=over.pop("commit", COMMIT), **parts, **over)
    return outcome, parts


def _refused(**over: Any) -> tuple[replay.PromoteRefused, dict]:
    parts = {
        "applier": over.pop("applier", FakeApplier()),
        "after": over.pop("after", FakeAfter()),
        "plan_fn": over.pop("plan_fn", _plan_fn()),
    }
    with pytest.raises(replay.PromoteRefused) as e:
        _replay(**parts, **over)
    return e.value, parts


class TestCode:
    def test_an_exact_code_is_used_and_a_prefix_is_answered_with_the_codes(self):
        """PROMO.REPLAY.01 — promote takes an exact code; a prefix or an unknown code refuses,
        listing the codes it matches."""
        assert replay.resolve_code(CODE, True, [CODE]) == CODE
        with pytest.raises(replay.PromoteRefused) as e:
            replay.resolve_code("PPW", False, [CODE, "PPW2-2026-2027"])
        assert "PPW1-2026-2027" in str(e.value) and "PPW2-2026-2027" in str(e.value)
        with pytest.raises(replay.PromoteRefused, match="no event"):
            replay.resolve_code("XYZ", False, [])

    def test_the_run_must_be_the_checked_out_commit(self):
        """PROMO.REPLAY.02 — the CERT run's commit is the code that runs; otherwise nothing is planned."""
        e, parts = _refused(commit="b" * 40)
        assert "checked out" in str(e) and COMMIT in str(e)
        assert parts["plan_fn"].calls == [] and parts["applier"].calls == []

    def test_no_recorded_run_refuses(self):
        """PROMO.REPLAY.03 — no CERT run of the event: ingest CERT first."""
        e, _ = _refused(cert=FakeSide("cert", run=None))
        assert "ingest-event.yml" in str(e)


class TestGateAndProd:
    def test_the_gate_runs_again_read_only_and_a_block_refuses(self):
        """PROMO.REPLAY.04 — every gate check runs again; a blocking finding refuses and is listed."""
        gate_fn = _gate(passed=False)
        e, parts = _refused(gate_fn=gate_fn)
        assert gate_fn.seen == [{"code": CODE, "main_commit": COMMIT, "environment": "cert"}]
        assert "PENDING row for X" in "\n".join(e.lines)
        assert parts["plan_fn"].calls == []

    def test_a_run_without_a_result_fingerprint_refuses(self):
        """PROMO.REPLAY.05 — a run with no recorded result fingerprint cannot be compared."""
        e, _ = _refused(cert=FakeSide("cert", run=_run(txt_result_fingerprint=None)))
        assert "fingerprint" in str(e)

    @pytest.mark.parametrize(
        ("state", "earlier", "prior"),
        [
            ({"status": "PLANNED", "fingerprint": "0" * 64, "has_results": False}, [], None),
            (
                {"status": "IN_PROGRESS", "fingerprint": FP_DAY1, "has_results": True},
                [FP_DAY1],
                FP_DAY1,
            ),
            (
                {"status": "COMPLETED", "fingerprint": FP_DAY1, "has_results": True},
                [FP_DAY1],
                FP_DAY1,
            ),
            ({"status": "COMPLETED", "fingerprint": FP, "has_results": True}, [], None),
        ],
    )
    def test_prod_holds_nothing_the_previous_promote_or_this_run(self, state, earlier, prior):
        """PROMO.REPLAY.06 — PROD holds nothing, an earlier CERT run's result (day 2 or a
        correction), or this run's (idempotent; the apply skips its writes)."""
        assert replay.prior_fingerprint(CODE, run_fp=FP, state=state, earlier=earlier) == prior

    @pytest.mark.parametrize(
        ("state", "needle"),
        [
            (None, "does not exist on PROD"),
            ({"status": "CANCELLED", "fingerprint": "0", "has_results": False}, "CANCELLED"),
            (
                {"status": "IN_PROGRESS", "fingerprint": "9" * 64, "has_results": True},
                "no FINISHED CERT run",
            ),
        ],
    )
    def test_prod_holding_anything_else_refuses(self, state, needle):
        """PROMO.REPLAY.07 — results no CERT run produced are never overwritten."""
        with pytest.raises(replay.PromoteRefused, match=needle):
            replay.prior_fingerprint(CODE, run_fp=FP, state=state, earlier=[FP_DAY1])


class TestPlanCompare:
    def test_a_plan_refusal_refuses_promote(self):
        """PROMO.REPLAY.08 — plan mode's refusal (identity or precondition) stops promote."""
        e, parts = _refused(
            plan_fn=_plan_fn(PlanRefused("identity", "PROD would create KOWAL Ewa"))
        )
        assert "KOWAL Ewa" in str(e) and "identity" in str(e)
        assert parts["applier"].calls == []

    def test_the_plan_reads_prod_with_the_runs_url_and_created_fencers(self):
        """PROMO.REPLAY.09 — the plan replays the CERT run: its URL, season and created fencers."""
        _, parts = _replay()
        assert parts["plan_fn"].calls == [
            {
                "code": CODE,
                "season": 2027,
                "url": _run()["url_event"],
                "created": _run()["jsonb_master_data"]["created"],
            }
        ]

    def test_source_differences(self):
        """PROMO.REPLAY.10 — a listing changed, added or gone since the CERT run, or a changed
        schedule, is named."""
        run = _listings(A="h1", B="h2")
        assert replay.source_differences(run, _listings(A="h1", B="h2")) == []
        changed = replay.source_differences(run, _listings(A="h1", B="other"))
        assert len(changed) == 1 and "B" in changed[0]
        gone = replay.source_differences(run, _listings(A="h1"))
        assert len(gone) == 1 and "B" in gone[0]
        added = replay.source_differences(run, _listings(A="h1", B="h2", C="h3"))
        assert len(added) == 1 and "C" in added[0]
        moved = _listings(A="h1", B="h2")
        moved["schedule"]["sha256"] = "other"
        assert any("schedule" in d for d in replay.source_differences(run, moved))

    def test_a_source_difference_refuses_before_anything_is_written(self):
        """PROMO.REPLAY.11 — the source check refuses with nothing written."""
        e, parts = _refused(plan_fn=_plan_fn(_plan(listings=_listings(A="h1", B="new"))))
        assert any("B" in line for line in e.lines)
        assert parts["applier"].calls == []

    def test_master_differences(self):
        """PROMO.REPLAY.12 — created fencers and birth-year moves must equal the CERT run's, id
        for id; a birth-year write that leaves PROD's value is not a move."""
        master = _run()["jsonb_master_data"]
        before = {12: {"int_birth_year": 1970, "bool_birth_year_estimated": False}}
        assert replay.master_differences(master, _plan(), before) == []
        other_id = _plan(created=[{"id_fencer": 901, "surname": "NOWAK", "first_name": "Jan"}])
        assert any("901" in d for d in replay.master_differences(master, other_id, before))
        other_year = _plan(
            ops=[
                {
                    "op": "update_fencer_birth_year",
                    "id_fencer": 12,
                    "birth_year": 1969,
                    "estimated": False,
                }
            ]
        )
        assert any("#12" in d for d in replay.master_differences(master, other_year, before))
        no_move = {**master, "birth_year_moved": []}
        same = _plan(
            ops=[
                {
                    "op": "update_fencer_birth_year",
                    "id_fencer": 12,
                    "birth_year": 1970,
                    "estimated": False,
                }
            ]
        )
        assert replay.master_differences(no_move, same, before) == []

    def test_a_master_difference_refuses(self):
        """PROMO.REPLAY.13 — a different birth-year move refuses before the apply."""
        e, parts = _refused(prod_db=FakeProdDb({12: (1968, False)}))
        assert any("#12" in line for line in e.lines)
        assert parts["applier"].calls == []

    def test_a_plan_that_commits_nothing_refuses(self):
        """PROMO.REPLAY.14 — no status from the lifecycle rule means the plan commits nothing."""
        e, parts = _refused(plan_fn=_plan_fn(_plan(status=None)))
        assert "commits nothing" in str(e)
        assert parts["applier"].calls == []


class TestApply:
    def test_dry_run_then_apply_with_the_runs_fingerprint_and_inputs(self):
        """PROMO.REPLAY.15 — a dry run, then the apply, with the CERT run's fingerprint, its input
        parts, PROD's prior result and the plan's status."""
        outcome, parts = _replay()
        dry, real = parts["applier"].calls
        assert dry["p_dry_run"] is True and real["p_dry_run"] is False
        assert {k: v for k, v in dry.items() if k != "p_dry_run"} == {
            k: v for k, v in real.items() if k != "p_dry_run"
        }
        assert real["p_event_code"] == CODE
        assert real["p_expected_fingerprint"] == FP
        assert real["p_expected_inputs"] == INPUTS
        assert real["p_prior_fingerprint"] is None
        assert real["p_status"] == "IN_PROGRESS"
        assert real["p_plan"]["event_code"] == CODE and len(real["p_plan"]["ops"]) == 3
        assert outcome.applied and outcome.fingerprint == FP and outcome.writes == 58

    @pytest.mark.parametrize(
        ("dry", "needle"),
        [
            (f"PROMOTE_DRY_RUN_OK {'e' * 64}", "dry run"),
            ("PROMOTE_FINGERPRINT_MISMATCH: expected f, PROD would hold e", "FINGERPRINT_MISMATCH"),
            (None, "returned"),
        ],
    )
    def test_a_dry_run_that_does_not_report_the_runs_fingerprint_refuses(self, dry, needle):
        """PROMO.REPLAY.16 — the real apply never runs after a failed dry run."""
        applier = FakeApplier(dry=dry)
        e, _ = _refused(applier=applier)
        assert needle in str(e) + "\n".join(e.lines)
        assert [c["p_dry_run"] for c in applier.calls] == [True]

    def test_a_failed_apply_writes_nothing_and_refuses(self):
        """PROMO.REPLAY.17 — the apply's own refusal rolls it back; nothing after it runs."""
        applier = FakeApplier(real=replay.ApplyError("PROMOTE_INPUT_CHANGED: roster differs"))
        after = FakeAfter()
        e, _ = _refused(applier=applier, after=after)
        assert "PROMOTE_INPUT_CHANGED" in str(e) and "nothing was written" in str(e)
        assert after.order == []

    def test_a_dry_run_promote_stops_after_the_dry_apply(self):
        """PROMO.REPLAY.18 — `--dry-run` plans, compares and dry-applies, and writes nothing."""
        outcome, parts = _replay(write=False)
        assert [c["p_dry_run"] for c in parts["applier"].calls] == [True]
        assert parts["after"].order == []
        assert not outcome.applied


class TestAfterCommit:
    def test_report_then_drain_to_empty_then_compare_with_cert(self):
        """PROMO.REPLAY.19 — the report goes out, PROD's queue drains to empty, and every
        drained event and the promoted one are compared with CERT."""
        prod = FakeSide("prod", run=None, ids={31: "PPW1-2025-2026", 32: "PPW2-2025-2026"})
        outcome, parts = _replay(prod=prod)
        assert parts["after"].order == ["report", "drain", "drain"]
        assert outcome.drained == ["PPW1-2025-2026", "PPW2-2025-2026"]
        assert outcome.differences == []

    def test_a_difference_after_the_drain_is_reported_not_rolled_back(self):
        """PROMO.REPLAY.20 — a drained event that differs from CERT is listed in the outcome."""
        prod = FakeSide(
            "prod", run=None, ids={31: "PPW1-2025-2026"}, fps={"PPW1-2025-2026": "p" * 64}
        )
        cert = FakeSide("cert", fps={"PPW1-2025-2026": "c" * 64})
        outcome, _ = _replay(prod=prod, cert=cert, after=FakeAfter([[31], []]))
        assert outcome.applied
        assert len(outcome.differences) == 1 and "PPW1-2025-2026" in outcome.differences[0]

    def test_an_idempotent_promote_still_reports_drains_and_compares(self):
        """PROMO.REPLAY.21 — PROD already holding the run: the apply skips its writes, the rest runs."""
        prod = FakeSide(
            "prod",
            run=None,
            state={"status": "IN_PROGRESS", "fingerprint": FP, "has_results": True},
        )
        applier = FakeApplier(real={"skipped": True, "writes": 0, "fingerprint": FP})
        outcome, parts = _replay(prod=prod, applier=applier)
        assert outcome.skipped and parts["after"].order[0] == "report"


class TestConnections:
    def test_the_direct_apply_sets_its_timeout_and_rolls_back_on_error(self):
        """PROMO.REPLAY.22 — the apply runs over a direct connection with its own
        statement_timeout; a database error rolls back and becomes an ApplyError."""

        class DbError(Exception):
            def __init__(self, primary: str):
                super().__init__(primary)
                self.diag = type("D", (), {"message_primary": primary})()

        class Cursor:
            def __init__(self, conn):
                self.conn = conn

            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

            def execute(self, sql, params=None):
                self.conn.log.append((sql, params))
                if "fn_promote_event_apply" in sql and self.conn.fail:
                    raise DbError("PROMOTE_DRY_RUN_OK " + FP)

            def fetchone(self):
                return ({"writes": 3},)

        class Conn:
            def __init__(self, fail):
                self.fail, self.log, self.done = fail, [], []

            def cursor(self):
                return Cursor(self)

            def commit(self):
                self.done.append("commit")

            def rollback(self):
                self.done.append("rollback")

            def close(self):
                self.done.append("close")

        params = {
            "p_event_code": CODE,
            "p_plan": {"ops": []},
            "p_expected_fingerprint": FP,
            "p_expected_inputs": INPUTS,
            "p_prior_fingerprint": None,
            "p_status": "IN_PROGRESS",
            "p_dry_run": False,
        }
        ok = Conn(fail=False)
        applier = replay.DirectApplier("dsn", 900, connect=lambda dsn: ok, error_type=DbError)
        assert applier.apply(params) == {"writes": 3}
        assert ok.log[0][0] == "SET LOCAL statement_timeout = '900s'"
        assert ok.done == ["commit", "close"]
        bad = Conn(fail=True)
        applier = replay.DirectApplier("dsn", 900, connect=lambda dsn: bad, error_type=DbError)
        with pytest.raises(replay.ApplyError, match="PROMOTE_DRY_RUN_OK"):
            applier.apply({**params, "p_dry_run": True})
        assert bad.done == ["rollback", "close"]

    @pytest.mark.parametrize(
        ("target", "url", "dsn", "ok"),
        [
            (
                "local",
                "http://127.0.0.1:54321",
                "postgresql://postgres:postgres@127.0.0.1:54322/postgres",
                True,
            ),
            (
                "local",
                f"https://{replay.CERT_REF}.supabase.co",
                "postgresql://x@127.0.0.1:54322/p",
                False,
            ),
            (
                "prod",
                f"https://{replay.PROD_REF}.supabase.co",
                f"postgresql://postgres.{replay.PROD_REF}:pw@pooler:5432/postgres",
                True,
            ),
            (
                "prod",
                f"https://{replay.CERT_REF}.supabase.co",
                f"postgresql://postgres.{replay.PROD_REF}:pw@pooler/p",
                False,
            ),
            (
                "prod",
                f"https://{replay.PROD_REF}.supabase.co",
                f"postgresql://postgres.{replay.CERT_REF}:pw@pooler/p",
                False,
            ),
        ],
    )
    def test_promote_writes_only_the_database_it_was_asked_to(self, target, url, dsn, ok):
        """PROMO.REPLAY.23 — the API URL and the direct connection must both be the target's."""
        if ok:
            replay.check_target(target, url, dsn)
        else:
            with pytest.raises(replay.PromoteRefused):
                replay.check_target(target, url, dsn)

    def test_the_rehearsal_reads_local_in_a_read_only_session(self, monkeypatch):
        """PROMO.REPLAY.25 — LOCAL standing in for PROD is read in a read-only session, and the
        replay's readers refuse a transport that could write."""
        from python.pipeline.promotion import refresh

        commands: list[list[str]] = []

        class Done:
            returncode, stdout, stderr = 0, "1", ""

        monkeypatch.setattr(
            refresh.subprocess, "run", lambda cmd, **kw: commands.append(cmd) or Done()
        )
        refresh.LocalTransport(read_only=True).fetch_json("SELECT 1 AS j")
        refresh.LocalTransport().fetch_json("SELECT 1 AS j")
        assert "PGOPTIONS=-c default_transaction_read_only=on" in commands[0]
        assert not any("PGOPTIONS" in c for c in commands[1])
        with pytest.raises(replay.PromoteRefused):
            replay.SqlSide("prod", refresh.LocalTransport())


class TestWiring:
    def test_workflows_gas_and_telegram_take_an_exact_code(self):
        """PROMO.REPLAY.24 — promote.yml resolves the run's commit, checks it out and replays it
        in prod-write, then exports the seed as its own job; ingest-event.yml refuses PROD and
        joins cert-write with the CERT drain; the hint and /help name an exact code."""
        import yaml

        def wf(name: str) -> dict:
            return yaml.safe_load((ROOT / ".github/workflows" / name).read_text())

        promote = wf("promote.yml")
        jobs = promote["jobs"]
        assert set(jobs) == {"resolve", "promote", "seed", "notify"}
        assert "concurrency" not in promote
        assert jobs["promote"]["concurrency"] == {
            "group": "prod-write",
            "cancel-in-progress": False,
            "queue": "max",
        }
        checkout = next(s for s in jobs["promote"]["steps"] if "checkout" in str(s.get("uses")))
        assert checkout["with"]["ref"] == "${{ needs.resolve.outputs.commit }}"
        runs = " ".join(s.get("run") or "" for s in jobs["promote"]["steps"])
        assert "python -m python.pipeline.promotion.replay" in runs
        assert jobs["seed"]["continue-on-error"] is True
        assert "rebase" in " ".join(s.get("run") or "" for s in jobs["seed"]["steps"])

        ingest = wf("ingest-event.yml")
        assert ingest["jobs"]["ingest-event"]["concurrency"]["group"] == "cert-write"
        validate = next(
            s for s in ingest["jobs"]["ingest-event"]["steps"] if s.get("name") == "Validate inputs"
        )
        assert "promote" in validate["run"] and '"$TARGET_ENV" == "prod"' in validate["run"]
        assert wf("recompute-drain.yml")["jobs"]["drain"]["concurrency"]["group"] == "cert-write"

        from python.pipeline import ingest_cli

        sent: list[dict] = []

        class N:
            def send_staging_report(self, **kw):
                sent.append(kw)

            def send_document(self, *a, **kw):
                pass

        ingest_cli._send_staging_via_telegram(N(), CODE, {"_rendered_md": "# r"})
        assert sent[0]["extras"]["promote_hint"] == f"reply `promote {CODE}` to push to PROD"
        gas = (ROOT / "doc/gas/Code.gs").read_text()
        assert "promote &lt;exact code&gt;" in gas
