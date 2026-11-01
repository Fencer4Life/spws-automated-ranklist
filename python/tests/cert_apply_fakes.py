"""Fakes for the recorded CERT ingest: plan + apply (ADR-119 §3, D3).

A recorded run (`--record-run cert|local`) plans the ingestion against CERT and
writes it with one fn_promote_event_apply call, then drains CERT's recompute
queue and runs the gate. These fakes stand in for the apply, the drain and the
gate, so a test drives the real reader, planner and committer.

`CertMemoryDb` adds what a recorded run reads and writes on CERT to the
in-memory database of test_promotion_plan: the run record, reserved fencer
ids and the event's result state. `MemoryApplier` applies a plan to it as the
database function does (apply_plan, with D4's replace and R2.1's guard).
"""

from __future__ import annotations

import copy
import hashlib
import json
from collections.abc import Generator
from contextlib import contextmanager
from typing import Any
from unittest.mock import MagicMock, patch

from python.pipeline.promotion import plan as pl
from python.pipeline.promotion.gate import Finding, GateResult
from python.pipeline.promotion.replay import ApplyError
from python.tests.test_promotion_plan import MemoryDb

PASSED = GateResult([])
FP_ANY = "f" * 64


class CertMemoryDb(MemoryDb):
    """CERT's database for a recorded run. `order` collects the steps of the
    run in the order they happen, shared with the fakes below."""

    def __init__(self, *args, order: list[str] | None = None, **kwargs):
        super().__init__(*args, **kwargs)
        self.order = order if order is not None else []
        self.runs: dict[int, dict] = {}
        self.reserved: list[int] = []
        self._run_seq = 40
        self.resumed: list[str] = []

    # the run record
    def open_ingest_run(self, params):
        self._run_seq += 1
        self.runs[self._run_seq] = {
            "params": params,
            "status": "RUNNING",
            "inserted_before": list(self.inserted),
        }
        self.order.append("open")
        return self._run_seq

    def ingest_run_input_parts(self, run_id):
        return {"schema": "s", "roster": f"r{run_id}", "event": "e"}

    def _close(self, run_id, status, listings, error=None):
        run = self.runs[run_id]
        if run["status"] != "RUNNING":
            raise RuntimeError(f"INGEST_RUN_NOT_RUNNING: run {run_id} is {run['status']}")
        created = [i for i in self.inserted if i not in run["inserted_before"]]
        run.update(
            status=status,
            listings=copy.deepcopy(listings),
            error=error,
            fingerprint=self.fingerprint(run["params"]["p_event_code"])
            if status == "FINISHED"
            else None,
        )
        self.order.append(status.lower())
        return {"created": [{"id_fencer": i} for i in created]}

    def finish_ingest_run(self, run_id, listings):
        return self._close(run_id, "FINISHED", listings)

    def fail_ingest_run(self, run_id, error, listings):
        return self._close(run_id, "FAILED", listings, error)

    # CERT's reads for the plan
    def reserve_fencer_id(self):
        id_ = self._seq
        self._seq += 1
        self.reserved.append(id_)
        return id_

    def _event_id(self, code):
        return next(e["id_event"] for e in self.events.values() if e["txt_code"] == code)

    def fingerprint(self, code) -> str:
        """The event's results by codes and fencer ids, as fn_event_result_fingerprint."""
        ev = self._event_id(code)
        body = sorted(
            (
                t["enum_weapon"],
                t["enum_gender"],
                t["enum_age_category"],
                json.dumps(
                    sorted(self.results.get(tid, []), key=lambda r: r["int_place"]),
                    sort_keys=True,
                    default=str,
                ),
            )
            for tid, t in self.tournaments.items()
            if t["id_event"] == ev
        )
        return hashlib.sha256(json.dumps(body).encode()).hexdigest()

    def resume_results_sync(self, code):
        """fn_results_sync_resume: a finished run lifts the sync's pause (D8)."""
        self.order.append("resume")
        self.resumed.append(code)
        return False

    def event_result_state(self, code):
        ev = self._event_id(code)
        has = any(
            self.results.get(tid) for tid, t in self.tournaments.items() if t["id_event"] == ev
        )
        return {"fingerprint": self.fingerprint(code), "has_results": has}


class MemoryApplier:
    """fn_promote_event_apply on a CertMemoryDb: D4's replace, R2.1's guard,
    every operation, the status, and the fingerprint reached. `fail` raises a
    certain ApplyError before writing; `uncertain` raises an uncertain one,
    after the writes when `committed`."""

    def __init__(self, db: CertMemoryDb, *, fail=None, uncertain=False, committed=True):
        self.db = db
        self.calls: list[dict] = []
        self.results: list[dict] = []
        self.fail = fail
        self.uncertain = uncertain
        self.committed = committed

    def apply(self, params: dict) -> dict:
        self.calls.append(copy.deepcopy(params))
        self.db.order.append("apply")
        if self.fail:
            raise ApplyError(self.fail)
        if self.uncertain and not self.committed:
            raise ApplyError("ReadTimeout: no answer", uncertain=True)
        code = params["p_event_code"]
        ops = params["p_plan"]["ops"]
        ev = self.db._event_id(code)
        named = {
            (o["weapon"], o["gender"], o["category"])
            for o in ops
            if o["op"] == "find_or_create_tournament"
        }
        if not named and self.db.event_result_state(code)["has_results"]:
            raise ApplyError(f"PROMOTE_PLAN_EMPTY: the plan of {code} names no tournament")
        for tid, t in list(self.db.tournaments.items()):
            key = (t["enum_weapon"], t["enum_gender"], t["enum_age_category"])
            if t["id_event"] == ev and key not in named:
                del self.db.tournaments[tid]
                self.db.results.pop(tid, None)
        pl.apply_plan(ops, self.db, status=params["p_status"], event_code=code)
        if self.uncertain:
            raise ApplyError("ReadTimeout: no answer", uncertain=True)
        result = {
            "event": code,
            "skipped": False,
            "fingerprint": self.db.fingerprint(code),
            "writes": len(ops),
            "status": params["p_status"],
        }
        self.results.append(result)
        return result


class AcceptingApplier:
    """The apply for a MagicMock database: records the call and accepts it."""

    def __init__(self, order: list[str] | None = None):
        self.calls: list[dict] = []
        self.order = order if order is not None else []

    def apply(self, params: dict) -> dict:
        self.calls.append(params)
        self.order.append("apply")
        return {"skipped": False, "fingerprint": FP_ANY, "writes": len(params["p_plan"]["ops"])}


def blocked(*lines: tuple[str, str, str]) -> GateResult:
    return GateResult([Finding(check, kind, message) for check, kind, message in lines])


def cert_state(db: MagicMock, *, fingerprint=FP_ANY, has_results=False) -> MagicMock:
    """What a MagicMock CERT answers for a recorded run."""
    db.event_result_state.return_value = {"fingerprint": fingerprint, "has_results": has_results}
    db.ingest_run_input_parts.return_value = {"schema": "s"}
    db.reserve_fencer_id.side_effect = iter(range(9000, 9100))
    return db


@contextmanager
def recorded(
    *,
    applier: Any = None,
    gate: GateResult = PASSED,
    drained: tuple[int, ...] = (),
    order: list[str] | None = None,
) -> Generator[dict]:
    """Patch the apply, the drain and the gate of the recorded path. Yields
    the applier and the recorded gate and drain calls."""
    order = order if order is not None else []
    applier = applier or AcceptingApplier(order)
    calls: dict = {"applier": applier, "gate": [], "drain": []}

    def drain(db):
        order.append("drain")
        calls["drain"].append(db)
        return list(drained)

    def gate_for(event_code, environment):
        order.append("gate")
        calls["gate"].append((event_code, environment))
        return gate

    with (
        patch("python.pipeline.promotion.cert_apply.applier_for", return_value=applier),
        patch("python.pipeline.promotion.cert_apply.drain", side_effect=drain),
        patch("python.pipeline.promotion.cert_apply.gate_for", side_effect=gate_for),
        patch("python.pipeline.promotion.cert_apply.require_gate"),
    ):
        yield calls
