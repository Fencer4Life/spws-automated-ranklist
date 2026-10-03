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


def _identity(ctx: Any) -> dict:
    """What the identity step reported for the listing (its IDENTITY fragment):
    fencers created with their nearest existing name, birth years reconciled,
    conflicts, and the rows left PENDING. The gate reads it (ADR-108 §5)."""
    payload: dict = {}
    for fragment in getattr(ctx, "report", None) or []:
        if getattr(fragment, "section", None) == "IDENTITY":
            payload = dict(fragment.payload or {})
    clean = json.loads(json.dumps(payload, ensure_ascii=False, default=str))
    return {
        "created": clean.get("created") or [],
        "reconciled": clean.get("reconciled") or [],
        "conflicts": clean.get("conflicts") or [],
        "pending": [
            {
                "scraped_name": m.get("scraped_name"),
                "place": m.get("place"),
                "notes": m.get("notes"),
            }
            for m in clean.get("matches") or []
            if m.get("method") == "PENDING"
        ],
    }


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


class ListingLog:
    """The schedule and every listing a run read, with their hashes. The
    ingestion adds them as it reads them. Plan mode keeps one without a
    database (ADR-108 §6); RunRecord stores it on the run row."""

    def __init__(self) -> None:
        self.schedule: dict | None = None
        self.rounds: list[dict] = []
        self.current: str | None = None
        self.refusal: dict | None = None

    def add_schedule(self, kept: Sequence[Mapping], skipped: Sequence[Mapping]) -> None:
        from python.pipeline.promotion.lifecycle import NOT_FINAL, last_day

        self.schedule = {
            "sha256": schedule_sha256(kept, skipped),
            "kept": len(kept),
            "skipped": [{"name": s.get("name"), "reason": s.get("reason")} for s in skipped],
            # ADR-108 §7: the latest day an individual listing is scheduled on.
            "last_day": last_day([*kept, *(s for s in skipped if s.get("reason") == NOT_FINAL)]),
        }

    def add_unparseable(self, name: str, uuid: str) -> None:
        self.rounds.append({"name": name, "uuid": uuid, "status": "unparseable"})

    def begin(self, rec: Mapping) -> None:
        """The listing about to be committed, so a refusal can name it."""
        self.current = rec["name"]

    def add_round(self, rec: Mapping, decision: Mapping, ctx: Any = None) -> None:
        """One listing the run read: its hash and its rows as parsed, the
        keep-rule's verdict, and, when it was committed, what the commit did and
        what the identity step reported."""
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
            "rows": [[r.place, r.fencer_name] for r in rec["_base"].results],
        }
        if ctx is not None:
            entry["outcome"] = _outcome(ctx)
            entry["identity"] = _identity(ctx)
        self.rounds.append(entry)
        self.current = None

    def listings(self) -> dict:
        out: dict = {"schedule": self.schedule, "rounds": self.rounds}
        if self.refusal:
            out["refusal"] = self.refusal
        return out


class RunRecord(ListingLog):
    """One open run. `finish` or `fail` closes the row with its listings."""

    def __init__(self, db: Any, run_id: int):
        super().__init__()
        self.db = db
        self.run_id = run_id

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

    def finish(self) -> dict:
        changes = self.db.finish_ingest_run(self.run_id, self.listings()) or {}
        counts = ", ".join(f"{k} {len(v)}" for k, v in changes.items() if isinstance(v, list))
        print(f"run record {self.run_id} finished: {len(self.rounds)} listing(s); {counts}")
        return changes

    def fail(self, error: str, *, kind: str | None = None, message: str | None = None) -> None:
        """Close the row FAILED. A refused listing (ListingRefused) is named with
        its kind, for the gate. Never masks the ingestion's own error."""
        if kind:
            self.refusal = {"listing": self.current, "kind": kind, "message": message or error}
        try:
            self.db.fail_ingest_run(self.run_id, error, self.listings())
            print(f"run record {self.run_id} failed: {error}")
        except Exception as e:
            print(f"  (run record {self.run_id} could not be closed: {e})")
