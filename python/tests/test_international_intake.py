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


class TestNationalityOverride:
    """P3.OV17 — a nationality entry in the event's override file fills a
    blank nationality and never replaces one the source prints (ADR-105 §1.1,
    decision C A, 2 Oct 2026). Budapest 2025's V1 men's épée page is headed
    Club: BOBUSIA Jarosław (POL at EVF) is named; KULKA Dawid, on our roster as
    PL, entered for Ireland and is not."""

    @staticmethod
    def _rows():
        return [_row("NOWAK Adam", 5, None), _row("KOWALSKI Jan", 6, "IRL")]

    @staticmethod
    def _overrides():
        from python.pipeline.types import NationalityOverride

        return Overrides(
            nationality=[
                NationalityOverride("NOWAK Adam", "POL", "EVF: 5th of 33, POL"),
                NationalityOverride("KOWALSKI Jan", "POL", "never replaces a printed IRL"),
            ]
        )

    def _assert_outcome(self, pctx):
        assert [(m.scraped_name, m.id_fencer) for m in pctx.matches] == [("NOWAK Adam", 43)]
        assert pctx.dismissed_non_pol == [{"name": "KOWALSKI Jan", "place": 6, "country": "IRL"}]
        assert pctx.nationality_from_override == [
            {"name": "NOWAK Adam", "place": 5, "country": "POL"}
        ]

    def test_old_pipeline_fills_a_blank_never_a_printed_nationality(self):
        """P3.OV17 s6_resolve_identity: the named row with no country is kept
        and matched; the named row printed IRL is still dismissed."""
        ctx = _ctx(self._rows(), "PEW1efs-2025-2026")
        ctx.overrides = self._overrides()
        s6_resolve_identity(ctx, _db())
        self._assert_outcome(ctx)

    def test_new_pipeline_fills_a_blank_never_a_printed_nationality(self):
        """P3.OV17 ResolveFencers: the same."""
        from python.pipeline.core.contract import Context, Services
        from python.pipeline.plugins.bridge import LEGACY
        from python.pipeline.plugins.resolve_fencers import ResolveFencers

        pctx = _ctx(self._rows(), "PEW1efs-2025-2026")
        pctx.overrides = self._overrides()
        ctx = Context()
        ctx.data[LEGACY] = pctx
        ctx.data["parsed"] = pctx.parsed
        ctx.data["event"] = pctx.event
        db = _db()
        plugin = ResolveFencers()
        ctx._begin(plugin)
        plugin.run(ctx, Services(db=db))
        ctx._end()
        self._assert_outcome(pctx)
        db.insert_fencer.assert_not_called()


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
        """INTL.DRAFT.02 every linked Pole is written to that one tournament
        at their source place, labelled with the source category; a Pole with
        no birth year (left out of the split) is written too. An EXCLUDED row
        is not, and neither is a PENDING one (amended 2 Oct 2026): its fencer
        is the matcher's guess, and the commit would credit the result to that
        guess (Jabłonna 2025: BISKUPSKI Marek guessed as MIKULICKI). It is
        reported in the staging summary instead; N stays the whole bracket."""
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

    def test_a_bracket_without_a_country_column_is_flagged(self):
        """INTL.INV.03 a bracket whose source prints no country (Budapest 2025,
        V1 men's épée, headed Club) is flagged with how many fencers the
        override file names, even when one of them is kept."""
        from python.pipeline.types import NationalityOverride
        from python.tools.phase5_runner import _format_international_section

        ctx = _ctx(
            [_row(f"R{p}", p, None) for p in range(1, 6)], "PEW1efs-2025-2026", raw_pool_size=5
        )
        ctx.overrides = Overrides(nationality=[NationalityOverride("R5", "POL", "EVF")])
        s6_resolve_identity(ctx, MagicMock(fetch_fencer_db=MagicMock(return_value=[])))
        text = "\n".join(
            _format_international_section("PEW1efs-2025-2026", [(1, ctx.parsed, ctx, None)])
        )
        assert "the source has no country" in text
        assert "1 named in the override file" in text

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

    @staticmethod
    def _schedule(*names: str) -> str:
        links = "".join(f'<a href="/events/view/U{i:03d}">{n}</a>' for i, n in enumerate(names))
        return f"<html><body>{links}</body></html>"

    def test_category_first_names_are_brackets_not_guests(self):
        """INTL.SCHED.02 EVF Circuit Jabłonna 2025 names its brackets with the
        category first ("V2 Szpada Mężczyzn"). The guest-event guard (5.21)
        skipped all 24 of them; a real guest event is still skipped."""
        from python.tools.scrape_ftl_event_urls import parse_event_schedule

        kept, skipped = parse_event_schedule(
            self._schedule(
                "V2 Szpada Mężczyzn", "V4 Szabla Kobiet", "Akademickie Mistrzostwa Warszawy"
            ),
            with_skips=True,
        )
        assert [e["name"] for e in kept] == ["V2 Szpada Mężczyzn", "V4 Szabla Kobiet"]
        assert [s["name"] for s in skipped] == ["Akademickie Mistrzostwa Warszawy"]

    def test_a_pool_round_is_skipped_when_its_categories_have_brackets(self):
        """INTL.SCHED.03 a joint pool round ("Szpada Kobiet V3, V4 - runda
        grupowa") is not a result when the same weapon and gender have their
        own category brackets on the schedule; those are the results. A pool
        round with no category bracket beside it is kept."""
        from python.tools.scrape_ftl_event_urls import parse_event_schedule

        kept, skipped = parse_event_schedule(
            self._schedule(
                "Szpada Kobiet V3, V4 - runda grupowa",
                "V3 Szpada Kobiet",
                "V4 Szpada Kobiet",
                "Floret Mężczyzn V3, V4 - runda grupowa",
            ),
            with_skips=True,
        )
        assert [e["name"] for e in kept] == [
            "V3 Szpada Kobiet",
            "V4 Szpada Kobiet",
            "Floret Mężczyzn V3, V4 - runda grupowa",
        ]
        assert [(s["name"], s["reason"]) for s in skipped] == [
            (
                "Szpada Kobiet V3, V4 - runda grupowa",
                "pool round (its categories have their own brackets)",
            )
        ]

    def test_a_bracket_listed_for_two_days_is_one_bracket(self):
        """INTL.SCHED.04 FTL lists a two-day bracket twice, "(Day 1)" and
        "(Day 2)", with the same link (EMW Plovdiv 2025, men's épée V1–V3).
        One link is one bracket: it is read once. The repeat is not a skip, so
        it does not count as a pool round."""
        from python.tools.scrape_ftl_event_urls import parse_event_schedule

        html = (
            '<a href="/events/view/C69C">Vet-60 Men\'s Epee EM3\n (Day 1)</a>'
            '<a href="/events/view/D3C6">Vet-60 Women\'s Epee EW3</a>'
            '<a href="/events/view/C69C">Vet-60 Men\'s Epee EM3\n (Day 2)</a>'
        )
        kept, skipped = parse_event_schedule(html, with_skips=True)
        assert [e["uuid"] for e in kept] == ["C69C", "D3C6"]
        assert skipped == []

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


class TestRepairRunner:
    """The runner steps the international data repair needs
    (doc/plans/international-data-repair-batch-1-2026-10-01.html)."""

    def test_a_weapon_outside_the_event_is_skipped(self):
        """INTL.WPN.01 an international bracket whose weapon is not one of
        the event's weapons is skipped with a reason: EVF Circuit Jabłonna
        2025 is épée and sabre, its organiser's schedule also has foil
        (decision F A, 2 Oct 2026). A domestic event, and a bracket with no
        weapon, are never skipped this way."""
        from types import SimpleNamespace

        from python.tools.phase5_runner import _weapon_outside_event

        jab = {"txt_code": "PEW7es-2024-2025", "arr_weapons": ["EPEE", "SABRE"]}
        foil = SimpleNamespace(weapon="FOIL")
        assert "FOIL" in (_weapon_outside_event(foil, jab) or "")
        assert _weapon_outside_event(SimpleNamespace(weapon="EPEE"), jab) is None
        assert _weapon_outside_event(SimpleNamespace(weapon=None), jab) is None
        assert (
            _weapon_outside_event(foil, {"txt_code": "PPW1-2026-2027", "arr_weapons": ["EPEE"]})
            is None
        )
        # No stored weapons: the PEW code's letters decide.
        assert _weapon_outside_event(foil, {"txt_code": "PEW7es-2024-2025", "arr_weapons": None})

    def test_wrong_match_pairs_are_not_flushed_for_an_international_event(self):
        """INTL.ALIAS.01 the stage-time alias flush writes no ❌ pair for an
        international event (decision W A, 2 Oct 2026): staging Jabłonna 2025
        wrote "BISKUPSKI Marek" onto MIKULICKI, and a later run would match by
        that alias. ✓ and ❓ pairs are still written; a domestic event keeps
        the Option-1 behaviour."""
        from types import SimpleNamespace

        from python.tools.phase5_runner import _stage_flush_pairs

        pairs = [SimpleNamespace(icon=i) for i in ("✓", "❓", "❌")]
        assert [p.icon for p in _stage_flush_pairs(pairs, international=True)] == ["✓", "❓"]
        assert [p.icon for p in _stage_flush_pairs(pairs, international=False)] == [
            "✓",
            "❓",
            "❌",
        ]

    def test_replace_event_commits_through_the_atomic_replace(self):
        """REPAIR.RUN.01 with --replace-event the commit calls
        fn_replace_event_from_draft (rollback by exact code and commit in one
        transaction); without it, fn_commit_event_draft as before. A replace
        needs the exact event code."""
        from python.tools.phase5_runner import _commit_run

        db = MagicMock()
        _commit_run(db, "run-1", "PEW7es-2024-2025", replace=True)
        db._sb.rpc.assert_called_once_with(
            "fn_replace_event_from_draft",
            {"p_event_code": "PEW7es-2024-2025", "p_run_id": "run-1"},
        )
        db = MagicMock()
        _commit_run(db, "run-1", None, replace=False)
        db._sb.rpc.assert_called_once_with("fn_commit_event_draft", {"p_run_id": "run-1"})
        with pytest.raises(ValueError, match="event code"):
            _commit_run(MagicMock(), "run-1", None, replace=True)

    def test_sign_off_refuses_unresolved_rows(self):
        """REPAIR.RUN.02 a draft row with a fencer and no match method is an
        unresolved PENDING guess; sign-off lists it and refuses, for every
        event, because the commit would credit the result to the guess. The
        sign-off check that blocks ❌ pairs reads linked rows only, so these
        passed it."""
        from python.tools.phase5_runner import _unresolved_draft_rows

        db = MagicMock()
        q = db._sb.table.return_value.select.return_value.eq.return_value
        q.execute.return_value.data = [
            {"id_fencer": 100, "txt_scraped_name": "BISKUPSKI Marek", "enum_match_method": None},
            {
                "id_fencer": 109,
                "txt_scraped_name": "SZKODA Marek",
                "enum_match_method": "AUTO_MATCH",
            },
            {"id_fencer": None, "txt_scraped_name": "X", "enum_match_method": None},
        ]
        assert _unresolved_draft_rows(db, "run-1") == [
            {"id_fencer": 100, "txt_scraped_name": "BISKUPSKI Marek", "enum_match_method": None}
        ]

    def test_staging_writes_aliases_only_from_confirmed_matches(self):
        """INTL.ALIAS.02 for an international event the stage-time flush
        takes only AUTO_MATCHED rows: a PENDING row's fencer is a guess, and
        its pair can look like a typo to the checker ("ŁOJAK Szymon" →
        NOWAK Szymon, Jabłonna 2026). A domestic event keeps every row with a
        fencer (Option-1)."""
        from types import SimpleNamespace

        from python.tools.phase5_runner import _flush_source_matches

        auto = SimpleNamespace(id_fencer=1, method="AUTO_MATCHED")
        guess = SimpleNamespace(id_fencer=2, method="PENDING")
        none = SimpleNamespace(id_fencer=None, method="EXCLUDED")
        assert _flush_source_matches([auto, guess, none], international=True) == [auto]
        assert _flush_source_matches([auto, guess, none], international=False) == [auto, guess]
