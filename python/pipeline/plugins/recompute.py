"""RECOMPUTE_DOMESTIC source — `LoadCommitted` (ADR-072).

Loads an affected event's stored, FK-linked results across ALL its V-cat
brackets so `AssignFinalVcat`/`ValidateCounts`/`Commit` can re-derive V-cats +
re-score from durable data — no source fetch, no re-match. Event-granular: a BY
change relocates a result between brackets, and the moving result is stored
under its OLD bracket, so the whole event is the unit (design §6.2, ADR-072).

It writes the same `matches`/`event` Context keys the ingest source produces, so
`AssignFinalVcat`/`ValidateCounts`/`Commit` are reused unchanged across
INGEST_DOMESTIC and RECOMPUTE_DOMESTIC. The per-row governed BY comes from
`db.fetch_event_results` (which reads the current, corrected `tbl_fencer.BY`).
"""

from __future__ import annotations

from python.pipeline.core.contract import Abort, Context, PluginKind, Services
from python.pipeline.plugins.base import BasePlugin
from python.pipeline.plugins.bridge import ensure_pctx
from python.pipeline.types import StageMatchResult


class LoadCommitted(BasePlugin):
    name = "LoadCommitted"
    kind = PluginKind.SOURCE
    writes = frozenset({"matches", "event"})

    def run(self, ctx: Context, svc: Services) -> None:
        cfg = svc.config or {}
        db = svc.db
        id_event = cfg.get("id_event")
        if id_event is None:
            raise Abort(plugin=self.name, detail="no id_event for RECOMPUTE_DOMESTIC")

        event = cfg.get("event")
        if event is None and hasattr(db, "find_event_by_id"):
            event = db.find_event_by_id(id_event)
        event = event or {"id_event": id_event}

        # The CDC trigger only knows id_fencer → events; it cannot pass a
        # season_end_year. Derive it from the event's season so the self-heal
        # loop runs unattended (ADR-072). An explicit config value wins.
        season_end_year = cfg.get("season_end_year")
        if season_end_year is None:
            season_end_year = self._derive_season_end_year(db, event)

        rows = db.fetch_event_results(id_event)
        matches = [
            StageMatchResult(
                scraped_name=str(r.get("id_fencer")),
                place=r.get("place"),
                id_fencer=r.get("id_fencer"),
                confidence=100.0,
                method="AUTO_MATCHED",
                governed_birth_year=r.get("int_birth_year"),
                # Step C: carry the source bracket's weapon/gender/date so Commit
                # can re-partition by (weapon, gender, governed-V-cat).
                weapon=r.get("weapon"),
                gender=r.get("gender"),
                tournament_date=r.get("date"),
            )
            for r in rows
        ]

        # Minimal bridge pctx — recompute has no source parse (parsed=None), so
        # AssignFinalVcat takes its BY-derivation path and ValidateCounts skips
        # the source/URL checks (see ingest.ValidateCounts).
        pctx = ensure_pctx(
            ctx,
            parsed=None,
            season_end_year=season_end_year,
            event_code=event.get("txt_code"),
        )
        pctx.event = event
        pctx.matches = matches
        ctx.set("event", event)
        ctx.set("matches", matches)

    @staticmethod
    def _derive_season_end_year(db, event) -> int | None:
        """End-year of the event's season — preferred via the FK id_season,
        falling back to the event's own dt_end year."""
        id_season = event.get("id_season")
        if id_season is not None and hasattr(db, "find_season_by_id"):
            season = db.find_season_by_id(id_season)
            dt_end = (season or {}).get("dt_end")
            if dt_end:
                return int(str(dt_end)[:4])
        dt_end = event.get("dt_end")
        return int(str(dt_end)[:4]) if dt_end else None
