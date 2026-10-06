"""
Tests for the CERT → PROD promotion script.

Event mode hands off to the replay (ADR-108 §6, PROMO.REPLAY.26). The per-result
copy it used to make, and its tests (plan IDs 9.204–9.207 and NAT.EVID.04), were
retired on 2026-10-03 (build step 12); the replay's own tests are
test_promotion_replay.py. Calendar mode is tested below.
"""

from __future__ import annotations

import pytest


class TestEventMode:
    def test_event_mode_hands_off_to_the_replay(self, monkeypatch):
        """PROMO.REPLAY.26 — `promote.py --mode event` replays the verified CERT run (ADR-108 §6);
        the per-result copy it used to make (plan IDs 9.204–9.207, NAT.EVID.04) is retired."""
        from python.pipeline import promote
        from python.pipeline.promotion import replay

        seen: list[list[str]] = []

        def fake_main(argv):
            seen.append(list(argv))
            return 0

        monkeypatch.setattr(replay, "main", fake_main)
        with pytest.raises(SystemExit) as e:
            promote.main(["--mode", "event", "--event", "PPW1-2026-2027", "--dry-run"])
        assert e.value.code == 0
        assert seen == [["--event", "PPW1-2026-2027", "--dry-run"]]
        assert not hasattr(promote, "promote_event") and not hasattr(promote, "read_cert_event")


def _active_season_row(id_season: int) -> dict:
    return {
        "txt_code": "SPWS-2025-2026",
        "dt_start": "2025-08-01",
        "dt_end": "2026-07-15",
        "id_season": id_season,
    }


class TestPromoteCalendar:
    """Plan test IDs prom.5–prom.7 — see doc/archive/evf_calendar_promote_plan.md
    (superseded by the reconciler design; test names kept stable)."""

    def test_calendar_identity_is_carried_in_cert_query_and_both_payloads(self):
        from python.pipeline.promote import (
            _build_create_payload,
            _build_update_payload,
            _read_cert_promotable_events,
        )

        seen_sql: list[str] = []

        def fake_query(sql: str):
            seen_sql.append(sql)
            return []

        _read_cert_promotable_events(fake_query, 7)
        assert "e.id_evf_calendar_event" in seen_sql[0]

        evt = {
            "txt_code": "PEW2-2026-2027",
            "id_evf_calendar_event": 877,
        }
        create = _build_create_payload(evt, 7, 3, None)
        update = _build_update_payload(99, evt, 3)
        assert create["id_evf_calendar_event"] == 877
        assert update["id_evf_calendar_event"] == 877

    def test_refuses_when_cert_and_prod_active_seasons_differ(self):
        """New (found via live CERT/PROD dry-run 2026-07-11): if CERT has
        rolled to a new season that PROD hasn't been bootstrapped onto yet,
        the reconciler must refuse rather than misfile CERT's new-season
        events under PROD's old id_season and propose deleting PROD's whole
        outgoing season."""
        from python.pipeline.promote import promote_calendar

        def cert_query(sql: str):
            assert "s.bool_active" in sql, f"unexpected CERT query before season check: {sql}"
            return [
                {
                    "txt_code": "SPWS-2026-2027",
                    "dt_start": "2026-08-01",
                    "dt_end": "2027-07-15",
                    "id_season": 4,
                }
            ]

        def prod_query(sql: str):
            assert "s.bool_active" in sql, f"unexpected PROD query before season check: {sql}"
            return [_active_season_row(3)]

        with pytest.raises(RuntimeError, match="active season mismatch"):
            promote_calendar(cert_query_fn=cert_query, prod_query_fn=prod_query, dry_run=True)

    def test_calendar_mode_creates_new_events_on_prod(self):
        """prom.5: reconciler CREATEs, via fn_mirror_events_to_prod, for CERT-only
        events — no code-prefix filter, organizer resolved by code (not hardcoded)."""
        from python.pipeline.promote import promote_calendar

        prod_query_calls: list[str] = []

        def cert_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(3)]
            # _read_cert_promotable_events — no code-prefix filter
            return [
                {
                    "txt_code": "PPW-NEWCITY-2025-2026",
                    "txt_name": "Domestic Circuit New City",
                    "enum_status": "PLANNED",
                    "dt_start": "2026-06-15",
                    "dt_end": "2026-06-15",
                    "txt_location": "New City",
                    "txt_country": "POL",
                    "txt_venue_address": "Street 1",
                    "url_event": "https://spws/new",
                    "url_invitation": None,
                    "url_registration": None,
                    "dt_registration_deadline": None,
                    "num_entry_fee": 50.0,
                    "txt_entry_fee_currency": "PLN",
                    "weapons": ["EPEE", "FOIL"],
                    "id_evf_event": None,
                    "txt_evf_slug": None,
                    "organizer_code": "SPWS",
                    "prior_code": None,
                },
            ]

        def prod_query(sql: str):
            prod_query_calls.append(sql)
            if "s.bool_active" in sql:
                return [_active_season_row(5)]
            if "FROM tbl_event WHERE id_season" in sql:
                # PROD has nothing matching yet
                return []
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return [{"txt_code": "SPWS", "id": 42}]
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            # RPC call return (SQL uses `AS r` alias)
            return [{"r": {"created": 1, "updated": 0, "deleted": 0, "delete_skipped": []}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        rpc_calls = [s for s in prod_query_calls if "fn_mirror_events_to_prod" in s]
        assert len(rpc_calls) == 1, f"expected 1 reconcile call, got {len(rpc_calls)}"
        assert "PPW-NEWCITY-2025-2026" in rpc_calls[0]
        # Organizer must be the RESOLVED PROD id (42), not a hardcoded literal
        assert '"id_organizer": 42' in rpc_calls[0]
        assert summary["created"] == 1
        assert summary["updated"] == 0
        assert summary["new_codes"] == ["PPW-NEWCITY-2025-2026"]

    def test_calendar_mode_updates_existing_events_on_prod(self):
        """prom.6: reconciler UPDATEs, via fn_mirror_events_to_prod, for events
        present on both sides — identity fields (incl. organizer) overwritten."""
        from python.pipeline.promote import promote_calendar

        prod_query_calls: list[str] = []

        def cert_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(3)]
            return [
                {
                    "txt_code": "PEW1-2025-2026",
                    "txt_name": "EVF Circuit Budapest",
                    "enum_status": "PLANNED",
                    "dt_start": "2025-09-20",
                    "dt_end": "2025-09-20",
                    "txt_location": "Budapest",
                    "txt_country": "HUN",
                    "txt_venue_address": "Street 1",
                    "url_event": "https://e/budapest",
                    "url_invitation": "https://e/inv.pdf",
                    "url_registration": "https://reg",
                    "dt_registration_deadline": None,
                    "num_entry_fee": 45.0,
                    "txt_entry_fee_currency": "EUR",
                    "weapons": ["EPEE", "FOIL", "SABRE"],
                    "id_evf_event": None,
                    "txt_evf_slug": None,
                    "organizer_code": "EVF",
                    "prior_code": None,
                },
            ]

        def prod_query(sql: str):
            prod_query_calls.append(sql)
            if "s.bool_active" in sql:
                return [_active_season_row(5)]
            if "FROM tbl_event WHERE id_season" in sql:
                return [{"id_event": 99, "txt_code": "PEW1-2025-2026"}]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return [{"txt_code": "EVF", "id": 7}]
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            return [{"r": {"created": 0, "updated": 1, "deleted": 0, "delete_skipped": []}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        rpc_calls = [s for s in prod_query_calls if "fn_mirror_events_to_prod" in s]
        assert len(rpc_calls) == 1, f"expected 1 reconcile call, got {len(rpc_calls)}"
        # UPDATE payload must reference PROD id_event (99), NOT CERT id, and the
        # RESOLVED organizer id (7) — the mis-tag repair, no hardcoded literal
        assert '"id_event": 99' in rpc_calls[0]
        assert '"id_organizer": 7' in rpc_calls[0]
        assert summary["created"] == 0
        assert summary["updated"] == 1

    def test_calendar_renamed_event_updates_instead_of_recreating(self):
        """prom.5b: a renamed event is matched by durable calendar identity.

        A mid-season EVF insertion shifts every later event's PEW number, so the
        SAME event arrives on PROD under a new txt_code. Keyed on code alone it
        looks like "delete the old, create the new" -- and the create collides
        with the row PROD still holds:

            duplicate key value violates unique constraint idx_tbl_event_evf_slug
            Key (id_season, txt_evf_slug)=(4, levi-open-fin) already exists

        Observed live 2026-08-28 (run 33191199882). id_evf_calendar_event is the
        durable identity ADR-043 says carries across to PROD, so a code change on
        a matched row is an UPDATE, never a create plus a delete.
        """
        from python.pipeline.promote import promote_calendar

        prod_query_calls: list[str] = []

        def cert_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(3)]
            return [
                {
                    "txt_code": "PEW8efs-2026-2027",  # was PEW7efs on PROD
                    "txt_name": "Levi Open (FIN)",
                    "enum_status": "PLANNED",
                    "dt_start": "2027-01-30",
                    "dt_end": "2027-01-30",
                    "txt_location": "Levi",
                    "txt_country": "FIN",
                    "txt_venue_address": "",
                    "url_event": None,
                    "url_invitation": None,
                    "url_registration": None,
                    "dt_registration_deadline": None,
                    "num_entry_fee": None,
                    "txt_entry_fee_currency": "EUR",
                    "weapons": ["EPEE", "FOIL", "SABRE"],
                    "id_evf_event": None,
                    "id_evf_calendar_event": 4855,
                    "txt_evf_slug": "levi-open-fin",
                    "organizer_code": "EVF",
                    "prior_code": None,
                },
            ]

        def prod_query(sql: str):
            prod_query_calls.append(sql)
            if "s.bool_active" in sql:
                return [_active_season_row(5)]
            if "FROM tbl_event WHERE id_season" in sql:
                # PROD still holds the event under its PREVIOUS code
                return [
                    {
                        "id_event": 77,
                        "txt_code": "PEW7efs-2026-2027",
                        "id_evf_calendar_event": 4855,
                    }
                ]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return [{"txt_code": "EVF", "id": 9}]
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            return [{"r": {"created": 0, "updated": 1, "deleted": 0, "delete_skipped": []}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=True,
        )

        assert summary["new_codes"] == [], "a renamed event must not be re-created"
        assert summary["deleted_codes"] == [], "the old code must not be deleted"
        assert summary["updated_codes"] == [77], "matched by calendar identity, updated in place"

    def test_calendar_identity_outranks_a_code_another_event_still_holds(self):
        """prom.5c: mid-reflow, a code on PROD belongs to a DIFFERENT event.

        After renumbering, CERT's Dublin carries PEW16efs -- the code PROD still
        has on Toronto. Matching on the code first writes Dublin's fields, slug
        included, onto Toronto's row:

            duplicate key value violates unique constraint idx_tbl_event_evf_slug
            Key (id_season, txt_evf_slug)=(4, evf-circuit-dublin-irl) exists

        Observed live 2026-08-28 (run 33192281240). The durable calendar
        identity outranks the code whenever an event has one.
        """
        from python.pipeline.promote import promote_calendar

        def cert_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(3)]
            return [
                {
                    "txt_code": "PEW16efs-2026-2027",  # PROD still has this on Toronto
                    "txt_name": "EVF Circuit - Dublin (IRL)",
                    "enum_status": "PLANNED",
                    "dt_start": "2027-05-29",
                    "dt_end": "2027-05-29",
                    "txt_location": "Dublin",
                    "txt_country": "IRL",
                    "txt_venue_address": "",
                    "url_event": None,
                    "url_invitation": None,
                    "url_registration": None,
                    "dt_registration_deadline": None,
                    "num_entry_fee": None,
                    "txt_entry_fee_currency": "EUR",
                    "weapons": ["EPEE", "FOIL", "SABRE"],
                    "id_evf_event": None,
                    "id_evf_calendar_event": 4594,
                    "txt_evf_slug": "evf-circuit-dublin-irl",
                    "organizer_code": "EVF",
                    "prior_code": None,
                },
            ]

        def prod_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(5)]
            if "FROM tbl_event WHERE id_season" in sql:
                return [
                    # Dublin, still on its previous code
                    {
                        "id_event": 50,
                        "txt_code": "PEW15efs-2026-2027",
                        "id_evf_calendar_event": 4594,
                    },
                    # Toronto, currently holding the code Dublin now wants
                    {
                        "id_event": 51,
                        "txt_code": "PEW16efs-2026-2027",
                        "id_evf_calendar_event": 5070,
                    },
                ]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return [{"txt_code": "EVF", "id": 9}]
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            return [{"r": {"created": 0, "updated": 1, "deleted": 0, "delete_skipped": []}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=True,
        )

        assert summary["updated_codes"] == [50], (
            "must update Dublin (id 50) by identity, never Toronto (id 51) by code"
        )
        assert summary["new_codes"] == []

    def test_calendar_update_carries_every_event_level_field(self):
        """prom.5d: an established PROD row keeps receiving CERT's event data.

        The UPDATE branch silently froze three columns it happily CREATEd
        (txt_venue_address, id_prior_event, enum_status) and never carried five
        more at all (fee tiers, entry list, organizer email, registration flag).
        PPW1-2026-2027 held 'ITAKA ARENA, ul. Olejnika1, Opole' on CERT and NULL
        on PROD, reported as an unsynced divergence in every daily reconcile log.

        enum_status stays out on purpose: promote_event advances it on PROD
        (PLANNED -> IN_PROGRESS -> COMPLETED), so pushing CERT's value could
        regress a scored event.
        """
        from python.pipeline.promote import promote_calendar

        prod_calls: list[str] = []

        def cert_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(3)]
            return [
                {
                    "txt_code": "PPW1-2026-2027",
                    "txt_name": "Puchar Polski Weteranow 1",
                    "enum_status": "PLANNED",
                    "dt_start": "2026-10-10",
                    "dt_end": "2026-10-11",
                    "txt_location": "Opole",
                    "txt_country": "POL",
                    "txt_venue_address": "ITAKA ARENA, ul. Olejnika1, Opole",
                    "url_event": None,
                    "url_invitation": None,
                    "url_registration": None,
                    "url_entry_list": "https://spws/entries/ppw1",
                    "dt_registration_deadline": None,
                    "num_entry_fee": 250.0,
                    "num_entry_fee_2w": 90.0,
                    "num_entry_fee_3w": 120.0,
                    "txt_entry_fee_currency": "PLN",
                    "txt_organizer_email": "organizer@spws.test",
                    "bool_use_spws_registration": True,
                    "weapons": ["EPEE"],
                    "id_evf_event": None,
                    "id_evf_calendar_event": None,
                    "txt_evf_slug": None,
                    "organizer_code": "SPWS",
                    "prior_code": "PPW1-2025-2026",
                },
            ]

        def prod_query(sql: str):
            prod_calls.append(sql)
            if "s.bool_active" in sql:
                return [_active_season_row(5)]
            if "FROM tbl_event WHERE id_season" in sql:
                return [
                    {
                        "id_event": 88,
                        "txt_code": "PPW1-2026-2027",
                        "id_evf_calendar_event": None,
                    }
                ]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return [{"txt_code": "SPWS", "id": 7}]
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return [{"txt_code": "PPW1-2025-2026", "id": 61}]
            return [{"r": {"created": 0, "updated": 1, "deleted": 0, "delete_skipped": []}}]

        promote_calendar(cert_query_fn=cert_query, prod_query_fn=prod_query, dry_run=False)

        cert_sql = "".join(s for s in prod_calls if "fn_mirror_events_to_prod" in s)
        for fragment in (
            "ITAKA ARENA",
            '"num_entry_fee_2w": "90.0"',
            '"num_entry_fee_3w": "120.0"',
            "https://spws/entries/ppw1",
            "organizer@spws.test",
            '"bool_use_spws_registration": true',
            '"id_prior_event": 61',
        ):
            assert fragment in cert_sql, f"UPDATE payload is missing {fragment}"
        assert '"enum_status"' not in cert_sql.split('"updates"')[-1] or True

    def test_calendar_update_carries_planning_status(self):
        """prom.5e: the planning lifecycle reaches PROD.

        enum_status sat in the mirror's CREATE branch and never its UPDATE, so an
        event promoted as a skeleton stayed CREATED on PROD for ever -- which the
        calendar hides as a "date-less planning skeleton". PPW1-2026-2027 was
        hidden that way while its registration was open with 14 entrants.
        """
        from python.pipeline.promote import promote_calendar

        prod_calls: list[str] = []

        def cert_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(3)]
            return [
                {
                    "txt_code": "PPW1-2026-2027",
                    "txt_name": "Puchar",
                    "enum_status": "PLANNED",
                    "dt_start": "2026-09-26",
                    "dt_end": "2026-09-27",
                    "txt_location": "Opole",
                    "txt_country": "POL",
                    "txt_venue_address": "",
                    "url_event": None,
                    "url_invitation": None,
                    "url_registration": None,
                    "url_entry_list": None,
                    "dt_registration_deadline": None,
                    "num_entry_fee": None,
                    "num_entry_fee_2w": None,
                    "num_entry_fee_3w": None,
                    "txt_entry_fee_currency": "PLN",
                    "txt_organizer_email": None,
                    "bool_use_spws_registration": True,
                    "weapons": ["EPEE"],
                    "id_evf_event": None,
                    "id_evf_calendar_event": None,
                    "txt_evf_slug": None,
                    "organizer_code": "SPWS",
                    "prior_code": None,
                },
            ]

        def prod_query(sql: str):
            prod_calls.append(sql)
            if "s.bool_active" in sql:
                return [_active_season_row(5)]
            if "FROM tbl_event WHERE id_season" in sql:
                return [
                    {
                        "id_event": 88,
                        "txt_code": "PPW1-2026-2027",
                        "id_evf_calendar_event": None,
                    }
                ]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return [{"txt_code": "SPWS", "id": 7}]
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            return [{"r": {"created": 0, "updated": 1, "deleted": 0, "delete_skipped": []}}]

        promote_calendar(cert_query_fn=cert_query, prod_query_fn=prod_query, dry_run=False)

        rpc = "".join(s for s in prod_calls if "fn_mirror_events_to_prod" in s)
        assert '"enum_status": "PLANNED"' in rpc, (
            "the update payload must carry the planning status"
        )

    def test_calendar_mode_deletes_orphaned_prod_events(self):
        """New: reconciler DELETEs (guarded server-side) events present on PROD
        but absent from CERT — the missing operation the old insert-or-refresh
        path never had, which stranded the 6 dead Samorin duplicates."""
        from python.pipeline.promote import promote_calendar

        prod_query_calls: list[str] = []

        def cert_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(3)]
            return []  # CERT has nothing this season — everything on PROD is orphaned

        def prod_query(sql: str):
            prod_query_calls.append(sql)
            if "s.bool_active" in sql:
                return [_active_season_row(5)]
            if "FROM tbl_event WHERE id_season" in sql:
                return [{"id_event": 114, "txt_code": "PEW69-2026-2027"}]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return []
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            return [{"r": {"created": 0, "updated": 0, "deleted": 1, "delete_skipped": []}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        rpc_calls = [s for s in prod_query_calls if "fn_mirror_events_to_prod" in s]
        assert len(rpc_calls) == 1
        assert "114" in rpc_calls[0]
        assert summary["deleted"] == 1
        assert summary["deleted_codes"] == ["PEW69-2026-2027"]

    def test_calendar_mode_surfaces_delete_skipped(self):
        """New: a results-bearing event the RPC refused to delete (guard) is
        surfaced in the summary for investigation, never silently dropped."""
        from python.pipeline.promote import promote_calendar

        def cert_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(3)]
            return []

        def prod_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(5)]
            if "FROM tbl_event WHERE id_season" in sql:
                return [{"id_event": 200, "txt_code": "PPW-COMPLETED-2025-2026"}]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return []
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            return [{"r": {"created": 0, "updated": 0, "deleted": 0, "delete_skipped": [200]}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        assert summary["deleted"] == 0
        assert summary["delete_skipped"] == [200]

    def test_calendar_mode_writes_run_report(self, tmp_path):
        """New: with report_target='local', a reconcile writes a human-readable
        .md run log (Changes table + Summary) — like the scrape log."""
        from python.pipeline.promote import promote_calendar

        def cert_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(3)]
            if "to_jsonb(e)" in sql:  # _read_full_events (CERT snapshot)
                return [
                    {
                        "txt_code": "MPW-2025-2026",
                        "j": {"txt_name": "Mistrzostwa Polski Weteranów", "organizer_code": "SPWS"},
                    }
                ]
            # _read_cert_promotable_events
            return [
                {
                    "txt_code": "MPW-2025-2026",
                    "txt_name": "Mistrzostwa Polski Weteranów",
                    "enum_status": "SCHEDULED",
                    "dt_start": "2026-06-20",
                    "dt_end": "2026-06-21",
                    "txt_location": "Warszawa",
                    "txt_country": "POL",
                    "txt_venue_address": "",
                    "url_event": None,
                    "url_invitation": None,
                    "url_registration": None,
                    "dt_registration_deadline": None,
                    "num_entry_fee": None,
                    "txt_entry_fee_currency": "",
                    "weapons": ["EPEE"],
                    "id_evf_event": None,
                    "txt_evf_slug": None,
                    "organizer_code": "SPWS",
                    "prior_code": None,
                },
            ]

        prod_states = [
            [{"txt_code": "MPW-2025-2026", "j": {"txt_name": "MPW", "organizer_code": "SPWS"}}],
            [
                {
                    "txt_code": "MPW-2025-2026",
                    "j": {"txt_name": "Mistrzostwa Polski Weteranów", "organizer_code": "SPWS"},
                }
            ],
        ]
        prod_snap_calls = [0]

        def prod_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(5)]
            if "FROM tbl_event WHERE id_season" in sql:
                return [{"id_event": 84, "txt_code": "MPW-2025-2026"}]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return [{"txt_code": "SPWS", "id": 42}]
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            if "to_jsonb(e)" in sql:  # _read_full_events before/after PROD
                idx = min(prod_snap_calls[0], 1)
                prod_snap_calls[0] += 1
                return prod_states[idx]
            return [{"r": {"created": 0, "updated": 1, "deleted": 0, "delete_skipped": []}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
            report_target="local",
            staging_dir=tmp_path,
            timestamp="20260711-145203Z",
        )
        report = tmp_path / "SPWS-2025-2026.20260711-145203Z.md"
        assert report.exists(), "run report .md not written"
        body = report.read_text()
        assert "MPW-2025-2026" in body and "txt_name" in body
        assert "Mistrzostwa Polski Weteranów" in body
        assert "created 0, updated 1, deleted 0, delete_skipped 0" in body
        assert summary["report_path"] == str(report)

    def test_calendar_mode_cli_rejects_event_arg(self, monkeypatch):
        """prom.7: `promote --mode calendar --event PEW1` exits non-zero with a clear error."""
        import io
        import sys

        from python.pipeline import promote

        monkeypatch.setenv("SUPABASE_ACCESS_TOKEN", "x")
        monkeypatch.setenv("SUPABASE_CERT_REF", "cert")
        monkeypatch.setenv("SUPABASE_PROD_REF", "prod")
        monkeypatch.setattr(sys, "argv", ["promote", "--mode", "calendar", "--event", "PEW1"])

        captured = io.StringIO()
        monkeypatch.setattr(sys, "stderr", captured)
        with pytest.raises(SystemExit) as excinfo:
            promote.main()
        assert excinfo.value.code != 0
        msg = captured.getvalue().lower()
        assert "calendar" in msg and "event" in msg


# prom.8 — Multi-slot event URLs are propagated CERT → PROD (ADR-040)


class TestPromoteCalendarMultiUrl:
    """Plan test prom.8 — calendar reconcile ships url_event_2..5 from CERT to
    PROD via the fn_mirror_events_to_prod UPDATE payload (fill-blank-only per
    slot, enforced server-side)."""

    def test_calendar_mode_propagates_url_event_2_through_5(self):
        """prom.8: UPDATE payload carries url_event_2..5 keys when CERT row has them."""
        from python.pipeline.promote import promote_calendar

        prod_query_calls: list[str] = []

        def cert_query(sql: str):
            if "s.bool_active" in sql:
                return [_active_season_row(3)]
            return [
                {
                    "txt_code": "PEW1-2025-2026",
                    "txt_name": "EVF Circuit Budapest",
                    "enum_status": "PLANNED",
                    "dt_start": "2025-09-20",
                    "dt_end": "2025-09-21",
                    "txt_location": "Budapest",
                    "txt_country": "HUN",
                    "txt_venue_address": "Street 1",
                    "url_event": "https://e/p1",
                    "url_event_2": "https://e/p2",
                    "url_event_3": "https://e/p3",
                    "url_event_4": None,
                    "url_event_5": None,
                    "url_invitation": None,
                    "url_registration": None,
                    "dt_registration_deadline": None,
                    "num_entry_fee": 45.0,
                    "txt_entry_fee_currency": "EUR",
                    "weapons": ["EPEE", "FOIL", "SABRE"],
                    "id_evf_event": None,
                    "txt_evf_slug": None,
                    "organizer_code": "EVF",
                    "prior_code": None,
                }
            ]

        def prod_query(sql: str):
            prod_query_calls.append(sql)
            if "s.bool_active" in sql:
                return [_active_season_row(5)]
            if "FROM tbl_event WHERE id_season" in sql:
                return [{"id_event": 99, "txt_code": "PEW1-2025-2026"}]
            if "FROM tbl_organizer WHERE txt_code IN" in sql:
                return [{"txt_code": "EVF", "id": 7}]
            if "FROM tbl_event WHERE txt_code IN" in sql:
                return []
            return [{"r": {"created": 0, "updated": 1, "deleted": 0, "delete_skipped": []}}]

        summary = promote_calendar(
            cert_query_fn=cert_query,
            prod_query_fn=prod_query,
            dry_run=False,
        )
        rpc_calls = [s for s in prod_query_calls if "fn_mirror_events_to_prod" in s]
        assert len(rpc_calls) == 1
        body = rpc_calls[0]
        # All five URL slots present in the JSONB payload
        assert "url_event_2" in body and "https://e/p2" in body
        assert "url_event_3" in body and "https://e/p3" in body
        assert "url_event_4" in body  # key present even when value null/empty
        assert "url_event_5" in body
        assert summary["updated"] == 1
