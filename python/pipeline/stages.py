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

from python.matcher.fuzzy_match import find_best_match, normalize_name, parse_scraped_name
from python.matcher.pipeline import estimate_birth_year
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
# S0 — Roster reconciliation (ADR-050 / ADR-056 / ADR-010 / ADR-038)
# ===========================================================================

# 2-letter → IOC 3-letter nationality folding. Only the bulk POL case actually
# matters for the high-precision dedup (a stored "PL" must not look different
# from a scraped "POL", or we would create a duplicate of an existing Pole).
# Foreign newcomers don't exact-name-collide, so an exhaustive table is moot.
_NAT_FOLD = {"PL": "POL"}

# FTL (N) age marker / category_hint digit → V-cat token.
_VCAT_DIGIT = re.compile(r"([0-4])")


def _norm_nat(nat: str | None) -> str | None:
    """Fold a nationality code to a comparable form (uppercase, PL→POL)."""
    if not nat:
        return None
    n = nat.strip().upper()
    return _NAT_FOLD.get(n, n)


def _row_authoritative_vcat(ctx: PipelineContext, r: Any) -> str | None:
    """The V-cat that authoritatively governs this result row.

    Precedence (per ADR-056 / Stage-0 plan):
      1. bracket `category_hint` — single-cat brackets carry the V-cat label.
      2. per-fencer FTL `(N)` `raw_age_marker` — combined pools mark each row.
      3. None — unmarked fencer in a combined pool (V-cat unknown).
    """
    ch = getattr(ctx.parsed, "category_hint", None)
    if isinstance(ch, str):
        m = _VCAT_DIGIT.search(ch)
        if m:
            return f"V{m.group(1)}"
    rm = getattr(r, "raw_age_marker", None)
    if rm is not None:
        m = _VCAT_DIGIT.search(str(rm))
        if m:
            return f"V{m.group(1)}"
    return None


def _find_exact_fencer(
    scraped_name: str,
    nationality: str | None,
    fencer_db: list[dict],
) -> int | None:
    """HIGH-PRECISION existence check — exact, NOT fuzzy.

    A fencer is the same person iff the normalized (surname, first_name) match
    exactly, OR the scraped full name equals one of their stored aliases. When
    both nationalities are known and differ (folded), they are treated as
    DIFFERENT people (a foreign newcomer who collides on an exact Polish name
    must still be created separately). Diacritics are folded so BARAŃSKI ==
    BARANSKI; this is the same normalization the fuzzy matcher uses, but here
    we require an EXACT post-fold equality, never a distance score.

    Returns the matching id_fencer, or None.
    """
    s_sur, s_fst = parse_scraped_name(scraped_name)
    s_sur_n = normalize_name(s_sur, use_diacritic_folding=True)
    s_fst_n = normalize_name(s_fst, use_diacritic_folding=True)
    s_full_n = normalize_name(scraped_name, use_diacritic_folding=True)
    scraped_nat = _norm_nat(nationality)

    for f in fencer_db:
        f_nat = _norm_nat(f.get("txt_nationality"))
        nat_conflict = scraped_nat is not None and f_nat is not None and scraped_nat != f_nat
        # Exact (surname, first_name) match.
        f_sur_n = normalize_name(f.get("txt_surname") or "", use_diacritic_folding=True)
        f_fst_n = normalize_name(f.get("txt_first_name") or "", use_diacritic_folding=True)
        if f_sur_n == s_sur_n and f_fst_n == s_fst_n and not nat_conflict:
            return f["id_fencer"]
        # Exact alias match (aliases are confirmed equivalences → nationality
        # is not re-litigated here).
        for alias in f.get("json_name_aliases") or []:
            if normalize_name(alias, use_diacritic_folding=True) == s_full_n:
                return f["id_fencer"]
    return None


def s0_reconcile_roster(ctx: PipelineContext, db: Any) -> None:
    """Stage 0 — reconcile the master roster against this bracket's rows.

    Runs FIRST, before the fuzzy matcher (s6), so that genuinely-new
    participants exist in master data (the matcher then exact-matches them
    instead of fuzzy-gluing them to the nearest existing name), and so that
    every fencer's stored birth year stays consistent with the V-cat of the
    brackets they actually competed in (ADR-010: ranking category is
    BY-derived, so a wrong/estimated BY files a result under the wrong
    ranking).

    Two mirror jobs per row, keyed on the row's authoritative V-cat:
      1. NEW fencer (high-precision exact dedup) → create with
         int_birth_year = band midpoint (NULL if V-cat unknown),
         bool_birth_year_estimated = TRUE.
      2. MATCHED fencer whose stored BY conflicts with the bracket V-cat →
         correct to the band midpoint. Estimated keeps the flag; CONFIRMED is
         overwritten AND downgraded to estimated (surfaced loudly).

    International events (PEW/MEW/MSW, ADR-038) are skipped entirely. Never
    halts; on any condition it can't act on, it leaves the row for downstream
    stages / admin. Idempotent: the exact check prevents re-creation and a
    BY already at its band midpoint produces no further conflict.
    """
    # ADR-038: skip international/EXCLUDED events. Derive organizer from the
    # admin-canonical event code (available at construction; ctx.event isn't
    # resolved until S2, keeping S0 source-agnostic).
    if _organizer_for_event({"txt_code": ctx.event_code}) in ("EVF", "FIE"):
        return

    season_end = ctx.season_end_year
    bracket_gender = getattr(ctx.parsed, "gender", None)
    source = getattr(ctx.parsed.source_kind, "value", str(ctx.parsed.source_kind))

    fencer_db = db.fetch_fencer_db()
    # Track per-run touches so a fencer appearing in two conflicting brackets
    # within one run is flagged once, not thrashed back and forth.
    touched: dict[int, str] = {}

    for r in ctx.parsed.results:
        if getattr(r, "bool_excluded", False):
            continue

        vcat = _row_authoritative_vcat(ctx, r)
        nat = getattr(r, "fencer_country", None)
        existing_id = _find_exact_fencer(r.fencer_name, nat, fencer_db)

        if existing_id is None:
            # ---- Job 1: create the new participant ----
            surname, first_name = parse_scraped_name(r.fencer_name)
            by = estimate_birth_year(vcat, season_end) if vcat else None
            payload = {
                "txt_surname": surname,
                "txt_first_name": first_name,
                "int_birth_year": by,
                "bool_birth_year_estimated": by is not None,
                "txt_nationality": nat or "PL",
            }
            if bracket_gender:
                payload["enum_gender"] = bracket_gender
            new_id = db.insert_fencer(payload)
            # Make subsequent rows in this same bracket see the new fencer
            # (within-run idempotence + dedup).
            fencer_db.append(
                {
                    "id_fencer": new_id,
                    "txt_surname": surname,
                    "txt_first_name": first_name,
                    "int_birth_year": by,
                    "bool_birth_year_estimated": by is not None,
                    "txt_nationality": nat or "PL",
                    "enum_gender": bracket_gender,
                    "json_name_aliases": [],
                }
            )
            ctx.created_fencers.append(
                {
                    "id_fencer": new_id,
                    "scraped_name": r.fencer_name,
                    "txt_surname": surname,
                    "txt_first_name": first_name,
                    "nationality": nat or "PL",
                    "vcat": vcat,
                    "birth_year": by,
                    "estimated": by is not None,
                    "source": source,
                }
            )
            continue

        # ---- Job 2: reconcile a matched fencer's birth year ----
        if vcat is None:
            continue  # no authoritative V-cat → nothing to reconcile against

        row = next((f for f in fencer_db if f["id_fencer"] == existing_id), None)
        stored_by = row.get("int_birth_year") if row else None
        if stored_by is None:
            continue  # missing BY is an admin task, not a conflict to correct

        current_vcat = vcat_for_age(season_end - stored_by)
        if current_vcat == vcat:
            continue  # already consistent

        # Conflict. Guard against cross-bracket thrash within one run.
        if existing_id in touched and touched[existing_id] != vcat:
            ctx.reconcile_conflicts.append(
                {
                    "id_fencer": existing_id,
                    "scraped_name": r.fencer_name,
                    "first_vcat": touched[existing_id],
                    "second_vcat": vcat,
                    "source": source,
                }
            )
            continue

        new_by = estimate_birth_year(vcat, season_end)
        was_confirmed = not bool(row.get("bool_birth_year_estimated"))
        db.update_fencer_birth_year(existing_id, new_by, estimated=True)
        if row is not None:
            row["int_birth_year"] = new_by
            row["bool_birth_year_estimated"] = True
        touched[existing_id] = vcat
        ctx.reconciled_fencers.append(
            {
                "id_fencer": existing_id,
                "scraped_name": r.fencer_name,
                "vcat": vcat,
                "old_birth_year": stored_by,
                "new_birth_year": new_by,
                "was_confirmed": was_confirmed,
                "source": source,
            }
        )


# ===========================================================================
# S1 — IR validate
# ===========================================================================


def s1_validate_ir(ctx: PipelineContext, db: Any) -> None:
    """Validate the ParsedTournament IR has all required fields.

    Halts:
      - POOL_ROUND_DETECTED if the parser flagged the source as a
        pool-only qualifier (no DE — ELIMINACJE round). This check runs
        FIRST so we halt before complaining about missing date/weapon/
        gender on a file we're going to drop anyway.
      - IR_INVALID if results empty or required fields missing.
    """
    p = ctx.parsed
    # User instruction 2026-05-27: structural pool-only skip applies to
    # every source. The parser is responsible for setting the flag based
    # on data structure, never on names.
    if getattr(p, "is_pool_only_qualifier", False):
        ctx.is_pool_round = True
        raise HaltError(
            HaltReason.POOL_ROUND_DETECTED,
            "source has pool data but no DE/tableau — qualifier round, "
            "does not contribute to ranklist (skipping per ADR-067 / "
            "structural pool-only rule)",
        )
    if not p.results:
        raise HaltError(HaltReason.IR_INVALID, "ParsedTournament has no results")
    if p.parsed_date is None:
        raise HaltError(HaltReason.IR_INVALID, "ParsedTournament.parsed_date is required")
    if p.weapon is None:
        raise HaltError(HaltReason.IR_INVALID, "ParsedTournament.weapon is required")
    # gender=None is INTENTIONALLY allowed (user instruction 2026-05-27, ADR-34).
    # Some organizers publish brackets with no gender marker in AltName and
    # `Sexe="X"` (e.g. PPW5 'Szabla kat. 4'). Cross-gender / mixed tournaments
    # are legitimate; ADR-34 reassigns women's points to the women's ranklist
    # at query time via fn_effective_gender. The draft writer defaults the
    # stored gender to 'M' so the NOT NULL enum_gender column accepts the row;
    # the ranking-query layer does the right thing afterwards.


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
                HaltReason.EVENT_NOT_RESOLVED, f"No event found for txt_code={ctx.event_code!r}"
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
                        f"{ev_start_s} – {ev_end_s} (event {ctx.event_code!r})",
                    )
                if len(seasons) > 1:
                    codes = ", ".join(s.get("txt_code", "?") for s in seasons)
                    raise HaltError(
                        HaltReason.EVENT_NOT_RESOLVED,
                        f"Multiple seasons contain event dates "
                        f"{ev_start_s} – {ev_end_s}: {codes} (showstopper — "
                        f"season ranges overlap)",
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
                f"No event scheduled for date {date_str} in active season",
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
    pending: list[tuple[Any, int]] = []  # (ParsedResult, effective_birth_year)
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
            f"Combined-pool fencers without birth_year (and no override): {unresolved}",
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
                HaltReason.SPLITTER_UNRESOLVED, f"Combined-pool fencers under 30: {unresolved}"
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
                    f"{r.fencer_name} (R005b — fix upstream data, no override path)",
                )

    # Fetch fencer DB once (no per-row queries).
    fencer_db = db.fetch_fencer_db()
    domestic = _is_domestic(ctx.event)

    # ADR-064: asymmetric F-bracket filter — domestic events only. When
    # parsed.gender is 'F' on a SPWS-organized bracket, M-gender candidates
    # are dropped from the matcher's candidate set (federation rule: men
    # cannot legitimately appear in women's tournaments). bracket_gender
    # stays None for non-domestic events and for compound brackets where
    # parsed.gender hasn't been set yet (ADR-056 V-cat split happens at s7).
    parsed_gender = getattr(ctx.parsed, "gender", None)
    matcher_bracket_gender = parsed_gender if domestic else None

    matches: list[StageMatchResult] = []
    for cat, r in rows:
        # Path 1: identity override
        ovr = ctx.overrides.identity_for(r.fencer_name)
        if ovr is not None:
            if ovr.id_fencer is not None:
                matches.append(
                    StageMatchResult(
                        scraped_name=r.fencer_name,
                        place=r.place,
                        id_fencer=ovr.id_fencer,
                        confidence=100.0,
                        method="AUTO_MATCHED",
                        notes="identity override (link)",
                    )
                )
            else:
                # create_fencer: id_fencer left None — caller (commit RPC or
                # admin) must materialize the new fencer before insert.
                matches.append(
                    StageMatchResult(
                        scraped_name=r.fencer_name,
                        place=r.place,
                        id_fencer=None,
                        confidence=100.0,
                        method="AUTO_CREATED",
                        notes=f"identity override (create_fencer): {ovr.create_fencer}",
                    )
                )
            continue

        # Path 2: match-method override (still runs matcher to capture id_fencer)
        mm = ctx.overrides.match_method_for(r.fencer_name)
        if mm is not None:
            best = find_best_match(
                r.fencer_name,
                fencer_db,
                age_category=cat,
                season_end_year=ctx.season_end_year,
                bracket_gender=matcher_bracket_gender,
            )
            matches.append(
                StageMatchResult(
                    scraped_name=r.fencer_name,
                    place=r.place,
                    id_fencer=best.id_fencer,
                    confidence=best.confidence,
                    method=mm.force_method,
                    notes=f"match_method override: {mm.note or 'forced'}",
                )
            )
            continue

        # Path 3: standard matcher
        best = find_best_match(
            r.fencer_name,
            fencer_db,
            age_category=cat,
            season_end_year=ctx.season_end_year,
            bracket_gender=matcher_bracket_gender,
        )
        method = best.status  # AUTO_MATCHED | PENDING | UNMATCHED
        if method == "UNMATCHED":
            method = "AUTO_CREATED" if domestic else "EXCLUDED"

        matches.append(
            StageMatchResult(
                scraped_name=r.fencer_name,
                place=r.place,
                id_fencer=best.id_fencer,
                confidence=best.confidence,
                method=method,
            )
        )

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
                f"by {diff:+d} — outside off-by-one tolerance",
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
    """Group matched fencers by V-cat.

    ADR-056 (revised 2026-05-03): bracket-label V-cat overrides BY derivation
    for past tournaments. When `ctx.parsed.category_hint` is a single V-cat
    string (e.g. parsed from FTL `Vet Men's Saber` → V1), every matched
    fencer is grouped under that V-cat regardless of canonical BY+season_end
    math. The organizer's bracket placement is the source of truth for past
    tournament data; applying canonical BY-V-cat across a season boundary
    (a fencer turning 50 on event date but season end is next year) would
    retroactively move their result into a ranklist they never competed in.

    Joint-pool brackets (parsed name returns a list → `category_hint=None`)
    keep the BY-derivation path: each fencer's V-cat comes from
    `BY + ctx.season_end_year`. ADR-049's `bool_joint_pool_split` flags these.

    Inputs:  ctx.matches with id_fencer set on AUTO_MATCHED / AUTO_CREATED rows.
             ctx.parsed.category_hint — single V-cat str (bracket label) or None.
    Outputs: ctx.vcat_groups: {V-cat: [StageMatchResult]}
             ctx.is_joint_pool: True iff vcat_groups has ≥2 V-cats
             ctx.unassigned_matches: PENDING / UNMATCHED / null-BY rows for review

    Does not raise. Operator decides whether unassigned rows block commit.
    """
    bracket_vcat = getattr(ctx.parsed, "category_hint", None)

    groups: dict[str, list] = {}
    unassigned: list = []

    if isinstance(bracket_vcat, str) and bracket_vcat:
        # Single-V-cat bracket: every matched fencer goes to the bracket V-cat.
        # BY-unknown matched fencers are still placed in the bracket (organizer
        # already accepted them) — admin reviews BY mismatches via staging .md.
        for m in ctx.matches:
            if getattr(m, "id_fencer", None) is None:
                unassigned.append(m)
                continue
            groups.setdefault(bracket_vcat, []).append(m)
    else:
        # Joint-pool: BY-derivation per fencer (existing ADR-056 behaviour).
        # Reference year is season_end_year — V-cat = age at end of season.
        reference_year = ctx.season_end_year
        matched_ids = [
            m.id_fencer for m in ctx.matches if getattr(m, "id_fencer", None) is not None
        ]
        by_map: dict[int, int | None] = (
            db.fetch_birth_years_batch(matched_ids)
            if matched_ids and hasattr(db, "fetch_birth_years_batch")
            else {}
        )
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
_POOL_CHECK_MIN_MINORITY_COUNT = 3  # ≥3 cross-gender fencers (more than ADR-034 noise)
_POOL_CHECK_MIN_MINORITY_RATIO = 0.20  # ≥20% minority share (genuine mix)


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
    matched_ids = [m.id_fencer for m in ctx.matches if getattr(m, "id_fencer", None) is not None]
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
    if (
        minority >= _POOL_CHECK_MIN_MINORITY_COUNT
        and minority_ratio >= _POOL_CHECK_MIN_MINORITY_RATIO
    ):
        ctx.is_pool_round = True
        raise HaltError(
            HaltReason.POOL_ROUND_DETECTED,
            f"bracket has {n_m}M/{n_f}F (minority {minority_ratio:.0%}, "
            f"count {minority}) — looks like a pool round, not a per-gender "
            f"tournament; above ADR-034 cross-gender tolerance",
        )

    # Wrong-name bracket: parsed gender disagrees with majority
    parsed_gender = getattr(ctx.parsed, "gender", None)
    majority_gender = "M" if n_m >= n_f else "F"
    if parsed_gender and parsed_gender != majority_gender:
        ctx.is_pool_round = True
        raise HaltError(
            HaltReason.POOL_ROUND_DETECTED,
            f"bracket parsed as gender={parsed_gender!r} but matched-fencer "
            f"majority is {majority_gender!r} ({n_m}M/{n_f}F) — name/data mismatch",
        )
