"""Tests for the EVF-sync self-healing fallback (ADR-039 rev 2).

Plan test IDs:
  evf.47  _heal_future_completed heals a future-COMPLETED row from its event
          URL — UPDATEs dt_start/dt_end + populates url_event; no status flip.
  evf.48  When no date is recoverable, _heal_future_completed issues NO date
          UPDATE and instead demotes the row's status.
  evf.49  The status demotion bypasses the lifecycle trigger
          (DISABLE TRIGGER … UPDATE enum_status='PLANNED' … ENABLE TRIGGER).
"""

from unittest.mock import patch

import python.scrapers.evf_sync as evf_sync


class _DummyClient:
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def _violator(url_event=None):
    return {
        "id_event": 82, "txt_code": "PEW63e-2025-2026",
        "dt_start": "2026-10-01", "dt_end": "2026-10-01",
        "enum_status": "COMPLETED", "txt_country": None,
        "txt_location": None, "url_event": url_event,
    }


def _run_heal(existing, cal_events, fetch_meta_return):
    """Run _heal_future_completed with DB + FTL mocked; return the SQL log."""
    sql_log: list[str] = []

    def fake_query(ref, token, sql):
        sql_log.append(sql)
        return []  # no FTL tournament rows; keeps branch (c) empty

    with patch.object(evf_sync, "_management_query", side_effect=fake_query), \
         patch.object(evf_sync, "get_authed_ftl_client", return_value=_DummyClient()), \
         patch.object(evf_sync, "fetch_ftl_event_metadata", return_value=fetch_meta_return), \
         patch.object(evf_sync, "_telegram"):
        evf_sync._heal_future_completed(
            "ref", "tok", existing, cal_events, "bot", "chat", dry_run=False,
        )
    return sql_log


class TestSelfHealOrchestration:
    def test_heals_date_from_event_url(self):
        """evf.47: a row carrying url_event is healed from the FTL eventSchedule
        page — dt UPDATE includes the date and populates url_event; no flip."""
        url = ("https://www.fencingtimelive.com/tournaments/eventSchedule/"
               "E2A7B077F2824DD8A7F2E413B4211296")
        sql = _run_heal([_violator(url_event=url)], [],
                        fetch_meta_return={"date": "2026-01-10"})
        updates = [s for s in sql if s.strip().startswith("UPDATE tbl_event")]
        assert any("2026-01-10" in s and "url_event" in s and "id_event = 82" in s
                   for s in updates), "dt + url_event populated on the event row"
        assert not any("DISABLE TRIGGER" in s for s in sql), "no status flip when healed"

    def test_status_flip_when_no_date(self):
        """evf.48: no url_event, no calendar match, no FTL date → no dt UPDATE,
        a status demotion instead."""
        sql = _run_heal([_violator(url_event=None)], [], fetch_meta_return=None)
        assert not any(s.strip().startswith("UPDATE tbl_event SET dt_start") for s in sql), \
            "no date UPDATE when nothing recovered"
        assert any("enum_status = 'PLANNED'" in s for s in sql), "row demoted to PLANNED"

    def test_status_flip_bypasses_lifecycle_trigger(self):
        """evf.49: the demotion disables trg_event_transition around the UPDATE
        (COMPLETED is terminal in fn_validate_event_transition)."""
        sql = _run_heal([_violator(url_event=None)], [], fetch_meta_return=None)
        flip = [s for s in sql if "enum_status = 'PLANNED'" in s][0]
        assert "DISABLE TRIGGER trg_event_transition" in flip
        assert "ENABLE TRIGGER trg_event_transition" in flip
        assert "id_event = 82" in flip and "enum_status = 'COMPLETED'" in flip
