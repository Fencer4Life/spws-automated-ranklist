"""
Supabase DB connector for the ingestion pipeline.

Thin wrapper around the Supabase client that exposes only
the operations needed by the orchestrator.
"""

from __future__ import annotations

import os


class DbConnector:
    """Wraps a Supabase client for pipeline database operations."""

    def __init__(self, supabase_client) -> None:
        self._sb = supabase_client

    def fetch_fencer_db(self) -> list[dict]:
        """Return all fencers with fields needed for fuzzy matching."""
        resp = (
            self._sb.table("tbl_fencer")
            .select("id_fencer, txt_surname, txt_first_name, int_birth_year, json_name_aliases")
            .execute()
        )
        return resp.data

    def find_event_by_date(self, date: str) -> dict | None:
        """Find event in active season by date (ADR-025).

        Returns dict with id_event, txt_code, txt_name, enum_status or None.
        """
        resp = self._sb.rpc(
            "fn_find_event_by_date",
            {"p_date": date},
        ).execute()
        if resp.data:
            return resp.data[0]
        return None

    def find_or_create_tournament(
        self, event_id: int, weapon: str, gender: str,
        category: str, date: str, tournament_type: str,
    ) -> int:
        """Find or create tournament under event (ADR-025).

        Returns id_tournament.
        """
        resp = self._sb.rpc(
            "fn_find_or_create_tournament",
            {
                "p_event_id": event_id,
                "p_weapon": weapon,
                "p_gender": gender,
                "p_age_category": category,
                "p_date": date,
                "p_type": tournament_type,
            },
        ).execute()
        return resp.data

    def find_tournament(
        self, weapon: str, gender: str, category: str, date: str
    ) -> dict | None:
        """Legacy: look up tournament by weapon+gender+category+date globally.

        Kept for backwards compatibility. Prefer find_event_by_date +
        find_or_create_tournament for new code.
        """
        resp = (
            self._sb.table("tbl_tournament")
            .select("id_tournament, txt_code, enum_type")
            .eq("enum_weapon", weapon)
            .eq("enum_gender", gender)
            .eq("enum_age_category", category)
            .eq("dt_tournament", date)
            .execute()
        )
        if resp.data:
            return resp.data[0]
        return None

    def has_existing_results(self, tournament_id: int) -> bool:
        """Check if a tournament already has results in tbl_result."""
        resp = (
            self._sb.table("tbl_result")
            .select("id_result")
            .eq("id_tournament", tournament_id)
            .limit(1)
            .execute()
        )
        return len(resp.data) > 0

    def ingest_results(self, tournament_id: int, results_json: list[dict],
                        participant_count: int | None = None) -> dict:
        """Call fn_ingest_tournament_results RPC (ADR-022).

        Args:
            participant_count: Optional total tournament size. When provided,
                overrides auto-count from results array. Critical for international
                tournaments where only POL fencers are imported.
        """
        params = {"p_tournament_id": tournament_id, "p_results": results_json}
        if participant_count is not None:
            params["p_participant_count"] = participant_count
        resp = self._sb.rpc("fn_ingest_tournament_results", params).execute()
        return resp.data

    def insert_fencer(self, fencer_dict: dict) -> int:
        """Insert a new fencer and return the id_fencer."""
        resp = (
            self._sb.table("tbl_fencer")
            .insert(fencer_dict)
            .execute()
        )
        return resp.data[0]["id_fencer"]


def create_db_connector() -> DbConnector:
    """Create a DbConnector from environment variables."""
    from supabase import create_client

    url = os.environ["SUPABASE_URL"]
    key = os.environ["SUPABASE_KEY"]
    client = create_client(url, key)
    return DbConnector(client)