"""SRC.CONS — what a source states twice, compared and reported (ADR-119 G42 A).

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, G42 and the
push 2b build sheet (2b.1–2b.12).

Organisers state a bracket's label twice, picked from a list and typed into a
title; Madrid 2026 declared sabre under "EPEE MALE 2" (WPN.TITLE), and Budapest
2025 declared women under "Men's Epee V4 (70)". The readers choose one
statement, and before G42 only the weapon's choice was reported. G42 reports
every disagreement on the bracket (`ParsedTournament.source_disagreements`),
changes no choice, holds no event and stops no write (2b.1):

  SRC.CONS.01  the places of a whole bracket are 1..N, ties allowed;
  SRC.CONS.02  a bracket in which no row has a country is reported;
  SRC.CONS.03  Engarde: the count it prints against the rows it lists;
  SRC.CONS.04  Engarde: gender (sexe against the title) and category
               (the slug against the title), on the real fixtures;
  SRC.CONS.05  d'Artagnan: the declared line's gender against the <h3>;
  SRC.CONS.06  FencingTime XML: Sexe against AltName's gender word;
  SRC.CONS.08  the fetcher carries a competition's disagreements onto its
               bracket;
  SRC.CONS.09  the read's log names no one; the staging report's gaps and
               the run record list every disagreement;
  SRC.CONS.10  a disagreement is not part of a listing's hash.

SRC.CONS.07 (EVF's results API) waits for G58.
"""

from __future__ import annotations

import re
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from python.pipeline import source_consistency as sc
from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind

FIXTURES = Path(__file__).parent / "fixtures"
ENGARDE = FIXTURES / "engarde"


def _rows(places, countries=None):
    countries = countries or ["POL"] * len(places)
    return [
        ParsedResult(source_row_id=str(i), fencer_name=f"SURNAME{i} Jan", place=p, fencer_country=c)
        for i, (p, c) in enumerate(zip(places, countries, strict=True))
    ]


def _bracket(places, countries=None, kind=SourceKind.ENGARDE, **kw):
    return ParsedTournament(source_kind=kind, results=_rows(places, countries), **kw)


# --------------------------------------------------------------------------
# SRC.CONS.01 — places
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    "places",
    [[1, 2, 3, 4], [1, 2, 3, 3, 5, 6], [1, 1, 3], [2, 1, 3, 3], [], [1]],
)
def test_SRC_CONS_01_places_one_to_n_with_ties_agree(places):
    assert sc.places(_rows(places)) is None


@pytest.mark.parametrize(
    ("places", "detail"),
    [
        ([1, 2, 4], "after 2 row(s) the next place is 4, not 3"),
        ([2, 3, 4], "after 0 row(s) the next place is 2, not 1"),
        ([1, 2, 3, 3, 4], "after 4 row(s) the next place is 4, not 5"),
    ],
)
def test_SRC_CONS_01_a_gap_or_a_wrong_tie_is_reported(places, detail):
    got = sc.places(_rows(places))
    assert got == {"kind": sc.PLACES, "detail": f"places are not 1..{len(places)}: {detail}"}


def test_SRC_CONS_01_unplaced_and_excluded_rows_are_aside():
    rows = _rows([1, 2, 0, 3])
    rows.append(ParsedResult(source_row_id="x", fencer_name="X Y", place=9, bool_excluded=True))
    assert sc.places(rows) is None


def test_SRC_CONS_01_an_evf_bracket_is_whole_and_checked():
    """EVF's API returns a competition's full results (`EvfApiClient.get_results`),
    so its places are checked as any engine's (2b.3 corrected, 1 Nov)."""
    assert sc.of(_bracket([3, 7], kind=SourceKind.EVF_API)) == [sc.places(_rows([3, 7]))]
    assert sc.of(_bracket([1, 2], kind=SourceKind.EVF_API)) == []


# --------------------------------------------------------------------------
# SRC.CONS.02 — no nationality
# --------------------------------------------------------------------------


def test_SRC_CONS_02_a_bracket_without_any_country_is_reported():
    got = sc.nationality(_rows([1, 2, 3], [None, None, ""]))
    assert got == {
        "kind": sc.NATIONALITY,
        "detail": "none of the 3 rows has a country: admission decides each by identity alone",
    }
    assert sc.nationality(_rows([1, 2], [None, "HUN"])) is None
    assert sc.nationality([]) is None


def test_SRC_CONS_02_a_domestic_bracket_is_never_checked_for_countries():
    """SPWS and PZSz admit every participant: a missing country decides nothing."""
    bracket = _bracket([1, 2], [None, None])
    assert sc.of(bracket, international=False) == []
    assert [d["kind"] for d in sc.of(bracket)] == [sc.NATIONALITY]


def test_SRC_CONS_02_checked_puts_the_list_on_the_bracket_once():
    bracket = sc.checked(_bracket([1, 3], source_disagreements=[{"kind": "x", "detail": "y"}]))
    assert [d["kind"] for d in bracket.source_disagreements] == ["x", sc.PLACES]
    assert sc.lines("B", bracket) == [
        "  disagree 'B': x: y",
        "  disagree 'B': places: places are not 1..2: after 1 row(s) the next place is 3, not 2",
    ]


def test_SRC_CONS_02_the_budapest_club_page_has_no_nationality_column():
    from python.scrapers.engarde import parse_html

    parsed = parse_html((ENGARDE / "clasfinal_hunfencing_club.html").read_text(encoding="utf-8"))
    assert [d["kind"] for d in sc.of(parsed)] == [sc.NATIONALITY]


# --------------------------------------------------------------------------
# SRC.CONS.03 — Engarde's printed count
# --------------------------------------------------------------------------


@pytest.mark.parametrize("path", sorted(ENGARDE.glob("*.html")), ids=lambda p: p.name)
def test_SRC_CONS_03_every_engarde_fixture_lists_what_it_prints(path):
    from python.scrapers.engarde import parse_html

    parsed = parse_html(path.read_text(encoding="utf-8"))
    assert not [d for d in parsed.source_disagreements if d["kind"] == sc.COUNT]


def test_SRC_CONS_03_a_page_listing_fewer_than_it_prints_is_reported():
    from python.scrapers.engarde import parse_html

    html = (ENGARDE / "clasfinal_hunfencing.html").read_text(encoding="utf-8")
    html = html.replace("(57 fencers)", "(59 fencers)")
    parsed = parse_html(html)
    assert parsed.source_disagreements == [
        {"kind": sc.COUNT, "detail": "the source prints 59 fencer(s) and lists 57"}
    ]
    assert parsed.raw_pool_size == 57  # N is the placed rows, as before


def test_SRC_CONS_03_the_unplaced_rows_count_as_listed():
    """Criterium 2026 foil V2 prints 33 and lists 33, one of them unplaced."""
    from python.scrapers.engarde import parse_html

    parsed = parse_html((ENGARDE / "competition_crit26_fhv2.html").read_text(encoding="utf-8"))
    assert parsed.raw_pool_size == 32
    assert parsed.source_disagreements == []


# --------------------------------------------------------------------------
# SRC.CONS.04 — Engarde gender and category
# --------------------------------------------------------------------------


def _finals(xml_name, org="o", event="e"):
    from python.scrapers.engarde import parse_competition_list

    kept, _ = parse_competition_list((ENGARDE / xml_name).read_text(encoding="utf-8"), org, event)
    return {k["slug"]: k for k in kept}


def test_SRC_CONS_04_budapest_men_s_epee_v4_declared_women():
    final = _finals("competitions_budapest.xml")["me70"]
    assert final["gender"] == "M"  # the title wins, as before
    assert final["disagreements"] == [
        {
            "kind": sc.GENDER,
            "detail": 'title "Men\'s Epee V4 (70)" says M; the source declared F; the title wins',
        }
    ]


def test_SRC_CONS_04_madrid_2024_women_s_sabre_declared_men():
    finals = _finals("competitions_madrid2024.xml")
    for slug in ("t-sf-1", "t-sf-2"):
        assert finals[slug]["gender"] == "F"
        assert [d["kind"] for d in finals[slug]["disagreements"]] == [sc.GENDER]
        assert "the source declared M; the title wins" in finals[slug]["disagreements"][0]["detail"]


def test_SRC_CONS_04_agreeing_finals_carry_no_disagreement():
    for name in ("competitions_crit26.xml", "competitions_madrid.xml", "competitions_sivo2025.xml"):
        for final in _finals(name).values():
            assert "disagreements" not in final, (name, final["slug"])


def test_SRC_CONS_04_a_slug_naming_another_category_is_reported():
    from python.scrapers.engarde import parse_competition_list

    xml = (
        '<compes><comp compe="ehv1" arme="e" sexe="m" etat="completed" '
        'estindividuelle="1" date="2026 11 14"><titre>Men\'s Epee V2</titre></comp></compes>'
    )
    (final,), _ = parse_competition_list(xml, "o", "e")
    assert final["category"] == "V2"
    assert final["disagreements"] == [
        {
            "kind": sc.CATEGORY,
            "detail": 'title "Men\'s Epee V2" says V2; the source declared V1; the title wins',
        }
    ]


# --------------------------------------------------------------------------
# SRC.CONS.05 — d'Artagnan
# --------------------------------------------------------------------------


def test_SRC_CONS_05_dartagnan_declared_line_against_the_title():
    from python.scrapers.dartagnan import list_dartagnan_competitions

    html = (FIXTURES / "dartagnan" / "index.html").read_text(encoding="utf-8")
    changed = re.sub(r"(<h3>Men Epee V1</h3>\s*)männlich,", r"\1weiblich,", html, count=1)
    assert changed != html
    kept, _ = list_dartagnan_competitions(changed, "https://example.org/de/index.html")
    v1 = next(c for c in kept if c["title"] == "Men Epee V1")
    (d,) = v1["disagreements"]
    assert d["kind"] == sc.GENDER
    assert d["detail"].startswith("title 'Men Epee V1' says M; the source declared F; ")
    assert d["detail"].endswith(
        f"{'the title' if v1['gender'] == 'M' else 'the declared value'} wins"
    )


def test_SRC_CONS_05_the_dartagnan_fixture_agrees():
    from python.scrapers.dartagnan import list_dartagnan_competitions

    html = (FIXTURES / "dartagnan" / "index.html").read_text(encoding="utf-8")
    kept, _ = list_dartagnan_competitions(html, "https://example.org/de/index.html")
    assert kept and all("disagreements" not in c for c in kept)


# --------------------------------------------------------------------------
# SRC.CONS.06 — FencingTime XML
# --------------------------------------------------------------------------


def _xml(sexe: str, alt_name: str) -> bytes:
    raw = (FIXTURES / "fencingtime_xml" / "single_category.xml").read_text(encoding="utf-8")
    raw = re.sub(r'Sexe="[MF]"', f'Sexe="{sexe}"', raw, count=1)
    raw = raw.replace('AltName="SZPADA MĘŻCZYZN v2"', f'AltName="{alt_name}"', 1)
    return raw.encode("utf-8")


def test_SRC_CONS_06_xml_sexe_against_the_altname():
    from python.scrapers.fencingtime_xml import parse

    parsed = parse(_xml("F", "SZPADA MĘŻCZYZN v2"))
    assert parsed.gender == "M"  # AltName wins, as before
    assert parsed.source_disagreements == [
        {
            "kind": sc.GENDER,
            "detail": "title 'SZPADA MĘŻCZYZN v2' says M; the source declared F; the title wins",
        }
    ]


@pytest.mark.parametrize("name", ["single_category.xml", "combined_v0v1.xml", "no_dob.xml"])
def test_SRC_CONS_06_xml_fixtures_agree(name):
    from python.scrapers.fencingtime_xml import parse

    parsed = parse((FIXTURES / "fencingtime_xml" / name).read_bytes())
    assert [d for d in parsed.source_disagreements if d["kind"] == sc.GENDER] == []


# --------------------------------------------------------------------------
# SRC.CONS.07 — EVF's results API (G58 A)
# --------------------------------------------------------------------------


class _EvfClient:
    def __init__(self, competitions, results):
        self.competitions, self.results = competitions, results

    def get_competitions(self, _event_id):
        return self.competitions

    def get_results(self, comp_id):
        return self.results[comp_id]


def _evf_row(abbr, place):
    return {
        "weapon_abbr": abbr,
        "place": place,
        "country_abbr": "POL",
        "fencer_surname": "NOWAK",
        "fencer_firstname": "Jan",
        "fencer_dob": "",
        "total_points": 0,
    }


def test_SRC_CONS_07_an_unknown_abbreviation_keeps_its_competition_s_weapon():
    """G58 A: a row whose weapon_abbr is unknown took the previous row's weapon,
    not its competition's; each row now keeps what its competition declared."""
    from python.scrapers.evf_results import scrape_event_results

    client = _EvfClient(
        [{"id": 1, "weaponId": 1, "categoryId": 2}], {1: [_evf_row("ME", 1), _evf_row("??", 2)]}
    )
    rows = scrape_event_results(85, client=client)  # type: ignore[arg-type]
    assert [(r["weapon"], r["gender"]) for r in rows] == [("EPEE", "M"), ("FOIL", "F")]
    assert [r["declared_weapon"] for r in rows] == ["FOIL", "FOIL"]
    assert [r["weapon_abbr"] for r in rows] == ["ME", "??"]


def test_SRC_CONS_07_known_abbreviations_are_unchanged():
    from python.scrapers.evf_results import scrape_event_results

    client = _EvfClient(
        [{"id": 1, "weaponId": 2, "categoryId": 1}, {"id": 2, "weaponId": 3, "categoryId": 4}],
        {1: [_evf_row("WE", 1), _evf_row("ME", 1)], 2: [_evf_row("MS", 1)]},
    )
    rows = scrape_event_results(85, client=client)  # type: ignore[arg-type]
    assert [(r["weapon"], r["gender"], r["category"]) for r in rows] == [
        ("EPEE", "F", "V1"),
        ("EPEE", "M", "V1"),
        ("SABRE", "M", "V4"),
    ]


def test_SRC_CONS_07_the_bracket_reports_its_rows_against_their_competition():
    from python.pipeline import international_sources as src

    def row(weapon, gender, declared, abbr, place):
        return {
            "weapon": weapon,
            "gender": gender,
            "category": "V2",
            "fencer_name": "NOWAK Jan",
            "place": place,
            "country": "POL",
            "declared_weapon": declared,
            "weapon_abbr": abbr,
        }

    rows = [
        row("EPEE", "M", "FOIL", "ME", 1),
        row("EPEE", "M", "EPEE", "ME", 2),
        row("FOIL", "F", "FOIL", "??", 1),
    ]
    recs, _kept, _skipped = src.read_brackets(
        {"txt_code": "IMEW-2023-2024", "id_evf_event": 77},
        ["evf:77"],
        evf_scrape=lambda _id: rows,
        finality=src.SETTLED,
    )
    found = {r["name"]: r["_base"].source_disagreements for r in recs}
    assert found == {
        "EVF EPEE M V2": [
            {
                "kind": sc.WEAPON,
                "detail": "1 row(s) whose weapon_abbr says EPEE; "
                "their competition declared FOIL; the abbreviation wins",
            }
        ],
        "EVF FOIL F V2": [
            {
                "kind": sc.GENDER,
                "detail": "1 row(s) with an unknown weapon_abbr ('??'): "
                "the competition's weapon is kept and the gender guessed F",
            }
        ],
    }


# --------------------------------------------------------------------------
# SRC.CONS.08 — the fetcher carries them onto the bracket
# --------------------------------------------------------------------------


def test_SRC_CONS_08_engarde_fetcher_carries_the_competition_s_disagreements():
    from python.pipeline.review_cli import Fetcher

    xml = (ENGARDE / "competitions_budapest.xml").read_text(encoding="utf-8")
    page = (ENGARDE / "clasfinal_hunfencing.html").read_text(encoding="utf-8")

    def get(url):
        resp = MagicMock()
        resp.raise_for_status.return_value = None
        resp.text = xml if "getCompeForDisplay.php" in url else page
        return resp

    http = MagicMock()
    http.get.side_effect = get
    parsed, _ = Fetcher(http_client=http).fetch_event_url_with_skips(
        "https://engarde-service.com/tournament/hunfencing/2025_budapest"
    )
    me70 = next(p for p in parsed if p.tournament_name == "Men's Epee V4 (70)")
    assert [d["kind"] for d in me70.source_disagreements] == [sc.GENDER]
    others = [p for p in parsed if p is not me70]
    assert others and all(
        sc.GENDER not in [d["kind"] for d in p.source_disagreements] for p in others
    )


# --------------------------------------------------------------------------
# SRC.CONS.09 — where they show
# --------------------------------------------------------------------------

GENDER_NOTE = {
    "kind": "gender",
    "detail": 'title "Men\'s Epee V4 (70)" says M; the source declared F; the title wins',
}


def test_SRC_CONS_09_the_log_lines_name_the_bracket_and_no_fencer():
    parsed = sc.checked(_bracket([1, 2, 4], source_disagreements=[GENDER_NOTE]))
    lines = sc.lines("Men's Epee V4 (70)", parsed)
    assert lines == [
        f'  disagree "Men\'s Epee V4 (70)": gender: {GENDER_NOTE["detail"]}',
        '  disagree "Men\'s Epee V4 (70)": places: places are not 1..3: '
        "after 2 row(s) the next place is 4, not 3",
    ]
    assert not any("SURNAME" in line for line in lines)


def test_SRC_CONS_09_the_international_read_prints_them(capsys):
    from python.pipeline import ingest_cli

    rec = {
        "name": "Men's Epee V4 (70)",
        "url": "u",
        "uuid": "u",
        "weapon": "EPEE",
        "gender": "M",
        "cats": ["V4"],
        "count": 3,
        "_base": _bracket([1, 2, 4], source_disagreements=[GENDER_NOTE]),
    }
    with (
        patch("python.pipeline.international_sources.event_sources", return_value=[]),
        patch("python.pipeline.international_sources.sightings_for", return_value=None),
        patch(
            "python.pipeline.international_sources.read_brackets",
            return_value=([rec], [], []),
        ),
        patch("python.pipeline.overrides.load_for_event", return_value=None),
    ):
        ingest_cli._read_international(
            {"txt_code": "PEW3ef-2026-2027", "dt_start": "2026-11-14"},
            "PEW3ef-2026-2027",
            2027,
            None,
            db=MagicMock(),
        )
    out = capsys.readouterr().out
    assert f'disagree "Men\'s Epee V4 (70)": gender: {GENDER_NOTE["detail"]}' in out
    assert "places are not 1..3" in out
    assert "SURNAME" not in out


def test_SRC_CONS_09_the_domestic_read_checks_its_places(capsys):
    """An SPWS event's FTL bracket is whole: its places are checked, its
    countries are not, and the bracket it commits carries the list."""
    from python.pipeline import ingest_cli
    from python.tests.test_promotion_plan import SCHEDULE, _Ftl
    from python.tests.test_promotion_plan import _drive as drive

    ftl = _Ftl({"U1": ("Szpada Mężczyzn kat. 2", [("KOWALSKI Jan", 1), ("NOWAK Adam", 3)])})
    event = {"txt_code": "PPW4-2026-2027", "dt_start": "2027-02-13", "json_source_overrides": None}
    read, _staging, _joining = drive(
        ftl, ingest_cli.read_event, event, "PPW4-2026-2027", 2027, SCHEDULE, db=MagicMock()
    )
    out = capsys.readouterr().out
    detail = "places are not 1..2: after 1 row(s) the next place is 3, not 2"
    assert f"disagree 'Szpada Mężczyzn kat. 2': places: {detail}" in out
    assert "KOWALSKI" not in out and "NOWAK" not in out
    (listing,) = read.listings
    assert listing["_commit"]["parsed"].source_disagreements == [
        {"kind": sc.PLACES, "detail": detail}
    ]


def test_SRC_CONS_09_the_staging_report_lists_each_disagreement(monkeypatch, tmp_path):
    from python.pipeline.plugins.staging_formatter import StagingFormatter
    from python.tests.test_pipeline_plugins import _ingest
    from python.tests.test_staging_report import _event_ctx, _formatter_svc

    b1 = _ingest(monkeypatch)
    ctx = _event_ctx([b1.report], event=b1.get("event"))
    ctx.data["_source_disagreements"] = [
        {"name": "Men's Epee V4 (70)", "disagreements": [GENDER_NOTE]}
    ]
    StagingFormatter().run(ctx, _formatter_svc(tmp_path))
    md = [p for p in tmp_path.glob("*.md") if not p.name.endswith(".diff.md")][0].read_text()
    gaps = md[md.index("## Detected automation gaps") : md.index("## Fencer matching")]
    assert "Source disagreements: 1" in gaps
    assert "Men's Epee V4 (70)" in gaps and GENDER_NOTE["detail"] in gaps


def test_SRC_CONS_09_the_event_report_collects_them_from_its_brackets():
    from python.pipeline import ingest_cli
    from python.pipeline.core.contract import Context
    from python.pipeline.plugins import bridge

    noted, plain = Context(), Context()
    noted.data[bridge.LEGACY] = SimpleNamespace(
        parsed=_bracket(
            [1, 2], tournament_name="Men's Epee V4 (70)", source_disagreements=[GENDER_NOTE]
        )
    )
    plain.data[bridge.LEGACY] = SimpleNamespace(parsed=_bracket([1, 2], tournament_name="Plain"))
    seen = {}

    def fake_run_flow(*_args, ctx=None, **_kw):
        assert ctx is not None
        seen["notes"] = ctx.get("_source_disagreements")
        return ctx

    with (
        patch("python.pipeline.run.run_flow", side_effect=fake_run_flow),
        patch("python.pipeline.international_report.section_lines", return_value=[]),
    ):
        ingest_cli._fire_staging_report(
            {"id_event": 1, "txt_code": "X"}, [noted, plain], db=MagicMock()
        )
    assert seen["notes"] == [{"name": "Men's Epee V4 (70)", "disagreements": [GENDER_NOTE]}]


def _rec(base):
    return {
        "name": "Men's Epee V4 (70)",
        "uuid": "u",
        "url": "u",
        "count": 2,
        "has_de": True,
        "weapon": "EPEE",
        "gender": "M",
        "cats": ["V4"],
        "_base": base,
    }


def test_SRC_CONS_09_the_run_record_keeps_them():
    from python.pipeline.promotion.run_record import ListingLog

    log = ListingLog()
    log.add_round(
        _rec(_bracket([1, 2], source_disagreements=[GENDER_NOTE])), {"status": "committed"}
    )
    log.add_round(_rec(_bracket([1, 2])), {"status": "committed"})
    first, second = log.listings()["rounds"]
    assert first["source_disagreements"] == [GENDER_NOTE]
    assert "source_disagreements" not in second


# --------------------------------------------------------------------------
# SRC.CONS.10 — not in the hash
# --------------------------------------------------------------------------


def test_SRC_CONS_10_a_disagreement_never_changes_a_listing_s_hash():
    from python.pipeline.promotion.run_record import ListingLog

    plain, noted = ListingLog(), ListingLog()
    plain.add_round(_rec(_bracket([1, 2])), {"status": "committed"})
    noted.add_round(
        _rec(_bracket([1, 2], source_disagreements=[GENDER_NOTE])), {"status": "committed"}
    )
    assert plain.listings()["rounds"][0]["sha256"] == noted.listings()["rounds"][0]["sha256"]
