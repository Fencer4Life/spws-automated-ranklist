"""INTL.POL — only Polish rows of an international event reach the matcher.

ADR-105 §1.1 / §5.1 and ADR-038: for PEW, MEW, MSW and PSW (including the
IMEW/IMSW alternation codes) every row whose country does not fold to POL is
dismissed before matching, in both pipelines, so a foreign name can never be
linked to a Polish fencer. A row with no country is dismissed too (ADR-038
point 4, fail-closed). Before this, ``s6_resolve_identity`` and
``ResolveFencers`` matched every row and excluded only the unmatched ones, so
an exact or near name collision gave a foreign fencer a Polish result
(KUZMICHOVA Svitlana, MSW Manama 2025, is not a Polish entry on FTL).

The dismissed rows still count towards the parse's completeness check, so
S7 compares matches + dismissed with the source bracket size.
"""

from __future__ import annotations

from unittest.mock import MagicMock

import pytest

from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.stages import s6_resolve_identity, s7_validate
from python.pipeline.types import HaltError, Overrides, PipelineContext

KOWALSKI = {
    "id_fencer": 42,
    "txt_surname": "KOWALSKI",
    "txt_first_name": "Jan",
    "int_birth_year": 1970,
    "txt_nationality": "PL",
    "json_name_aliases": None,
}
NOWAK = {
    "id_fencer": 43,
    "txt_surname": "NOWAK",
    "txt_first_name": "Adam",
    "int_birth_year": 1968,
    "txt_nationality": "PL",
    "json_name_aliases": None,
}


def _row(name, place, country):
    return ParsedResult(
        source_row_id=f"t:{name}:{place}",
        fencer_name=name,
        place=place,
        fencer_country=country,
    )


def _ctx(rows, code, *, raw_pool_size=None):
    parsed = ParsedTournament(
        source_kind=SourceKind.FTL,
        results=rows,
        raw_pool_size=raw_pool_size,
        weapon="EPEE",
        gender="M",
        category_hint="V2",
        season_end_year=2026,
    )
    ctx = PipelineContext(parsed=parsed, overrides=Overrides(), season_end_year=2026)
    ctx.event = {"id_event": 1, "txt_code": code}
    return ctx


def _db():
    db = MagicMock()
    db.fetch_fencer_db.return_value = [KOWALSKI, NOWAK]
    return db


class TestOldPipeline:
    def test_a_foreign_namesake_is_dismissed_before_matching(self):
        """INTL.POL.01 in an EVF event a German row named exactly like a Pole
        is dismissed: no match, no result, recorded as dismissed."""
        ctx = _ctx([_row("KOWALSKI Jan", 3, "GER"), _row("NOWAK Adam", 7, "POL")], "PEW3-2025-2026")
        s6_resolve_identity(ctx, _db())
        assert [(m.scraped_name, m.id_fencer) for m in ctx.matches] == [("NOWAK Adam", 43)]
        assert ctx.dismissed_non_pol == [{"name": "KOWALSKI Jan", "place": 3, "country": "GER"}]

    @pytest.mark.parametrize("code", ["IMSW-2025-2026", "IMEW-2024-2025", "MSW-2026-2027"])
    def test_the_alternation_codes_are_international_too(self, code):
        """INTL.POL.02 IMSW and IMEW (the alternation codes) and MSW filter the
        same way; a "PL" country folds to POL and is matched."""
        ctx = _ctx([_row("KOWALSKI Jan", 3, "UKR"), _row("NOWAK Adam", 7, "PL")], code)
        s6_resolve_identity(ctx, _db())
        assert [m.id_fencer for m in ctx.matches] == [43]
        assert [d["name"] for d in ctx.dismissed_non_pol] == ["KOWALSKI Jan"]

    def test_no_country_is_dismissed_and_domestic_is_unfiltered(self):
        """INTL.POL.03 a row with no country is dismissed in an international
        event (ADR-038 point 4); a domestic event filters nothing."""
        intl = _ctx([_row("NOWAK Adam", 1, None)], "PEW3-2025-2026")
        s6_resolve_identity(intl, _db())
        assert intl.matches == []
        assert intl.dismissed_non_pol == [{"name": "NOWAK Adam", "place": 1, "country": None}]

        dom = _ctx([_row("KOWALSKI Jan", 1, "GER"), _row("NOWAK Adam", 2, None)], "PPW3-2025-2026")
        s6_resolve_identity(dom, _db())
        assert {m.id_fencer for m in dom.matches} == {42, 43}
        assert dom.dismissed_non_pol == []

    def test_a_foreign_row_never_trips_the_v0_halt(self):
        """INTL.POL.04 a dismissed foreign row is gone before the V0 check, so
        it cannot halt the event; a Polish V0 row in an IMSW event still does."""
        ctx = _ctx([_row("YOUNG Foreigner", 1, "FRA")], "IMSW-2025-2026")
        ctx.is_combined_pool = True
        ctx.splits = {"V0": list(ctx.parsed.results)}
        s6_resolve_identity(ctx, _db())
        assert ctx.matches == []

        pole = _ctx([_row("NOWAK Adam", 1, "POL")], "IMSW-2025-2026")
        pole.is_combined_pool = True
        pole.splits = {"V0": list(pole.parsed.results)}
        with pytest.raises(HaltError):
            s6_resolve_identity(pole, _db())

    def test_the_count_check_counts_dismissed_rows(self):
        """INTL.POL.05 S7 compares matches + dismissed with the source bracket:
        2 Poles and 58 dismissed rows of a 60-fencer bracket pass."""
        rows = [_row("NOWAK Adam", 31, "POL"), _row("KOWALSKI Jan", 48, "POL")]
        rows += [_row(f"FOREIGN {i}", i, "ITA") for i in range(1, 61) if i not in (31, 48)]
        ctx = _ctx(rows, "PEW3-2025-2026", raw_pool_size=60)
        s6_resolve_identity(ctx, _db())
        ctx.event = None  # count check only: URL-to-data needs a canonical event row
        s7_validate(ctx, MagicMock())
        assert ctx.count_validation == {"expected": 60, "actual": 60, "ok": True}


class TestNewPipeline:
    def test_resolve_fencers_dismisses_foreign_rows(self):
        """INTL.POL.06 ResolveFencers dismisses the foreign namesake of an EVF
        event before the exact and fuzzy phases: no link, no fencer created;
        a domestic event is unchanged."""
        from python.pipeline.core.contract import Context, Services
        from python.pipeline.plugins.bridge import LEGACY
        from python.pipeline.plugins.resolve_fencers import ResolveFencers

        def run(code, rows):
            pctx = _ctx(rows, code)
            ctx = Context()
            ctx.data[LEGACY] = pctx
            ctx.data["parsed"] = pctx.parsed
            ctx.data["event"] = pctx.event
            db = _db()
            plugin = ResolveFencers()
            ctx._begin(plugin)
            plugin.run(ctx, Services(db=db))
            ctx._end()
            return pctx, db

        pctx, db = run(
            "PEW3-2025-2026", [_row("KOWALSKI Jan", 3, "GER"), _row("NOWAK Adam", 7, "POL")]
        )
        assert [(m.scraped_name, m.id_fencer) for m in pctx.matches] == [("NOWAK Adam", 43)]
        assert [d["name"] for d in pctx.dismissed_non_pol] == ["KOWALSKI Jan"]
        db.insert_fencer.assert_not_called()

        pctx, _ = run(
            "PPW3-2025-2026", [_row("KOWALSKI Jan", 3, "GER"), _row("NOWAK Adam", 7, "POL")]
        )
        assert {m.id_fencer for m in pctx.matches} == {42, 43}
        assert pctx.dismissed_non_pol == []


# ---------------------------------------------------------------------------
# INTL.DRAFT — the Phase 5 draft writer files an international bracket whole
# ---------------------------------------------------------------------------


def _session(event_code):
    from python.pipeline.review_cli import ReviewSession

    session = ReviewSession(
        event_code=event_code,
        db=MagicMock(),
        draft_store=MagicMock(),
        prompt=lambda *_a, **_k: "",
        output=lambda *_a, **_k: None,
        fetcher=MagicMock(),
    )
    session.skip_url_validation = True
    return session


def _match(id_fencer, place, method="AUTO_MATCHED"):
    from python.pipeline.types import StageMatchResult

    return StageMatchResult(
        scraped_name=f"POLE {id_fencer}",
        place=place,
        id_fencer=id_fencer,
        confidence=99.0,
        method=method,
    )


def _draft_ctx(code, *, category_hint: str | None = "V2", n=60, matches=(), vcat_groups=None):
    from datetime import date

    rows = [_row(f"R{p}", p, "ITA") for p in range(1, n + 1)]
    parsed = ParsedTournament(
        source_kind=SourceKind.FTL,
        results=rows,
        raw_pool_size=n,
        parsed_date=date(2025, 11, 12),
        weapon="EPEE",
        gender="F",
        category_hint=category_hint,
        season_end_year=2026,
        source_url="https://example.test/vet50we",
    )
    ctx = PipelineContext(parsed=parsed, overrides=Overrides(), season_end_year=2026)
    ctx.event = {"id_event": 9, "txt_code": code}
    ctx.matches = list(matches)
    ctx.vcat_groups = vcat_groups if vcat_groups is not None else {}
    ctx.is_joint_pool = len(ctx.vcat_groups) >= 2
    return ctx


class TestDraftWriter:
    def test_one_draft_tournament_at_the_source_size(self):
        """INTL.DRAFT.01 an international bracket becomes ONE draft tournament
        in its source category with N = the whole bracket (60), even when the
        Poles' birth years point to two categories."""
        a, b = _match(11, 31), _match(12, 48)
        ctx = _draft_ctx("IMSW-2025-2026", matches=[a, b], vcat_groups={"V2": [a], "V3": [b]})
        rows = _session("IMSW-2025-2026")._build_tournament_draft_rows(ctx)
        assert [
            (r["enum_age_category"], r["int_participant_count"], r["bool_joint_pool_split"])
            for r in rows
        ] == [("V2", 60, False)]

    def test_every_pole_keeps_the_source_place(self):
        """INTL.DRAFT.02 every matched or pending Pole is written to that one
        tournament at their source place, labelled with the source category;
        a Pole with no birth year (left out of the split) is written too; an
        EXCLUDED row is not."""
        a, b = _match(11, 31), _match(12, 48)
        nob = _match(13, 52)  # no birth year: s7 leaves it out of vcat_groups
        pending = _match(14, 55, method="PENDING")
        excluded = _match(None, 57, method="EXCLUDED")
        ctx = _draft_ctx(
            "PEW3-2025-2026",
            matches=[a, b, nob, pending, excluded],
            vcat_groups={"V2": [a], "V3": [b]},
        )
        rows = _session("PEW3-2025-2026")._build_result_draft_rows(ctx, {"V2": 701})
        assert [
            (
                r["id_fencer"],
                r["int_place"],
                r["id_tournament_draft"],
                r["enum_source_age_category"],
            )
            for r in rows
        ] == [
            (11, 31, 701, "V2"),
            (12, 48, 701, "V2"),
            (13, 52, 701, "V2"),
            (14, 55, 701, "V2"),
        ]

    def test_no_source_category_is_refused_and_domestic_is_unchanged(self):
        """INTL.DRAFT.03 an international bracket with no single source
        category is refused, because no category may be invented from a birth
        year; a domestic bracket still drafts per V-cat group with its own
        count (ADR-049)."""
        ctx = _draft_ctx("PEW3-2025-2026", category_hint=None, matches=[_match(11, 31)])
        with pytest.raises(ValueError, match="source category"):
            _session("PEW3-2025-2026")._build_tournament_draft_rows(ctx)

        a, b = _match(11, 1), _match(12, 2)
        dom = _draft_ctx("PPW3-2025-2026", n=10, matches=[a, b], vcat_groups={"V2": [a], "V3": [b]})
        rows = _session("PPW3-2025-2026")._build_tournament_draft_rows(dom)
        assert sorted((r["enum_age_category"], r["int_participant_count"]) for r in rows) == [
            ("V2", 1),
            ("V3", 1),
        ]


# ---------------------------------------------------------------------------
# INTL.URL — the new pipeline's event URL path refuses international events
# ---------------------------------------------------------------------------


class TestEventUrlPath:
    @pytest.mark.parametrize("code", ["PEW3-2025-2026", "IMSW-2025-2026", "MEW-2026-2027"])
    def test_an_international_event_is_refused_before_any_write(self, code):
        """INTL.URL.01 ingest_event_from_url treats every event as domestic, so
        it refuses an international one and names the Phase 5 runner. Nothing
        is written, not even the URL override, and no source is fetched."""
        from python.pipeline.ingest_cli import ingest_event_from_url

        db = MagicMock()
        db.find_event_by_code.return_value = {"id_event": 1, "txt_code": code}
        with pytest.raises(ValueError, match="phase5"):
            ingest_event_from_url(code, 2026, db=db, url_event_override="https://example.test/e")
        db.set_event_url_event.assert_not_called()

    def test_a_domestic_event_is_not_refused(self, monkeypatch):
        """INTL.URL.01 a domestic event still reaches the source fetch."""
        from python.pipeline.ingest_cli import ingest_event_from_url
        from python.scrapers import ftl_auth

        class Reached(Exception):
            pass

        def boom(*_a, **_k):
            raise Reached

        monkeypatch.setattr(ftl_auth, "get_authed_ftl_client", boom)
        db = MagicMock()
        db.find_event_by_code.return_value = {
            "id_event": 1,
            "txt_code": "PPW3-2025-2026",
            "url_event": "https://example.test/e",
        }
        with pytest.raises(Reached):
            ingest_event_from_url("PPW3-2025-2026", 2026, db=db)


# ---------------------------------------------------------------------------
# INTL.SCRAPE — scrape_tournament ingests an international bracket whole
# ---------------------------------------------------------------------------


class TestScrapeTournament:
    def _anchor(self, ttype, cat="V2"):
        return {
            "id_tournament": 501,
            "txt_code": f"X-{cat}-F-EPEE-2025-2026",
            "enum_type": ttype,
            "enum_age_category": cat,
        }

    def test_an_international_bracket_is_one_bucket_at_the_source_size(self):
        """INTL.SCRAPE.01 an international tournament is not split by birth
        year or re-ranked: every scraped row goes to its own category at the
        scraped place, and N is the whole scraped bracket (60)."""
        from python.tools.scrape_tournament import international_bucket

        rows = [{"fencer_name": f"R{p}", "place": p, "country": "ITA"} for p in range(1, 61)]
        anchor = self._anchor("MSW")
        cat, bucket, n = international_bucket(anchor, [anchor], rows)  # type: ignore[misc]
        assert (cat, n, [r["place"] for r in bucket][:3]) == ("V2", 60, [1, 2, 3])
        assert len(bucket) == 60

    def test_shared_urls_are_refused_and_domestic_is_unchanged(self):
        """INTL.SCRAPE.01 an international tournament sharing its URL with a
        sibling is refused (one tournament is one source bracket); a domestic
        tournament returns None and keeps the per-V-cat split."""
        from python.tools.scrape_tournament import international_bucket

        rows = [{"fencer_name": "A", "place": 1, "country": "POL"}]
        a, b = self._anchor("PEW", "V2"), self._anchor("PEW", "V3")
        with pytest.raises(ValueError, match="one source bracket"):
            international_bucket(a, [a, b], rows)
        assert international_bucket(self._anchor("PPW"), [self._anchor("PPW")], rows) is None


# ---------------------------------------------------------------------------
# INTL.INV.02 — the staging summary shows every international bracket's size
# ---------------------------------------------------------------------------


class TestStagingSummary:
    def _ctx(self, n, poles, dismissed_country: str | None = "ITA"):
        rows = [
            _row(f"R{p}", p, "POL" if p in poles else dismissed_country) for p in range(1, n + 1)
        ]
        ctx = _ctx(rows, "IMSW-2025-2026", raw_pool_size=n)
        s6_resolve_identity(ctx, MagicMock(fetch_fencer_db=MagicMock(return_value=[])))
        return ctx.parsed, ctx

    def test_each_bracket_lists_n_highest_place_poles_and_dismissed(self):
        """INTL.INV.02 per international bracket the summary shows the source
        N, the highest place, the Polish rows, how many are linked (none here:
        the roster is empty and an international Pole is never auto-created)
        and the rows dismissed; a bracket whose N equals its Polish rows is
        flagged, and so is one where every row was dismissed for having no
        country."""
        from python.tools.phase5_runner import _format_international_section

        ok = self._ctx(60, {31, 48})
        suspicious = self._ctx(2, {1, 2})
        no_country = self._ctx(5, set(), dismissed_country=None)
        lines = _format_international_section(
            "IMSW-2025-2026",
            [
                (1, ok[0], ok[1], None),
                (1, suspicious[0], suspicious[1], None),
                (1, no_country[0], no_country[1], None),
            ],
        )
        text = "\n".join(lines)
        assert "| V2 | EPEE | M | 60 | 60 | 2 | 0 | 58 | ✓ |" in text
        assert "N equals the POL rows" in text
        assert "no country" in text

    def test_a_domestic_event_has_no_section(self):
        """INTL.INV.02 a domestic event gets no international section."""
        from python.tools.phase5_runner import _format_international_section

        assert _format_international_section("PPW3-2025-2026", []) == []


# ---------------------------------------------------------------------------
# INTL.SCHED / INTL.DRAFT.04 — found replaying MSW Manama on LOCAL (1 Oct 2026)
# ---------------------------------------------------------------------------


class TestTeamBracketsAndDuplicateCodes:
    @pytest.mark.parametrize(
        "name",
        [
            "Vet  Team Men's Épée",
            "Vet Team Women's Saber",
            "Szpada drużynowa mężczyzn",
            "Équipe Fleuret Dames",
        ],
    )
    def test_team_brackets_are_skipped_at_discovery(self, name):
        """INTL.SCHED.01 a team bracket is skipped when the schedule is read:
        it lists teams, not individual places. FTL's MSW Manama schedule lists
        "Vet Team …" next to every "Vet-40 …" bracket; both parsed as V1 and
        were merged into one draft (a team row "POL" even matched a fencer)."""
        from python.tools.scrape_ftl_event_urls import _skip_reason, parse_tournament_name

        assert _skip_reason(name) == "team event (not an individual result)"
        assert parse_tournament_name(name) is None

    @pytest.mark.parametrize(
        "name", ["Vet-40   Men's Épée", "Szpada mężczyzn kat. 2", "Vet-70 Women's Foil"]
    )
    def test_individual_brackets_are_kept(self, name):
        """INTL.SCHED.01 an individual bracket is not mistaken for a team."""
        from python.tools.scrape_ftl_event_urls import _skip_reason

        assert _skip_reason(name) is None

    def _sb(self, drafts, results_per_draft):
        """A Supabase client mock whose table mocks are cached per name, so a
        test can assert what was (not) updated or deleted."""
        tables: dict[str, MagicMock] = {}

        def table(name):
            if name in tables:
                return tables[name]
            t = MagicMock()
            if name == "tbl_tournament_draft":
                t.select.return_value.eq.return_value.execute.return_value.data = drafts
            else:

                def eq(_col, draft_id):
                    q = MagicMock()
                    q.execute.return_value.data = [{}] * results_per_draft[draft_id]
                    return q

                t.select.return_value.eq.side_effect = eq
            tables[name] = t
            return t

        sb = MagicMock()
        sb.table.side_effect = table
        return sb, tables

    def test_an_international_duplicate_code_is_refused_not_merged(self):
        """INTL.DRAFT.04 two source brackets mapping to one tournament code of
        an international event are refused: merging would put two brackets'
        places under one N, and the merge recounted N to the Poles kept."""
        from python.tools.phase5_runner import _consolidate_duplicate_codes

        drafts = [
            {
                "id_tournament_draft": 1,
                "txt_code": "IMSW-V4-M-EPEE-2025-2026",
                "bool_joint_pool_split": False,
                "url_results": "https://ftl/vet70",
            },
            {
                "id_tournament_draft": 2,
                "txt_code": "IMSW-V4-M-EPEE-2025-2026",
                "bool_joint_pool_split": False,
                "url_results": "https://ftl/vet80",
            },
        ]
        sb, tables = self._sb(drafts, {1: 2, 2: 1})
        with pytest.raises(ValueError, match="one source bracket"):
            _consolidate_duplicate_codes(MagicMock(_sb=sb), "run", international=True)
        for t in tables.values():
            t.update.assert_not_called()
            t.delete.assert_not_called()

    def test_a_domestic_duplicate_code_still_merges(self):
        """INTL.DRAFT.04 a domestic event still merges duplicate codes and
        counts the merged rows (ADR-056 revision), unchanged."""
        from python.tools.phase5_runner import _consolidate_duplicate_codes

        drafts = [
            {
                "id_tournament_draft": 1,
                "txt_code": "GP1-V2-M-SABRE-2023-2024",
                "bool_joint_pool_split": False,
                "url_results": "u1",
            },
            {
                "id_tournament_draft": 2,
                "txt_code": "GP1-V2-M-SABRE-2023-2024",
                "bool_joint_pool_split": False,
                "url_results": "u2",
            },
        ]
        sb, tables = self._sb(drafts, {1: 8, 2: 2})
        assert _consolidate_duplicate_codes(MagicMock(_sb=sb), "run") == 1
        tables["tbl_tournament_draft"].update.assert_called_with({"int_participant_count": 10})


# ---------------------------------------------------------------------------
# INTL.S0 — Stage 0 never creates a fencer for an international event
# ---------------------------------------------------------------------------


class TestStageZero:
    @pytest.mark.parametrize("code", ["IMSW-2025-2026", "IMEW-2024-2025", "PEW3-2025-2026"])
    def test_no_fencer_is_created_for_an_international_event(self, code):
        """INTL.S0.01 s0_reconcile_roster skips an international event entirely
        (ADR-038 amendment 2026-06-13). The skip was keyed on the organizer
        prefix, so IMSW/IMEW passed and Stage 0 created every participant of
        MSW Manama, foreign ones included (LOCAL, 1 October 2026: 911 fencers
        in one staging run)."""
        from python.pipeline.stages import s0_reconcile_roster

        ctx = _ctx([_row("DUPONT Jean", 1, "FRA"), _row("NOWAK Nowy", 2, "POL")], code)
        ctx.event_code = code
        db = MagicMock()
        db.fetch_fencer_db.return_value = []
        s0_reconcile_roster(ctx, db)
        db.insert_fencer.assert_not_called()
        assert ctx.created_fencers == []
