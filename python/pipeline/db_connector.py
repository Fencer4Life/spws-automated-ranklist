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
        """Return all fencers with fields needed for fuzzy matching.

        ADR-064: enum_gender is selected so the matcher's asymmetric
        F-bracket filter can drop M-gender candidates from the candidate
        set when bracket_gender='F' (domestic events only).

        ADR-050 Stage 0: txt_nationality + bool_birth_year_estimated are also
        selected so s0_reconcile_roster can run its high-precision exact dedup
        (nationality belt-and-suspenders) and decide estimated vs confirmed
        reconciliation. Harmless extra columns for the matcher.
        """
        resp = (
            self._sb.table("tbl_fencer")
            .select("id_fencer, txt_surname, txt_first_name, int_birth_year, "
                    "json_name_aliases, enum_gender, txt_nationality, "
                    "bool_birth_year_estimated")
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

    def find_event_by_code(self, event_code: str) -> dict | None:
        """Find an event by txt_code (Phase 3 ADR-050 — review_cli lookup).

        Returns dict with id_event, txt_code, txt_name, url_results,
        dt_start, dt_end, enum_status, id_season, id_organizer, txt_location
        — or None if not found.

        Phase 5: id_season is included so Stage 2 can resolve the correct
        season (not assume the active one).
        """
        resp = (
            self._sb.table("tbl_event")
            .select("id_event, txt_code, txt_name, "
                    "url_event, url_event_2, url_event_3, url_event_4, url_event_5, "
                    "dt_start, dt_end, enum_status, id_season, "
                    "id_organizer, txt_location")
            .eq("txt_code", event_code)
            .execute()
        )
        if resp.data:
            return resp.data[0]
        return None

    def find_season_by_id(self, id_season: int) -> dict | None:
        """Look up a season row by id_season (Phase 5 — Stage 2 uses
        this to derive season_end_year for the resolved event).

        Returns {id_season, txt_code, dt_start, dt_end} or None.
        """
        resp = (
            self._sb.table("tbl_season")
            .select("id_season, txt_code, dt_start, dt_end")
            .eq("id_season", id_season)
            .execute()
        )
        if resp.data:
            return resp.data[0]
        return None

    def fetch_genders_batch(self, id_fencers: list[int]) -> dict[int, str | None]:
        """Phase 5 — batch fetch enum_gender for matched fencers.

        Used by `s7_pool_round_check` to detect pool rounds via gender
        distribution structural signal. Returns {id_fencer: 'M'|'F'|None}.
        """
        if not id_fencers:
            return {}
        resp = (
            self._sb.table("tbl_fencer")
                    .select("id_fencer,enum_gender")
                    .in_("id_fencer", id_fencers)
                    .execute()
        )
        return {row["id_fencer"]: row.get("enum_gender") for row in (resp.data or [])}

    def fetch_fencer_basics_batch(self, id_fencers: list[int]) -> dict[int, dict]:
        """Phase 5 — batch fetch surname / first_name / aliases / birth-year
        flags for matched fencers. Used by the runner to build the per-event
        fencer-matching summary (alias usage, BY-estimated tracking).

        Returns {id_fencer: {txt_surname, txt_first_name, json_name_aliases,
        json_user_confirmed_aliases, int_birth_year, bool_birth_year_estimated}}.
        """
        if not id_fencers:
            return {}
        resp = (
            self._sb.table("tbl_fencer")
                    .select("id_fencer,txt_surname,txt_first_name,"
                            "json_name_aliases,json_user_confirmed_aliases,"
                            "int_birth_year,bool_birth_year_estimated")
                    .in_("id_fencer", id_fencers)
                    .execute()
        )
        return {row["id_fencer"]: row for row in (resp.data or [])}

    def fetch_birth_years_batch(self, id_fencers: list[int]) -> dict[int, int | None]:
        """ADR-056 (Phase 5) — batch fetch int_birth_year for matched fencers.

        Returns dict {id_fencer: int_birth_year}. Fencers whose row was not
        found are absent from the dict; fencers whose int_birth_year is NULL
        appear with value None. Empty input → empty dict (no DB call).
        """
        if not id_fencers:
            return {}
        resp = (
            self._sb.table("tbl_fencer")
                    .select("id_fencer,int_birth_year")
                    .in_("id_fencer", id_fencers)
                    .execute()
        )
        return {row["id_fencer"]: row.get("int_birth_year") for row in (resp.data or [])}

    def find_seasons_containing_dates(
        self, event_dt_start: str, event_dt_end: str
    ) -> list[dict]:
        """Return every season whose date range contains BOTH event dates.

        Phase 5: Stage 2 uses this to resolve which season the event truly
        belongs to (not to be confused with the FK on tbl_event.id_season,
        which historical seed data has wrong for some events). Exactly-one
        match is required; zero or many is a showstopper handled by the
        caller.

        A season `s` "contains" the event iff
            s.dt_start <= event_dt_start AND s.dt_end >= event_dt_end.
        """
        resp = (
            self._sb.table("tbl_season")
            .select("id_season, txt_code, dt_start, dt_end")
            .lte("dt_start", event_dt_start)
            .gte("dt_end", event_dt_end)
            .order("dt_start")
            .execute()
        )
        return list(resp.data or [])

    def fetch_cert_rows_for_event(self, event_code: str) -> list[dict]:
        """Fetch cert_ref result rows for an event (Phase 4 — 3-way diff CERT column).

        Calls fn_cert_ref_rows_for_event RPC, which joins cert_ref.tbl_event
        + tbl_tournament + tbl_result + tbl_fencer. Returns list of dicts
        with at minimum: {place, fencer_name, id_fencer, num_final_score,
        enum_age_category, txt_first_name, txt_surname, txt_nationality,
        int_birth_year}. Three_way_diff joins by `place`.
        Empty list if cert_ref schema is unpopulated for the event_code.
        """
        try:
            resp = self._sb.rpc(
                "fn_cert_ref_rows_for_event",
                {"p_event_code": event_code},
            ).execute()
        except Exception:
            return []
        rows = resp.data or []
        # Normalize: build a `place` key (three_way_diff joins by it)
        for r in rows:
            r["place"] = r.get("int_place")
        return rows

    def fetch_cert_tournament_for_event(self, event_code: str) -> dict | None:
        """Fetch the first cert_ref tournament for an event (Phase 4 — cert_ref parser input).

        Returns dict matching tbl_tournament columns, or None if absent.
        """
        try:
            resp = self._sb.rpc(
                "fn_cert_ref_tournament_for_event",
                {"p_event_code": event_code},
            ).execute()
        except Exception:
            return None
        return resp.data[0] if resp.data else None

    def call_age_categories_batch(
        self, birth_years: list[int], season_end_year: int,
    ) -> dict[int, str | None]:
        """Batch-resolve V-cat for a list of birth years (ADR-050 R001 / Stage 4).

        ONE RPC call per pool (not per fencer). The Postgres function
        fn_age_categories_batch (Phase 0) returns rows of (birth_year, age_category).

        Returns:
          {birth_year: V-cat-string}. V-cat is None for under-30 birth years.
        """
        resp = self._sb.rpc(
            "fn_age_categories_batch",
            {"p_birth_years": birth_years, "p_season_end_year": season_end_year},
        ).execute()
        return {row["birth_year"]: row["age_category"] for row in resp.data}

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

    def update_fencer_birth_year(
        self, fencer_id: int, birth_year: int, estimated: bool = False
    ) -> None:
        """Reconcile a fencer's birth year (ADR-050 Stage 0).

        Thin wrapper over the existing fn_update_fencer_birth_year RPC
        (migration 20260412000004) so the audit trigger preserves the prior
        value. Used by s0_reconcile_roster to correct a stored BY that
        conflicts with the V-cat of a bracket the fencer competed in.
        """
        self._sb.rpc(
            "fn_update_fencer_birth_year",
            {
                "p_fencer_id": fencer_id,
                "p_birth_year": birth_year,
                "p_estimated": estimated,
            },
        ).execute()

    # -----------------------------------------------------------------------
    # Phase 4 (ADR-046, ADR-053) — post-commit hooks + parity gate
    # -----------------------------------------------------------------------

    def pew_recompute_event_code(self, id_event: int) -> int:
        """Stage 8b cascade-rename. Returns count of tbl_event/tbl_tournament rows renamed.

        Idempotent. No-op for non-PEW events. Calls fn_pew_recompute_event_code.
        """
        resp = self._sb.rpc(
            "fn_pew_recompute_event_code", {"p_id_event": id_event}
        ).execute()
        # RPC returns INT scalar
        return int(resp.data) if resp.data is not None else 0

    def event_results_for_parity(self, id_event: int) -> list[dict]:
        """Return POL fencer rows shaped for the parity gate's `local_results`."""
        resp = self._sb.rpc(
            "fn_event_results_for_parity", {"p_id_event": id_event}
        ).execute()
        return resp.data or []

    def promote_evf_published(
        self, id_event: int, evf_scores: list[dict]
    ) -> dict:
        """Atomic: overwrite num_final_score per fencer + flip status + audit."""
        resp = self._sb.rpc(
            "fn_promote_evf_published",
            {"p_id_event": id_event, "p_evf_scores": evf_scores},
        ).execute()
        return resp.data or {}

    def annotate_parity_fail(self, id_event: int, notes: str) -> dict:
        resp = self._sb.rpc(
            "fn_annotate_parity_fail",
            {"p_id_event": id_event, "p_notes": notes},
        ).execute()
        return resp.data or {}

    def evf_events_pending_parity(self, max_age_days: int = 60) -> list[dict]:
        resp = self._sb.rpc(
            "fn_evf_events_pending_parity",
            {"p_max_age_days": max_age_days},
        ).execute()
        return resp.data or []

    def update_event_parity_notes(self, id_event: int, notes: str) -> None:
        """Direct table update used by the daily sweep when annotating "EVF API
        empty after 30 days" — uses fn_annotate_parity_fail so the audit log
        trail stays consistent.
        """
        self.annotate_parity_fail(id_event, notes)


# Tournament type → tbl_scoring_config column.
# ADR-066: PPW/MPW/PSW (domestic SPWS) gate on int_min_participants_ppw;
# PEW/MEW/MSW (international classification) gate on int_min_participants_evf.
_PPW_TYPES = frozenset({"PPW", "MPW", "PSW"})
_EVF_TYPES = frozenset({"PEW", "MEW", "MSW"})


def get_min_participants(db: "DbConnector", id_season: int, tourn_type: str) -> int:
    """Return the per-season minimum-participants threshold for a
    tournament type.

    ADR-066: tournaments with `n_competitors < threshold` are skipped at
    ingestion (no tbl_tournament row, no points awarded). Read from
    `tbl_scoring_config.int_min_participants_{ppw,evf}` keyed by
    `id_season`. Default 1 (include everything) when:
      - the season has no scoring_config row, OR
      - the tournament type is unrecognised.
    """
    if tourn_type in _PPW_TYPES:
        column = "int_min_participants_ppw"
    elif tourn_type in _EVF_TYPES:
        column = "int_min_participants_evf"
    else:
        return 1
    rows = (
        db._sb.table("tbl_scoring_config")
        .select(column)
        .eq("id_season", id_season)
        .execute()
        .data
    ) or []
    if not rows:
        return 1
    val = rows[0].get(column)
    return int(val) if val is not None else 1


def derive_tourn_type_from_event_code(event_code: str) -> "str | None":
    """Map a `tbl_event.txt_code` to its tournament type for ADR-066 routing.

    Active season uses prefixes (per ADR-046 + spec):
      - PPW{N} (domestic Puchar Polski Weteranów)            → PPW
      - MPW (Mistrzostwa Polski Weteranów championship)      → MPW
      - PSW (Mistrzostwa Szkolne Weteranów school champ)     → PSW
      - PEW{N}{efs}* (international circuit)                  → PEW
      - MEW (international individual championship)          → MEW
      - IMEW (alternation pair with DMEW; individual)        → MEW
      - DMEW (international team championship)               → MPW (team semantics)
      - MSW (international SuperSenior championship)         → MSW
      - IMSW (alternation pair; individual SuperSenior)      → MSW

    Returns None for codes that don't match any known prefix (defensive
    fallback — `gate_below_min_participants` then defaults to threshold=1).
    """
    if not event_code:
        return None
    prefix = event_code.split("-", 1)[0]
    if prefix.startswith("PPW") and prefix[3:].isdigit():
        return "PPW"
    if prefix == "MPW":
        return "MPW"
    if prefix == "PSW":
        return "PSW"
    if prefix.startswith("PEW"):
        rest = prefix[3:]
        head = ""
        for ch in rest:
            if ch.isdigit():
                head += ch
            else:
                break
        suffix = rest[len(head):]
        if head and (not suffix or all(c in "efs" for c in suffix.lower())):
            return "PEW"
    if prefix == "MEW" or prefix == "IMEW":
        return "MEW"
    if prefix == "DMEW":
        return "MPW"
    if prefix == "MSW" or prefix == "IMSW":
        return "MSW"
    return None


def gate_below_min_participants(
    db: "DbConnector", id_season: int, tourn_type: str, n_results: int,
) -> "tuple[bool, str | None]":
    """ADR-066 ingestion gate.

    Strict less-than: returns (True, reason) when `n_results < threshold`,
    else (False, None). Reason string is `BELOW_MIN_PARTICIPANTS (n=X, min=Y)`
    so the staging summary can render it.
    """
    threshold = get_min_participants(db, id_season, tourn_type)
    if n_results < threshold:
        return True, f"BELOW_MIN_PARTICIPANTS (n={n_results}, min={threshold})"
    return False, None


def create_db_connector() -> DbConnector:
    """Create a DbConnector from environment variables."""
    from supabase import create_client

    url = os.environ["SUPABASE_URL"]
    key = os.environ["SUPABASE_KEY"]
    client = create_client(url, key)
    return DbConnector(client)