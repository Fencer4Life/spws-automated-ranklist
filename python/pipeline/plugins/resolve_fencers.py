"""ResolveFencers — the merged, early identity plugin (ADR-070, design §5.1).

Folds the old Stage-0 (roster reconcile) ⊕ Stage-6 (fuzzy match) into ONE plugin
that owns *name → governed fencer* and runs FIRST of the core, before the split.
Its own per-row V-cat comes from `_row_authoritative_vcat` (category_hint /
per-fencer raw_age_marker / source BY) — NOT from `splits` — which is exactly why
it can run before `SplitByAge`.

Two phases (one plugin, all name→fencer logic in one place):
  PHASE A — exact, high precision: settle the roster. Post-fold exact match
            (ADR-003, ~0 false positives); on hit, reconcile a conflicting stored
            BY to the V-cat band midpoint (ADR-056).
  PHASE B — fuzzy, against the now-reconciled roster: link iff the matcher returns
            its calibrated AUTO_MATCHED status (or conf ≥ an explicit
            `auto_link_threshold` override); else CREATE a new fencer at the band
            midpoint. Asymmetric safety — create-over-uncertain-link; duplicates
            are swept by DEDUP_SWEEP (ADR-071, M5).

Reuses the existing helpers verbatim (`_find_exact_fencer`, `_row_authoritative_vcat`,
`vcat_for_age`, `find_best_match`, `estimate_birth_year`, `db.insert_fencer`,
`db.update_fencer_birth_year`) — no new domain logic, only a new orchestration.
effects: master_data — emits the change that drives self-healing recompute (ADR-072).
"""

from __future__ import annotations

from typing import Any

from python.matcher.fuzzy_match import find_best_match
from python.matcher.pipeline import estimate_birth_year
from python.pipeline.core.contract import Context, PluginKind, Services
from python.pipeline.plugins.base import BasePlugin
from python.pipeline.plugins.bridge import get_pctx
from python.pipeline.stages import (
    _find_exact_fencer,
    _is_domestic,
    _row_authoritative_vcat,
    reconcile_fencer_birth_year,
)
from python.pipeline.types import StageMatchResult


class ResolveFencers(BasePlugin):
    name = "ResolveFencers"
    kind = PluginKind.MUTATOR
    reads = frozenset({"parsed", "event"})
    writes = frozenset({"matches"})
    effects = frozenset({"master_data"})

    def run(self, ctx: Context, svc: Services) -> None:
        if ctx.params.get("scope") == "whole_roster":
            self._sweep(ctx, svc)  # DEDUP_SWEEP (ADR-071) — same dedup logic, whole roster
            return
        pctx = get_pctx(ctx)
        db = svc.db
        domestic = _is_domestic(pctx.event)
        season_end = pctx.season_end_year
        parsed_gender = getattr(pctx.parsed, "gender", None)
        bracket_gender = parsed_gender if domestic else None  # ADR-064
        auto_thresh = (svc.config or {}).get("auto_link_threshold")  # optional recalibration knob

        fencer_db = db.fetch_fencer_db()
        rows = [
            (_row_authoritative_vcat(pctx, r), r)
            for r in pctx.parsed.results
            if not getattr(r, "bool_excluded", False)
        ]

        matches: list[StageMatchResult] = []
        touched: dict[int, str] = {}
        remaining: list[tuple[str | None, Any]] = []
        alias_writebacks: list[dict] = []  # G4: scraped→canonical pairs recorded as aliases

        # ---- PHASE A — exact match + BY reconcile ----
        for vcat, r in rows:
            ovr = pctx.overrides.identity_for(r.fencer_name)
            if ovr is not None:
                matches.append(self._from_override(r, ovr, fencer_db, season_end, vcat))
                continue
            exact_id = _find_exact_fencer(
                r.fencer_name, getattr(r, "fencer_country", None), fencer_db
            )
            if exact_id is not None:
                gby = self._reconcile_by(ctx, db, fencer_db, exact_id, vcat, season_end, touched, r)
                matches.append(
                    StageMatchResult(
                        scraped_name=r.fencer_name,
                        place=r.place,
                        id_fencer=exact_id,
                        confidence=100.0,
                        method="AUTO_MATCHED",
                        governed_birth_year=gby,
                        notes="exact",
                    )
                )
            else:
                remaining.append((vcat, r))

        # ---- PHASE B — fuzzy link-or-create ----
        for vcat, r in remaining:
            best = find_best_match(
                r.fencer_name,
                fencer_db,
                age_category=vcat,
                season_end_year=season_end,
                bracket_gender=bracket_gender,
                auto_match_threshold=auto_thresh,
            )
            mm = pctx.overrides.match_method_for(r.fencer_name)
            if mm is not None:
                matches.append(
                    StageMatchResult(
                        scraped_name=r.fencer_name,
                        place=r.place,
                        id_fencer=best.id_fencer,
                        confidence=best.confidence,
                        method=mm.force_method,
                        governed_birth_year=self._gby_of(
                            fencer_db, best.id_fencer, vcat, season_end
                        ),
                        notes=f"match_method override: {mm.note or 'forced'}",
                    )
                )
                continue

            if best.id_fencer is not None and self._should_link(best, auto_thresh):
                self._alias_writeback(db, best.id_fencer, r.fencer_name)
                alias_writebacks.append(
                    {
                        "scraped": r.fencer_name,
                        "id_fencer": best.id_fencer,
                        "canonical": best.matched_name,
                    }
                )
                matches.append(
                    StageMatchResult(
                        scraped_name=r.fencer_name,
                        place=r.place,
                        id_fencer=best.id_fencer,
                        confidence=best.confidence,
                        method="AUTO_MATCHED",
                        governed_birth_year=self._gby_of(
                            fencer_db, best.id_fencer, vcat, season_end
                        ),
                        notes="fuzzy-link",
                    )
                )
            elif domestic:
                new_id, gby = self._create(
                    db, fencer_db, r, vcat, season_end, parsed_gender, ctx, best=best
                )
                matches.append(
                    StageMatchResult(
                        scraped_name=r.fencer_name,
                        place=r.place,
                        id_fencer=new_id,
                        confidence=best.confidence,
                        method="AUTO_CREATED",
                        governed_birth_year=gby,
                        notes="created (create-over-uncertain-link)",
                    )
                )
            else:  # international (deferred §12) — exclude
                matches.append(
                    StageMatchResult(
                        scraped_name=r.fencer_name,
                        place=r.place,
                        id_fencer=None,
                        confidence=best.confidence,
                        method="EXCLUDED",
                    )
                )

        pctx.matches = matches
        ctx.set("matches", matches)
        # ADR-075: serialize identity resolution to the staging report. The legacy
        # pctx still carries created/reconciled/conflicts (kept for the bridge), but
        # the report channel is the file's self-contained source of truth.
        self.report(
            ctx,
            "IDENTITY",
            matches=[
                {
                    "scraped_name": m.scraped_name,
                    "id_fencer": m.id_fencer,
                    "place": m.place,
                    "method": m.method,
                    "confidence": m.confidence,
                    "governed_birth_year": m.governed_birth_year,
                    "notes": getattr(m, "notes", None),
                }
                for m in matches
            ],
            created=list(pctx.created_fencers),
            reconciled=list(pctx.reconciled_fencers),
            conflicts=list(pctx.reconcile_conflicts),
            alias_writebacks=alias_writebacks,
        )

    # ------------------------------------------------------------------ #
    # DEDUP_SWEEP — whole-roster dedup (ADR-071), same primitive (fn_merge_fencers)
    # ------------------------------------------------------------------ #
    def _sweep(self, ctx: Context, svc: Services) -> None:
        from python.matcher.fuzzy_match import normalize_name
        from python.pipeline.stages import _norm_nat

        db = svc.db
        groups: dict[tuple, list[int]] = {}
        for f in db.fetch_fencer_db():
            key = (
                normalize_name(f.get("txt_surname") or "", use_diacritic_folding=True),
                normalize_name(f.get("txt_first_name") or "", use_diacritic_folding=True),
                _norm_nat(f.get("txt_nationality")),
            )
            groups.setdefault(key, []).append(f["id_fencer"])

        merged: list[tuple[int, int]] = []
        for ids in groups.values():
            if len(ids) > 1:
                survivor = min(ids)  # stable survivor choice
                for dup in sorted(ids):
                    if dup != survivor:
                        db.merge_fencers(survivor, dup)  # re-point + fold + enqueue both
                        merged.append((survivor, dup))
        ctx.data["_merged_pairs"] = merged  # for the Notify summary
        ctx.set("matches", [])  # whole-roster: no per-row matches

    # ------------------------------------------------------------------ #
    # policy
    # ------------------------------------------------------------------ #
    @staticmethod
    def _should_link(best, auto_thresh) -> bool:
        """Calibrated link policy. Default: the matcher's AUTO_MATCHED status
        (which already encodes the calibrated auto-threshold + ADR-064 gender
        filter + age tiebreak). An explicit numeric override recalibrates."""
        if auto_thresh is not None:
            return best.confidence >= auto_thresh
        return best.status == "AUTO_MATCHED"

    # ------------------------------------------------------------------ #
    # reuse of the Stage-0 reconcile / create primitives
    # ------------------------------------------------------------------ #
    def _reconcile_by(
        self, ctx, db, fencer_db, existing_id, vcat, season_end, touched, r
    ) -> int | None:
        # Delegates to the single shared reconcile policy (not forked from s0).
        return reconcile_fencer_birth_year(
            ctx.get("_legacy"),
            db,
            fencer_db,
            existing_id,
            vcat,
            season_end,
            touched,
            r.fencer_name,
        )

    def _create(
        self, db, fencer_db, r, vcat, season_end, gender, ctx, best=None
    ) -> tuple[int, int | None]:
        from python.matcher.fuzzy_match import parse_scraped_name

        surname, first_name = parse_scraped_name(r.fencer_name)
        nat = getattr(r, "fencer_country", None)
        by = estimate_birth_year(vcat, season_end) if vcat else None
        payload = {
            "txt_surname": surname,
            "txt_first_name": first_name,
            "int_birth_year": by,
            "bool_birth_year_estimated": by is not None,
            "txt_nationality": nat or "PL",
        }
        if gender:
            payload["enum_gender"] = gender
        new_id = db.insert_fencer(payload)
        fencer_db.append(
            {
                "id_fencer": new_id,
                "txt_surname": surname,
                "txt_first_name": first_name,
                "int_birth_year": by,
                "bool_birth_year_estimated": by is not None,
                "txt_nationality": nat or "PL",
                "enum_gender": gender,
                "json_name_aliases": [],
            }
        )
        # G5 (ADR-075): record the fuzzy near-miss the matcher rejected, so the
        # staging report can flag a creation that may actually be a duplicate.
        near_miss = None
        if best is not None and getattr(best, "matched_name", None) is not None:
            near_miss = {
                "id_fencer": best.id_fencer,
                "name": best.matched_name,
                "confidence": best.confidence,
            }
        ctx.get("_legacy").created_fencers.append(
            {
                "id_fencer": new_id,
                "scraped_name": r.fencer_name,
                "txt_surname": surname,
                "txt_first_name": first_name,
                "nationality": nat or "PL",
                "vcat": vcat,
                "birth_year": by,
                "estimated": by is not None,
                "near_miss": near_miss,
            }
        )
        return new_id, by

    @staticmethod
    def _gby_of(fencer_db, id_fencer, vcat, season_end) -> int | None:
        row = next((f for f in fencer_db if f["id_fencer"] == id_fencer), None)
        if row is not None and row.get("int_birth_year") is not None:
            return row["int_birth_year"]
        return estimate_birth_year(vcat, season_end) if vcat else None

    def _from_override(self, r, ovr, fencer_db, season_end, vcat) -> StageMatchResult:
        if ovr.id_fencer is not None:
            return StageMatchResult(
                scraped_name=r.fencer_name,
                place=r.place,
                id_fencer=ovr.id_fencer,
                confidence=100.0,
                method="AUTO_MATCHED",
                governed_birth_year=self._gby_of(fencer_db, ovr.id_fencer, vcat, season_end),
                notes="identity override (link)",
            )
        return StageMatchResult(
            scraped_name=r.fencer_name,
            place=r.place,
            id_fencer=None,
            confidence=100.0,
            method="AUTO_CREATED",
            notes=f"identity override (create_fencer): {ovr.create_fencer}",
        )

    @staticmethod
    def _alias_writeback(db, id_fencer, scraped_name) -> None:
        """Record the scraped spelling as an alias so next run exact-matches.
        Best-effort: fn_update_fencer_aliases when the connector exposes it."""
        fn = getattr(db, "update_fencer_aliases", None)
        if callable(fn):
            try:
                fn(id_fencer, [scraped_name])
            except Exception:  # never block ingestion on an alias writeback
                pass
