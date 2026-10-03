"""The record of one CERT ingestion, which promote replays (ADR-108 §4).

`ingest-event.yml` with target cert opens a tbl_ingest_run row before the
ingestion writes anything and closes it when the run ends. The database
computes the input fingerprint and the master-data changes
(fn_ingest_run_open, fn_ingest_run_finish), so CERT and PROD compute them the
same way. This module adds what only the run knows: the commit that ran, the
URL it ingested, and a hash of the schedule and of every source listing as
parsed. Promote recomputes those hashes with the functions below before it
replays, so a listing the organiser changed after the CERT run is refused.
"""

from __future__ import annotations

import dataclasses
import hashlib
import json
import os
import subprocess
from collections.abc import Iterable, Mapping, Sequence
from pathlib import Path
from typing import Any

from python.pipeline.ir import ParsedResult

ENVIRONMENTS = ("local", "cert")
ROOT = Path(__file__).resolve().parents[3]


def _sha256(obj: Any) -> str:
    """A hash of canonical JSON: sorted keys, no spacing, dates as ISO text."""
    text = json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":"), default=str)
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def listing_sha256(name: str, uuid: str, has_de: bool, results: Sequence[ParsedResult]) -> str:
    """One source listing as parsed: its name and FTL id, whether it has a
    direct-elimination tableau (the keep-rule reads it), and every parsed row
    in source order."""
    rows = [dataclasses.asdict(r) for r in results]
    return _sha256({"name": name, "uuid": uuid, "has_de": has_de, "results": rows})


def schedule_sha256(kept: Iterable[Mapping], skipped: Iterable[Mapping]) -> str:
    """The event schedule as parsed: the rounds kept and the rounds skipped, with why."""
    return _sha256(
        {
            "kept": [{"uuid": k.get("uuid"), "name": k.get("name")} for k in kept],
            "skipped": [
                {"uuid": s.get("uuid"), "name": s.get("name"), "reason": s.get("reason")}
                for s in skipped
            ],
        }
    )


def git_commit(env: Mapping[str, str] = os.environ) -> str:
    """The commit that runs: GitHub's for a workflow run, else the checkout's HEAD."""
    sha = env.get("GITHUB_SHA")
    if sha:
        return sha
    return subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True, capture_output=True, text=True
    ).stdout.strip()


def run_url(env: Mapping[str, str] = os.environ) -> str | None:
    """The GitHub Actions run, or None outside one."""
    parts = [env.get(k) for k in ("GITHUB_SERVER_URL", "GITHUB_REPOSITORY", "GITHUB_RUN_ID")]
    if not all(parts):
        return None
    server, repo, run_id = parts
    return f"{server}/{repo}/actions/runs/{run_id}"


def override_sha256(event_code: str, overrides_dir: Path | None = None) -> str | None:
    """The event's override file (doc/overrides/<event>.yaml), or None when it has none."""
    path = (overrides_dir or ROOT / "doc" / "overrides") / f"{event_code}.yaml"
    if not path.exists():
        return None
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _outcome(ctx: Any) -> dict:
    """What the listing's commit did: categories and N, or skipped, and its faults.
    Tournament ids differ between environments, so they are not recorded."""
    committed = ctx.get("committed") or {}
    return {
        "skipped": bool(committed.get("skipped")),
        "tournaments": [
            {"category": t.get("vcat"), "n": t.get("n")} for t in committed.get("tournaments") or []
        ],
        "faults": [{"kind": f.kind.value, "detail": f.detail} for f in ctx.faults],
    }


class RunRecord:
    """One open run. The ingestion adds the schedule and each listing as it reads
    them; `finish` or `fail` closes the row with them."""

    def __init__(self, db: Any, run_id: int):
        self.db = db
        self.run_id = run_id
        self.schedule: dict | None = None
        self.rounds: list[dict] = []

    @classmethod
    def open(
        cls, db: Any, *, event_code: str, environment: str, season_end_year: int, url_event: str
    ) -> RunRecord:
        if environment not in ENVIRONMENTS:
            raise ValueError(
                f"A run is recorded on {' or '.join(ENVIRONMENTS)}, not {environment!r} (ADR-108 §4)."
            )
        commit = git_commit()
        run_id = db.open_ingest_run(
            {
                "p_event_code": event_code,
                "p_environment": environment,
                "p_git_commit": commit,
                "p_season_end_year": season_end_year,
                "p_url_event": url_event,
                "p_run_url": run_url(),
                "p_override_sha256": override_sha256(event_code),
            }
        )
        print(f"run record {run_id} opened on {environment} (commit {commit[:12]})")
        return cls(db, run_id)

    def add_schedule(self, kept: Sequence[Mapping], skipped: Sequence[Mapping]) -> None:
        self.schedule = {
            "sha256": schedule_sha256(kept, skipped),
            "kept": len(kept),
            "skipped": [{"name": s.get("name"), "reason": s.get("reason")} for s in skipped],
        }

    def add_unparseable(self, name: str, uuid: str) -> None:
        self.rounds.append({"name": name, "uuid": uuid, "status": "unparseable"})

    def add_round(self, rec: Mapping, decision: Mapping, ctx: Any = None) -> None:
        """One listing the run read: its hash, the keep-rule's verdict, and, when it
        was committed, what the commit did."""
        entry = {
            "name": rec["name"],
            "uuid": rec["uuid"],
            "url": rec["url"],
            "sha256": listing_sha256(rec["name"], rec["uuid"], rec["has_de"], rec["_base"].results),
            "count": rec["count"],
            "has_de": rec["has_de"],
            "weapon": rec["weapon"],
            "gender": rec["gender"],
            "categories": list(rec["cats"]),
            "status": decision["status"],
            "reason": decision.get("reason", ""),
            "committed_categories": list(decision.get("commit_cats") or []),
        }
        if ctx is not None:
            entry["outcome"] = _outcome(ctx)
        self.rounds.append(entry)

    def listings(self) -> dict:
        return {"schedule": self.schedule, "rounds": self.rounds}

    def finish(self) -> dict:
        changes = self.db.finish_ingest_run(self.run_id, self.listings()) or {}
        counts = ", ".join(f"{k} {len(v)}" for k, v in changes.items() if isinstance(v, list))
        print(f"run record {self.run_id} finished: {len(self.rounds)} listing(s); {counts}")
        return changes

    def fail(self, error: str) -> None:
        """Close the row FAILED. Never masks the ingestion's own error."""
        try:
            self.db.fail_ingest_run(self.run_id, error, self.listings())
            print(f"run record {self.run_id} failed: {error}")
        except Exception as e:
            print(f"  (run record {self.run_id} could not be closed: {e})")
