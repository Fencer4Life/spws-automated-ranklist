"""NAME.CELLS — a name the source repeats in both name cells is an exception.

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, G41 A (signed
1 Nov 2026). Engarde, d'Artagnan, 4fence and FencingTime XML print a surname
cell and a first-name cell. The norm, read on every row of the ten Engarde
events of the last 30 months (2,740 rows): one cell holds the surname, the
other the given names, and neither repeats the other. Five rows break it, all
keyed by one organiser: the whole name in both cells ("ANNA GANSZCZYK" /
"Anna Ganszczyk", PEW Madrid 2026), or in the first-name cell ("GONZALEZ" /
"Patricia Gonzalez"). Such a row is a source exception: its printed name is
kept, and the readings its words allow are tried by the same identity rule;
exactly one fit stores it, anything else leaves it PENDING. Every exception
is reported, and a bracket where more than one row breaks the norm, and more
than one row in ten, is refused as not understood.
"""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import MagicMock

import pytest
from bs4 import BeautifulSoup

from python.scrapers import name_cells

FIXTURES = Path(__file__).parent / "fixtures"
TEN_EVENTS = json.loads((FIXTURES / "engarde" / "name_cells_ten_events.json").read_text())

# The five rows of the ten events whose cells repeat each other (event,
# competition, place), read on 1 Nov 2026.
FIVE = {
    ("PEW2efs-2025-2026", "EPEE MALE -2", "2"),
    ("PEW2efs-2025-2026", "TABLE FOIL MALE 2", "2"),
    ("PEW2efs-2026-2027", "TABLE EPEE FEMALE 2", "11"),
    ("PEW2efs-2026-2027", "TABLE EPEE FEMALE 1", "1"),
    ("PEW2efs-2026-2027", "TABLE EPEE MALE 4", "3"),
}


def _rows():
    for code, event in TEN_EVENTS.items():
        for title, rows in event["competitions"].items():
            for place, country, surname, first in rows:
                yield code, title, place, country, surname, first


# --------------------------------------------------------------------------
# NAME.CELLS.01 — the norm, decided by the data
# --------------------------------------------------------------------------


def test_NAME_CELLS_01_the_ten_events_keep_the_norm_but_five_rows():
    rows = list(_rows())
    assert len(rows) == 2740
    breaking = {(c, t, p) for c, t, p, _, s, f in rows if name_cells.repeats(s, f)}
    assert breaking == FIVE
    assert len(rows) - len(breaking) == 2735


@pytest.mark.parametrize(
    ("surname", "first", "repeats"),
    [
        ("ANNA GANSZCZYK", "Anna Ganszczyk", True),
        ("GONZALEZ", "Patricia Gonzalez", True),
        ("GRAHAM REID", "Graham Reid", True),
        ("PRZYKŁADOWA", "Przykladowa Anna", True),  # Polish letters folded
        # A particle shared by a surname and a second given name is the norm
        # (PEW Madrid 2024, EPEE FEMALE -2, place 3).
        ("DE VARGAS HILLA", "Cristina De Lourdes", False),
        ("NOWAK", "Anna", False),
        ("NOWAK", "", False),
        ("", "Anna", False),
    ],
)
def test_NAME_CELLS_01_one_cell_repeats_the_other(surname, first, repeats):
    assert name_cells.repeats(surname, first) is repeats


# --------------------------------------------------------------------------
# NAME.CELLS.02 — the readings an exception allows
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("surname", "first", "reading"),
    [
        ("ANNA GANSZCZYK", "Anna Ganszczyk", "GANSZCZYK Anna"),
        ("GRAHAM REID", "Graham Reid", "REID Graham"),
        ("GONZALEZ", "Patricia Gonzalez", "GONZALEZ Patricia"),
        ("ASHRAFI", "Ehsan Ashrafi", "ASHRAFI Ehsan"),
        ("KOWALSKA NOWAK", "Anna Kowalska Nowak", "KOWALSKA NOWAK Anna"),
    ],
)
def test_NAME_CELLS_02_every_split_of_the_whole_name_is_a_reading(surname, first, reading):
    got = name_cells.readings(surname, first)
    assert reading in got
    assert len(got) == len(set(got))
    assert all(r.split()[0].isupper() for r in got)  # SURNAME First, as every engine prints


def test_NAME_CELLS_02_a_single_word_twice_allows_no_reading():
    assert name_cells.readings("NOWAK", "Nowak") == ()


# --------------------------------------------------------------------------
# NAME.CELLS.03 — the guard: an exception stays an exception
# --------------------------------------------------------------------------


def test_NAME_CELLS_03_the_real_brackets_pass_the_guard():
    """One exception in a bracket never trips it: Madrid 2026's TABLE EPEE
    MALE 4 holds one in seven rows."""
    for event in TEN_EVENTS.values():
        for title, rows in event["competitions"].items():
            check = name_cells.NameCellCheck()
            for place, _, surname, first in rows:
                check.row(surname, first, printed=f"{surname} {first}", place=int(place))
            check.checked(len(rows), title)  # does not raise


def test_NAME_CELLS_03_a_table_whose_layout_changed_is_refused():
    check = name_cells.NameCellCheck()
    rows = [("PRZYKŁADOWA", "Anna Przykładowa"), ("WZORCOWA", "Ewa Wzorcowa")]
    rows += [(f"NAZWISKO{i}", "Jan") for i in range(10)]
    for i, (s, f) in enumerate(rows, start=1):
        check.row(s, f, printed=f"{s} {f}", place=i)
    with pytest.raises(name_cells.SourceNotUnderstood) as refused:
        check.checked(len(rows), "TABLE EPEE FEMALE 2")
    text = str(refused.value)
    assert "TABLE EPEE FEMALE 2" in text and "2 of 12" in text
    assert "PRZYKŁADOWA" not in text and "WZORCOWA" not in text  # D12: no name
    assert isinstance(refused.value, ValueError)


def test_NAME_CELLS_03_the_refusal_passes_to_the_pause_with_its_text():
    from python.pipeline.promotion.results_sync import public_error

    e = name_cells.SourceNotUnderstood("TABLE X: 2 of 12 rows repeat the name")
    assert public_error(e) == "SourceNotUnderstood: TABLE X: 2 of 12 rows repeat the name"


# --------------------------------------------------------------------------
# NAME.CELLS.04 — every engine with two name cells records its exceptions
# --------------------------------------------------------------------------


def _set_cells(html: str, table_class: str, surname_at: int, first_at: int, min_cells: int) -> str:
    """The page with its first placed row's name cells keyed twice."""
    soup = BeautifulSoup(html, "html.parser")
    table = soup.find("table", class_=table_class)
    assert table is not None
    for tr in table.find_all("tr"):
        cells = tr.find_all("td")
        if len(cells) >= min_cells and cells[0].get_text(strip=True)[:1].isdigit():
            cells[surname_at].string = "ANNA PRZYKŁADOWA"
            cells[first_at].string = "Anna Przykładowa"
            return str(soup)
    raise AssertionError("no placed row")


def _the_exception(parsed, place=None):
    (e,) = parsed.source_exceptions
    assert e["kind"] == name_cells.REPEATED
    assert "PRZYKŁADOWA Anna" in e["readings"]
    row = next(r for r in parsed.results if r.fencer_name == e["printed"])
    assert "PRZYKŁADOWA" in row.fencer_name  # the printed name is kept as read
    if place is not None:
        assert e["place"] == place
    return e


def test_NAME_CELLS_04_engarde():
    from python.scrapers.engarde import parse_html

    html = (FIXTURES / "engarde" / "competition_crit26_ehv2.html").read_text()
    parsed = parse_html(_set_cells(html, "liste", 1, 2, 4), source_url="u")
    _the_exception(parsed)
    assert parse_html(html, source_url="u").source_exceptions == []


def test_NAME_CELLS_04_dartagnan():
    from python.scrapers.dartagnan import parse_rankings

    html = (FIXTURES / "dartagnan" / "6687-rankings.html").read_text()
    parsed = parse_rankings(_set_cells(html, "lists", 1, 2, 6), source_url="u")
    _the_exception(parsed)
    assert parse_rankings(html, source_url="u").source_exceptions == []


def test_NAME_CELLS_04_fourfence():
    from python.scrapers.fourfence import parse_html

    html = (FIXTURES / "fourfence" / "napoli_fm7_clafinale.html").read_text()
    soup = BeautifulSoup(html, "html.parser")
    for tr in soup.find_all("tr", class_="null767"):
        cells = tr.find_all("td")
        if len(cells) >= 9 and cells[3].get_text(strip=True).isdigit():
            cells[4].string = "ANNA PRZYKŁADOWA"
            cells[5].string = "Anna Przykładowa"
            break
    tab4 = (FIXTURES / "fourfence" / "napoli_fm7_tab4.html").read_text()
    _the_exception(parse_html(str(soup), source_url="u", tab4_html=tab4))
    assert parse_html(html, source_url="u", tab4_html=tab4).source_exceptions == []


def test_NAME_CELLS_04_fencingtime_xml():
    from python.scrapers.fencingtime_xml import parse

    raw = (FIXTURES / "fencingtime_xml" / "single_category.xml").read_text(encoding="utf-8")
    start = raw.index("<Tireur ")
    nom = raw.index('Nom="', start)
    prenom = raw.index('Prenom="', start)
    first_nom_end = raw.index('"', nom + 5)
    first_prenom_end = raw.index('"', prenom + 8)
    keyed = (
        raw[: nom + 5]
        + "ANNA PRZYKŁADOWA"
        + raw[first_nom_end : prenom + 8]
        + "Anna Przykładowa"
        + raw[first_prenom_end:]
    )
    _the_exception(parse(keyed.encode("utf-8"), source_url="u"))
    assert parse(raw.encode("utf-8"), source_url="u").source_exceptions == []


def test_NAME_CELLS_04_the_listing_hash_does_not_change():
    """The exception rides on the bracket, not the row: a listing's hash hashes
    every field of every row (promote and the sync compare it), so the row keeps
    exactly the fields it had, and a CERT run recorded before this change still
    matches PROD's read after it."""
    from dataclasses import fields

    from python.pipeline.ir import ParsedResult

    assert [f.name for f in fields(ParsedResult)] == [
        "source_row_id",
        "fencer_name",
        "place",
        "fencer_country",
        "birth_year",
        "birth_date",
        "raw_age_marker",
        "source_vcat_hint",
        "bool_excluded",
    ]


# --------------------------------------------------------------------------
# NAME.CELLS.05 — the international identity rule reads the exception
# --------------------------------------------------------------------------

ROSTER = [
    {
        "id_fencer": 501,
        "txt_surname": "PRZYKŁADOWA",
        "txt_first_name": "Anna",
        "int_birth_year": 1975,
        "txt_nationality": "POL",
    },
    {
        "id_fencer": 502,
        "txt_surname": "PRZYKŁADOWA",
        "txt_first_name": "Ewa",
        "int_birth_year": 1974,
        "txt_nationality": "POL",
    },
]
PRINTED = "ANNA PRZYKŁADOWA Anna Przykładowa"


def _admit(roster, country="POL", starters=(501, 502), exceptions=True):
    from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
    from python.pipeline.stages import _admit_international_rows
    from python.pipeline.types import Overrides, PipelineContext

    row = ParsedResult(source_row_id="r11", fencer_name=PRINTED, place=11, fencer_country=country)
    parsed = ParsedTournament(
        source_kind=SourceKind.ENGARDE,
        results=[row],
        source_exceptions=[
            {
                "kind": name_cells.REPEATED,
                "place": 11,
                "printed": PRINTED,
                "readings": list(name_cells.readings("ANNA PRZYKŁADOWA", "Anna Przykładowa")),
            }
        ]
        if exceptions
        else [],
    )
    ctx = PipelineContext(
        parsed=parsed, overrides=Overrides(), season_end_year=2027, event_code="PEW2efs-2026-2027"
    )
    ctx.event = {"txt_code": "PEW2efs-2026-2027"}
    db = MagicMock()
    db.fetch_spws_starter_ids.return_value = list(starters)
    return _admit_international_rows(ctx, [("V2", row)], roster, db), ctx


def test_NAME_CELLS_05_exactly_one_fit_stores_the_row():
    from python.pipeline.international_admission import STORED

    ((_, _, admission),), _ = _admit(ROSTER)
    assert (admission.decision, admission.id_fencer) == (STORED, 501)
    assert "repeat" in admission.reason


def test_NAME_CELLS_05_without_the_exception_the_row_is_pending_as_before():
    from python.pipeline.international_admission import PENDING

    ((_, _, admission),), _ = _admit(ROSTER, exceptions=False)
    assert admission.decision == PENDING


def test_NAME_CELLS_05_two_fits_leave_it_pending():
    from python.pipeline.international_admission import PENDING

    twin = {**ROSTER[0], "id_fencer": 503, "int_birth_year": 1976}
    ((_, _, admission),), _ = _admit([*ROSTER, twin], starters=(501, 502, 503))
    assert admission.decision == PENDING


def test_NAME_CELLS_05_no_fit_is_pending_for_pol_and_rejected_otherwise():
    from python.pipeline.international_admission import PENDING

    ((_, _, admission),), _ = _admit(ROSTER[1:])
    assert admission.decision == PENDING
    kept, ctx = _admit(ROSTER[1:], country="ARG")
    assert kept == [] and ctx.rejected[0]["place"] == 11


def test_NAME_CELLS_05_a_fit_without_an_spws_start_is_not_stored():
    from python.pipeline.international_admission import PENDING

    ((_, _, admission),), _ = _admit(ROSTER, starters=(502,))
    assert admission.decision == PENDING


# --------------------------------------------------------------------------
# NAME.CELLS.06 — the domestic exact rule reads it too, and never creates
# --------------------------------------------------------------------------


def _domestic(roster, readings):
    from python.pipeline.stages import lookup_exact_with_readings

    return lookup_exact_with_readings(PRINTED, tuple(readings), "POL", roster, "V2", 2027)


def test_NAME_CELLS_06_one_fit_is_the_fencer():
    readings = name_cells.readings("ANNA PRZYKŁADOWA", "Anna Przykładowa")
    assert _domestic(ROSTER, readings).id_fencer == 501


def test_NAME_CELLS_06_no_fit_waits_for_a_person():
    readings = name_cells.readings("ANNA PRZYKŁADOWA", "Anna Przykładowa")
    lookup = _domestic(ROSTER[1:], readings)
    assert lookup.id_fencer is None and lookup.reason == "source_exception"


def test_NAME_CELLS_06_a_row_without_an_exception_is_looked_up_as_before():
    lookup = _domestic(ROSTER, ())
    assert lookup.id_fencer is None and lookup.reason is None


# --------------------------------------------------------------------------
# NAME.CELLS.07 — every exception is reported; the public log counts it
# --------------------------------------------------------------------------

EXCEPTION = {
    "kind": name_cells.REPEATED,
    "place": 11,
    "printed": PRINTED,
    "readings": ["PRZYKŁADOWA Anna", "ANNA Przykładowa"],
}


def test_NAME_CELLS_07_the_staging_report_lists_each_exception(monkeypatch, tmp_path):
    from python.pipeline.plugins.staging_formatter import StagingFormatter
    from python.tests.test_pipeline_plugins import _ingest
    from python.tests.test_staging_report import _event_ctx, _formatter_svc

    b1 = _ingest(monkeypatch)
    ctx = _event_ctx([b1.report], event=b1.get("event"))
    ctx.data["_source_exceptions"] = [{"name": "TABLE EPEE FEMALE 2", "exceptions": [EXCEPTION]}]
    StagingFormatter().run(ctx, _formatter_svc(tmp_path))
    md = [p for p in tmp_path.glob("*.md") if not p.name.endswith(".diff.md")][0].read_text()
    gaps = md[md.index("## Detected automation gaps") : md.index("## Fencer matching")]
    assert "Source exceptions" in gaps
    assert "TABLE EPEE FEMALE 2" in gaps and PRINTED in gaps and "PRZYKŁADOWA Anna" in gaps


def test_NAME_CELLS_07_the_run_record_keeps_them():
    from python.pipeline.ir import ParsedTournament, SourceKind
    from python.pipeline.promotion.run_record import ListingLog

    rec = {
        "name": "TABLE EPEE FEMALE 2",
        "uuid": "u",
        "url": "u",
        "count": 0,
        "has_de": True,
        "weapon": "EPEE",
        "gender": "F",
        "cats": ["V2"],
        "_base": ParsedTournament(source_kind=SourceKind.ENGARDE, source_exceptions=[EXCEPTION]),
    }
    log = ListingLog()
    log.add_round(rec, {"status": "committed", "commit_cats": ["V2"]})
    assert log.listings()["rounds"][0]["source_exceptions"] == [EXCEPTION]
    rec["_base"] = ParsedTournament(source_kind=SourceKind.ENGARDE)
    log.add_round(rec, {"status": "committed", "commit_cats": ["V2"]})
    assert "source_exceptions" not in log.listings()["rounds"][1]


def test_NAME_CELLS_07_the_event_report_collects_them_and_the_log_counts_them():
    from python.pipeline.ingest_cli import exception_lines, source_exception_notes
    from python.pipeline.ir import ParsedTournament, SourceKind

    parsed = ParsedTournament(
        source_kind=SourceKind.ENGARDE,
        tournament_name="TABLE EPEE FEMALE 2",
        source_exceptions=[EXCEPTION],
    )
    plain = ParsedTournament(source_kind=SourceKind.ENGARDE, tournament_name="TABLE X")
    assert source_exception_notes([parsed, plain]) == [
        {"name": "TABLE EPEE FEMALE 2", "exceptions": [EXCEPTION]}
    ]
    (line,) = exception_lines("TABLE EPEE FEMALE 2", parsed)
    assert "TABLE EPEE FEMALE 2" in line and "1 row" in line
    assert "PRZYKŁADOWA" not in line  # D12
