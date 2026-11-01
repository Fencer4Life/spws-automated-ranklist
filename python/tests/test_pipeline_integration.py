"""
Phase 3 (ADR-050) end-to-end integration test.

Exercises the full Phase 3 stack against a live LOCAL Supabase instance:
  parsed IR → run_pipeline → DraftStore → 3-way diff → discard

The tests make their own rows and depend on no date (ADR-119 G20). A module
fixture creates an SPWS event in the season LOCAL has active, on a date no other
event holds; when the module ends it removes everything the tests created (the
event, the fencers Stage 0 made, the drafts, the audit rows the removal writes)
and puts the id sequences back, so LOCAL stays equal to PROD. They used to pin
PPW1-2025-2026's date and failed unseen once 2026/27 became active.

CI's pytest job has no database and skips them. Preflight runs them against
LOCAL through scripts/run_local_integration.py, which fails on a skip.

Plan IDs P3.INT.1 - P3.INT.5 (P3.INT.5: the module leaves LOCAL as it found
it, ADR-119 G20) and DRYRUN.02 (the XML dry run on LOCAL, ADR-119 G23).
"""

from __future__ import annotations

import os
import re
import subprocess
import uuid
from datetime import date
from pathlib import Path
from unittest.mock import patch

import pytest

_DB_CONTAINER = "supabase_db_SPWSranklist"
_LOCAL_URL = re.compile(r"^https?://(127\.0\.0\.1|localhost)(:\d+)?/?")
# A PPW code, so the pipeline treats the event as SPWS-domestic.
_EVENT_CODE = "PPW90-INTEGRATION"
# Surnames no real fencer carries: Stage 0 creates these people, so it never
# moves a real fencer's birth year. The last set is the dry run's own.
_PIPELINE_SURNAMES = ("INTEGRACJAA", "INTEGRACJAB", "INTEGRACJAC")
_DRY_RUN_SURNAMES = ("INTEGRACJAD", "INTEGRACJAE", "INTEGRACJAF")
_SURNAMES = _PIPELINE_SURNAMES + _DRY_RUN_SURNAMES
# What the tests and their clean-up can touch. Each must hold as many rows after
# the module as before it, and the sequences must stand where they stood.
_COUNTED = (
    "tbl_fencer",
    "tbl_event",
    "tbl_tournament",
    "tbl_result",
    "tbl_tournament_draft",
    "tbl_result_draft",
    "tbl_audit_log",
    "tbl_recompute_queue",
)
_SEQUENCES = ("tbl_fencer_id_fencer_seq", "tbl_event_id_event_seq")
_XML = Path(__file__).parent / "fixtures" / "fencingtime_xml" / "combined_v0v1.xml"


def _local_supabase_reachable() -> bool:
    """True if the local Supabase container is up + reachable from this process."""
    try:
        result = subprocess.run(
            [
                "docker",
                "exec",
                _DB_CONTAINER,
                "psql",
                "-U",
                "postgres",
                "-c",
                "SELECT 1",
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


pytestmark = pytest.mark.skipif(
    not _local_supabase_reachable(),
    reason="Local Supabase container not reachable (expected in CI's test-python job).",
)


def _psql(sql: str) -> str:
    """Run SQL on LOCAL as the superuser; the unaligned, tuples-only output."""
    out = subprocess.run(
        ["docker", "exec", "-i", _DB_CONTAINER, "psql", "-U", "postgres", "-d", "postgres"]
        + ["-qAt", "-v", "ON_ERROR_STOP=1"],
        input=sql,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if out.returncode != 0:
        raise RuntimeError(out.stderr.strip())
    return out.stdout.strip()


def _state() -> dict[str, str]:
    """Row counts and sequence positions the module must leave as it found them."""
    counts = [f"SELECT '{t}', count(*)::text FROM {t}" for t in _COUNTED]
    seqs = [f"SELECT '{s}', last_value || '/' || is_called FROM {s}" for s in _SEQUENCES]
    rows = _psql(" UNION ALL ".join(counts + seqs)).splitlines()
    return dict(row.split("|", 1) for row in rows)


@pytest.fixture(scope="module")
def db():
    """Real DbConnector against LOCAL. Skips without an address and key; refuses
    any address but LOCAL's, since these tests write."""
    url = os.environ.get("SUPABASE_URL", "")
    if not url or not os.environ.get("SUPABASE_KEY"):
        pytest.skip(
            "SUPABASE_URL / SUPABASE_KEY not set; scripts/run_local_integration.py sets them."
        )
    if not _LOCAL_URL.match(url):
        pytest.fail("refusing: SUPABASE_URL is not LOCAL, and these tests write")
    from python.pipeline.db_connector import create_db_connector

    return create_db_connector()


@pytest.fixture(scope="module")
def local_event(db):
    """An SPWS event of LOCAL's active season, on the first date of that season no
    event holds. Afterwards every row the module made is removed and the id
    sequences are put back; LOCAL must then be as it was (P3.INT.5)."""
    del db  # requested for its LOCAL guard, which runs before anything is written
    names = ", ".join(f"'{s}'" for s in _SURNAMES)
    if _psql(f"SELECT count(*) FROM tbl_fencer WHERE txt_surname IN ({names})") != "0":
        pytest.fail("LOCAL holds this module's synthetic fencers; reset it: ./scripts/reset-dev.sh")
    found = _psql(
        """SELECT s.id_season, extract(year FROM s.dt_end)::int, min(g)::date
             FROM tbl_season s, generate_series(s.dt_start, s.dt_end, interval '1 day') g
            WHERE s.bool_active
              AND NOT EXISTS (SELECT 1 FROM tbl_event e WHERE e.dt_start = g::date)
            GROUP BY s.id_season, s.dt_end"""
    )
    if not found:
        pytest.fail("LOCAL has no active season with a free date")
    id_season, season_end, day = found.split("|")
    before = _state()
    max_fencer = _psql("SELECT coalesce(max(id_fencer), 0) FROM tbl_fencer")
    max_log = _psql("SELECT coalesce(max(id_log), 0) FROM tbl_audit_log")
    id_event = _psql(
        f"""INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end)
            VALUES ('{_EVENT_CODE}', 'Pipeline integration test', {id_season},
                    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
                    '{day}', '{day}')
            RETURNING id_event"""
    )
    yield {
        "id_event": int(id_event),
        "date": date.fromisoformat(day),
        "season_end_year": int(season_end),
    }
    sequences = "\n".join(
        f"SELECT setval('{s}', {before[s].split('/')[0]}, {before[s].split('/')[1]});"
        for s in _SEQUENCES
    )
    _psql(
        f"""BEGIN;
            DELETE FROM tbl_result_draft WHERE txt_run_id IN
                   (SELECT txt_run_id FROM tbl_tournament_draft WHERE id_event = {id_event});
            DELETE FROM tbl_tournament_draft WHERE id_event = {id_event};
            DELETE FROM tbl_fencer WHERE id_fencer > {max_fencer} AND txt_surname IN ({names});
            DELETE FROM tbl_event WHERE id_event = {id_event};
            DELETE FROM tbl_audit_log WHERE id_log > {max_log} AND txt_table_name IN
                   ('tbl_fencer', 'tbl_event', 'tbl_tournament_draft', 'tbl_result_draft');
            {sequences}
            COMMIT;"""
    )
    assert _state() == before, "the module must leave LOCAL as it found it"


def _parsed_for(event, surnames=_PIPELINE_SURNAMES, weapon="EPEE", gender="M"):
    """A synthetic V1 bracket on the module's event date, with birth years inside
    V1 for the event's season."""
    from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind

    end = event["season_end_year"]
    return ParsedTournament(
        source_kind=SourceKind.FENCINGTIME_XML,
        results=[
            ParsedResult(
                source_row_id=f"int:{place}",
                fencer_name=f"{surname} {first}",
                place=place,
                birth_year=end - age,
                fencer_country="POL",
            )
            for place, (surname, first, age) in enumerate(
                zip(surnames, ("Jan", "Adam", "Pawel"), (42, 45, 48), strict=True), start=1
            )
        ],
        parsed_date=event["date"],
        weapon=weapon,
        gender=gender,
        organizer_hint="SPWS",
        season_end_year=end,
        source_url="https://integration.test/results",
        category_hint="V1",
    )


@pytest.fixture
def fresh_run_id():
    """A unique run_id so successive integration runs don't collide."""
    return str(uuid.uuid4())


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestEndToEnd:
    def test_run_pipeline_resolves_event_for_active_season_date(self, db, local_event):
        """P3.INT.1 run_pipeline against real DB resolves the event for its date."""
        from python.pipeline.orchestrator import run_pipeline
        from python.pipeline.types import Overrides

        parsed = _parsed_for(local_event)
        ctx = run_pipeline(
            parsed=parsed,
            overrides=Overrides(),
            db=db,
            season_end_year=local_event["season_end_year"],
        )

        # Stage S1 passed (results non-empty, all required fields).
        # Stage S2 resolved the module's event by its date in the active season.
        assert ctx.event is not None, f"S2 should resolve the event; halt={ctx.halt_detail!r}"
        assert ctx.event["txt_code"] == _EVENT_CODE

    def test_run_pipeline_completes_through_s7(self, db, local_event):
        """P3.INT.2 full S1-S7 chain runs to completion (no halt) on synthetic input."""
        from python.pipeline.orchestrator import run_pipeline
        from python.pipeline.types import Overrides

        parsed = _parsed_for(local_event)
        ctx = run_pipeline(
            parsed=parsed,
            overrides=Overrides(),
            db=db,
            season_end_year=local_event["season_end_year"],
        )

        assert not ctx.halted, (
            f"Expected full S1-S7 completion; halted at "
            f"{ctx.halted_at_stage} ({ctx.halt_reason}): {ctx.halt_detail}"
        )
        # S6 produced one match per input row
        assert len(ctx.matches) == 3
        # S7 recorded count validation
        assert ctx.count_validation is not None

    def test_draftstore_write_read_discard_round_trip(self, db, local_event, fresh_run_id):
        """P3.INT.3 DraftStore write + read_drafts + discard round-trip works end-to-end."""
        from python.pipeline.draft_store import DraftStore

        store = DraftStore(db)

        # Write one minimal tournament draft + one result draft on the module's
        # event, found the way the pipeline finds it.
        day = local_event["date"].isoformat()
        event = db.find_event_by_date(day)
        assert event is not None and event["id_event"] == local_event["id_event"]

        store.write_tournament_drafts(
            tournaments=[
                {
                    "id_event": event["id_event"],
                    "txt_code": f"INT-{fresh_run_id[:8]}-V1-EPEE-M",
                    "enum_type": "PPW",
                    "enum_weapon": "EPEE",
                    "enum_gender": "M",
                    "enum_age_category": "V1",
                    "dt_tournament": day,
                    "url_results": "https://integration.test/x",
                    "enum_parser_kind": "FENCINGTIME_XML",
                }
            ],
            run_id=fresh_run_id,
        )
        store.write_result_drafts(
            results=[
                {
                    "id_fencer": None,
                    "id_tournament_draft": 0,  # placeholder; commit-path fills it
                    "int_place": 1,
                    "txt_scraped_name": "INTEGRATION TEST",
                }
            ],
            run_id=fresh_run_id,
        )

        # Read back
        tournaments, results = store.read_drafts(fresh_run_id)
        assert len(tournaments) == 1
        assert len(results) == 1
        assert tournaments[0]["txt_run_id"] == fresh_run_id

        # Clean up via discard
        result = store.discard(fresh_run_id)
        assert result["tournaments_discarded"] == 1
        assert result["results_discarded"] == 1

        # Read after discard → empty
        tournaments_after, results_after = store.read_drafts(fresh_run_id)
        assert tournaments_after == []
        assert results_after == []

    def test_three_way_diff_renders_for_pipeline_output(self, db, local_event, tmp_path):
        """P3.INT.4 3-way diff renders markdown from a real PipelineContext."""
        from python.pipeline.orchestrator import run_pipeline
        from python.pipeline.three_way_diff import (
            build_diff,
            confidence_histogram,
            render_markdown,
            write_diff,
        )
        from python.pipeline.types import Overrides

        parsed = _parsed_for(local_event)
        ctx = run_pipeline(
            parsed=parsed,
            overrides=Overrides(),
            db=db,
            season_end_year=local_event["season_end_year"],
        )

        assert not ctx.halted, f"setup halt: {ctx.halt_detail}"

        source_rows = [
            {"fencer_name": r.fencer_name, "place": r.place, "id_fencer": None}
            for r in parsed.results
        ]
        new_rows = [
            {"fencer_name": m.scraped_name, "place": m.place, "id_fencer": m.id_fencer}
            for m in ctx.matches
        ]
        diff_rows = build_diff(source_rows, [], new_rows)
        hist = confidence_histogram(ctx.matches)
        md = render_markdown("INT-TEST", diff_rows, hist)
        path = write_diff("INT-TEST", md, staging_dir=tmp_path)

        assert path.exists()
        content = path.read_text()
        assert "INT-TEST" in content
        assert "Bucket summary" in content
        assert "Match confidence distribution" in content

    def test_xml_dry_run_writes_nothing(self, db, local_event, capsys):
        """DRYRUN.02 (ADR-119 G23) the XML dry run against LOCAL runs S1-S7 through the
        recording connector: the fencer table and its sequence are as they were, and
        it says whom a live run would create."""
        from python.pipeline.ingest_cli import ingest_xml_unified
        from python.pipeline.notifications import TelegramNotifier

        names = ", ".join(f"'{s}'" for s in _DRY_RUN_SURNAMES)
        fencers = (
            "SELECT count(*) || '/' || (SELECT last_value FROM tbl_fencer_id_fencer_seq) "
            f"|| '/' || (SELECT count(*) FROM tbl_fencer WHERE txt_surname IN ({names})) "
            "FROM tbl_fencer"
        )
        before = _psql(fencers)
        parsed = _parsed_for(local_event, surnames=_DRY_RUN_SURNAMES)
        with patch("python.scrapers.fencingtime_xml.parse", return_value=parsed):
            run_id = ingest_xml_unified(
                path=str(_XML),
                event_code=_EVENT_CODE,
                season_end_year=local_event["season_end_year"],
                url_event_override="https://integration.test/event",
                db=db,
                notifier=TelegramNotifier(None, None),
                dry_run=True,
            )

        assert run_id is None
        assert _psql(fencers) == before
        out = capsys.readouterr().out
        assert "halted=False" in out
        for surname in _DRY_RUN_SURNAMES:
            assert f"would create {surname} " in out
