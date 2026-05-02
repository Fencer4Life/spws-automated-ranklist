"""
Tests for Telegram pipeline notifications.

Plan test IDs 9.173–9.190:
  9.173  success() calls send_telegram_alert with ✅ prefix
  9.174  warning() calls with ⚠️ prefix
  9.175  error() calls with ❌ prefix
  9.176  info() calls with ℹ️ prefix
  9.177  summary() formats multi-line batch summary
  9.178  bot_token=None → no-op (silent mode)
  9.179  notify_import_success produces correct message
  9.180  notify_batch_complete produces correct message
  9.181  notify_files_received produces correct message
  9.182  notify_identity_review produces correct message
  9.183  notify_missing_dob produces correct message
  9.184  notify_duplicate_import produces correct message
  9.185  notify_tournament_not_found produces correct message
  9.186  notify_event_missing_tournament produces correct message
  9.187  notify_unrecognized_xml produces correct message
  9.188  notify_pipeline_failure produces correct message
  9.189  notify_overdue_domestic produces correct message
  9.190  notify_overdue_international produces correct message
"""

from __future__ import annotations

from unittest.mock import patch


class TestCoreNotificationMethods:
    """Tests 9.173–9.178: Core TelegramNotifier methods."""

    def test_success_prefix(self):
        """9.173 success() calls send_telegram_alert with ✅ prefix."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.success("Import done")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert msg.startswith("✅")
            assert "Import done" in msg

    def test_warning_prefix(self):
        """9.174 warning() calls with ⚠️ prefix."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.warning("Check this")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert msg.startswith("⚠️")
            assert "Check this" in msg

    def test_error_prefix(self):
        """9.175 error() calls with ❌ prefix."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.error("Something broke")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert msg.startswith("❌")
            assert "Something broke" in msg

    def test_info_prefix(self):
        """9.176 info() calls with ℹ️ prefix."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.info("FYI")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert msg.startswith("ℹ️")
            assert "FYI" in msg

    def test_summary_formats_multiline(self):
        """9.177 summary() formats multi-line batch summary from IngestResult."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            # Simulate an IngestResult-like object
            result = type("IngestResult", (), {
                "tournament_ids": [1, 2, 3],
                "matched": 25,
                "pending": 3,
                "auto_created": 2,
                "skipped": 1,
                "errors": [],
                "skipped_files": ["RESULTS_GRVETXE.xml"],
            })()
            n.summary(result)
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "3" in msg  # tournaments
            assert "25" in msg  # matched
            assert "3" in msg  # pending
            assert "2" in msg  # auto_created

    def test_silent_mode_noop(self):
        """9.178 bot_token=None → no-op, no call to send_telegram_alert."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier(None, None)
            n.success("Should not send")
            n.warning("Should not send")
            n.error("Should not send")
            n.info("Should not send")
            mock_send.assert_not_called()


class TestRoutineNotifications:
    """Tests 9.179–9.181: Routine notification use cases."""

    def test_notify_import_success(self):
        """9.179 notify_import_success produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_import_success(
                "PPW4.5 Gdańsk: Epee M V2",
                {"matched": 8, "pending": 1, "auto_created": 0},
            )
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "PPW4.5 Gdańsk: Epee M V2" in msg
            assert "8 matched" in msg
            assert "1 pending" in msg

    def test_notify_batch_complete(self):
        """9.180 notify_batch_complete produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_batch_complete(
                file_count=15, skip_count=2, tournament_count=13
            )
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "15" in msg
            assert "2" in msg  # skipped
            assert "13" in msg  # tournaments

    def test_notify_files_received(self):
        """9.181 notify_files_received produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_files_received(
                "Fw: wyniki Gdańsk", file_count=17
            )
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "Fw: wyniki Gdańsk" in msg
            assert "17" in msg


class TestWarningNotifications:
    """Tests 9.182–9.184: Warning notification use cases."""

    def test_notify_identity_review(self):
        """9.182 notify_identity_review produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_identity_review(count=3, event_name="PPW4 Gdańsk")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "3" in msg
            assert "PPW4 Gdańsk" in msg
            assert "identity review" in msg.lower() or "review" in msg.lower()

    def test_notify_missing_dob(self):
        """9.183 notify_missing_dob produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_missing_dob(count=2, filename="RESULTS_VETME_v0v1.xml")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "2" in msg
            assert "v0v1" in msg
            assert "birth" in msg.lower() or "DOB" in msg or "dob" in msg.lower()

    def test_notify_duplicate_import(self):
        """9.184 notify_duplicate_import produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_duplicate_import("Epee M V2 Gdańsk")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "Epee M V2 Gdańsk" in msg
            assert "already imported" in msg.lower() or "re-import" in msg.lower()


class TestAlertNotifications:
    """Tests 9.185–9.188: Alert notification use cases."""

    def test_notify_tournament_not_found(self):
        """9.185 notify_tournament_not_found produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_tournament_not_found(
                weapon="Epee", gender="M", category="V3",
                date="2026-02-21", event_name="Gdańsk",
            )
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "Epee" in msg
            assert "V3" in msg
            assert "2026-02-21" in msg

    def test_notify_event_missing_tournament(self):
        """9.186 notify_event_missing_tournament produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_event_missing_tournament(
                event_name="PPW4 Gdańsk",
                weapon="Foil", gender="F", category="V1",
            )
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "PPW4 Gdańsk" in msg
            assert "Foil" in msg
            assert "V1" in msg

    def test_notify_unrecognized_xml(self):
        """9.187 notify_unrecognized_xml produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_unrecognized_xml("bad_file.xml")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "bad_file.xml" in msg

    def test_notify_pipeline_failure(self):
        """9.188 notify_pipeline_failure produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_pipeline_failure("ConnectionError: Supabase RPC timeout")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "ConnectionError" in msg


class TestOverdueNotifications:
    """Tests 9.189–9.190: Overdue reminder notifications."""

    def test_notify_overdue_domestic(self):
        """9.189 notify_overdue_domestic produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_overdue_domestic(event_name="PPW4 Gdańsk", days=5)
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "PPW4 Gdańsk" in msg
            assert "5" in msg

    def test_notify_overdue_international(self):
        """9.190 notify_overdue_international produces correct message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_overdue_international(event_name="MEW Budapest", days=10)
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "MEW Budapest" in msg
            assert "10" in msg


# ===========================================================================
# Phase 4 (ADR-052, ADR-053) — commit / parity / cascade lifecycle
# ===========================================================================


class TestPhase4Notifications:
    """P4.NT.1 – P4.NT.7: Phase 4 commit-lifecycle templates."""

    def _last_msg(self, mock):
        return mock.call_args[1].get("message") or mock.call_args[0][2]

    def test_notify_event_commit_basic(self):
        """P4.NT.1 notify_event_commit emits combined commit summary."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("t", "c")
            n.notify_event_commit(
                event_code="PPW1-2025-2026",
                summary={"matched": 30, "pending": 1, "auto_created": 0, "skipped": 2},
            )
            msg = self._last_msg(mock_send)
            assert "PPW1-2025-2026" in msg
            assert "30 matched" in msg
            assert "📨" in msg

    def test_notify_event_commit_with_cascade(self):
        """P4.NT.2 cascade rename appears in combined commit message."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("t", "c")
            n.notify_event_commit(
                event_code="PEW3-2025-2026",
                summary={"matched": 50, "pending": 0, "auto_created": 0, "skipped": 0},
                cascade_renamed_to="PEW3ef-2025-2026",
            )
            msg = self._last_msg(mock_send)
            assert "PEW cascade" in msg
            assert "PEW3ef-2025-2026" in msg

    def test_notify_event_commit_with_parity_pass(self):
        """P4.NT.3 parity-pass shows promotion line."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("t", "c")
            n.notify_event_commit(
                event_code="PEW3-2025-2026",
                summary={"matched": 50, "pending": 0, "auto_created": 0, "skipped": 0},
                parity_passed=True,
            )
            msg = self._last_msg(mock_send)
            assert "EVF parity" in msg
            assert "EVF_PUBLISHED" in msg

    def test_notify_evf_parity_fail_lists_all_fencers(self):
        """P4.NT.4 parity-fail enumerates every failing fencer (no truncation)."""
        from dataclasses import dataclass
        from python.pipeline.notifications import TelegramNotifier

        @dataclass
        class _F:
            sub_check: str
            fencer_name: str
            message: str

        fails = [
            _F("score", "Kowalski Adam", "engine=42.0 vs EVF=44.0"),
            _F("placement", "Nowak Jan", "local place=3 vs EVF Pos=2"),
            _F("count", "<count>", "POL count mismatch: local=10, EVF=11"),
        ]
        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("t", "c")
            n.notify_evf_parity_fail(
                event_code="PEW3-2025-2026",
                fail_details=fails,
                parity_notes="3 mismatches",
            )
            msg = self._last_msg(mock_send)
            assert "🚨" in msg
            assert "Kowalski Adam" in msg
            assert "Nowak Jan" in msg
            assert "POL count mismatch" in msg

    def test_notify_evf_promoted(self):
        """P4.NT.5 EVF promotion message names the event + fencer count."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("t", "c")
            n.notify_evf_promoted("PEW3-2025-2026", fencers_overwritten=42)
            msg = self._last_msg(mock_send)
            assert "PEW3-2025-2026" in msg
            assert "42" in msg
            assert "EVF_PUBLISHED" in msg

    def test_notify_stage_halt(self):
        """P4.NT.6 stage halt names the stage + reason."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("t", "c")
            n.notify_stage_halt(
                event_code="PPW1-2025-2026",
                stage="s7_validate",
                reason="URL_DATA_MISMATCH",
                detail="weapon: event=EPEE vs scraped=SABRE",
            )
            msg = self._last_msg(mock_send)
            assert "PPW1-2025-2026" in msg
            assert "s7_validate" in msg
            assert "URL_DATA_MISMATCH" in msg

    def test_notify_parity_sweep_summary(self):
        """P4.NT.7 daily sweep summary shows checked/promoted/failed/empty counts."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("t", "c")
            n.notify_parity_sweep_summary(
                n_checked=12, n_promoted=10, n_failed=1, n_empty=1
            )
            msg = self._last_msg(mock_send)
            assert "checked 12" in msg
            assert "promoted 10" in msg
            assert "failed 1" in msg
            assert "empty 1" in msg

    def test_silent_mode_no_send(self):
        """P4.NT.8 bot_token=None silences the new templates too."""
        from python.pipeline.notifications import TelegramNotifier

        with patch("python.pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier(None, None)
            n.notify_event_commit("X", {"matched": 0, "pending": 0,
                                         "auto_created": 0, "skipped": 0})
            n.notify_evf_promoted("X", 0)
            n.notify_parity_sweep_summary(0, 0, 0, 0)
            n.notify_pew_cascade("X", "Y", 0)
            mock_send.assert_not_called()
