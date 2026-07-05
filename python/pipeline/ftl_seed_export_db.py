"""
FTL seed export — Supabase glue (ADR-080 §2, Phase 3 DB-querying layer).

Thin wrapper that fetches the two inputs the pure orchestration in
ftl_seed_export.py needs and wires them together:

  1. the event's DECLARED registrations (tbl_registration — every row, no
     payment gate; population per ADR-079 §4 / user 2026-07-04), and
  2. the current-season ranking id_fencer order for each of the 10
     weapon×gender×category sub-rankings (fn_ranking_ppw), used only to ORDER
     registrants inside each mix-all sub-ranking.

All heavy logic lives in the pure module; this layer only does I/O, so it is
smoke-tested with a mocked client (test_ftl_seed_orchestration.py) and validated
E2E on LOCAL. Matches the DbConnector/DraftStore house style (wrap `_sb`,
`.table(...).select(...).execute()` / `.rpc(...).execute()`, read `.data`).
"""

from __future__ import annotations

from python.pipeline.ftl_seed_export import (
    MIXALL_SUBRANKING_ORDER,
    build_event_mixall_files,
    bundle_seed_zip,
)

# The 10 mix-all sub-ranking keys decomposed into fn_ranking_ppw arguments.
# key = <gender><vcat>, e.g. 'MV0' → (gender='M', category='V0').
_SUBRANKING_ARGS = tuple((key[0], key[1:]) for key in MIXALL_SUBRANKING_ORDER)

# arr_weapons enum → fn_ranking_ppw p_weapon enum (identical here, but explicit).
_WEAPON_ARG = {"EPEE": "EPEE", "FOIL": "FOIL", "SABRE": "SABRE"}


class FtlSeedExporter:
    """Builds an event's FTL mix-all seed bundle from its declared registrations."""

    def __init__(self, supabase_client) -> None:
        self._sb = supabase_client

    def fetch_registrations(self, id_event: int) -> list[dict]:
        """Every declared registration for the event, oldest first (ts_created).

        No payment gate — the declared row is the source of truth for "who is
        entering" (ADR-079 §4). ts_created order gives the unranked-newcomer
        interleave tiebreak for free.
        """
        resp = (
            self._sb.table("tbl_registration")
            .select(
                "id_registration, id_fencer, txt_surname, txt_first_name, "
                "enum_gender, int_birth_year, arr_weapons, ts_created"
            )
            .eq("id_event", id_event)
            .order("ts_created")
            .execute()
        )
        return resp.data or []

    def fetch_weapon_rankings(self, weapon: str, season: int | None = None) -> dict[str, list[int]]:
        """id_fencer order (rank ascending) for each of the 10 sub-rankings of
        one weapon, via fn_ranking_ppw. Empty sub-rankings map to []."""
        rankings: dict[str, list[int]] = {}
        for gender, category in _SUBRANKING_ARGS:
            params: dict[str, object] = {
                "p_weapon": _WEAPON_ARG[weapon],
                "p_gender": gender,
                "p_category": category,
            }
            if season is not None:
                params["p_season"] = season
            resp = self._sb.rpc("fn_ranking_ppw", params).execute()
            rows = resp.data or []
            rows = sorted(rows, key=lambda r: r.get("rank") or 0)
            rankings[f"{gender}{category}"] = [
                r["id_fencer"] for r in rows if r.get("id_fencer") is not None
            ]
        return rankings

    def build_bundle(
        self,
        id_event: int,
        weapons: list[str],
        season_code: str,
        event_code_stem: str,
        season_end_year: int,
        season: int | None = None,
        date_fichier_xml: str = "",
    ) -> dict[str, str]:
        """Fetch inputs and build {filename: xml} for every weapon with
        registrants. `weapons` is the event's declared weapon set (tbl_event
        arr_weapons)."""
        registrations = self.fetch_registrations(id_event)
        rankings_by_weapon = {w: self.fetch_weapon_rankings(w, season) for w in weapons}
        return build_event_mixall_files(
            registrations=registrations,
            weapons=weapons,
            rankings_by_weapon=rankings_by_weapon,
            season_code=season_code,
            event_code_stem=event_code_stem,
            season_end_year=season_end_year,
            date_fichier_xml=date_fichier_xml,
        )

    def build_bundle_zip(self, *args, **kwargs) -> bytes:
        """build_bundle → a single .zip (bytes) for Phase 4 delivery."""
        return bundle_seed_zip(self.build_bundle(*args, **kwargs))
