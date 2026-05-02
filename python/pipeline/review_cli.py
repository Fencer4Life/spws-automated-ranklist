"""
Phase 3 (ADR-050) interactive review CLI.

Per-event lifecycle for the operational rebuild (Phase 5). Walks events
one at a time, lets the operator pick the source-of-truth, runs the
unified pipeline, generates a 3-way diff, and decides commit / discard /
iterate.

Usage:
    python -m pipeline.review_cli <event_code>

Source-of-truth choices (per master plan):
  1  Use recorded URL (event.url_results)
  2  Paste different URL
  3  Paste local XML/CSV/JSON path
  4  EVF API (authoritative for EVF events — see project_evf_predominance.md)
  q  Skip this event

Frozen-snapshot choice deferred to Phase 4 per master plan boundary
(needs ADR-051 for the frozen-snapshot semantics).

Architectural decisions (Phase 3 design RFC, locked 2026-05-02):
  - Q4: separate module from ingest_cli (own arg surface, own concerns).
  - Q1: 5-surface override YAML loaded per event.
  - Q3: matcher config hot-reloaded at the start of each iteration.

Tests: python/tests/test_review_cli.py.
"""

from __future__ import annotations

import argparse
import os
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

from python.pipeline.db_connector import create_db_connector
from python.pipeline.draft_store import DraftStore
from python.pipeline.notifications import TelegramNotifier
from python.pipeline.orchestrator import run_pipeline
from python.pipeline.overrides import load_for_event
from python.pipeline.three_way_diff import (
    build_diff,
    confidence_histogram,
    render_markdown,
    write_diff,
)


# ===========================================================================
# Source-of-truth choice + fetcher contract
# ===========================================================================

@dataclass(frozen=True)
class SourceChoice:
    """Operator's source-of-truth decision for one event."""
    kind: str          # "recorded" | "url" | "path" | "skip"
    value: str | None  # URL or path; None for skip


class Fetcher:
    """Default fetcher: dispatches URLs to the right scraper by URL pattern,
    paths to the file-import module by extension, and EVF events to the
    EVF API client.

    Production wiring covers all 8 sources from Phase 1's parser registry.
    Tests inject a mock to avoid real I/O.
    """
    def fetch_url(self, url: str):
        raise NotImplementedError(
            "Fetcher.fetch_url: production wiring lands in Phase 3b. "
            "Inject a mock for tests."
        )

    def fetch_path(self, path: str):
        raise NotImplementedError(
            "Fetcher.fetch_path: production wiring lands in Phase 3b. "
            "Inject a mock for tests."
        )

    def fetch_evf_api(self, event: dict):
        """Fetch tournament results for an event via the EVF API.

        The event dict must contain at minimum txt_code, dt_start, dt_end.
        Returns ParsedTournament IR built via python.scrapers.evf_results.
        EVF events are authoritative on the EVF site (see
        project_evf_predominance.md), so this is the high-value path for
        EVF event review.
        """
        raise NotImplementedError(
            "Fetcher.fetch_evf_api: production wiring lands in Phase 3b. "
            "Inject a mock for tests."
        )


# ===========================================================================
# ReviewSession — the per-event interactive lifecycle
# ===========================================================================

class ReviewSession:
    """Encapsulates one event's review iteration loop.

    Constructor takes injectable prompt + output callables so tests can
    drive the dialog without blocking on stdin.
    """

    def __init__(
        self,
        event_code: str,
        db: Any,
        draft_store: DraftStore,
        prompt: Callable[[str], str] = input,
        output: Callable[[str], None] = print,
        fetcher: Fetcher | None = None,
        season_end_year: int = 2026,
    ) -> None:
        self.event_code = event_code
        self.db = db
        self.draft_store = draft_store
        self._prompt = prompt
        self._output = output
        self.fetcher = fetcher or Fetcher()
        self.season_end_year = season_end_year
        self.run_id: str | None = None  # set on first iteration

    # ---- Output helpers ----

    def _say(self, msg: str) -> None:
        self._output(msg)

    # ---- Stage 1: event summary ----

    def show_event_summary(self) -> dict | None:
        """Look up + display the event. Returns event dict or None if missing."""
        event = self.db.find_event_by_code(self.event_code)
        if event is None:
            self._say(f"⚠ Event not found: {self.event_code}")
            return None
        self._say(f"=== Event {event.get('txt_code')} — {event.get('txt_name', '')} ===")
        self._say(f"  Dates: {event.get('dt_start')} → {event.get('dt_end')}")
        self._say(f"  Status: {event.get('enum_status')}")
        self._say(f"  Recorded url_results: {event.get('url_results') or '_(none)_'}")
        return event

    # ---- Stage 2: source-of-truth choice ----

    def prompt_source_choice(self) -> SourceChoice:
        """Loop until operator picks a valid source. Returns SourceChoice."""
        while True:
            self._say("")
            self._say("Source of truth:")
            self._say("  [1] Use recorded URL")
            self._say("  [2] Paste a different URL")
            self._say("  [3] Paste a local file path (XML / CSV / JSON / XLSX)")
            self._say("  [4] EVF API (authoritative for EVF events)")
            self._say("  [q] Skip this event")
            choice = self._prompt("> ").strip().lower()

            if choice == "q":
                return SourceChoice(kind="skip", value=None)
            if choice == "1":
                event = self.db.find_event_by_code(self.event_code)
                url = (event or {}).get("url_results")
                if not url:
                    self._say("⚠ Recorded URL is empty for this event. Pick another option.")
                    continue
                return SourceChoice(kind="recorded", value=url)
            if choice == "2":
                url = self._prompt("URL: ").strip()
                if not url:
                    self._say("⚠ Empty URL.")
                    continue
                return SourceChoice(kind="url", value=url)
            if choice == "3":
                path = self._prompt("Path: ").strip()
                if not path:
                    self._say("⚠ Empty path.")
                    continue
                return SourceChoice(kind="path", value=path)
            if choice == "4":
                # EVF API — value carries the event_code; fetcher resolves the rest
                return SourceChoice(kind="evf_api", value=self.event_code)

            self._say(f"⚠ Invalid choice {choice!r}. Pick 1, 2, 3, 4, or q.")

    # ---- Stage 3: fetch + parse ----

    def fetch_source(self, choice: SourceChoice):
        """Dispatch to the fetcher; returns ParsedTournament IR."""
        if choice.kind in ("recorded", "url"):
            return self.fetcher.fetch_url(choice.value)
        if choice.kind == "path":
            return self.fetcher.fetch_path(choice.value)
        if choice.kind == "evf_api":
            event = self.db.find_event_by_code(self.event_code)
            if event is None:
                raise ValueError(f"EVF API path: event {self.event_code} not found in DB")
            return self.fetcher.fetch_evf_api(event)
        raise ValueError(f"fetch_source called with unsupported kind: {choice.kind!r}")

    # ---- Stage 4: pipeline + drafts + diff ----

    def run_iteration(self, parsed, staging_dir: Path | None = None):
        """Run one full pipeline iteration for the parsed IR.

        Loads overrides fresh (hot-reload), runs S1-S7, writes drafts,
        generates 3-way diff markdown to staging_dir.

        Returns:
          (PipelineContext, diff_path)
        """
        # Hot-reload overrides every iteration (operator may have edited mid-loop)
        overrides = load_for_event(self.event_code)

        ctx = run_pipeline(
            parsed=parsed,
            overrides=overrides,
            db=self.db,
            season_end_year=self.season_end_year,
        )

        if ctx.halted:
            self._say(
                f"⚠ Pipeline halted at {ctx.halted_at_stage}: "
                f"{ctx.halt_reason.value if ctx.halt_reason else '?'} — {ctx.halt_detail}"
            )
            # Still write what we have to draft for inspection
            return ctx, self._write_diff(ctx, staging_dir, halted=True)

        # Mint or reuse run_id (resumability across iterations)
        if self.run_id is None:
            self.run_id = str(uuid.uuid4())

        # Write tournament_drafts (one per category if combined; else one)
        # For Phase 3, build minimal draft rows from ctx.event + ctx.matches.
        # Production-rich draft rows happen in Phase 4 commit-path work.
        self.draft_store.write_tournament_drafts(
            tournaments=self._build_tournament_draft_rows(ctx),
            run_id=self.run_id,
        )
        self.draft_store.write_result_drafts(
            results=self._build_result_draft_rows(ctx),
            run_id=self.run_id,
        )

        diff_path = self._write_diff(ctx, staging_dir, halted=False)
        return ctx, diff_path

    def _build_tournament_draft_rows(self, ctx) -> list[dict]:
        """Translate PipelineContext into tbl_tournament_draft rows.

        Phase 3 minimal: one row per V-cat (or one if not combined-pool).
        """
        event_id = (ctx.event or {}).get("id_event")
        rows = []
        if ctx.is_combined_pool and ctx.splits:
            for vcat in sorted(ctx.splits.keys()):
                rows.append(self._draft_row_skeleton(ctx, event_id, vcat))
        else:
            rows.append(self._draft_row_skeleton(
                ctx, event_id, ctx.parsed.category_hint or "V1"
            ))
        return rows

    def _draft_row_skeleton(self, ctx, event_id, vcat) -> dict:
        return {
            "id_event": event_id,
            "txt_code": f"{self.event_code}-{vcat}-{ctx.parsed.weapon}-{ctx.parsed.gender}",
            "enum_type": "PPW",  # caller can override per event type
            "enum_weapon": ctx.parsed.weapon,
            "enum_gender": ctx.parsed.gender,
            "enum_age_category": vcat,
            "dt_tournament": ctx.parsed.parsed_date.isoformat() if ctx.parsed.parsed_date else None,
            "url_results": ctx.parsed.source_url,
            "enum_parser_kind": ctx.parsed.source_kind.value,
            "txt_source_url_used": ctx.parsed.source_url,
        }

    def _build_result_draft_rows(self, ctx) -> list[dict]:
        """Translate ctx.matches into tbl_result_draft rows.

        Phase 3 minimal: each StageMatchResult → one draft row. The
        id_tournament_draft linkage is filled in by the commit path
        (Phase 4 work) — Phase 3 puts a placeholder of 0 (caller wires it).
        """
        return [
            {
                "id_fencer": m.id_fencer,
                "id_tournament_draft": 0,  # placeholder; Phase 4 fills via mapping
                "int_place": m.place,
                "txt_scraped_name": m.scraped_name,
                "num_match_confidence": m.confidence,
                "enum_match_method": m.method,
            }
            for m in ctx.matches
        ]

    def _write_diff(self, ctx, staging_dir: Path | None, *, halted: bool) -> Path:
        """Build + write the 3-way diff markdown for this iteration."""
        # Source rows from the parsed IR
        source_rows = [
            {"fencer_name": r.fencer_name, "place": r.place,
             "id_fencer": None}
            for r in ctx.parsed.results
        ]
        # CERT rows from cert_ref (stub returns [] in Phase 3)
        cert_rows = self.db.fetch_cert_rows_for_event(self.event_code) \
            if hasattr(self.db, "fetch_cert_rows_for_event") else []
        # New LOCAL rows from ctx.matches
        new_rows = [
            {"fencer_name": m.scraped_name, "place": m.place,
             "id_fencer": m.id_fencer}
            for m in ctx.matches
        ]

        diff_rows = build_diff(source_rows, cert_rows, new_rows)
        hist = confidence_histogram(ctx.matches)
        notes = []
        if halted:
            notes.append(
                f"⚠ Pipeline HALTED at {ctx.halted_at_stage} — diff is incomplete."
            )
        md = render_markdown(self.event_code, diff_rows, hist, notes=notes)
        return write_diff(self.event_code, md, staging_dir=staging_dir)

    # ---- Stage 5: action prompt ----

    def prompt_action(self) -> str:
        """Loop until operator picks c/d/i. Returns 'commit'|'discard'|'iterate'."""
        while True:
            choice = self._prompt(
                "Action: [c]ommit / [d]iscard / [i]terate > "
            ).strip().lower()
            if choice in ("c", "commit"):
                return "commit"
            if choice in ("d", "discard"):
                return "discard"
            if choice in ("i", "iterate"):
                return "iterate"
            self._say(f"⚠ Invalid action {choice!r}. Pick c, d, or i.")

    # ---- Stage 6: commit / discard ----

    def commit(self) -> dict:
        if self.run_id is None:
            return {"error": "no run_id (no iteration ran)"}
        result = self.draft_store.commit(self.run_id)
        self._say(f"✅ Committed draft {self.run_id}: {result}")
        return result

    def discard(self) -> dict:
        if self.run_id is None:
            return {"discarded": 0}
        result = self.draft_store.discard(self.run_id)
        self._say(f"🗑  Discarded draft {self.run_id}: {result}")
        return result

    # ---- Top-level orchestration ----

    def run(self) -> str:
        """Walk the full per-event loop. Returns terminal state:
        'committed' | 'discarded' | 'skipped' | 'event_not_found'.
        """
        event = self.show_event_summary()
        if event is None:
            return "event_not_found"

        choice = self.prompt_source_choice()
        if choice.kind == "skip":
            self._say("Skipped.")
            return "skipped"

        parsed = self.fetch_source(choice)

        while True:
            ctx, diff_path = self.run_iteration(parsed)
            self._say(f"📄 3-way diff written to {diff_path}")
            action = self.prompt_action()
            if action == "commit":
                self.commit()
                return "committed"
            if action == "discard":
                self.discard()
                return "discarded"
            # iterate: loop again (overrides re-loaded next iteration)
            self._say("↻ Re-running pipeline (overrides + matcher config reloaded)…")


# ===========================================================================
# CLI entry point
# ===========================================================================

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Phase 3 (ADR-050) interactive event review CLI"
    )
    parser.add_argument("event_code", help="Event txt_code (e.g., PEW3-2025-2026)")
    parser.add_argument("--season-end-year", type=int, default=2026)
    args = parser.parse_args()

    db = create_db_connector()
    store = DraftStore(db)
    notifier = TelegramNotifier(
        os.environ.get("TELEGRAM_BOT_TOKEN"),
        os.environ.get("TELEGRAM_CHAT_ID"),
    )

    session = ReviewSession(
        event_code=args.event_code,
        db=db,
        draft_store=store,
        season_end_year=args.season_end_year,
    )
    try:
        terminal_state = session.run()
        if terminal_state in ("event_not_found", "skipped"):
            sys.exit(2)
    except Exception as e:
        notifier.notify_pipeline_failure(f"review_cli {args.event_code}: {e}")
        raise


if __name__ == "__main__":
    main()
