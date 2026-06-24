"""N15 — `ingest <prefix> <url>` Telegram loop: from-URL ingest accepts a url_event
override and sends the staging report(s) to Telegram (reusing ADR-059 send_document /
send_staging_report) + optional Storage persistence.

  N15.1  ingest_event_from_url(url_event_override=U) persists U to tbl_event.url_event
         and ingests from U
  N15.2  send_telegram=True fires the staging Telegram send (full + diff); default off
  N15.3  StagingFormatter honours md_target from svc.config (storage routing)
  N15.4  main() parses --url-event / --send-telegram / --md-target and threads them in

DB + run_flow + FTL client are mocked (contract); the live CERT PPW4 run is the
acceptance. Reuses the test_ingest_cli_flow harness.
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch


def _silent_notifier():
    from python.pipeline.notifications import TelegramNotifier

    return TelegramNotifier(None, None)


class _Resp:
    def __init__(self, text="", js=None):
        self.text = text
        self._js = js or []

    def raise_for_status(self):
        pass

    def json(self):
        return self._js


class _Client:
    """Mock authed FTL client: schedule → one bracket; data → 1 standing; results → DE."""

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def get(self, url):
        if "eventSchedule" in url:
            return _Resp(text="<schedule/>")
        if "/results/data/" in url:
            return _Resp(js=[{"id": "f1", "name": "KOWALSKI Jan", "place": "1", "country": "POL"}])
        return _Resp(text="<li>Tableau</li>")  # results page → has DE


def _event_db():
    db = MagicMock()
    db.find_event_by_code.return_value = {
        "id_event": 4,
        "txt_code": "PPW4-2025-2026",
        "url_event": "https://fencingtimelive.com/tournaments/eventSchedule/OLD",
        "dt_start": "2026-01-10",
    }
    return db


def _patches(seen):
    """Common patch set: authed client, url normalize, schedule discovery, run_flow."""

    def fake_run_flow(p, svc=None, **k):
        seen.append((p, svc))
        return MagicMock(get=lambda *a: {}, faults=[], report=[])

    return [
        patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=_Client()),
        patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
        patch(
            "python.tools.scrape_ftl_event_urls.parse_event_schedule",
            return_value=([{"uuid": "U1", "name": "Szpada Mężczyzn kat. 2"}], []),
        ),
        patch("python.pipeline.run.run_flow", side_effect=fake_run_flow),
    ]


# ---------------------------------------------------------------------------
# N15.1 — url_event override is persisted and used
# ---------------------------------------------------------------------------


class TestUrlEventOverride:
    def test_override_persisted_and_used(self):
        from python.pipeline import ingest_cli

        db = _event_db()
        new_url = "https://fencingtimelive.com/tournaments/eventSchedule/NEW123"
        fetched = []
        client = _Client()
        orig_get = client.get
        client.get = lambda u: (fetched.append(u), orig_get(u))[1]

        seen = []
        ps = _patches(seen)
        ps[0] = patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=client)
        with ps[0], ps[1], ps[2], ps[3]:
            ingest_cli.ingest_event_from_url(
                event_code="PPW4-2025-2026",
                season_end_year=2026,
                db=db,
                notifier=_silent_notifier(),
                url_event_override=new_url,
            )

        # persisted to tbl_event.url_event (admin-managed write)
        db.set_event_url_event.assert_called_once_with(4, new_url)
        # the schedule was fetched from the override, not the stale OLD url
        assert any("NEW123" in u for u in fetched)
        assert not any("/eventSchedule/OLD" in u for u in fetched)


# ---------------------------------------------------------------------------
# N15.2 — staging → Telegram
# ---------------------------------------------------------------------------


class TestStagingToTelegram:
    def test_send_helper_posts_full_and_diff(self):
        """N15.2 the helper sends the full md (send_staging_report) + the diff
        (send_document) from the rendered bytes on the post-commit ctx."""
        from python.pipeline import ingest_cli

        notifier = MagicMock()
        post = MagicMock()
        post.get.side_effect = lambda k, *a: {
            "_rendered_md": "# full report",
            "_rendered_diff": "# diff",
        }.get(k)
        ingest_cli._send_staging_via_telegram(notifier, "PPW4-2025-2026", post, n_tournaments=24)
        notifier.send_staging_report.assert_called_once()
        kw = notifier.send_staging_report.call_args
        assert "PPW4-2025-2026" in (list(kw.args) + list(kw.kwargs.values()))
        notifier.send_document.assert_called_once()
        # the diff document is named per event
        assert "PPW4-2025-2026" in str(notifier.send_document.call_args)

    def test_from_url_fires_send_when_enabled(self):
        from python.pipeline import ingest_cli

        with (
            patch.multiple(
                "python.scrapers.ftl_auth",
                get_authed_ftl_client=MagicMock(return_value=_Client()),
                normalize_ftl_url=lambda u: u,
            ),
            patch(
                "python.tools.scrape_ftl_event_urls.parse_event_schedule",
                return_value=([{"uuid": "U1", "name": "Szpada Mężczyzn kat. 2"}], []),
            ),
            patch(
                "python.pipeline.run.run_flow",
                side_effect=lambda p, svc=None, **k: MagicMock(
                    get=lambda *a: {}, faults=[], report=[]
                ),
            ),
            patch("python.pipeline.ingest_cli._send_staging_via_telegram") as send,
        ):
            ingest_cli.ingest_event_from_url(
                event_code="PPW4-2025-2026",
                season_end_year=2026,
                db=_event_db(),
                notifier=_silent_notifier(),
                send_telegram=True,
            )
        send.assert_called_once()

    def test_from_url_silent_by_default(self):
        from python.pipeline import ingest_cli

        with (
            patch.multiple(
                "python.scrapers.ftl_auth",
                get_authed_ftl_client=MagicMock(return_value=_Client()),
                normalize_ftl_url=lambda u: u,
            ),
            patch(
                "python.tools.scrape_ftl_event_urls.parse_event_schedule",
                return_value=([{"uuid": "U1", "name": "Szpada Mężczyzn kat. 2"}], []),
            ),
            patch(
                "python.pipeline.run.run_flow",
                side_effect=lambda p, svc=None, **k: MagicMock(
                    get=lambda *a: {}, faults=[], report=[]
                ),
            ),
            patch("python.pipeline.ingest_cli._send_staging_via_telegram") as send,
        ):
            ingest_cli.ingest_event_from_url(
                event_code="PPW4-2025-2026",
                season_end_year=2026,
                db=_event_db(),
                notifier=_silent_notifier(),
            )
        send.assert_not_called()


# ---------------------------------------------------------------------------
# N15.3 — StagingFormatter honours md_target
# ---------------------------------------------------------------------------


class TestStagingFormatterMdTarget:
    def test_md_target_storage_routes_write(self, tmp_path):
        from python.pipeline.core.contract import Context, Services
        from python.pipeline.plugins.staging_formatter import StagingFormatter

        ctx = Context()
        ctx.data["_bracket_reports"] = [[]]
        ctx.data["event"] = {"id_event": 4, "txt_code": "PPW4-2025-2026"}
        db = MagicMock()
        db.fetch_cert_rows_for_event.return_value = []
        db.fetch_fencer_db.return_value = []
        svc = Services(db=db, config={"staging_dir": str(tmp_path), "md_target": "storage"})
        with (
            patch("python.pipeline.plugins.staging_formatter.write_for_event") as wfe,
            patch(
                "python.pipeline.plugins.staging_formatter._fetch_event_meta",
                return_value={"_full_row": {}, "urls": []},
            ),
            patch(
                "python.pipeline.plugins.staging_formatter._live_tournament_rows", return_value=[]
            ),
        ):
            StagingFormatter().run(ctx, svc)
        assert wfe.call_args.kwargs.get("target") == "storage"
        # rendered md + diff are stashed for the Telegram sender
        assert ctx.get("_rendered_md") and ctx.get("_rendered_diff") is not None


# ---------------------------------------------------------------------------
# N15.4 — main() flag wiring
# ---------------------------------------------------------------------------


class TestCliFlags:
    def test_flags_thread_into_from_url(self):
        from python.pipeline import ingest_cli

        argv = [
            "prog",
            "--flow",
            "ingest_domestic",
            "--event-code",
            "PPW4-2025-2026",
            "--season-end-year",
            "2026",
            "--from-url",
            "--url-event",
            "https://ftl/NEW",
            "--send-telegram",
            "--md-target",
            "storage",
        ]
        with (
            patch("sys.argv", argv),
            patch("python.pipeline.ingest_cli.ingest_event_from_url") as mock_ing,
            patch("python.pipeline.ingest_cli.TelegramNotifier", return_value=_silent_notifier()),
        ):
            ingest_cli.main()
        kw = mock_ing.call_args.kwargs
        assert kw["url_event_override"] == "https://ftl/NEW"
        assert kw["send_telegram"] is True
        assert kw["md_target"] == "storage"
