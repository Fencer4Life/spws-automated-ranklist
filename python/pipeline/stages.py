"""
Phase 3 (ADR-050) pipeline stages S1-S7.

Each stage is a free function `s_X(ctx: PipelineContext, db: DbConnector) -> None`
that mutates ctx. Halts are signalled via HaltError; the dispatcher
(orchestrator.run_pipeline) catches them and writes halt fields.

Stage roster:
  S1  IR validate                       → ctx.parsed sanity-checked
  S2  Resolve event by date             → ctx.event populated from DB
  S3  Detect combined-pool              → ctx.is_combined_pool set
  S4  Split via fn_age_categories_batch → ctx.splits populated
  S5  Detect joint-pool siblings        → ctx.joint_pool_siblings set
  S6  Resolve identity + V0/EVF check   → ctx.matches populated
  S7  Validate count + URL              → ctx.count_validation set

Tests: python/tests/test_pipeline_stages.py (per-stage isolated tests).
"""

from __future__ import annotations

import re
from collections import defaultdict
from typing import Any

from python.matcher.fuzzy_match import find_best_match
from python.pipeline.types import (
    HaltError,
    HaltReason,
    PipelineContext,
    StageMatchResult,
)


# Combined-pool detector: looks for ≥2 V-cat tokens in a single raw_age_marker
_VCAT_TOKEN = re.compile(r"v[0-4]", re.IGNORECASE)


# ===========================================================================
# Helpers
# ===========================================================================

def _organizer_for_event(event: dict | None) -> str:
    """Derive organizer (SPWS/EVF/FIE) from event txt_code prefix.

    PPW/MPW = SPWS domestic.
    PEW/MEW = EVF.
    MSW     = FIE veterans circuit.

    Returns "UNKNOWN" if event missing or code prefix unrecognized.
    """
    if event is None:
        return "UNKNOWN"
    code = (event.get("txt_code") or "").upper()
    if code.startswith(("PPW", "MPW")):
        return "SPWS"
    if code.startswith(("PEW", "MEW")):
        return "EVF"
    if code.startswith("MSW"):
        return "FIE"
    return "UNKNOWN"


def _is_domestic(event: dict | None) -> bool:
    """True if the event is SPWS-domestic (PPW/MPW). Used by S6 to decide
    AUTO_CREATED (domestic) vs EXCLUDED (international) for unmatched rows.
    """
    return _organizer_for_event(event) == "SPWS"


# ===========================================================================
# S1 — IR validate
# ===========================================================================

def s1_validate_ir(ctx: PipelineContext, db: Any) -> None:
    """Validate the ParsedTournament IR has all required fields.

    Halts: IR_INVALID if results empty or required fields missing.
    """
    p = ctx.parsed
    if not p.results:
        raise HaltError(HaltReason.IR_INVALID, "ParsedTournament has no results")
    if p.parsed_date is None:
        raise HaltError(HaltReason.IR_INVALID, "ParsedTournament.parsed_date is required")
    if p.weapon is None:
        raise HaltError(HaltReason.IR_INVALID, "ParsedTournament.weapon is required")
    if p.gender is None:
        raise HaltError(HaltReason.IR_INVALID, "ParsedTournament.gender is required")


# ===========================================================================
# S2 — Resolve event by date
# ===========================================================================

def s2_resolve_event(ctx: PipelineContext, db: Any) -> None:
    """Look up the event in the active season by parsed_date.

    Halts: EVENT_NOT_RESOLVED if no event found for the date.
    """
    date_str = ctx.parsed.parsed_date.isoformat()
    event = db.find_event_by_date(date_str)
    if event is None:
        raise HaltError(
            HaltReason.EVENT_NOT_RESOLVED,
            f"No event scheduled for date {date_str} in active season"
        )
    ctx.event = event


# ===========================================================================
# S3 — Detect combined-pool from raw_age_marker
# ===========================================================================

def s3_detect_combined_pool(ctx: PipelineContext, db: Any) -> None:
    """Set ctx.is_combined_pool=True if any row has ≥2 V-cat tokens in
    raw_age_marker (e.g., 'v0v1', 'v0v1v2v3').

    No halt — single-cat is the default.
    """
    for r in ctx.parsed.results:
        if r.raw_age_marker and len(_VCAT_TOKEN.findall(r.raw_age_marker)) >= 2:
            ctx.is_combined_pool = True
            return
    ctx.is_combined_pool = False


# ===========================================================================
# S4 — Split via fn_age_categories_batch
# ===========================================================================

def s4_split_via_batch(ctx: PipelineContext, db: Any) -> None:
    """For combined pools, resolve each fencer's V-cat in ONE batch RPC.

    Splitter overrides applied first:
      - vcat_overrides bypass the batch (operator declared the V-cat directly)
      - birth_year_overrides replace the row's birth_year before the batch call

    Halts: SPLITTER_UNRESOLVED if any fencer has no birth_year (and no
    vcat_override / birth_year_override to fill the gap).
    """
    if not ctx.is_combined_pool:
        return  # No-op for single-cat tournaments

    so = ctx.overrides.splitter
    splits: dict[str, list] = defaultdict(list)
    pending: list[tuple[Any, int]] = []   # (ParsedResult, effective_birth_year)
    unresolved: list[str] = []

    for r in ctx.parsed.results:
        # vcat override wins (no birth_year computation needed)
        if r.fencer_name in so.vcat_overrides:
            splits[so.vcat_overrides[r.fencer_name]].append(r)
            continue

        # birth_year override replaces row value
        by = so.birth_year_overrides.get(r.fencer_name)
        if by is None:
            by = r.birth_year
        if by is None:
            unresolved.append(r.fencer_name)
            continue

        pending.append((r, by))

    if unresolved:
        raise HaltError(
            HaltReason.SPLITTER_UNRESOLVED,
            f"Combined-pool fencers without birth_year (and no override): {unresolved}"
        )

    if pending:
        bys = [t[1] for t in pending]
        cat_map = db.call_age_categories_batch(bys, ctx.season_end_year)

        for r, by in pending:
            cat = cat_map.get(by)
            if cat is None:
                unresolved.append(f"{r.fencer_name} (birth_year={by} → under 30)")
            else:
                splits[cat].append(r)

        if unresolved:
            raise HaltError(
                HaltReason.SPLITTER_UNRESOLVED,
                f"Combined-pool fencers under 30: {unresolved}"
            )

    ctx.splits = dict(splits)


# ===========================================================================
# S5 — Detect joint-pool siblings (override-driven)
# ===========================================================================

def s5_detect_joint_pool(ctx: PipelineContext, db: Any) -> None:
    """Populate ctx.joint_pool_siblings from the joint_pool override section.

    Phase 3 scope: override-driven only. Auto-detection by url_results
    sibling-grouping is performed at commit time inside fn_commit_event_draft
    (Phase 2). This stage just surfaces the operator's force-flag intent so
    the diff renders the correct sibling grouping.
    """
    siblings: set[str] = set()
    for o in ctx.overrides.joint_pool:
        siblings.add(o.tournament_code)
        siblings.update(o.siblings)
    ctx.joint_pool_siblings = sorted(siblings)


# ===========================================================================
# S6 — Resolve identity + alias writeback + V0/EVF check
# ===========================================================================

def s6_resolve_identity(ctx: PipelineContext, db: Any) -> None:
    """Run identity resolution per row.

    Order of precedence:
      1. V0/EVF check (R005b) — halt before any matcher work if violated.
      2. Identity override → AUTO_MATCHED (link) or AUTO_CREATED (create_fencer).
      3. Match-method override → forces classification, runs matcher for id_fencer.
      4. Standard matcher path → AUTO_MATCHED / PENDING / AUTO_CREATED-or-EXCLUDED.

    Domestic vs international decision:
      - PPW/MPW → AUTO_CREATED on UNMATCHED (R006).
      - PEW/MEW/MSW → EXCLUDED on UNMATCHED.

    Halts: V0_PROHIBITED_ON_INTERNATIONAL on V0 + (EVF|FIE) per R005b.
    """
    organizer = _organizer_for_event(ctx.event)

    # Build (cat, ParsedResult) tuples — splits if combined, else category_hint.
    if ctx.is_combined_pool and ctx.splits is not None:
        rows = [(cat, r) for cat, results in ctx.splits.items() for r in results]
    else:
        cat = ctx.parsed.category_hint
        rows = [(cat, r) for r in ctx.parsed.results]

    # V0/EVF check FIRST — halt before fetching fencer DB.
    if organizer in ("EVF", "FIE"):
        for cat, r in rows:
            if cat == "V0":
                raise HaltError(
                    HaltReason.V0_PROHIBITED_ON_INTERNATIONAL,
                    f"V0 result in {organizer} event ({ctx.event.get('txt_code')!r}): "
                    f"{r.fencer_name} (R005b — fix upstream data, no override path)"
                )

    # Fetch fencer DB once (no per-row queries).
    fencer_db = db.fetch_fencer_db()
    domestic = _is_domestic(ctx.event)

    matches: list[StageMatchResult] = []
    for cat, r in rows:
        # Path 1: identity override
        ovr = ctx.overrides.identity_for(r.fencer_name)
        if ovr is not None:
            if ovr.id_fencer is not None:
                matches.append(StageMatchResult(
                    scraped_name=r.fencer_name, place=r.place,
                    id_fencer=ovr.id_fencer, confidence=100.0,
                    method="AUTO_MATCHED",
                    notes="identity override (link)",
                ))
            else:
                # create_fencer: id_fencer left None — caller (commit RPC or
                # admin) must materialize the new fencer before insert.
                matches.append(StageMatchResult(
                    scraped_name=r.fencer_name, place=r.place,
                    id_fencer=None, confidence=100.0,
                    method="AUTO_CREATED",
                    notes=f"identity override (create_fencer): {ovr.create_fencer}",
                ))
            continue

        # Path 2: match-method override (still runs matcher to capture id_fencer)
        mm = ctx.overrides.match_method_for(r.fencer_name)
        if mm is not None:
            best = find_best_match(
                r.fencer_name, fencer_db,
                age_category=cat, season_end_year=ctx.season_end_year,
            )
            matches.append(StageMatchResult(
                scraped_name=r.fencer_name, place=r.place,
                id_fencer=best.id_fencer, confidence=best.confidence,
                method=mm.force_method,
                notes=f"match_method override: {mm.note or 'forced'}",
            ))
            continue

        # Path 3: standard matcher
        best = find_best_match(
            r.fencer_name, fencer_db,
            age_category=cat, season_end_year=ctx.season_end_year,
        )
        method = best.status  # AUTO_MATCHED | PENDING | UNMATCHED
        if method == "UNMATCHED":
            method = "AUTO_CREATED" if domestic else "EXCLUDED"

        matches.append(StageMatchResult(
            scraped_name=r.fencer_name, place=r.place,
            id_fencer=best.id_fencer, confidence=best.confidence,
            method=method,
        ))

    ctx.matches = matches


# ===========================================================================
# S7 — Validate count + URL→data
# ===========================================================================

def s7_validate(ctx: PipelineContext, db: Any) -> None:
    """Validate result count against parsed.raw_pool_size, and surface URL.

    Halts: COUNT_MISMATCH if expected/actual differ by more than 1
    (off-by-one is warned, not halted — common case is excluded fencers).

    URL→data deep validation (re-fetch + cross-check) deferred to a
    dedicated module/Phase 4. Phase 3 just records the URL we'd validate.
    """
    expected = ctx.parsed.raw_pool_size
    actual = len(ctx.matches)

    if expected is not None:
        diff = actual - expected
        if abs(diff) > 1:
            raise HaltError(
                HaltReason.COUNT_MISMATCH,
                f"Result count {actual} differs from raw_pool_size {expected} "
                f"by {diff:+d} — outside off-by-one tolerance"
            )
        if diff != 0:
            ctx.warnings.append(
                f"Count diff (within tolerance): actual={actual} vs expected={expected}"
            )

    ctx.count_validation = {"expected": expected, "actual": actual, "ok": True}

    # URL surface (deep validation deferred)
    url = (
        ctx.overrides.url.validation_url
        if ctx.overrides.url
        else ctx.parsed.source_url
    )
    if not url:
        ctx.warnings.append("S7: no URL for validation (neither parsed.source_url nor override)")
