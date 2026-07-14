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
            .select(
                "id_fencer, txt_surname, txt_first_name, int_birth_year, "
                "json_name_aliases, enum_gender, txt_nationality, "
                "bool_birth_year_estimated"
            )
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

        Returns event metadata used by ingestion and FTL seed delivery, or None.

        Phase 5: id_season is included so Stage 2 can resolve the correct
        season (not assume the active one).
        """
        resp = (
            self._sb.table("tbl_event")
            .select(
                "id_event, txt_code, txt_name, "
                "url_event, url_event_2, url_event_3, url_event_4, url_event_5, "
                "dt_start, dt_end, enum_status, id_season, "
                "id_organizer, txt_location, json_source_overrides, "
                "arr_weapons, txt_organizer_email, ts_ftl_sent, "
                "dt_registration_deadline, bool_use_spws_registration"
            )
            .eq("txt_code", event_code)
            .execute()
        )
        if resp.data:
            return resp.data[0]
        return None

    def mark_ftl_sent(self, event_code: str) -> str:
        """Stamp and return tbl_event.ts_ftl_sent after SMTP acceptance (FR-131)."""
        resp = self._sb.rpc("fn_mark_ftl_sent", {"p_event_code": event_code}).execute()
        return str(resp.data)

    def list_ftl_delivery_candidates(self) -> list[dict]:
        """Return unstamped SPWS-registration events for Python eligibility filtering."""
        resp = (
            self._sb.table("tbl_event")
            .select(
                "txt_code, dt_registration_deadline, dt_start, dt_end, enum_status, "
                "txt_organizer_email"
            )
            .eq("bool_use_spws_registration", True)
            .is_("ts_ftl_sent", "null")
            .execute()
        )
        return resp.data or []

    def set_event_url_event(self, id_event: int, url_event: str) -> None:
        """Persist an admin-supplied event URL to tbl_event.url_event (N15 — the
        Telegram `ingest <prefix> <url>` command provides the FTL eventSchedule URL).
        Admin-managed write; url_event stays operator-entered, never auto-scraped."""
        (
            self._sb.table("tbl_event")
            .update({"url_event": url_event})
            .eq("id_event", id_event)
            .execute()
        )

    def set_event_ingest_sources(self, id_event: int, sources: list) -> None:
        """Persist the from-URL ingest's discovered rounds + status for the event
        accordion (N13.4). Display-only JSONB; never enters scored tables."""
        (
            self._sb.table("tbl_event")
            .update({"json_ingest_sources": sources})
            .eq("id_event", id_event)
            .execute()
        )

    def find_event_by_id(self, id_event: int) -> dict | None:
        """Look up an event by id_event (ADR-072 — RECOMPUTE_DOMESTIC resolves the
        enqueued event to derive its season_end_year). Returns
        {id_event, txt_code, dt_start, dt_end, id_season, enum_status} or None.
        """
        resp = (
            self._sb.table("tbl_event")
            .select("id_event, txt_code, dt_start, dt_end, id_season, enum_status")
            .eq("id_event", id_event)
            .execute()
        )
        return resp.data[0] if resp.data else None

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
            .select(
                "id_fencer,txt_surname,txt_first_name,"
                "json_name_aliases,json_user_confirmed_aliases,"
                "int_birth_year,bool_birth_year_estimated"
            )
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

    def fetch_event_results(self, id_event: int) -> list[dict]:
        """ADR-072 — load an event's committed, FK-linked results across ALL its
        V-cat tournaments, each with the fencer's GOVERNED birth year, for
        RECOMPUTE_DOMESTIC (no source fetch, no re-match).

        Returns [{id_fencer, place, enum_age_category, int_birth_year, weapon,
        gender, date, id_tournament}]. Empty if the event has no committed
        tournaments yet. Reuses `fetch_birth_years_batch` so the BY is always the
        governed value. weapon/gender/date carry the source tournament's
        enum_weapon/enum_gender/dt_tournament so Commit can re-partition by
        (weapon, gender, governed-V-cat) on recompute (Step C).
        """
        tr = (
            self._sb.table("tbl_tournament")
            .select("id_tournament,enum_weapon,enum_gender,enum_age_category,dt_tournament")
            .eq("id_event", id_event)
            .execute()
        )
        tmeta = {r["id_tournament"]: r for r in (tr.data or [])}
        if not tmeta:
            return []
        # NOTE: the V-cat (enum_age_category) lives on tbl_tournament, NOT
        # tbl_result — joining it off the parent tournament is what the original
        # (never-live-run) query got wrong.
        rr = (
            self._sb.table("tbl_result")
            .select("id_fencer,int_place,id_tournament")
            .in_("id_tournament", list(tmeta))
            .execute()
        )
        rows = rr.data or []
        ids = [r["id_fencer"] for r in rows if r.get("id_fencer") is not None]
        by_map = self.fetch_birth_years_batch(ids)
        return [
            {
                "id_fencer": r.get("id_fencer"),
                "place": r.get("int_place"),
                "enum_age_category": tmeta[r["id_tournament"]].get("enum_age_category"),
                "int_birth_year": by_map.get(r.get("id_fencer")),
                "weapon": tmeta[r["id_tournament"]].get("enum_weapon"),
                "gender": tmeta[r["id_tournament"]].get("enum_gender"),
                "date": tmeta[r["id_tournament"]].get("dt_tournament"),
                "id_tournament": r.get("id_tournament"),
            }
            for r in rows
        ]

    def fetch_event_tournaments(self, id_event: int) -> list[dict]:
        """Return an event's committed tournaments (id + weapon/gender/V-cat).

        ADR-072 (Step C) — RECOMPUTE_DOMESTIC uses this to detect brackets that
        a birth-year relocation has *emptied*: a tournament present here but not
        rewritten by the re-partition must be cleared (`clear_tournament_results`).
        """
        resp = (
            self._sb.table("tbl_tournament")
            .select("id_tournament,enum_weapon,enum_gender,enum_age_category")
            .eq("id_event", id_event)
            .execute()
        )
        return list(resp.data or [])

    def clear_tournament_results(self, tournament_id: int) -> None:
        """Empty a tournament that a recompute relocation left with no fencers:
        delete its results (+ legacy match_candidate rows) and zero its count.
        Idempotent — a bracket with no results ranks nothing (ADR-072 drop)."""
        rids = [
            r["id_result"]
            for r in self._sb.table("tbl_result")
            .select("id_result")
            .eq("id_tournament", tournament_id)
            .execute()
            .data
            or []
        ]
        if rids:
            self._sb.table("tbl_match_candidate").delete().in_("id_result", rids).execute()
        self._sb.table("tbl_result").delete().eq("id_tournament", tournament_id).execute()
        self._sb.table("tbl_tournament").update({"int_participant_count": 0}).eq(
            "id_tournament", tournament_id
        ).execute()

    # -- CDC recompute queue + dedup (ADR-071 / ADR-072) --------------------

    def merge_fencers(self, survivor_id: int, duplicate_id: int) -> None:
        """ADR-071 — merge a duplicate into the survivor (re-point results + fold
        aliases + enqueue both sides). Thin wrapper over fn_merge_fencers."""
        self._sb.rpc(
            "fn_merge_fencers", {"p_survivor": survivor_id, "p_duplicate": duplicate_id}
        ).execute()

    def enqueue_affected_events(self, id_fencer: int) -> int:
        """Enqueue every event a fencer participated in (fn_enqueue_affected_events)."""
        resp = self._sb.rpc("fn_enqueue_affected_events", {"p_id_fencer": id_fencer}).execute()
        return resp.data if isinstance(resp.data, int) else 0

    def recompute_watermark(self):
        """Return ts_last_master_change (the debounce watermark), or None."""
        resp = (
            self._sb.table("tbl_recompute_watermark")
            .select("ts_last_master_change")
            .limit(1)
            .execute()
        )
        rows = resp.data or []
        return rows[0]["ts_last_master_change"] if rows else None

    def claim_recompute_batch(self) -> list[int]:
        """Claim recompute events (-> CLAIMED) and return their distinct id_events.

        Claims every row that is not yet DONE — both PENDING (newly enqueued) and
        CLAIMED. A row can only still be CLAIMED at the *start* of a drain if a
        previous worker died mid-run: CERT drains are serialised (the
        `recompute-drain` workflow's `cert-recompute` concurrency group runs one at
        a time, and the worker debounces 120s), so no live worker owns a CLAIMED
        row when a new drain begins. Reclaiming it is therefore deterministic crash
        recovery — no time-based heuristic.

        Both states are flipped to CLAIMED in one step (never back to PENDING), so a
        freshly-enqueued PENDING row coexisting with an orphaned CLAIMED row for the
        same event can't violate the one-PENDING-per-event partial unique index.
        Recompute is idempotent, so the queue converges to DONE.
        """
        not_done = ["PENDING", "CLAIMED"]
        rows = (
            self._sb.table("tbl_recompute_queue")
            .select("id_event")
            .in_("enum_status", not_done)
            .execute()
        )
        ids = sorted({r["id_event"] for r in (rows.data or [])})
        if ids:
            self._sb.table("tbl_recompute_queue").update(
                {"enum_status": "CLAIMED", "ts_claimed": "now()"}
            ).in_("enum_status", not_done).in_("id_event", ids).execute()
        return ids

    def mark_recompute_done(self, id_events: list[int]) -> None:
        """Flip claimed rows for these events to DONE."""
        if not id_events:
            return
        self._sb.table("tbl_recompute_queue").update({"enum_status": "DONE"}).eq(
            "enum_status", "CLAIMED"
        ).in_("id_event", id_events).execute()

    def find_seasons_containing_dates(self, event_dt_start: str, event_dt_end: str) -> list[dict]:
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
        self,
        birth_years: list[int],
        season_end_year: int,
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
        self,
        event_id: int,
        weapon: str,
        gender: str,
        category: str,
        date: str,
        tournament_type: str,
        url_results: str | None = None,
    ) -> int:
        """Find or create tournament under event (ADR-025).

        `url_results` (N14, ADR-073): when supplied (a web source's results page,
        gated in the Commit plugin) it is persisted/overwritten on the tournament;
        NULL preserves the existing value (admin/non-web URLs never wiped).

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
                "p_url_results": url_results,
            },
        ).execute()
        return resp.data

    def find_tournament(self, weapon: str, gender: str, category: str, date: str) -> dict | None:
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

    def ingest_results(
        self, tournament_id: int, results_json: list[dict], participant_count: int | None = None
    ) -> dict:
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
        resp = self._sb.table("tbl_fencer").insert(fencer_dict).execute()
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
        resp = self._sb.rpc("fn_pew_recompute_event_code", {"p_id_event": id_event}).execute()
        # RPC returns INT scalar
        return int(resp.data) if resp.data is not None else 0

    def event_results_for_parity(self, id_event: int) -> list[dict]:
        """Return POL fencer rows shaped for the parity gate's `local_results`."""
        resp = self._sb.rpc("fn_event_results_for_parity", {"p_id_event": id_event}).execute()
        return resp.data or []

    def promote_evf_published(self, id_event: int, evf_scores: list[dict]) -> dict:
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


def get_min_participants(db: DbConnector, id_season: int, tourn_type: str | None) -> int:
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
        db._sb.table("tbl_scoring_config").select(column).eq("id_season", id_season).execute().data
    ) or []
    if not rows:
        return 1
    val = rows[0].get(column)
    return int(val) if val is not None else 1


def derive_tourn_type_from_event_code(event_code: str) -> str | None:
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
        suffix = rest[len(head) :]
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
    db: DbConnector,
    id_season: int,
    tourn_type: str | None,
    n_results: int,
) -> tuple[bool, str | None]:
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
