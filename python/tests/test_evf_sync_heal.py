"""Tests for the EVF-sync self-healing fallback (ADR-070).

Plan test IDs:
  evf.47  _heal_future_completed rewrites a bogus future-COMPLETED date from
          the authoritative FTL results page and reports zero remaining.
  evf.48  _heal_future_completed returns the violator unchanged (no UPDATE)
          when FTL yields no usable date — the caller then halts.
"""

from unittest.mock import patch

import python.scrapers.evf_sync as evf_sync


def _existing_with_violator():
    """Roster with one future-COMPLETED row (PEW63e) plus a clean row."""
    return [
        {"id_event": 80, "txt_code": "PEW63e-2025-2026",
         "dt_start": "2026-10-01", "enum_status": "COMPLETED"},
        {"id_event": 5, "txt_code": "PEW4efs-2025-2026",
         "dt_start": "2026-03-07", "enum_status": "COMPLETED"},
    ]


class TestSelfHealOrchestration:
    def test_heals_and_applies_update(self):
        """evf.47: a recoverable FTL date triggers UPDATEs on tbl_event +
        tbl_tournament and leaves no un-healable violator."""
        sql_log: list[str] = []

        def fake_query(ref, token, sql):
            sql_log.append(sql)
            # The url_results lookup for the violator returns one FTL bracket.
            if "url_results FROM tbl_tournament" in sql:
                return [{"url_results":
                         "https://www.fencingtimelive.com/events/results/"
                         "220C587A8C854C6C85EB62D26D62F6C9"}]
            return []

        class _DummyClient:
            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

        with patch.object(evf_sync, "_management_query", side_effect=fake_query), \
             patch.object(evf_sync, "get_authed_ftl_client",
                          return_value=_DummyClient()), \
             patch.object(evf_sync, "fetch_ftl_event_metadata",
                          return_value={"date": "2026-01-10"}), \
             patch.object(evf_sync, "_telegram"):
            remaining = evf_sync._heal_future_completed(
                "ref", "tok", _existing_with_violator(),
                "bot", "chat", dry_run=False,
            )

        assert remaining == [], "the violator was healed"
        updates = [s for s in sql_log if s.startswith("UPDATE")]
        assert any("UPDATE tbl_event" in s and "2026-01-10" in s
                   and "id_event = 80" in s for s in updates)
        assert any("UPDATE tbl_tournament" in s and "id_event = 80" in s
                   for s in updates)

    def test_unhealable_leaves_violator_and_no_update(self):
        """evf.48: FTL yields nothing usable → no UPDATE, violator returned."""
        sql_log: list[str] = []

        def fake_query(ref, token, sql):
            sql_log.append(sql)
            if "url_results FROM tbl_tournament" in sql:
                return [{"url_results":
                         "https://www.fencingtimelive.com/events/results/DEADBEEF"}]
            return []

        class _DummyClient:
            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

        with patch.object(evf_sync, "_management_query", side_effect=fake_query), \
             patch.object(evf_sync, "get_authed_ftl_client",
                          return_value=_DummyClient()), \
             patch.object(evf_sync, "fetch_ftl_event_metadata",
                          return_value=None), \
             patch.object(evf_sync, "_telegram"):
            remaining = evf_sync._heal_future_completed(
                "ref", "tok", _existing_with_violator(),
                "bot", "chat", dry_run=False,
            )

        assert [r["txt_code"] for r in remaining] == ["PEW63e-2025-2026"]
        assert not [s for s in sql_log if s.startswith("UPDATE")], \
            "no UPDATE may run when the date can't be recovered"
