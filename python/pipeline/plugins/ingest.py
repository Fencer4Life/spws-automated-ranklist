"""INGEST_DOMESTIC forward plugins — thin wrappers over `stages.py` (ADR-073/074).

Each class is one concern. They delegate to the existing stage functions on the
shared `_legacy` PipelineContext (see `bridge.py`) and translate former halts to
non-blocking `ctx.fault`s (see `remediation.py`). The M2 plugin order matches the
final design §6.4; to keep byte-parity with today's `run_pipeline`, `ResolveFencers`
runs the s0→s3→s4→s6 cluster on the shared pctx, and `DetectCombinedPool`/
`SplitByAge` then mirror the already-computed pctx fields. M3 inlines this and
switches the split to read governed BY.
"""
from __future__ import annotations

from python.pipeline.core.contract import Context, PluginKind, Services
from python.pipeline.plugins.base import BasePlugin
from python.pipeline.plugins.bridge import ensure_pctx, get_pctx, run_stage
from python.pipeline.stages import vcat_for_age


# ---------------------------------------------------------------------------
# Source
# ---------------------------------------------------------------------------

class ParseSource(BasePlugin):
    """Produce the initial Context: parse the source IR + build the bridge pctx.

    M2 takes the parsed IR + admin context from `svc.config` (a dict). Live
    PARSERS dispatch + `source_artifact_path` retention is M4 (BR-13).
    """
    name = "ParseSource"
    kind = PluginKind.SOURCE
    writes = frozenset({"parsed"})

    def run(self, ctx: Context, svc: Services) -> None:
        cfg = svc.config or {}
        parsed = cfg.get("parsed")
        if parsed is None:
            from python.pipeline.core.contract import Abort
            raise Abort(plugin=self.name, detail="no parsed IR provided (svc.config['parsed'])")
        # BR-13 (ADR-072): retain the source artifact path so a dead-URL event
        # can be re-ingested from retained bytes (source="retained").
        artifact = cfg.get("source_artifact_path")
        if artifact is not None and getattr(parsed, "source_artifact_path", None) is None:
            parsed.source_artifact_path = artifact
        ensure_pctx(
            ctx,
            parsed=parsed,
            overrides=cfg.get("overrides"),
            season_end_year=cfg.get("season_end_year"),
            event_code=cfg.get("event_code"),
        )
        ctx.set("parsed", parsed)
        # ADR-075: serialize this source's contribution to the staging report.
        self.report(
            ctx, "SOURCE",
            weapon=getattr(parsed, "weapon", None),
            gender=getattr(parsed, "gender", None),
            category_hint=getattr(parsed, "category_hint", None),
            date=_iso_date(getattr(parsed, "parsed_date", None)),
            n_rows=len(getattr(parsed, "results", []) or []),
            source_url=getattr(parsed, "source_url", None),
            tournament_name=getattr(parsed, "tournament_name", None),
            season_end_year=cfg.get("season_end_year"),
        )


# ---------------------------------------------------------------------------
# Gates / transforms
# ---------------------------------------------------------------------------

class ValidateIR(BasePlugin):
    name = "ValidateIR"
    kind = PluginKind.GATE
    reads = frozenset({"parsed"})

    def run(self, ctx: Context, svc: Services) -> None:
        from python.pipeline.core.contract import FaultKind
        run_stage(ctx, "s1_validate_ir", svc.db)
        self.report(ctx, "VALIDATION", check="ir",
                    ok=not ctx.faults_of(FaultKind.IR_INVALID))


class ResolveEvent(BasePlugin):
    name = "ResolveEvent"
    kind = PluginKind.TRANSFORM
    reads = frozenset({"parsed"})
    writes = frozenset({"event"})

    def run(self, ctx: Context, svc: Services) -> None:
        run_stage(ctx, "s2_resolve_event", svc.db)  # EVENT_NOT_RESOLVED -> Abort
        pctx = get_pctx(ctx)
        if pctx is not None and pctx.event is not None:
            ctx.set("event", pctx.event)
            ev = pctx.event
            self.report(ctx, "EVENT",
                        id_event=ev.get("id_event"), txt_code=ev.get("txt_code"),
                        txt_name=ev.get("txt_name"),
                        dt_start=str(ev["dt_start"]) if ev.get("dt_start") else None)


# ResolveFencers (the merged, early identity plugin) lives in resolve_fencers.py.


def _governed_vcats(matches, season_end) -> dict:
    """Group matched rows by the V-cat derived from their GOVERNED birth year
    (ADR-070/056). The governed BY is emitted by ResolveFencers per row."""
    groups: dict[str, list] = {}
    for m in matches:
        by = getattr(m, "governed_birth_year", None)
        vcat = vcat_for_age(season_end - by) if by is not None else None
        if vcat is not None:
            groups.setdefault(vcat, []).append(m)
    return groups


class DetectCombinedPool(BasePlugin):
    """Detect a combined (multi-V-cat) pool from the GOVERNED birth-year spread
    of the resolved roster (ADR-024/070) — robust even when the source omitted
    age markers, since the fencers' governed BYs are known."""
    name = "DetectCombinedPool"
    kind = PluginKind.TRANSFORM
    reads = frozenset({"matches"})
    writes = frozenset({"combined"})

    def run(self, ctx: Context, svc: Services) -> None:
        pctx = get_pctx(ctx)
        season_end = pctx.season_end_year if pctx else None
        matches = ctx.get("matches") or []
        combined = season_end is not None and len(_governed_vcats(matches, season_end)) >= 2
        ctx.set("combined", combined)
        if pctx is not None:
            pctx.is_combined_pool = combined
        self.report(ctx, "STRUCTURE", combined=combined)


class SplitByAge(BasePlugin):
    """Group the resolved rows by GOVERNED birth year (ADR-070). Replaces the
    old splitter's reliance on scraped birth years / the batch RPC."""
    name = "SplitByAge"
    kind = PluginKind.TRANSFORM
    reads = frozenset({"matches", "combined"})
    writes = frozenset({"splits"})

    def applies(self, ctx: Context) -> bool:
        return bool(ctx.get("combined"))

    def run(self, ctx: Context, svc: Services) -> None:
        pctx = get_pctx(ctx)
        season_end = pctx.season_end_year if pctx else None
        matches = ctx.get("matches") or []
        splits = _governed_vcats(matches, season_end) if season_end is not None else {}
        ctx.set("splits", splits)
        if pctx is not None:
            pctx.splits = splits
        self.report(ctx, "STRUCTURE",
                    splits={k: len(v) for k, v in splits.items()})


class DetectJointPool(BasePlugin):
    name = "DetectJointPool"
    kind = PluginKind.TRANSFORM
    reads = frozenset({"event", "matches"})
    writes = frozenset({"joint_pool"})

    def run(self, ctx: Context, svc: Services) -> None:
        run_stage(ctx, "s5_detect_joint_pool", svc.db)
        pctx = get_pctx(ctx)
        if pctx is not None:
            sibs = list(pctx.joint_pool_siblings)
            ctx.set("joint_pool", sibs)
            self.report(ctx, "STRUCTURE", joint_pool_siblings=sibs)


class ValidateCounts(BasePlugin):
    """Count + URL→data (s7), plus the min-participants gate (ADR-066) that the
    NEW pipeline pulls into ingestion. Below-min -> ctx.fault(BELOW_MIN) ->
    drop_bracket (ADR-074); count/URL mismatch -> fault(accept_parsed)."""
    name = "ValidateCounts"
    kind = PluginKind.GATE
    reads = frozenset({"matches", "event"})

    def run(self, ctx: Context, svc: Services) -> None:
        pctx = get_pctx(ctx)
        # s7_validate compares against the source parse (count + URL→data). On
        # RECOMPUTE there is no source (parsed=None), so skip it; the min-
        # participants gate still runs against the loaded matches (ADR-072).
        has_source = (
            pctx is not None
            and getattr(pctx, "parsed", None) is not None
            and getattr(pctx.parsed, "results", None)
        )
        if has_source:
            run_stage(ctx, "s7_validate", svc.db)  # COUNT_MISMATCH / URL_DATA_MISMATCH -> fault
        self._check_min_participants(ctx, svc)
        from python.pipeline.core.contract import FaultKind
        self.report(ctx, "VALIDATION", check="count",
                    below_min=bool(ctx.faults_of(FaultKind.BELOW_MIN)),
                    count_mismatch=bool(ctx.faults_of(FaultKind.COUNT_MISMATCH)),
                    detail=getattr(pctx, "count_validation", None) if pctx else None)

    def _check_min_participants(self, ctx: Context, svc: Services) -> None:
        from python.pipeline.core.contract import FaultKind

        pctx = get_pctx(ctx)
        if pctx is None:
            return
        n = sum(
            1 for m in pctx.matches
            if getattr(m, "id_fencer", None) is not None
        ) or len(pctx.matches)
        cfg = svc.config or {}
        threshold = cfg.get("min_participants", self._default_min(pctx))
        if threshold and n < threshold:
            ctx.fault(FaultKind.BELOW_MIN, f"{n}<{threshold} participants")

    @staticmethod
    def _default_min(pctx) -> int:
        # Domestic PPW/MPW default = 1 (international default 5 is deferred §12).
        return 1


class DetectPoolRound(BasePlugin):
    name = "DetectPoolRound"
    kind = PluginKind.GATE
    reads = frozenset({"matches"})

    def run(self, ctx: Context, svc: Services) -> None:
        from python.pipeline.core.contract import FaultKind
        run_stage(ctx, "s7_pool_round_check", svc.db)  # POOL_ROUND_DETECTED -> fault
        prs = ctx.faults_of(FaultKind.POOL_ROUND)
        pctx = get_pctx(ctx)
        parsed = getattr(pctx, "parsed", None) if pctx else None
        # G3 (ADR-075): carry the bracket name + reason + URL so the staging report
        # can list it under "present but omitted from processing".
        self.report(ctx, "VALIDATION", check="pool_round",
                    is_pool_round=bool(prs),
                    name=getattr(parsed, "tournament_name", None) if parsed else None,
                    weapon=getattr(parsed, "weapon", None) if parsed else None,
                    url=getattr(parsed, "source_url", None) if parsed else None,
                    reason=prs[-1].detail if prs else None)


class AssignFinalVcat(BasePlugin):
    name = "AssignFinalVcat"
    kind = PluginKind.TRANSFORM
    reads = frozenset({"matches"})
    writes = frozenset({"final_vcats"})

    def run(self, ctx: Context, svc: Services) -> None:
        run_stage(ctx, "s7_split_by_vcat", svc.db)
        pctx = get_pctx(ctx)
        if pctx is not None:
            fv = dict(pctx.vcat_groups)
            ctx.set("final_vcats", fv)
            self.report(ctx, "STRUCTURE",
                        final_vcats={k: len(v) for k, v in fv.items()})


class Commit(BasePlugin):
    """Atomic delete-old + insert + score -> live, per V-cat bracket (ADR-014/022).

    For each V-cat in `final_vcats` it resolves/creates the bracket's tournament
    (`db.find_or_create_tournament`) and calls the existing atomic RPC
    `fn_ingest_tournament_results` via `db.ingest_results(tournament_id, rows,
    participant_count)`. The RPC deletes-then-inserts that tournament's rows and
    re-scores it in one transaction, so re-running the flow is idempotent (BR-6).

    `participant_count` is the bracket's OWN committed-row count — per the ADR-049
    amendment (2026-06-04) each V-cat slice is scored on its own field size, never
    the summed physical pool, so the per-bracket loop produces the correct count
    for combined/joint pools for free.

    Skips entirely when an inline remediation marked the artifact unrankable
    (`_skip_commit`). RECOMPUTE_DOMESTIC has no source parse and no per-bracket
    weapon/gender/date yet (LoadCommitted flattens them away); its live write-back
    is deferred to Step C, so on `parsed=None` Commit records a non-skipped,
    deferred commit and returns without touching the DB.
    """
    name = "Commit"
    kind = PluginKind.MUTATOR
    reads = frozenset({"matches", "final_vcats", "event"})
    writes = frozenset({"committed"})
    effects = frozenset({"live"})

    # StageMatchResult.method (new provenance vocabulary) -> the legacy
    # enum_match_status string fn_ingest_tournament_results casts. Anything not
    # listed (e.g. PENDING) passes through; the RPC defaults unknowns to AUTO_MATCH.
    _METHOD_TO_STATUS = {
        "AUTO_MATCHED": "AUTO_MATCHED",
        "AUTO_CREATED": "NEW_FENCER",
        "USER_CONFIRMED": "APPROVED",
    }

    def run(self, ctx: Context, svc: Services) -> None:
        if ctx.get("_skip_commit"):
            committed = {
                "skipped": True,
                "dropped": list(ctx.get("_dropped_brackets", [])),
            }
            ctx.set("committed", committed)
            self.report(ctx, "COMMIT", **committed)
            return
        pctx = get_pctx(ctx)
        db = svc.db
        event = ctx.get("event") or (pctx.event if pctx else None)
        final_vcats = ctx.get("final_vcats")
        if final_vcats is None:
            final_vcats = dict(pctx.vcat_groups) if pctx and pctx.vcat_groups else {}

        parsed = getattr(pctx, "parsed", None) if pctx else None
        if parsed is None:
            # RECOMPUTE_DOMESTIC — no source parse: re-partition the loaded rows
            # by (weapon, gender, governed-V-cat) and re-write each bracket.
            self._commit_recompute(ctx, svc, pctx, event)
            return

        event_id = event["id_event"]
        weapon = parsed.weapon
        gender = parsed.gender
        date = _iso_date(parsed.parsed_date)
        ttype = self._tournament_type(pctx, event)

        # Overlap-clobber fix (ADR-075-adjacent): the from-URL keep-rule hands this
        # listing the exact age-categories it OWNS via `commit_cats`. Categories not
        # in the set are owned by a more-specific listing (or a chosen alternative) —
        # this listing must NOT write them (else it clobbers via delete-reimport).
        # Absent (file/XML path) ⇒ write everything, unchanged. The from-URL flow
        # passes it via `svc.config` (the orchestrator resets ctx.params per step);
        # ctx.params is the direct-call fallback (unit tests).
        commit_cats = (svc.config or {}).get("commit_cats")
        if commit_cats is None:
            commit_cats = ctx.params.get("commit_cats")

        written: list[dict] = []
        held: list[str] = []
        for vcat in sorted(final_vcats.keys()):
            rows = [self._row(m) for m in final_vcats[vcat]
                    if getattr(m, "id_fencer", None) is not None]
            if not rows:
                continue
            if commit_cats is not None and vcat not in commit_cats:
                held.append(vcat)            # set aside — owned by another listing
                continue
            tournament_id = db.find_or_create_tournament(
                event_id, weapon, gender, vcat, date, ttype)
            db.ingest_results(tournament_id, rows, participant_count=len(rows))
            written.append({"vcat": vcat, "weapon": weapon, "gender": gender,
                            "id_tournament": tournament_id, "n": len(rows)})

        ctx.set("committed", {
            "skipped": False,
            "persisted": True,
            "tournaments": written,
            "vcat_groups": sorted(final_vcats.keys()),
            "held": held,
            # `live.committed` is the signal the PostCommit reactor observes
            # (Step D); recorded here as intent until that chaining is wired.
            "emitted": "live.committed",
        })
        self.report(ctx, "COMMIT", **ctx.get("committed"))

    def _commit_recompute(self, ctx: Context, svc: Services, pctx, event) -> None:
        """Re-persist a recomputed event (ADR-072, Step C).

        Groups the loaded matches by (weapon, gender, governed-V-cat) — an event
        spans many weapon/gender brackets, so V-cat alone would merge weapons —
        resolves each bracket's tournament and re-writes it via the atomic RPC
        (delete-old + insert + score), then CLEARS any pre-existing bracket the
        re-partition emptied (a birth-year relocation moved its only fencer out).
        """
        db = svc.db
        event_id = event["id_event"]
        season_end = pctx.season_end_year if pctx else None
        ttype = self._tournament_type(pctx, event)
        matches = ctx.get("matches") or []

        groups: dict[tuple, list] = {}
        for m in matches:
            if getattr(m, "id_fencer", None) is None:
                continue
            by = getattr(m, "governed_birth_year", None)
            vcat = vcat_for_age(season_end - by) if (by is not None and season_end) else None
            if vcat is None:
                continue
            groups.setdefault((m.weapon, m.gender, vcat), []).append(m)

        written: list[dict] = []
        written_ids: set = set()
        for (weapon, gender, vcat), rows_m in groups.items():
            rows = [self._row(m) for m in rows_m]
            date = _iso_date(rows_m[0].tournament_date)
            tournament_id = db.find_or_create_tournament(
                event_id, weapon, gender, vcat, date, ttype)
            db.ingest_results(tournament_id, rows, participant_count=len(rows))
            written.append({"vcat": vcat, "weapon": weapon, "gender": gender,
                            "id_tournament": tournament_id, "n": len(rows)})
            written_ids.add(tournament_id)

        # Drop: clear pre-existing brackets the re-partition no longer fills.
        cleared: list[int] = []
        existing = self._existing_tournaments(db, event_id)
        rewritten_keys = {(w, g, v) for (w, g, v) in groups}
        for t in existing:
            key = (t.get("enum_weapon"), t.get("enum_gender"), t.get("enum_age_category"))
            if t.get("id_tournament") not in written_ids and key not in rewritten_keys:
                if hasattr(db, "clear_tournament_results"):
                    db.clear_tournament_results(t["id_tournament"])
                    cleared.append(t["id_tournament"])

        ctx.set("committed", {
            "skipped": False,
            "persisted": True,
            "mode": "recompute",
            "tournaments": written,
            "cleared": cleared,
            "emitted": "live.committed",
        })
        self.report(ctx, "COMMIT", **ctx.get("committed"))

    @staticmethod
    def _existing_tournaments(db, event_id) -> list:
        fn = getattr(db, "fetch_event_tournaments", None)
        if not callable(fn):
            return []
        res = fn(event_id)
        return res if isinstance(res, list) else []

    def _row(self, m) -> dict:
        return {
            "id_fencer": m.id_fencer,
            "int_place": m.place,
            "txt_scraped_name": m.scraped_name,
            "num_confidence": m.confidence,
            "enum_match_status": self._METHOD_TO_STATUS.get(m.method, m.method),
        }

    @staticmethod
    def _tournament_type(pctx, event) -> str | None:
        from python.pipeline.db_connector import derive_tourn_type_from_event_code
        code = (pctx.event_code if pctx else None) or (event or {}).get("txt_code")
        return derive_tourn_type_from_event_code(code) or (event or {}).get("enum_type")


def _iso_date(d) -> str | None:
    """Normalize a parsed date to the PostgreSQL ISO `YYYY-MM-DD` the RPC expects.
    Handles a `datetime.date`, an ISO string, or a `DD.MM.YYYY` source string."""
    if d is None:
        return None
    if hasattr(d, "isoformat"):
        return d.isoformat()
    from datetime import datetime
    try:
        return datetime.strptime(str(d), "%d.%m.%Y").strftime("%Y-%m-%d")
    except ValueError:
        return str(d)
