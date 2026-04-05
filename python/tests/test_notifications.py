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
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.success("Import done")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert msg.startswith("✅")
            assert "Import done" in msg

    def test_warning_prefix(self):
        """9.174 warning() calls with ⚠️ prefix."""
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.warning("Check this")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert msg.startswith("⚠️")
            assert "Check this" in msg

    def test_error_prefix(self):
        """9.175 error() calls with ❌ prefix."""
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.error("Something broke")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert msg.startswith("❌")
            assert "Something broke" in msg

    def test_info_prefix(self):
        """9.176 info() calls with ℹ️ prefix."""
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.info("FYI")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert msg.startswith("ℹ️")
            assert "FYI" in msg

    def test_summary_formats_multiline(self):
        """9.177 summary() formats multi-line batch summary from IngestResult."""
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
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
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
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
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
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
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
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
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
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
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_identity_review(count=3, event_name="PPW4 Gdańsk")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "3" in msg
            assert "PPW4 Gdańsk" in msg
            assert "identity review" in msg.lower() or "review" in msg.lower()

    def test_notify_missing_dob(self):
        """9.183 notify_missing_dob produces correct message."""
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_missing_dob(count=2, filename="RESULTS_VETME_v0v1.xml")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "2" in msg
            assert "v0v1" in msg
            assert "birth" in msg.lower() or "DOB" in msg or "dob" in msg.lower()

    def test_notify_duplicate_import(self):
        """9.184 notify_duplicate_import produces correct message."""
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
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
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
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
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
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
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_unrecognized_xml("bad_file.xml")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "bad_file.xml" in msg

    def test_notify_pipeline_failure(self):
        """9.188 notify_pipeline_failure produces correct message."""
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_pipeline_failure("ConnectionError: Supabase RPC timeout")
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "ConnectionError" in msg


class TestOverdueNotifications:
    """Tests 9.189–9.190: Overdue reminder notifications."""

    def test_notify_overdue_domestic(self):
        """9.189 notify_overdue_domestic produces correct message."""
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_overdue_domestic(event_name="PPW4 Gdańsk", days=5)
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "PPW4 Gdańsk" in msg
            assert "5" in msg

    def test_notify_overdue_international(self):
        """9.190 notify_overdue_international produces correct message."""
        from pipeline.notifications import TelegramNotifier

        with patch("pipeline.notifications.send_telegram_alert") as mock_send:
            n = TelegramNotifier("fake-token", "fake-chat")
            n.notify_overdue_international(event_name="MEW Budapest", days=10)
            mock_send.assert_called_once()
            msg = mock_send.call_args[1].get("message") or mock_send.call_args[0][2]
            assert "MEW Budapest" in msg
            assert "10" in msg
