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

Cert_ref fallback choice [5] added in Phase 4 as just-another-parser
(no special status — engine still computes points like every other source).

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

from python.pipeline.commit_lifecycle import run_post_commit_hooks
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
# Parity-payload extractor for the EVF API path
# ===========================================================================

def _extract_parity_payload(parsed) -> list[dict] | None:
    """Best-effort extract of EVF parity payload from a ParsedTournament.

    Returns list of {name, pos, points} dicts when the parsed IR came from
    the EVF API and exposed per-fencer EVF points alongside place. Returns
    None for non-EVF sources or when the IR doesn't carry score detail.

    The IR's ParsedResult shape (as of Phase 1) doesn't carry a `points`
    field directly, so EVF-side score extraction relies on the parser
    annotating its rows. If the EVF parser doesn't expose points yet,
    callers fall back to "no parity check this run" gracefully.
    """
    from python.pipeline.ir import SourceKind
    if parsed is None:
        return None
    if getattr(parsed, "source_kind", None) != SourceKind.EVF_API:
        return None
    payload: list[dict] = []
    for r in getattr(parsed, "results", []) or []:
        # Look for a vendor-set `points` attribute on ParsedResult; absent → skip
        pts = getattr(r, "points", None)
        if pts is None:
            continue
        payload.append({
            "name": getattr(r, "fencer_name", ""),
            "pos": getattr(r, "place", 0),
            "points": float(pts),
        })
    return payload or None


# ===========================================================================
# Source-of-truth choice + fetcher contract
# ===========================================================================

@dataclass(frozen=True)
class SourceChoice:
    """Operator's source-of-truth decision for one event."""
    kind: str          # "recorded" | "url" | "path" | "skip"
    value: str | None  # URL or path; None for skip


def _detect_source_kind_from_url(url: str) -> str:
    """Map a URL to a SourceKind label by hostname pattern.

    Recognized hostnames:
      fencingtimelive.com → FTL (JSON API endpoint expected by FTL parser)
      engarde-* / engarde / hemafencing → ENGARDE
      4fence.com / 4fence.world → FOURFENCE
      fencingworldwide.com / ophardt.online → OPHARDT_HTML
      dartagnan.org / dartagnan.com → DARTAGNAN
      veteransfencing.eu → EVF_API
    Falls back to FENCINGTIME_XML for *.xml file URLs.
    """
    u = (url or "").lower()
    if "fencingtimelive.com" in u or "fencingtime.com" in u:
        return "FTL"
    if "engarde" in u or "hemafencing" in u:
        return "ENGARDE"
    if "4fence" in u:
        return "FOURFENCE"
    if "fencingworldwide.com" in u or "ophardt" in u:
        return "OPHARDT_HTML"
    if "dartagnan" in u:
        return "DARTAGNAN"
    if "veteransfencing.eu" in u:
        return "EVF_API"
    if u.endswith(".xml"):
        return "FENCINGTIME_XML"
    return "FTL"  # default — most common live source


class Fetcher:
    """Default fetcher: dispatches URLs to the right scraper by hostname,
    paths to the file-import module by extension, and EVF events to the
    EVF API client.

    Production wiring covers all 9 sources from Phase 1's parser registry
    (8 vendors + cert_ref fallback). Tests inject a mock to avoid real I/O.
    """

    def __init__(self, http_client=None) -> None:
        # Lazy import + injectable httpx client for tests
        if http_client is None:
            try:
                import httpx
                http_client = httpx.Client(timeout=30.0, follow_redirects=True)
            except ImportError:  # pragma: no cover
                http_client = None
        self._http = http_client

    def _get(self, url: str) -> str:
        """HTTP GET → text body. Raises on non-2xx."""
        if self._http is None:
            raise RuntimeError("Fetcher: no HTTP client available")
        resp = self._http.get(url)
        resp.raise_for_status()
        return resp.text

    def fetch_url(self, url: str):
        """Fetch a URL and dispatch to the matching parser by hostname pattern."""
        kind = _detect_source_kind_from_url(url)
        if kind == "FTL":
            # FTL JSON API: results endpoint typically returns JSON list
            import json as _json
            from python.scrapers.ftl import parse_json
            text = self._get(url)
            try:
                data = _json.loads(text)
            except _json.JSONDecodeError:
                # Some FTL pages serve HTML instead of JSON; fall back
                from python.scrapers.fencingtime_xml import parse as _ft_xml_parse
                return _ft_xml_parse(text.encode("utf-8"), source_url=url)
            return parse_json(data, source_url=url)
        if kind == "ENGARDE":
            from python.scrapers.engarde import parse_html
            return parse_html(self._get(url), source_url=url)
        if kind == "FOURFENCE":
            from python.scrapers.fourfence import parse_html
            return parse_html(self._get(url), source_url=url)
        if kind == "OPHARDT_HTML":
            from python.scrapers.ophardt import parse_results
            return parse_results(self._get(url), source_url=url)
        if kind == "DARTAGNAN":
            from python.scrapers.dartagnan import parse_rankings
            return parse_rankings(self._get(url), source_url=url)
        if kind == "EVF_API":
            from python.scrapers.evf_results import parse_results
            return parse_results(self._get(url), source_url=url)
        if kind == "FENCINGTIME_XML":
            from python.scrapers.fencingtime_xml import parse as ft_xml_parse
            return ft_xml_parse(self._get(url).encode("utf-8"), source_url=url)
        raise ValueError(f"Fetcher.fetch_url: no parser for URL {url!r} (detected kind={kind})")

    def fetch_path(self, path: str):
        """Read a local file and dispatch to file_import / ft_xml by extension."""
        from pathlib import Path
        p = Path(path)
        data = p.read_bytes()
        if p.suffix.lower() == ".xml":
            from python.scrapers.fencingtime_xml import parse as ft_xml_parse
            return ft_xml_parse(data, source_url=f"file://{p}")
        from python.scrapers.file_import import parse as file_import_parse
        return file_import_parse(data, source_url=f"file://{p}", filename=p.name)

    def fetch_evf_api(self, event: dict):
        """Fetch tournament results for an event via the EVF API.

        The event dict must contain at minimum txt_code, dt_start, dt_end.
        Returns ParsedTournament IR built via python.scrapers.evf_results.
        EVF events are authoritative on the EVF site (see
        project_evf_predominance.md), so this is the high-value path for
        EVF event review.

        Phase 4: thin wrapper around python.scrapers.evf_results.parse_results
        once the operator-supplied EVF API endpoint URL is known. The actual
        EVF API endpoint URL must be on the event row (url_results) or
        synthesized from the event's id/date — operator's responsibility.
        """
        url = (event or {}).get("url_results")
        if not url:
            raise ValueError(
                "Fetcher.fetch_evf_api: event has no url_results to fetch from"
            )
        from python.scrapers.evf_results import parse_results
        return parse_results(self._get(url), source_url=url)

    def fetch_cert_ref(self, event_code: str, db) -> "ParsedTournament":
        """Fetch cert_ref placements for an event and parse to IR.

        Phase 4 (ADR-050): operator picks `[5] cert_ref placements` when
        no live URL is available. Reads cert_ref via DbConnector RPC,
        hands to python.scrapers.cert_ref.parse.
        """
        from python.scrapers.cert_ref import parse as cert_ref_parse
        rows = db.fetch_cert_rows_for_event(event_code) if hasattr(db, "fetch_cert_rows_for_event") else []
        tournament = (
            db.fetch_cert_tournament_for_event(event_code)
            if hasattr(db, "fetch_cert_tournament_for_event") else None
        )
        return cert_ref_parse({"tournament": tournament or {}, "results": rows})

    # ------------------------------------------------------------------
    # Phase 5 — event-level fetch (multi-tournament expansion)
    # ------------------------------------------------------------------

    def fetch_event_url_with_skips(
        self, event_url: str
    ) -> "tuple[list, list[dict]]":
        """Phase 5 (ADR-057): same as fetch_event_url but ALSO returns the
        list of brackets the splitter skipped at parse time, so the runner
        can surface them in the per-event summary for operator verification.

        Returns: (parsed_list, skipped_list). skipped_list entries:
          {"weapon": str|None, "name": str, "url": str, "reason": str}
        """
        skipped: list[dict] = []
        if _is_ftl_event_schedule(event_url):
            from python.scrapers.ftl_auth import get_authed_ftl_client
            from python.tools.scrape_ftl_event_urls import (
                parse_event_schedule,
                parse_tournament_name,
                MIKST_PATTERN,
                SKIP_PATTERNS,
            )
            FTL_DATA_PREFIX = "https://www.fencingtimelive.com/events/results/data/"
            results: list = []
            event_url = _normalize_ftl_url(event_url)
            with get_authed_ftl_client() as authed:
                resp = authed.get(event_url)
                resp.raise_for_status()
                # parse_event_schedule(with_skips=True) returns BOTH the
                # kept brackets and the splitter-rejected ones (Mixed / DE /
                # etc.) so we can surface them in the per-event summary.
                raw_entries, name_skips = parse_event_schedule(
                    resp.text, with_skips=True
                )

                # Splitter-time name-pattern skips → record with weapon probe
                for sk in name_skips:
                    name_s = sk["name"]
                    upper = name_s.upper()
                    wpn = None
                    for k in ("EPEE", "FOIL", "SABRE", "SABER", "FLORET",
                              "SZABLA", "SZPADA", "ÉPÉE"):
                        if k in upper:
                            wpn = {"FLORET": "FOIL", "SZABLA": "SABRE",
                                   "SZPADA": "EPEE", "ÉPÉE": "EPEE",
                                   "SABER": "SABRE"}.get(k, k)
                            break
                    skipped.append({
                        "weapon": wpn,
                        "name": name_s,
                        "url": f"{FTL_DATA_PREFIX}{sk['uuid']}",
                        "reason": sk.get("reason", "splitter skip"),
                    })

                for raw in raw_entries:
                    name = raw["name"]
                    per_url = f"{FTL_DATA_PREFIX}{raw['uuid']}"
                    # Bracket name was kept by parse_event_schedule; try to
                    # extract weapon/gender/V-cat. Returning None here means
                    # parse_tournament_name found the name unparseable.
                    parsed_name = parse_tournament_name(name)
                    if parsed_name is None:
                        skipped.append({
                            "weapon": None, "name": name, "url": per_url,
                            "reason": "unparseable bracket name",
                        })
                        continue
                    is_combined = isinstance(parsed_name, list)
                    if is_combined:
                        weapon, gender, _ = parsed_name[0]
                        category = None
                    else:
                        weapon, gender, category = parsed_name
                    saved_http = self._http
                    try:
                        self._http = authed
                        per_parsed = self.fetch_url(per_url)
                    finally:
                        self._http = saved_http
                    annotated = _annotate_parsed(
                        per_parsed,
                        weapon=weapon, gender=gender,
                        age_category=category,
                        ftl_source_name=name,
                    )
                    results.append(annotated)
            return results, skipped
        return [self.fetch_url(event_url)], skipped

    def fetch_event_url(self, event_url: str) -> "list[ParsedTournament]":
        """Expand an event-level URL into per-tournament ParsedTournament IRs.

        Phase 5 entry point. Always start from the event URL; first step is
        to determine the per-tournament URLs, then fetch + parse each.

        FTL eventSchedule URLs (`/tournaments/eventSchedule/<UUID>`) get
        expanded via `python.tools.scrape_ftl_event_urls.parse_event_schedule`
        + an authed FTL client (FTL pages require login since 2026-04).

        For non-FTL or single-tournament URLs, returns a list of length 1
        wrapping the existing fetch_url result, so callers don't have to
        special-case URL kinds.

        Raises:
            ValueError if the event URL produces zero parseable tournaments.
        """
        if _is_ftl_event_schedule(event_url):
            from python.scrapers.ftl_auth import get_authed_ftl_client
            from python.tools.scrape_ftl_event_urls import (
                parse_event_schedule,
                parse_tournament_name,
            )
            FTL_DATA_PREFIX = "https://www.fencingtimelive.com/events/results/data/"
            event_url = _normalize_ftl_url(event_url)
            with get_authed_ftl_client() as authed:
                # 1. Discover per-tournament UUIDs from the eventSchedule page
                resp = authed.get(event_url)
                resp.raise_for_status()
                raw_entries = parse_event_schedule(resp.text)

                # 2. Map names → (weapon, gender, category) and per-tournament URL.
                #    A tuple means a single-V-cat bracket — emit one IR with
                #    that category. A list means combined-pool ("all cats" or
                #    "v0v1v2") — emit ONE IR with category_hint=None and let
                #    Stage 4 (combined-pool split) handle the V-cat split via
                #    per-fencer marker. Emitting one IR per category here
                #    causes duplicate pipeline runs against identical data.
                results: list = []
                for raw in raw_entries:
                    parsed_name = parse_tournament_name(raw["name"])
                    if parsed_name is None:
                        continue
                    is_combined = isinstance(parsed_name, list)
                    if is_combined:
                        weapon, gender, _ = parsed_name[0]
                        category = None  # Stage 4 splits via marker
                    else:
                        weapon, gender, category = parsed_name

                    per_url = f"{FTL_DATA_PREFIX}{raw['uuid']}"

                    # 3. Fetch + parse each per-tournament results page
                    #    via the authed client (FTL JSON API endpoint)
                    saved_http = self._http
                    try:
                        self._http = authed
                        per_parsed = self.fetch_url(per_url)
                    finally:
                        self._http = saved_http

                    annotated = _annotate_parsed(
                        per_parsed,
                        weapon=weapon,
                        gender=gender,
                        age_category=category,
                        ftl_source_name=raw["name"],
                    )
                    results.append(annotated)

                if not results:
                    raise ValueError(
                        f"fetch_event_url: zero parseable tournaments from "
                        f"FTL eventSchedule {event_url!r}"
                    )
                return results

        # Non-FTL-eventSchedule URLs — single-tournament path
        return [self.fetch_url(event_url)]


def _is_ftl_event_schedule(url: str) -> bool:
    """True iff `url` is an FTL master event-schedule page (multi-tournament)."""
    return bool(url) and "fencingtimelive.com" in url and "/tournaments/eventSchedule/" in url


def _normalize_ftl_url(url: str | None) -> str | None:
    """Force `www.fencingtimelive.com` host on FTL URLs.

    Phase 5 follow-up: FTL's auth cookies are scoped to the
    `www.fencingtimelive.com` host. Hitting the bare-hostname form
    (`fencingtimelive.com/…`) produces a 200 + redirect to
    `/account/login` because the cookies don't apply, and our parsers
    silently see 0 brackets. Some seed URLs lack the `www.` prefix
    (e.g. GP2-2023-2024). Normalize at fetch time so a single-host
    cookie jar works regardless of seed shape.
    """
    if not url:
        return url
    return url.replace(
        "https://fencingtimelive.com/",
        "https://www.fencingtimelive.com/",
        1,
    ).replace(
        "http://fencingtimelive.com/",
        "https://www.fencingtimelive.com/",
        1,
    )


def _to_human_results_url(url: str | None) -> str | None:
    """Convert an FTL JSON-data results URL to its human-friendly results page.

    The pipeline FETCHES `/events/results/data/<UUID>` (JSON API) but stores
    `url_results` for users to click. `/data/` belongs in `txt_source_url_used`
    only — strip it for the human-facing field. Non-FTL URLs are passed through.
    """
    if not url:
        return url
    return url.replace(
        "/events/results/data/",
        "/events/results/",
    )


def _annotate_parsed(parsed, *, weapon, gender, age_category, ftl_source_name):
    """Stamp weapon/gender/category_hint onto a ParsedTournament IR.

    The eventSchedule splitter knows the V-cat / weapon / gender from the
    sub-tournament's display name; the per-tournament JSON API doesn't
    always echo them. We override here so Stage 7 URL→data validation
    sees the right values. (`age_category` from the splitter maps to the
    IR's `category_hint` field.)

    Mutates a shallow copy via dataclasses.replace when possible; falls
    back to attribute set when the IR isn't a dataclass.
    """
    try:
        import dataclasses as _dc
        if _dc.is_dataclass(parsed):
            return _dc.replace(parsed, weapon=weapon, gender=gender,
                                category_hint=age_category)
    except Exception:
        pass
    setattr(parsed, "weapon", weapon)
    setattr(parsed, "gender", gender)
    setattr(parsed, "category_hint", age_category)
    setattr(parsed, "_ftl_source_name", ftl_source_name)
    return parsed


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
        notifier: Any | None = None,
    ) -> None:
        self.event_code = event_code
        self.db = db
        self.draft_store = draft_store
        self._prompt = prompt
        self._output = output
        self.fetcher = fetcher or Fetcher()
        self.season_end_year = season_end_year
        self.run_id: str | None = None  # set on first iteration
        self.notifier = notifier
        # Phase 4: parity payload captured if/when operator picks the EVF API
        # path; consumed by run_post_commit_hooks after commit.
        self._evf_parity_payload: list[dict] | None = None
        self._last_ctx: Any = None
        self._last_summary: dict = {}

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
            self._say("  [5] cert_ref placements (no live URL — fallback to backup snapshot)")
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
            if choice == "5":
                # cert_ref fallback — value carries the event_code
                return SourceChoice(kind="cert_ref", value=self.event_code)

            self._say(f"⚠ Invalid choice {choice!r}. Pick 1, 2, 3, 4, 5, or q.")

    # ---- Stage 3: fetch + parse ----

    def fetch_source(self, choice: SourceChoice):
        """Dispatch to the fetcher; returns ParsedTournament IR.

        Phase 4: when the operator picks the EVF API path, also capture the
        parity payload (per-fencer name/pos/points) for the post-commit
        parity gate. Other paths leave _evf_parity_payload = None.
        """
        if choice.kind in ("recorded", "url"):
            parsed = self.fetcher.fetch_url(choice.value)
            # If the operator's URL happens to be the EVF API, the parsed IR
            # already came from python.scrapers.evf_results — extract a payload
            # for parity (best-effort, ignored when None).
            self._evf_parity_payload = _extract_parity_payload(parsed)
            return parsed
        if choice.kind == "path":
            return self.fetcher.fetch_path(choice.value)
        if choice.kind == "evf_api":
            event = self.db.find_event_by_code(self.event_code)
            if event is None:
                raise ValueError(f"EVF API path: event {self.event_code} not found in DB")
            parsed = self.fetcher.fetch_evf_api(event)
            self._evf_parity_payload = _extract_parity_payload(parsed)
            return parsed
        if choice.kind == "cert_ref":
            return self.fetcher.fetch_cert_ref(self.event_code, self.db)
        raise ValueError(f"fetch_source called with unsupported kind: {choice.kind!r}")

    # ---- Stage 4: pipeline + drafts + diff ----

    def _summary_from_ctx(self, ctx) -> dict:
        """Build the matched/pending/auto_created/skipped counts for Telegram."""
        matched = sum(1 for m in ctx.matches if m.method == "AUTO_MATCHED")
        pending = sum(1 for m in ctx.matches if m.method == "PENDING")
        auto_created = sum(1 for m in ctx.matches if m.method == "AUTO_CREATED")
        skipped = sum(1 for m in ctx.matches if m.method == "EXCLUDED")
        return {
            "matched": matched, "pending": pending,
            "auto_created": auto_created, "skipped": skipped,
        }

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
            event_code=self.event_code,
        )
        self._last_ctx = ctx

        if ctx.halted:
            self._say(
                f"⚠ Pipeline halted at {ctx.halted_at_stage}: "
                f"{ctx.halt_reason.value if ctx.halt_reason else '?'} — {ctx.halt_detail}"
            )
            if self.notifier is not None:
                self.notifier.notify_stage_halt(
                    self.event_code,
                    ctx.halted_at_stage or "?",
                    ctx.halt_reason.value if ctx.halt_reason else "?",
                    ctx.halt_detail,
                )
            # Still write what we have to draft for inspection
            return ctx, self._write_diff(ctx, staging_dir, halted=True)

        # Mint or reuse run_id (resumability across iterations)
        if self.run_id is None:
            self.run_id = str(uuid.uuid4())

        # ADR-056 (Phase 5): build tournament_drafts from ctx.vcat_groups (one
        # per V-cat group, populated by s7_split_by_vcat) and link result_drafts
        # via the returned id_tournament_draft. Replaces the old placeholder-=0
        # path that prevented fn_commit_event_draft from migrating result rows.
        tournament_rows = self._build_tournament_draft_rows(ctx)

        # Phase 5 follow-up: VALIDATE every url_results before saving.
        # The validator fetches via the authed FTL client and rejects login
        # walls, HTTP errors, and the JSON data endpoint. Verdicts are
        # attached to the row dict (`_url_check`) so the runner can render
        # them in the summary; bad URLs do NOT block writing the draft —
        # the operator decides at sign-off whether to commit. (The check
        # is skipped when the caller passes self.skip_url_validation,
        # set by tests / offline mode.)
        if not getattr(self, "skip_url_validation", False):
            self._validate_draft_urls(tournament_rows)

        tournament_ids = self.draft_store.write_tournament_drafts(
            tournaments=tournament_rows,
            run_id=self.run_id,
        )
        # Map vcat → id_tournament_draft for the result-row linkage
        vcats_in_order = [r["enum_age_category"] for r in tournament_rows]
        vcat_to_tournament_id = dict(zip(vcats_in_order, tournament_ids))

        result_rows = self._build_result_draft_rows(ctx, vcat_to_tournament_id)
        if result_rows:
            self.draft_store.write_result_drafts(
                results=result_rows,
                run_id=self.run_id,
            )

        diff_path = self._write_diff(ctx, staging_dir, halted=False)
        return ctx, diff_path

    def _build_tournament_draft_rows(self, ctx) -> list[dict]:
        """Translate PipelineContext.vcat_groups into tbl_tournament_draft rows.

        ADR-056 (Phase 5): one row per V-cat group derived from matched
        fencers' birth years. `bool_joint_pool_split` is true iff the
        source bracket spanned ≥2 V-cats. Falls back to ctx.splits /
        category_hint when vcat_groups is empty (e.g. legacy callers).
        """
        event_id = (ctx.event or {}).get("id_event")
        rows = []

        if getattr(ctx, "vcat_groups", None):
            # ADR-049 refinement: bool_joint_pool_split flags only the
            # OUTLIER V-cat children — i.e. groups whose V-cat differs from
            # the bracket's nominal V-cat (`category_hint`, parsed from the
            # bracket name). The dominant child (V-cat == nominal) keeps
            # FALSE so it remains a "clean" V-cat ranking.
            # Combined-pool brackets (no nominal V-cat → category_hint is
            # None) flag every child TRUE, since there is no single
            # anchor V-cat to be "the real one".
            nominal_vcat = getattr(ctx.parsed, "category_hint", None)
            for vcat in sorted(ctx.vcat_groups.keys()):
                if not ctx.vcat_groups[vcat]:
                    continue
                row = self._draft_row_skeleton(ctx, event_id, vcat)
                if nominal_vcat is None:
                    row["bool_joint_pool_split"] = ctx.is_joint_pool
                else:
                    row["bool_joint_pool_split"] = (vcat != nominal_vcat)
                rows.append(row)
        elif ctx.is_combined_pool and ctx.splits:
            for vcat in sorted(ctx.splits.keys()):
                rows.append(self._draft_row_skeleton(ctx, event_id, vcat))
        else:
            rows.append(self._draft_row_skeleton(
                ctx, event_id, ctx.parsed.category_hint or "V1"
            ))
        return rows

    def _validate_draft_urls(self, tournament_rows: list[dict]) -> None:
        """Fetch every draft `url_results` and store the verdict on self.

        Phase 5 follow-up: catches the FTL login-wall problem (200 + login
        HTML) and the never-should-have-leaked `/events/results/data/<UUID>`
        format. Verdicts go into `self.url_check_results` keyed by
        txt_code (NOT into the row dict — Postgres would reject unknown
        columns on insert). Caching by URL avoids re-fetching when an
        outlier-V-cat draft shares a URL with its dominant-V-cat sibling.
        """
        from python.pipeline.url_reachability import check_results_url

        if not hasattr(self, "url_check_results"):
            self.url_check_results: dict[str, object] = {}
        cache: dict[str, object] = {}
        for row in tournament_rows:
            url = row.get("url_results")
            code = row.get("txt_code", "?")
            if url is None:
                continue
            if url in cache:
                verdict = cache[url]
            else:
                verdict = check_results_url(url)
                cache[url] = verdict
            self.url_check_results[code] = verdict
            try:
                self._say(
                    f"  url-check {code}: "
                    f"{'OK' if verdict.ok else verdict.reason}"
                    + (f" ({verdict.evidence})" if not verdict.ok and verdict.evidence else "")
                )
            except Exception:  # noqa: BLE001
                pass  # _say is best-effort logging only

    def _draft_row_skeleton(self, ctx, event_id, vcat) -> dict:
        # url_results is the human-friendly results page (what users see in a
        # browser); txt_source_url_used keeps the actual fetched endpoint
        # (e.g. FTL JSON `/events/results/data/<UUID>`) for the audit trail.
        return {
            "id_event": event_id,
            "txt_code": f"{self.event_code}-{vcat}-{ctx.parsed.weapon}-{ctx.parsed.gender}",
            "enum_type": "PPW",  # caller can override per event type
            "enum_weapon": ctx.parsed.weapon,
            "enum_gender": ctx.parsed.gender,
            "enum_age_category": vcat,
            "dt_tournament": ctx.parsed.parsed_date.isoformat() if ctx.parsed.parsed_date else None,
            "url_results": _to_human_results_url(ctx.parsed.source_url),
            "enum_parser_kind": ctx.parsed.source_kind.value,
            "txt_source_url_used": ctx.parsed.source_url,
        }

    def _build_result_draft_rows(
        self, ctx, vcat_to_tournament_id: dict[str, int] | None = None,
    ) -> list[dict]:
        """Translate vcat_groups → tbl_result_draft rows with proper linkage.

        ADR-056: each match in ctx.vcat_groups[V] gets the V's tournament_draft
        id assigned to id_tournament_draft (replaces the Phase-3 =0 placeholder
        that prevented fn_commit_event_draft from migrating result rows).
        """
        method_map = {
            "AUTO_MATCHED": "AUTO_MATCH",
            "USER_CONFIRMED": "USER_CONFIRMED",
            "AUTO_CREATED": "AUTO_CREATED",
            "BY_ESTIMATED": "BY_ESTIMATED",
        }
        rows: list[dict] = []
        if not getattr(ctx, "vcat_groups", None) or not vcat_to_tournament_id:
            return rows
        for vcat, matches in ctx.vcat_groups.items():
            tournament_id = vcat_to_tournament_id.get(vcat)
            if tournament_id is None:
                continue
            for m in matches:
                if m.method not in method_map:
                    continue  # PENDING / EXCLUDED — not finalized, skip
                rows.append({
                    "id_fencer": m.id_fencer,
                    "id_tournament_draft": tournament_id,
                    "int_place": m.place,
                    "txt_scraped_name": m.scraped_name,
                    "num_match_confidence": m.confidence,
                    "enum_match_method": method_map[m.method],
                })
        return rows

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

        # Phase 4 (ADR-046, ADR-053) post-commit hooks: PEW cascade + parity gate +
        # combined Telegram batch. Only fires when we have a valid PipelineContext
        # (not the case on degraded paths where Stage 7 never ran).
        if self._last_ctx is not None and self._last_ctx.event is not None:
            summary = self._summary_from_ctx(self._last_ctx)
            self._last_summary = summary
            try:
                lifecycle = run_post_commit_hooks(
                    db=self.db,
                    ctx=self._last_ctx,
                    summary=summary,
                    evf_results=self._evf_parity_payload,
                    notifier=self.notifier,
                )
                if lifecycle.cascade_renamed_to:
                    self._say(
                        f"↻ PEW cascade rename: {self._last_ctx.event.get('txt_code')} "
                        f"→ {lifecycle.cascade_renamed_to} ({lifecycle.cascade_rows} rows)"
                    )
                if lifecycle.parity_ran and lifecycle.parity_passed:
                    self._say(
                        f"✅ EVF parity passed — promoted to EVF_PUBLISHED "
                        f"({lifecycle.fencers_overwritten} fencers overwritten)"
                    )
                elif lifecycle.parity_ran and not lifecycle.parity_passed:
                    self._say(
                        f"🚨 EVF parity FAILED — stay ENGINE_COMPUTED. "
                        f"Notes: {lifecycle.parity_notes}"
                    )
                result.setdefault("post_commit", {})
                result["post_commit"] = {
                    "cascade_ran": lifecycle.cascade_ran,
                    "cascade_renamed_to": lifecycle.cascade_renamed_to,
                    "parity_ran": lifecycle.parity_ran,
                    "parity_passed": lifecycle.parity_passed,
                    "fencers_overwritten": lifecycle.fencers_overwritten,
                    "parity_notes": lifecycle.parity_notes,
                }
            except Exception as e:  # pragma: no cover — defensive
                self._say(f"⚠ Post-commit hooks raised: {e}")

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
        notifier=notifier,
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
