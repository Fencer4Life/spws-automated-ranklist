"""CommitPzszSenior — the PZSz-senior-specific write step (design §07, ADR-100).

Unlike `Commit` (ingest.py), which writes ONE tournament PER V-CAT slice of a
combined pool, a PZSz PPS/MPS bracket is never split: it is one undivided
senior field, and this plugin writes exactly ONE tournament per (weapon,
gender), labeled `enum_age_category='SENIOR'`. Each matched veteran's own row
still carries their real V0-V4 category via `enum_source_age_category`
(ADR-056's "trust the splitter" escape hatch, reused unchanged) -- the ranking
functions already key off a fencer's own computed category first
(`fn_age_category`), falling back to the tournament's stored category only
when a fencer's birth year is unknown, so a SENIOR-labeled tournament needs no
changes anywhere in `fn_ranking_ppw`/`fn_ranking_kadra`/`fn_ranking_full` to be
read correctly.

Two invariants `Commit` does not need to enforce, because they never arise for
a per-V-cat bracket:
  - `int_participant_count` is the FULL SOURCE FIELD SIZE (every competitor in
    the parsed IR, matched or not) -- never the written-row count. Set
    directly on the tournament, before its rows are written.
  - A matched veteran's `int_place` is their ORIGINAL scraped place, never
    renumbered -- the PER_CATEGORY_RENUMBER module is a per-V-cat-split
    concept and is never invoked here.
  - The senior field is ONE category (ADR-103 §4): K = the full field, m =
    the original place, and b = the fencers of the full field with a strictly
    worse place. They are written whatever the engine -- EVF classic, which
    scores PPS and MPS in 2026/2027, does not read them.

The matches come from `AdmitPzszRoster` (ADR-111): a row is stored on
surname, first name and the start list's birth year, or skipped. A skipped
row (no fencer) writes nothing, and nothing is queued for review. When nobody
matched, no tournament is created and nothing is written at all (ADR-111 §5).
"""

from __future__ import annotations

from python.pipeline.core.contract import Context, PluginKind, Services
from python.pipeline.plugins.base import BasePlugin
from python.pipeline.plugins.bridge import get_pctx
from python.pipeline.plugins.ingest import _iso_date, _url_results_for
from python.pipeline.stages import vcat_for_age


class CommitPzszSenior(BasePlugin):
    name = "CommitPzszSenior"
    kind = PluginKind.MUTATOR
    reads = frozenset({"matches", "event"})
    writes = frozenset({"committed"})
    effects = frozenset({"live"})

    # Same provenance -> legacy-status mapping Commit uses (kept in sync
    # deliberately rather than imported, since Commit's own version is a
    # private module detail, not a shared contract).
    _METHOD_TO_STATUS = {
        "AUTO_MATCHED": "AUTO_MATCHED",
        "USER_CONFIRMED": "APPROVED",
    }

    def run(self, ctx: Context, svc: Services) -> None:
        pctx = get_pctx(ctx)
        db = svc.db
        event = ctx.get("event") or (pctx.event if pctx else None)
        matches = ctx.get("matches") or []
        parsed = getattr(pctx, "parsed", None) if pctx else None

        assert event is not None, (
            "CommitPzszSenior.run: no event on ctx or pctx — must run after ResolveEvent"
        )
        assert parsed is not None, (
            "CommitPzszSenior.run: no parsed IR — the PZSz flow has no RECOMPUTE variant"
        )

        event_id = event["id_event"]
        weapon = parsed.weapon
        gender = parsed.gender or "M"
        date = _iso_date(parsed.parsed_date)
        ttype = self._tournament_type(pctx, event)
        season_end = pctx.season_end_year if pctx else None
        url_results = _url_results_for(parsed)
        full_n = len(parsed.results)

        rows: list[dict] = []
        for m in matches:
            if m.id_fencer is not None:
                vcat = (
                    vcat_for_age(season_end - m.governed_birth_year)
                    if (season_end is not None and m.governed_birth_year is not None)
                    else None
                )
                rows.append(
                    {
                        "id_fencer": m.id_fencer,
                        "int_place": m.place,
                        "txt_scraped_name": m.scraped_name,
                        "num_confidence": m.confidence,
                        "enum_match_status": self._METHOD_TO_STATUS.get(m.method, m.method),
                        "enum_source_age_category": vcat,
                    }
                )
            # else: skipped by the admission — nothing written, nothing queued.

        if not rows:
            # ADR-111 §5: nobody matched — no tournament, no N, no result.
            ctx.set(
                "committed",
                {
                    "skipped": False,
                    "persisted": False,
                    "tournaments": [],
                    "vcat_groups": [],
                    "nobody_matched": True,
                },
            )
            self.report(ctx, "COMMIT", **ctx.get("committed"))
            return

        tournament_id = db.find_or_create_tournament(
            event_id, weapon, gender, "SENIOR", date, ttype, url_results=url_results
        )
        # The full field size, before the rows: it does not depend on how
        # matching turned out.
        db.set_tournament_participant_count(tournament_id, full_n)
        db.ingest_results(tournament_id, rows, participant_count=full_n)

        ctx.set(
            "committed",
            {
                "skipped": False,
                "persisted": True,
                "tournaments": [
                    {
                        "vcat": "SENIOR",
                        "weapon": weapon,
                        "gender": gender,
                        "id_tournament": tournament_id,
                        "n": len(rows),
                    }
                ],
                "vcat_groups": ["SENIOR"],
                "emitted": "live.committed",
            },
        )
        self.report(ctx, "COMMIT", **ctx.get("committed"))

    @staticmethod
    def _tournament_type(pctx, event) -> str | None:
        from python.pipeline.db_connector import derive_tourn_type_from_event_code

        code = (pctx.event_code if pctx else None) or (event or {}).get("txt_code")
        derived = derive_tourn_type_from_event_code(code) if code else None
        return derived or (event or {}).get("enum_type")
