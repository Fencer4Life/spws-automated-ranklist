"""N11 — staging report as a first-class plugin output (ADR-075).

The NEW pipeline auto-commits (ADR-074: no draft/review gate), so it produced no
staging artifact. This restores the OLD pipeline's two human-review files per event
(`<EVENT>.<ts>.md` + `<EVENT>.<ts>.diff.md`) via Option B: every plugin serializes
its own fragment to a fifth Context channel (`report`) as it runs, and one terminal
`StagingFormatter` plugin shapes the accumulated fragments into the files from a
template. Informational/post-commit only — no drafts, no blocking gate.

DB + renderers are mocked here (contract + orchestration); the real LOCAL PPW3
from-url re-ingest is the live acceptance (plan §Verification).
"""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest


# ===========================================================================
# N11.1 — the `report` channel on Context
# ===========================================================================

class TestReportChannel:
    def test_fresh_context_has_empty_report(self):
        """N11.1 a new Context starts with an empty report append-log."""
        from python.pipeline.core.contract import Context

        assert Context().report == []

    def test_add_report_tags_active_plugin_and_kind(self):
        """N11.1 ctx.add_report appends a ReportFragment tagged with the active
        plugin name + kind (set by the orchestrator's _begin) and the payload."""
        from python.pipeline.core.contract import (
            Context, PluginKind, ReportFragment,
        )

        ctx = Context()
        plugin = MagicMock(name="ParseSource")
        plugin.name = "ParseSource"
        plugin.kind = PluginKind.SOURCE
        plugin.writes = frozenset()

        ctx._begin(plugin)
        ctx.add_report("SOURCE", weapon="EPEE", n_rows=12)
        ctx._end()

        assert len(ctx.report) == 1
        frag = ctx.report[0]
        assert isinstance(frag, ReportFragment)
        assert frag.plugin == "ParseSource"
        assert frag.kind == PluginKind.SOURCE
        assert frag.section == "SOURCE"
        assert frag.payload == {"weapon": "EPEE", "n_rows": 12}

    def test_add_report_bypasses_write_discipline(self):
        """N11.1 the report channel is a forward signal (like fault/warn), NOT a
        DAG key — emitting it never trips write-discipline even though the active
        plugin declared no writes."""
        from python.pipeline.core.contract import Context, PluginKind

        ctx = Context()
        plugin = MagicMock()
        plugin.name = "ValidateIR"
        plugin.kind = PluginKind.GATE
        plugin.writes = frozenset()  # declares nothing

        ctx._begin(plugin)
        ctx.add_report("VALIDATION", check="ir", ok=True)  # must not raise
        ctx._end()

        assert ctx.report[0].section == "VALIDATION"

    def test_add_report_explicit_plugin_kind_override(self):
        """N11.1 add_report accepts explicit plugin/kind (used by BasePlugin.report
        so a plugin can serialize even outside orchestrator bracketing)."""
        from python.pipeline.core.contract import Context, PluginKind

        ctx = Context()
        ctx.add_report("COMMIT", plugin="Commit", kind=PluginKind.MUTATOR, n=3)

        frag = ctx.report[0]
        assert frag.plugin == "Commit"
        assert frag.kind == PluginKind.MUTATOR
        assert frag.payload == {"n": 3}


# ===========================================================================
# N11.2 — BasePlugin.report convenience
# ===========================================================================

class TestBasePluginReport:
    def test_report_forwards_name_and_kind(self):
        """N11.2 BasePlugin.report(ctx, section, **kw) forwards the plugin's own
        name + kind to ctx.add_report, so every subclass can serialize a fragment
        idiomatically (and standalone, without orchestrator bracketing)."""
        from python.pipeline.core.contract import Context, PluginKind
        from python.pipeline.plugins.base import BasePlugin

        class Demo(BasePlugin):
            name = "Demo"
            kind = PluginKind.TRANSFORM

        ctx = Context()
        Demo().report(ctx, "STRUCTURE", combined=True)

        frag = ctx.report[0]
        assert frag.plugin == "Demo"
        assert frag.kind == PluginKind.TRANSFORM
        assert frag.section == "STRUCTURE"
        assert frag.payload == {"combined": True}


# ===========================================================================
# N11.3 — every plugin serializes its fragment during a real flow run
# ===========================================================================

def _by_section(ctx):
    out: dict[str, list] = {}
    for frag in ctx.report:
        out.setdefault(frag.section, []).append(frag)
    return out


class TestPerPluginEmission:
    """Run the real INGEST_DOMESTIC chain (reusing the test_pipeline_plugins
    harness — real ResolveFencers, stubbed wrapped stages) and assert each plugin
    kind serialized its own fragment to the report channel."""

    def test_source_fragment(self, monkeypatch):
        """N11.3 ParseSource (SOURCE) emits weapon/gender/n_rows."""
        from python.pipeline.core.contract import PluginKind
        from python.tests.test_pipeline_plugins import _ingest

        ctx = _ingest(monkeypatch)
        src = _by_section(ctx)["SOURCE"][0]
        assert src.plugin == "ParseSource" and src.kind == PluginKind.SOURCE
        assert src.payload["weapon"] == "EPEE"
        assert src.payload["gender"] == "M"
        assert src.payload["n_rows"] == 2

    def test_event_fragment(self, monkeypatch):
        """N11.3 ResolveEvent (TRANSFORM) emits the event header."""
        from python.tests.test_pipeline_plugins import _ingest

        ctx = _ingest(monkeypatch)
        ev = _by_section(ctx)["EVENT"][0]
        assert ev.plugin == "ResolveEvent"
        assert ev.payload["id_event"] == 7
        assert ev.payload["txt_code"] == "PPW3-2025-2026"

    def test_identity_fragment(self, monkeypatch):
        """N11.3 ResolveFencers (MUTATOR) emits matches + created/reconciled."""
        from python.pipeline.core.contract import PluginKind
        from python.tests.test_pipeline_plugins import _ingest

        ctx = _ingest(monkeypatch)
        ident = _by_section(ctx)["IDENTITY"][0]
        assert ident.plugin == "ResolveFencers" and ident.kind == PluginKind.MUTATOR
        assert len(ident.payload["matches"]) == 2
        assert {m["id_fencer"] for m in ident.payload["matches"]} == {101, 102}
        assert ident.payload["created"] == []  # both pre-existing

    def test_validation_count_fragment(self, monkeypatch):
        """N11.3 ValidateCounts (GATE) emits a count check fragment."""
        from python.tests.test_pipeline_plugins import _ingest

        ctx = _ingest(monkeypatch)
        checks = {f.payload.get("check") for f in _by_section(ctx)["VALIDATION"]}
        assert "count" in checks

    def test_pool_round_fragment(self, monkeypatch):
        """N11.3 DetectPoolRound (GATE) emits a pool_round check fragment."""
        from python.tests.test_pipeline_plugins import _ingest

        ctx = _ingest(monkeypatch)
        checks = {f.payload.get("check") for f in _by_section(ctx)["VALIDATION"]}
        assert "pool_round" in checks

    def test_commit_fragment(self, monkeypatch):
        """N11.3 Commit (MUTATOR) emits the committed-tournaments fragment."""
        from python.tests.test_pipeline_plugins import _ingest

        ctx = _ingest(monkeypatch)
        commit = _by_section(ctx)["COMMIT"][0]
        assert commit.plugin == "Commit"
        assert commit.payload["skipped"] is False
        assert "tournaments" in commit.payload


# ===========================================================================
# N11.4–N11.6 — the terminal StagingFormatter plugin (template + diff)
# ===========================================================================

def _event_ctx(bracket_reports, *, event=None, schedule_skips=None):
    from python.pipeline.core.contract import Context
    ctx = Context()
    ctx.data["_bracket_reports"] = bracket_reports
    ctx.data["event"] = event or {"id_event": 7, "txt_code": "PPW3-2025-2026"}
    if schedule_skips is not None:
        ctx.data["_schedule_skips"] = schedule_skips
    return ctx


def _formatter_svc(tmp_path, cert_rows=None):
    from python.pipeline.core.contract import Services
    db = MagicMock()
    db.fetch_cert_rows_for_event.return_value = cert_rows or []
    return Services(db=db, config={"staging_dir": str(tmp_path)})


class TestStagingFormatterApplies:
    def test_skipped_without_bracket_reports(self):
        """N11.4 the per-bracket POST_COMMIT (no _bracket_reports) does NOT render."""
        from python.pipeline.core.contract import Context
        from python.pipeline.plugins.staging_formatter import StagingFormatter

        assert StagingFormatter().applies(Context()) is False

    def test_applies_at_event_scope(self):
        """N11.4 the event-scoped fire (seeded _bracket_reports) renders."""
        from python.pipeline.plugins.staging_formatter import StagingFormatter

        assert StagingFormatter().applies(_event_ctx([[]])) is True


class TestStagingFormatterMd:
    def test_renders_md_with_all_sections_in_template_order(self, monkeypatch, tmp_path):
        """N11.5 StagingFormatter merges _bracket_reports, renders the template, and
        writes <EVENT>.<ts>.md with the template sections in order."""
        from python.tests.test_pipeline_plugins import _ingest
        from python.pipeline.plugins.staging_formatter import StagingFormatter

        b1 = _ingest(monkeypatch)
        ctx = _event_ctx([b1.report], event=b1.get("event"),
                         schedule_skips=[{"weapon": "EPEE", "name": "Szpada kat. Veteran",
                                          "reason": "pool_round"}])
        StagingFormatter().run(ctx, _formatter_svc(tmp_path))

        mds = list(tmp_path.glob("PPW3-2025-2026.*.md"))
        md_files = [p for p in mds if not p.name.endswith(".diff.md")]
        assert len(md_files) == 1
        md = md_files[0].read_text()
        for a, b in [("## Event", "## Fencer matching"),
                     ("## Fencer matching", "## Committed tournaments"),
                     ("## Committed tournaments", "## Pool rounds / counts"),
                     ("## Pool rounds / counts", "## Sign-off")]:
            assert md.index(a) < md.index(b), f"{a} must precede {b}"

    def test_schedule_skips_surface_in_validation_section(self, monkeypatch, tmp_path):
        """N11.5 schedule-level pool-only skips appear in the file (they never ran,
        so only the schedule knows about them)."""
        from python.tests.test_pipeline_plugins import _ingest
        from python.pipeline.plugins.staging_formatter import StagingFormatter

        b1 = _ingest(monkeypatch)
        ctx = _event_ctx([b1.report], event=b1.get("event"),
                         schedule_skips=[{"weapon": "FOIL", "name": "Floret kat. Veteran",
                                          "reason": "pool-only qualifier"}])
        StagingFormatter().run(ctx, _formatter_svc(tmp_path))
        md = [p for p in tmp_path.glob("*.md") if not p.name.endswith(".diff.md")][0].read_text()
        assert "Floret kat. Veteran" in md

    def test_timestamped_filenames_share_stem(self, monkeypatch, tmp_path):
        """Timestamp requirement — both files of one run share a sortable UTC stem
        so reruns of the same event are comparable."""
        from python.tests.test_pipeline_plugins import _ingest
        from python.pipeline.plugins.staging_formatter import StagingFormatter

        b1 = _ingest(monkeypatch)
        ctx = _event_ctx([b1.report], event=b1.get("event"))
        StagingFormatter().run(ctx, _formatter_svc(tmp_path))

        md = [p for p in tmp_path.glob("*.md") if not p.name.endswith(".diff.md")][0]
        diff = list(tmp_path.glob("*.diff.md"))[0]
        # PPW3-2025-2026.<STEM>.md  and  PPW3-2025-2026.<STEM>.diff.md
        md_stem = md.name[len("PPW3-2025-2026."):-len(".md")]
        diff_stem = diff.name[len("PPW3-2025-2026."):-len(".diff.md")]
        assert md_stem == diff_stem
        assert md_stem and md_stem[0].isdigit()  # YYYYMMDD-... sortable


class TestStagingFormatterDiff:
    def test_writes_diff_via_three_way_diff(self, monkeypatch, tmp_path):
        """N11.6 builds aggregated source/new rows + cert rows, calls the 3-way diff
        builders, and writes <EVENT>.<ts>.diff.md with a confidence histogram."""
        from python.tests.test_pipeline_plugins import _ingest
        from python.pipeline.plugins.staging_formatter import StagingFormatter

        b1 = _ingest(monkeypatch)
        ctx = _event_ctx([b1.report], event=b1.get("event"))
        svc = _formatter_svc(tmp_path)
        StagingFormatter().run(ctx, svc)

        svc.db.fetch_cert_rows_for_event.assert_called_once_with("PPW3-2025-2026")
        diff = list(tmp_path.glob("*.diff.md"))[0].read_text()
        assert "3-way diff" in diff
        assert "Match confidence distribution" in diff


# ===========================================================================
# N11.7 — the CLI fires ONE event-scoped POST_COMMIT seeded with all reports
# ===========================================================================

class TestEventScopedFire:
    def test_fire_seeds_bracket_reports_and_runs_post_commit(self):
        """N11.7 _fire_staging_report seeds `_bracket_reports` (one per bracket) +
        `event` and runs POST_COMMIT once with react=False (no re-fire)."""
        from python.pipeline import ingest_cli
        from python.pipeline.core.contract import Context
        from python.pipeline.engine.flows import Flow

        b1, b2 = Context(), Context()
        b1.add_report("COMMIT", plugin="Commit", n=1)
        b2.add_report("COMMIT", plugin="Commit", n=2)
        event = {"id_event": 7, "txt_code": "PPW3-2025-2026"}

        seen = {}

        def fake_run_flow(params, ctx=None, svc=None, **kw):
            seen["flow"] = params.flow
            seen["react"] = kw.get("react")
            seen["bracket_reports"] = ctx.get("_bracket_reports")
            return ctx

        with patch("python.pipeline.run.run_flow", side_effect=fake_run_flow):
            ingest_cli._fire_staging_report(event, [b1, b2], db=MagicMock())

        assert seen["flow"] == Flow.POST_COMMIT
        assert seen["react"] is False
        assert seen["bracket_reports"] == [b1.report, b2.report]

    def test_no_fire_when_no_contexts(self):
        """N11.7 nothing committed -> no staging fire."""
        from python.pipeline import ingest_cli

        with patch("python.pipeline.run.run_flow") as rf:
            out = ingest_cli._fire_staging_report({"id_event": 1}, [], db=MagicMock())
        assert out is None
        rf.assert_not_called()

    def test_ingest_from_url_fires_staging_once(self):
        """N11.7 ingest_event_from_url fires exactly one event-scoped staging report
        after the bracket loop, carrying the schedule skips."""
        from python.pipeline import ingest_cli

        db = MagicMock()
        db.find_event_by_code.return_value = {
            "id_event": 1, "txt_code": "PPW3-2025-2026",
            "url_event": "https://x/eventSchedule/ABC", "dt_start": "2025-12-13"}

        class _Client:
            def __enter__(self): return self
            def __exit__(self, *a): return False
            def get(self, url):
                r = MagicMock(); r.raise_for_status = lambda: None
                r.text = "<sched/>"; r.json = lambda: [
                    {"id": "f1", "name": "KOWALSKI Jan", "place": "1", "country": "POL"}]
                return r

        fire = {}
        with patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=_Client()), \
             patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u), \
             patch("python.tools.scrape_ftl_event_urls.parse_event_schedule",
                   return_value=([{"uuid": "U1", "name": "Szpada Mężczyzn kat. 2"}],
                                 [{"weapon": "FOIL", "name": "Floret kat. Veteran",
                                   "reason": "pool-only"}])), \
             patch("python.pipeline.ingest_cli._run_parsed_through_flow",
                   side_effect=lambda *a, **k: __import__(
                       "python.pipeline.core.contract", fromlist=["Context"]).Context()), \
             patch("python.pipeline.ingest_cli._fire_staging_report",
                   side_effect=lambda *a, **k: fire.update(args=a, kwargs=k)):
            ingest_cli.ingest_event_from_url(
                event_code="PPW3-2025-2026", season_end_year=2026, db=db)

        assert "args" in fire  # fired exactly once
        assert fire["kwargs"].get("schedule_skips") == [
            {"weapon": "FOIL", "name": "Floret kat. Veteran", "reason": "pool-only"}]
