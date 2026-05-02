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
    """Resolve the event for this parse.

    Phase 5: prefer ctx.event_code (set by the operator-driven runner) and
    look up directly by code — avoids the active-season assumption that
    breaks historical re-ingest.

    Legacy path: if event_code is unset (older callers, file-import flows),
    fall back to find_event_by_date which still uses the active season.

    Halts: EVENT_NOT_RESOLVED if neither lookup finds the event.
    """
    event = None
    if ctx.event_code:
        event = db.find_event_by_code(ctx.event_code)
        if event is None:
            raise HaltError(
                HaltReason.EVENT_NOT_RESOLVED,
                f"No event found for txt_code={ctx.event_code!r}"
            )

        # Phase 5: resolve the season by event dates, not by the FK on the
        # event row (some historical events have wrong id_season). Find the
        # season whose date range contains BOTH event.dt_start and dt_end.
        # Exactly one match required; zero or many is a showstopper.
        if hasattr(db, "find_seasons_containing_dates"):
            ev_start = event.get("dt_start")
            ev_end = event.get("dt_end") or ev_start
            ev_start_s = str(ev_start)[:10] if ev_start else None
            ev_end_s = str(ev_end)[:10] if ev_end else None
            if ev_start_s and ev_end_s:
                seasons = db.find_seasons_containing_dates(ev_start_s, ev_end_s)
                if len(seasons) == 0:
                    raise HaltError(
                        HaltReason.EVENT_NOT_RESOLVED,
                        f"No season contains event dates "
                        f"{ev_start_s} – {ev_end_s} (event {ctx.event_code!r})"
                    )
                if len(seasons) > 1:
                    codes = ", ".join(s.get("txt_code", "?") for s in seasons)
                    raise HaltError(
                        HaltReason.EVENT_NOT_RESOLVED,
                        f"Multiple seasons contain event dates "
                        f"{ev_start_s} – {ev_end_s}: {codes} (showstopper — "
                        f"season ranges overlap)"
                    )
                season = seasons[0]
                from datetime import date as _date
                dt_end = season["dt_end"]
                if isinstance(dt_end, str):
                    try:
                        dt_end = _date.fromisoformat(dt_end[:10])
                    except ValueError:
                        dt_end = None
                if dt_end:
                    ctx.season_end_year = dt_end.year
                # Stamp resolved season on the event dict for downstream stages
                event["id_season"] = season["id_season"]
                event["txt_season_code"] = season.get("txt_code")
    else:
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
    """Validate result count + URL→data per-field comparison (Phase 4 ADR-052).

    Two sub-stages combined:

      a) Count: compare len(ctx.matches) to parsed.raw_pool_size.
         Halts COUNT_MISMATCH on diff > 1; off-by-one warns.

      b) URL→data: opportunistic per-field comparison between scraped
         metadata (ctx.parsed) and the canonical event row (ctx.event).
         Six halt-fields (date / weapon / gender / age category / country
         / city); name warns. PEW weapon-mismatch sets ctx.pew_cascade_pending
         instead of halting. Combined-pool sources skip age-category.
         Cert_ref source skips URL→data entirely (no URL to validate).
         Skipped when ctx.event is None (e.g. legacy / unit-test paths).
    """
    from python.pipeline.ir import SourceKind
    from python.pipeline.url_validation import (
        ScrapedMetadata,
        validate_metadata,
    )

    # ---- (a) Count validation ----
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

    # ---- (b) URL→data validation (ADR-052) ----
    if ctx.event is None:
        ctx.warnings.append("S7: no event resolved; URL→data validation skipped")
        return
    if ctx.parsed.source_kind == SourceKind.CERT_REF:
        # Cert_ref pulls from the snapshot table — no URL to cross-check.
        ctx.warnings.append("S7: cert_ref source — URL→data validation skipped")
        return

    scraped = ScrapedMetadata(
        parsed_date=ctx.parsed.parsed_date,
        weapon=ctx.parsed.weapon,
        gender=ctx.parsed.gender,
        age_category=ctx.parsed.category_hint,
        is_combined_pool=ctx.is_combined_pool,
        city=ctx.parsed.city,
        country=ctx.parsed.country,
        tournament_name=ctx.parsed.tournament_name,
    )
    val = validate_metadata(ctx.event, scraped)
    ctx.url_validation = val
    ctx.pew_cascade_pending = val.pew_cascade_pending

    for w in val.warns:
        ctx.warnings.append(f"S7 warn: {w.message}")

    if val.has_halt:
        summary = "; ".join(f"{f.field}: {f.message}" for f in val.halts)
        raise HaltError(HaltReason.URL_DATA_MISMATCH, summary)


# ===========================================================================
# ADR-056 — V-cat split by post-match fencer birth year (Phase 5)
# ===========================================================================

def vcat_for_age(age: int | None) -> str | None:
    """Map an age (years on the event year) to a V-cat enum value.

    < 40 → V0, 40-49 → V1, 50-59 → V2, 60-69 → V3, ≥ 70 → V4.
    Returns None for None / negative age.
    """
    if age is None or age < 0:
        return None
    if age < 40:
        return "V0"
    if age < 50:
        return "V1"
    if age < 60:
        return "V2"
    if age < 70:
        return "V3"
    return "V4"


def s7_split_by_vcat(ctx: PipelineContext, db: Any) -> None:
    """Group matched fencers by V-cat derived from their birth year.

    ADR-056: post-match canonical V-cat assignment. Replaces the marker-based
    Stage 4 split as the primary V-cat source. Marker-based path is retained
    upstream as a fast-path for sources that emit reliable per-fencer markers
    (cert_ref, EVF API).

    Inputs:  ctx.matches with id_fencer set on AUTO_MATCHED / AUTO_CREATED rows.
    Outputs: ctx.vcat_groups: {V-cat: [StageMatchResult]}
             ctx.is_joint_pool: True iff vcat_groups has ≥2 V-cats
             ctx.unassigned_matches: PENDING / UNMATCHED / null-BY rows for review

    Does not raise. Operator decides whether unassigned rows block commit.
    """
    # Fencing-convention: V-cat is based on age at the END of the season
    # (the season_end_year), not the calendar year of the event. Trigger
    # `fn_assert_result_vcat` enforces this; mismatching here causes commit
    # failures on the V-cat invariant.
    reference_year = ctx.season_end_year

    # Collect ids of matches that have an id_fencer (AUTO_MATCHED / AUTO_CREATED)
    matched_ids = [
        m.id_fencer for m in ctx.matches
        if getattr(m, "id_fencer", None) is not None
    ]
    by_map: dict[int, int | None] = (
        db.fetch_birth_years_batch(matched_ids)
        if matched_ids and hasattr(db, "fetch_birth_years_batch")
        else {}
    )

    groups: dict[str, list] = {}
    unassigned: list = []
    for m in ctx.matches:
        if getattr(m, "id_fencer", None) is None:
            unassigned.append(m)
            continue
        by = by_map.get(m.id_fencer)
        vcat = vcat_for_age(reference_year - by) if by is not None else None
        if vcat is None:
            unassigned.append(m)
            continue
        groups.setdefault(vcat, []).append(m)

    ctx.vcat_groups = groups
    ctx.unassigned_matches = unassigned
    ctx.is_joint_pool = len(groups) >= 2


# ===========================================================================
# Phase 5 — Pool-round structural detection (gender-distribution signal)
# ===========================================================================

# Minimum bracket size where the percentage rule is meaningful. Below this,
# tiny brackets pass regardless of gender mix (insufficient signal).
_POOL_CHECK_MIN_FENCERS = 4

# Pool round = "MASSIVE gender mix" per user 2026-05-02. ADR-034 allows
# a small number of cross-gender fencers in a real tournament (a woman
# competing in a men's bracket when there's no women's bracket); those
# get re-assigned at scoring time, the bracket is still a real tournament.
# Threshold combines absolute count + ratio so we don't flag ADR-034
# singletons-in-tiny-brackets nor a couple of cross-gender entries in a
# medium bracket.
_POOL_CHECK_MIN_MINORITY_COUNT = 3      # ≥3 cross-gender fencers (more than ADR-034 noise)
_POOL_CHECK_MIN_MINORITY_RATIO = 0.20   # ≥20% minority share (genuine mix)


def s7_pool_round_check(ctx: PipelineContext, db: Any) -> None:
    """Halt the bracket if its matched-fencer gender distribution looks
    like a pool round (M+F mixed) rather than a real per-gender tournament.

    Phase 5 (post-ADR-056 follow-up): the FTL splitter classifies brackets
    by display name, but pool rounds aren't always named recognizably.
    Real per-gender tournaments have near-pure gender distribution (single-
    fencer outliers tolerated). Pool rounds are deeply mixed.

    Halts: POOL_ROUND_DETECTED if minority-gender share ≥
    _POOL_CHECK_MIN_MINORITY_RATIO in a bracket of ≥
    _POOL_CHECK_MIN_FENCERS matched fencers.

    Also halts if the bracket's parsed gender disagrees with the
    matched-fencer majority gender (data error / misnamed bracket).

    No-op when:
      - Fewer than _POOL_CHECK_MIN_FENCERS matched fencers (insufficient signal).
      - No matched fencers carry id_fencer (all PENDING/UNMATCHED).
      - DB doesn't expose fetch_genders_batch (defensive — keeps tests green).
    """
    matched_ids = [
        m.id_fencer for m in ctx.matches
        if getattr(m, "id_fencer", None) is not None
    ]
    if len(matched_ids) < _POOL_CHECK_MIN_FENCERS:
        return  # insufficient signal
    if not hasattr(db, "fetch_genders_batch"):
        return

    gender_map = db.fetch_genders_batch(matched_ids) or {}
    genders = [gender_map.get(i) for i in matched_ids]
    genders = [g for g in genders if g in ("M", "F")]
    if len(genders) < _POOL_CHECK_MIN_FENCERS:
        return

    n = len(genders)
    n_m = sum(1 for g in genders if g == "M")
    n_f = n - n_m
    minority = min(n_m, n_f)
    minority_ratio = minority / n

    # Mixed-gender pool round: ≥3 cross-gender fencers AND ≥20% minority share
    # (both must apply — ADR-034 allows up to ~2 cross-gender fencers in a
    # legit per-gender tournament; and 1-2 outliers in a tiny bracket can hit
    # 15-30% ratio without indicating a real pool round).
    if minority >= _POOL_CHECK_MIN_MINORITY_COUNT and minority_ratio >= _POOL_CHECK_MIN_MINORITY_RATIO:
        ctx.is_pool_round = True
        raise HaltError(
            HaltReason.POOL_ROUND_DETECTED,
            f"bracket has {n_m}M/{n_f}F (minority {minority_ratio:.0%}, "
            f"count {minority}) — looks like a pool round, not a per-gender "
            f"tournament; above ADR-034 cross-gender tolerance"
        )

    # Wrong-name bracket: parsed gender disagrees with majority
    parsed_gender = getattr(ctx.parsed, "gender", None)
    majority_gender = "M" if n_m >= n_f else "F"
    if parsed_gender and parsed_gender != majority_gender:
        ctx.is_pool_round = True
        raise HaltError(
            HaltReason.POOL_ROUND_DETECTED,
            f"bracket parsed as gender={parsed_gender!r} but matched-fencer "
            f"majority is {majority_gender!r} ({n_m}M/{n_f}F) — name/data mismatch"
        )
