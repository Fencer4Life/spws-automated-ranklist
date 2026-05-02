"""
Tests for python/pipeline/review_cli.py — Phase 3 (ADR-050) interactive CLI.

Plan IDs P3.RC1-P3.RC12.

The review_cli orchestrates the per-event lifecycle:
  1. Show event summary
  2. Prompt for source-of-truth choice (1=recorded URL, 2=paste URL,
     3=paste path, 4=EVF API, 5=cert_ref fallback, q=skip)
  3. Fetch + parse → ParsedTournament IR
  4. Run pipeline (S1-S7) → draft tables
  5. Generate 3-way diff markdown
  6. Prompt action: commit / discard / iterate
  7. On iterate: re-run pipeline (config hot-reloaded)

All prompts are injected via a Callable so tests don't block on stdin.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

import pytest


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

def _scripted_prompt(answers: list[str]):
    """Build a prompt callable that returns each answer in sequence.

    Raises if more prompts are issued than answers provided (catches
    test bugs where the dialog flow doesn't match expectations).
    """
    iterator = iter(answers)

    def _prompt(message: str) -> str:
        try:
            return next(iterator)
        except StopIteration:
            raise AssertionError(f"unexpected extra prompt: {message!r}")
    return _prompt


def _make_session(prompt_answers, db=None, store=None, fetcher=None,
                  output_lines=None):
    """Build a ReviewSession with mocks ready to use in tests."""
    from python.pipeline.review_cli import ReviewSession

    db = db or MagicMock()
    store = store or MagicMock()
    fetcher = fetcher or MagicMock()
    output_lines = output_lines if output_lines is not None else []

    session = ReviewSession(
        event_code="TEST-EVT-1",
        db=db,
        draft_store=store,
        prompt=_scripted_prompt(prompt_answers),
        output=output_lines.append,
        fetcher=fetcher,
    )
    # Phase 5 follow-up: every test session skips live URL reachability
    # checks by default. Tests that want to verify the validator wire-in
    # set this to False explicitly.
    session.skip_url_validation = True
    return session, db, store, fetcher, output_lines


# ---------------------------------------------------------------------------
# Source-of-truth choice dispatch
# ---------------------------------------------------------------------------

class TestSourceChoice:
    def test_choice_1_uses_recorded_url(self):
        """P3.RC1 choice '1' returns SourceChoice(kind='recorded')."""
        from python.pipeline.review_cli import ReviewSession, SourceChoice
        session, db, *_ = _make_session(prompt_answers=["1"])
        # Event has recorded url_results
        db.find_event_by_code.return_value = {
            "id_event": 1, "txt_code": "TEST-EVT-1",
            "url_results": "https://recorded.example/foo",
        }
        choice = session.prompt_source_choice()
        assert isinstance(choice, SourceChoice)
        assert choice.kind == "recorded"
        assert choice.value == "https://recorded.example/foo"

    def test_choice_2_prompts_for_url(self):
        """P3.RC2 choice '2' issues a follow-up prompt for URL."""
        from python.pipeline.review_cli import SourceChoice
        session, *_ = _make_session(prompt_answers=["2", "https://different.example/x"])
        choice = session.prompt_source_choice()
        assert choice.kind == "url"
        assert choice.value == "https://different.example/x"

    def test_choice_3_prompts_for_path(self):
        """P3.RC3 choice '3' issues a follow-up prompt for path."""
        session, *_ = _make_session(prompt_answers=["3", "/tmp/test.xml"])
        choice = session.prompt_source_choice()
        assert choice.kind == "path"
        assert choice.value == "/tmp/test.xml"

    def test_choice_q_skips(self):
        """P3.RC4 choice 'q' returns SourceChoice(kind='skip')."""
        session, *_ = _make_session(prompt_answers=["q"])
        choice = session.prompt_source_choice()
        assert choice.kind == "skip"

    def test_choice_4_evf_api(self):
        """P3.RC4b choice '4' returns SourceChoice(kind='evf_api', value=event_code).

        EVF API is the authoritative source for EVF events (predominant on
        the calendar per project_evf_predominance.md).
        """
        session, *_ = _make_session(prompt_answers=["4"])
        choice = session.prompt_source_choice()
        assert choice.kind == "evf_api"
        assert choice.value == "TEST-EVT-1"

    def test_invalid_choice_reprompts(self):
        """P3.RC5 invalid choice re-prompts until valid."""
        session, *_ = _make_session(prompt_answers=["foo", "9", "1"])
        session.db.find_event_by_code.return_value = {
            "id_event": 1, "txt_code": "TEST-EVT-1",
            "url_results": "https://recorded.example/x",
        }
        choice = session.prompt_source_choice()
        assert choice.kind == "recorded"


# ---------------------------------------------------------------------------
# Fetch dispatch
# ---------------------------------------------------------------------------

class TestFetcher:
    def test_fetch_recorded_uses_event_url(self):
        """P3.RC6 fetch('recorded') invokes fetcher.fetch_url with event URL."""
        from python.pipeline.review_cli import SourceChoice
        from python.pipeline.ir import ParsedTournament, SourceKind

        fetcher = MagicMock()
        fetcher.fetch_url.return_value = ParsedTournament(
            source_kind=SourceKind.FENCINGTIME_XML, results=[],
        )
        session, db, *_ = _make_session(prompt_answers=[], fetcher=fetcher)
        db.find_event_by_code.return_value = {
            "id_event": 1, "txt_code": "TEST-EVT-1",
            "url_results": "https://recorded.example/x",
        }

        parsed = session.fetch_source(SourceChoice(kind="recorded",
                                                    value="https://recorded.example/x"))
        fetcher.fetch_url.assert_called_once_with("https://recorded.example/x")
        assert parsed.source_kind == SourceKind.FENCINGTIME_XML

    def test_fetch_path_uses_local_file(self):
        """P3.RC7 fetch('path') invokes fetcher.fetch_path."""
        from python.pipeline.review_cli import SourceChoice
        from python.pipeline.ir import ParsedTournament, SourceKind

        fetcher = MagicMock()
        fetcher.fetch_path.return_value = ParsedTournament(
            source_kind=SourceKind.FILE_IMPORT, results=[],
        )
        session, *_ = _make_session(prompt_answers=[], fetcher=fetcher)
        parsed = session.fetch_source(SourceChoice(kind="path", value="/tmp/x.csv"))
        fetcher.fetch_path.assert_called_once_with("/tmp/x.csv")
        assert parsed.source_kind == SourceKind.FILE_IMPORT

    def test_fetch_evf_api_passes_event_dict(self):
        """P3.RC7b fetch('evf_api') invokes fetcher.fetch_evf_api with event dict.

        EVF events are predominant; this is the high-value source path
        (per project_evf_predominance.md).
        """
        from python.pipeline.review_cli import SourceChoice
        from python.pipeline.ir import ParsedTournament, SourceKind

        fetcher = MagicMock()
        fetcher.fetch_evf_api.return_value = ParsedTournament(
            source_kind=SourceKind.EVF_API, results=[],
        )
        session, db, *_ = _make_session(prompt_answers=[], fetcher=fetcher)
        event = {"id_event": 99, "txt_code": "PEW3-2025-2026",
                 "dt_start": "2026-04-01", "dt_end": "2026-04-01"}
        db.find_event_by_code.return_value = event

        parsed = session.fetch_source(SourceChoice(kind="evf_api",
                                                    value="PEW3-2025-2026"))
        fetcher.fetch_evf_api.assert_called_once_with(event)
        assert parsed.source_kind == SourceKind.EVF_API

    def test_fetch_evf_api_event_missing_raises(self):
        """P3.RC7c fetch('evf_api') raises clearly when event isn't in DB."""
        from python.pipeline.review_cli import SourceChoice

        fetcher = MagicMock()
        session, db, *_ = _make_session(prompt_answers=[], fetcher=fetcher)
        db.find_event_by_code.return_value = None  # event missing

        with pytest.raises(ValueError, match="event TEST-EVT-1 not found"):
            session.fetch_source(SourceChoice(kind="evf_api", value="TEST-EVT-1"))
        fetcher.fetch_evf_api.assert_not_called()


# ---------------------------------------------------------------------------
# Iteration loop
# ---------------------------------------------------------------------------

class TestRunIteration:
    def test_iteration_runs_pipeline_writes_drafts_and_diff(self, tmp_path, monkeypatch):
        """P3.RC8 iteration: pipeline → drafts → 3-way diff written to staging dir."""
        from python.pipeline import review_cli
        from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
        from python.pipeline.types import StageMatchResult

        # Stub run_pipeline to return a synthetic context with one match
        def fake_run_pipeline(parsed, overrides, db, season_end_year, event_code=None):
            from python.pipeline.types import Overrides, PipelineContext
            ctx = PipelineContext(parsed=parsed, overrides=overrides or Overrides(),
                                  season_end_year=season_end_year)
            ctx.event = {"id_event": 1, "txt_code": "TEST-EVT-1"}
            ctx.matches = [
                StageMatchResult(scraped_name="X", place=1, id_fencer=42,
                                 confidence=99.0, method="AUTO_MATCHED"),
            ]
            # ADR-056: run_iteration now writes via vcat_groups; populate
            # synthetically so the test's draft-write assertions still hold.
            ctx.vcat_groups = {"V1": list(ctx.matches)}
            ctx.is_joint_pool = False
            return ctx
        monkeypatch.setattr(review_cli, "run_pipeline", fake_run_pipeline)

        # Stub cert_ref query (Phase 3 reads but for now we mock)
        session, db, store, *_ = _make_session(prompt_answers=[])
        db.fetch_cert_rows_for_event.return_value = []
        # ADR-056: write_tournament_drafts returns list of ids — stub a list
        # of length 1 so the runner's vcat→id linkage map is non-empty and
        # write_result_drafts gets called.
        store.write_tournament_drafts.return_value = [101]

        parsed = ParsedTournament(
            source_kind=SourceKind.FENCINGTIME_XML,
            results=[ParsedResult(source_row_id="r1", fencer_name="X", place=1)],
            parsed_date=date(2026, 4, 1),
            weapon="EPEE", gender="M", season_end_year=2026,
        )

        ctx, diff_path = session.run_iteration(parsed, staging_dir=tmp_path)

        # Pipeline ran, drafts written, diff created
        assert len(ctx.matches) == 1
        store.write_tournament_drafts.assert_called()
        store.write_result_drafts.assert_called()
        assert diff_path.exists()
        content = diff_path.read_text()
        assert "TEST-EVT-1" in content


# ---------------------------------------------------------------------------
# Action prompt: commit / discard / iterate
# ---------------------------------------------------------------------------

class TestPromptAction:
    def test_commit_returns_commit(self):
        """P3.RC9 'c' returns 'commit'."""
        session, *_ = _make_session(prompt_answers=["c"])
        assert session.prompt_action() == "commit"

    def test_discard_returns_discard(self):
        """P3.RC10 'd' returns 'discard'."""
        session, *_ = _make_session(prompt_answers=["d"])
        assert session.prompt_action() == "discard"

    def test_iterate_returns_iterate(self):
        """P3.RC11 'i' returns 'iterate'."""
        session, *_ = _make_session(prompt_answers=["i"])
        assert session.prompt_action() == "iterate"


# ---------------------------------------------------------------------------
# End-to-end orchestration
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Joint flag semantics + url_results transform (Phase 5 follow-up)
# ---------------------------------------------------------------------------

class TestJointFlagAndUrlTransform:
    """Phase 5 follow-up: bool_joint_pool_split must flag only the
    OUTLIER V-cat children, not the dominant V-cat child whose V-cat
    matches the bracket's nominal V-cat. And url_results must be the
    human-friendly /events/results/<UUID> URL, not the JSON data endpoint
    /events/results/data/<UUID> we actually fetched.
    """

    def _make_ctx(self, *, category_hint: str | None, vcat_groups: dict,
                  source_url: str = "https://example.test/x"):
        from python.pipeline.ir import ParsedTournament, SourceKind
        from python.pipeline.types import Overrides, PipelineContext

        parsed = ParsedTournament(
            source_kind=SourceKind.FENCINGTIME_XML,
            results=[],
            parsed_date=date(2026, 4, 1),
            weapon="EPEE",
            gender="M",
            season_end_year=2026,
            source_url=source_url,
            category_hint=category_hint,
        )
        ctx = PipelineContext(parsed=parsed, overrides=Overrides(), season_end_year=2026)
        ctx.event = {"id_event": 99, "txt_code": "TEST-EVT-1"}
        ctx.vcat_groups = vcat_groups
        ctx.is_joint_pool = len(vcat_groups) >= 2
        return ctx

    # 5.J1 single V-cat group → joint=FALSE
    def test_single_group_joint_false(self):
        from python.pipeline.types import StageMatchResult
        m = StageMatchResult(scraped_name="X", place=1, id_fencer=1,
                             confidence=99.0, method="AUTO_MATCHED")
        session, *_ = _make_session(prompt_answers=[])
        ctx = self._make_ctx(category_hint="V2", vcat_groups={"V2": [m]})
        rows = session._build_tournament_draft_rows(ctx)
        assert len(rows) == 1
        assert rows[0]["enum_age_category"] == "V2"
        assert rows[0]["bool_joint_pool_split"] is False

    # 5.J2 single-V-cat-named bracket with outlier → dominant FALSE, outlier TRUE
    def test_named_bracket_with_outlier_only_outlier_flagged(self):
        from python.pipeline.types import StageMatchResult
        dom1 = StageMatchResult(scraped_name="A", place=1, id_fencer=1,
                                confidence=99.0, method="AUTO_MATCHED")
        dom2 = StageMatchResult(scraped_name="B", place=2, id_fencer=2,
                                confidence=99.0, method="AUTO_MATCHED")
        outlier = StageMatchResult(scraped_name="C", place=3, id_fencer=3,
                                   confidence=99.0, method="AUTO_MATCHED")
        session, *_ = _make_session(prompt_answers=[])
        ctx = self._make_ctx(
            category_hint="V2",
            vcat_groups={"V2": [dom1, dom2], "V3": [outlier]},
        )
        rows = session._build_tournament_draft_rows(ctx)
        by_vcat = {r["enum_age_category"]: r for r in rows}
        assert by_vcat["V2"]["bool_joint_pool_split"] is False
        assert by_vcat["V3"]["bool_joint_pool_split"] is True

    # 5.J3 combined-pool bracket (no nominal V-cat) → all groups TRUE
    def test_combined_pool_all_groups_flagged(self):
        from python.pipeline.types import StageMatchResult
        a = StageMatchResult(scraped_name="A", place=1, id_fencer=1,
                             confidence=99.0, method="AUTO_MATCHED")
        b = StageMatchResult(scraped_name="B", place=2, id_fencer=2,
                             confidence=99.0, method="AUTO_MATCHED")
        c = StageMatchResult(scraped_name="C", place=3, id_fencer=3,
                             confidence=99.0, method="AUTO_MATCHED")
        session, *_ = _make_session(prompt_answers=[])
        ctx = self._make_ctx(
            category_hint=None,
            vcat_groups={"V1": [a], "V2": [b], "V3": [c]},
        )
        rows = session._build_tournament_draft_rows(ctx)
        assert len(rows) == 3
        assert all(r["bool_joint_pool_split"] is True for r in rows)

    # 5.J4 url_results transforms FTL data endpoint → human URL
    def test_url_results_transformed_for_ftl(self):
        from python.pipeline.types import StageMatchResult
        m = StageMatchResult(scraped_name="X", place=1, id_fencer=1,
                             confidence=99.0, method="AUTO_MATCHED")
        session, *_ = _make_session(prompt_answers=[])
        ctx = self._make_ctx(
            category_hint="V2", vcat_groups={"V2": [m]},
            source_url="https://www.fencingtimelive.com/events/results/data/22488366AC2E4DA9A7A7828054EB230C",
        )
        rows = session._build_tournament_draft_rows(ctx)
        r = rows[0]
        assert r["url_results"] == "https://www.fencingtimelive.com/events/results/22488366AC2E4DA9A7A7828054EB230C"
        # txt_source_url_used keeps the actual fetched endpoint (audit trail)
        assert r["txt_source_url_used"] == "https://www.fencingtimelive.com/events/results/data/22488366AC2E4DA9A7A7828054EB230C"

    # 5.J5 non-FTL URLs are passed through unchanged
    def test_non_ftl_url_unchanged(self):
        from python.pipeline.types import StageMatchResult
        m = StageMatchResult(scraped_name="X", place=1, id_fencer=1,
                             confidence=99.0, method="AUTO_MATCHED")
        session, *_ = _make_session(prompt_answers=[])
        ctx = self._make_ctx(
            category_hint="V2", vcat_groups={"V2": [m]},
            source_url="https://engarde-service.com/some/path",
        )
        rows = session._build_tournament_draft_rows(ctx)
        assert rows[0]["url_results"] == "https://engarde-service.com/some/path"


class TestRun:
    def test_skip_choice_exits_without_writes(self):
        """P3.RC12 source-of-truth='q' (skip) returns without touching draft store."""
        session, db, store, *_ = _make_session(prompt_answers=["q"])
        db.find_event_by_code.return_value = {
            "id_event": 1, "txt_code": "TEST-EVT-1", "url_results": "https://x",
        }
        result = session.run()
        assert result == "skipped"
        store.write_tournament_drafts.assert_not_called()
        store.commit.assert_not_called()
        store.discard.assert_not_called()
