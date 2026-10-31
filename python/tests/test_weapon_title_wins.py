"""WPN.TITLE — where a source states a bracket's weapon twice, the title wins.

doc/plans/weapon-declared-vs-title-check-2026-10-31.html (signed off 31 Oct
2026, W1 A). Organisers give a bracket's weapon twice: picked from a list
(Engarde ``arme``, FencingTime ``Arme``, d'Artagnan's "männlich, Degen") and
typed into its title. At PEW Madrid 2026 "EPEE MALE 2" carries ``arme="s"``:
read from ``arme`` it is men's sabre V2, and once TABLE SABRE MALE 2 is also
final the event is refused as two sources for one bracket. When the title
names exactly one weapon, that weapon is the bracket's, and an override is
reported; a title with no weapon, or two, leaves the declared weapon.
"""

from __future__ import annotations

import re
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

FIXTURES = Path(__file__).parent / "fixtures"
ENGARDE = FIXTURES / "engarde"


# --------------------------------------------------------------------------
# WPN.TITLE.01 — one reader of weapon words
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("text", "weapons"),
    [
        ("EPEE MALE 2", {"EPEE"}),
        ("Épée Hommes V2", {"EPEE"}),
        ("Men Epee V1", {"EPEE"}),
        ("SZPADA MĘŻCZYZN v2", {"EPEE"}),
        ("I PGE Puchar Polski seniorów w szpadzie", {"EPEE"}),
        ("männlich, Degen", {"EPEE"}),
        ("Espada Masculina V3", {"EPEE"}),
        ("Spada Maschile Cat.1 40+", {"EPEE"}),
        ("Férfi párbajtőr V2", {"EPEE"}),
        ("Fleuret Dames V1", {"FOIL"}),
        ("FLORET KOBIET kat. 1", {"FOIL"}),
        ("Mistrzostwa we florecie", {"FOIL"}),
        ("Florett Herren V50 Einzel", {"FOIL"}),
        ("Női tőr V1", {"FOIL"}),
        ("TABLE SABLE MALE  3", {"SABRE"}),
        ("SZABLA KOBIET", {"SABRE"}),
        ("männlich, Säbel", {"SABRE"}),
        ("Sciabola Femminile", {"SABRE"}),
        ("Férfi kard V4", {"SABRE"}),
        ("Coupe Épée-Sabre", {"EPEE", "SABRE"}),
        ("Hommes V2", set()),
        ("Torneo Tor Vergata V2", set()),
        ("", set()),
    ],
)
def test_WPN_TITLE_01_the_weapons_a_text_names(text, weapons):
    """Every platform's language, accents folded, Polish forms, Hungarian;
    "Tor" without its accent is not the Hungarian foil."""
    from python.pipeline.weapon_words import find_weapons

    assert find_weapons(text) == weapons


def test_WPN_TITLE_01_source_identity_reads_the_same_table():
    """One table: the URL-identity check reads weapons with the same reader."""
    from python.pipeline import source_identity, weapon_words

    assert source_identity.find_weapons is weapon_words.find_weapons


# --------------------------------------------------------------------------
# WPN.TITLE.02 — the rule
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("declared", "title", "weapon", "overridden"),
    [
        ("SABRE", "EPEE MALE 2", "EPEE", True),
        ("EPEE", "EPEE MALE 2", "EPEE", False),
        ("SABRE", "Hommes V2", "SABRE", False),
        ("SABRE", "Coupe Épée-Sabre", "SABRE", False),
        (None, "EPEE MALE 2", "EPEE", False),
        (None, "Hommes V2", None, False),
    ],
)
def test_WPN_TITLE_02_the_title_wins_when_it_names_one_weapon(declared, title, weapon, overridden):
    from python.pipeline.weapon_words import weapon_from_title

    got, note = weapon_from_title(declared, title)
    assert got == weapon
    assert (note is not None) == overridden
    if overridden:
        assert note is not None
        assert title in note and declared in note and weapon in note


# --------------------------------------------------------------------------
# WPN.TITLE.03–04 — Engarde
# --------------------------------------------------------------------------


def _completed(xml: str, *slugs: str) -> str:
    for slug in slugs:
        head, sep, tail = xml.partition(f'compe="{slug}"')
        assert sep, slug
        xml = head + sep + re.sub(r'etat="[^"]*"', 'etat="completed"', tail, count=1)
    return xml


def test_WPN_TITLE_03_madrid_epee_male_2_is_epee_and_the_event_is_not_refused():
    """Madrid 2026's own competition list, both brackets completed."""
    from python.pipeline.international_sources import _refuse_two_sources
    from python.scrapers.engarde import parse_competition_list

    xml = _completed(
        (ENGARDE / "competitions_madrid2026.xml").read_text(), "epeemale2", "tablesabremale2"
    )
    kept, _ = parse_competition_list(xml, org="aeve_esgrima", event="aeve_esgrima")
    by_slug = {c["slug"]: c for c in kept}

    assert (by_slug["epeemale2"]["weapon"], by_slug["epeemale2"]["category"]) == ("EPEE", "V2")
    assert "SABRE" in by_slug["epeemale2"]["weapon_note"]
    assert by_slug["tablesabremale2"]["weapon"] == "SABRE"
    assert "weapon_note" not in by_slug["tablesabremale2"]
    _refuse_two_sources(
        {"txt_code": "PEW2efs-2026-2027"},
        [
            {
                "weapon": c["weapon"],
                "gender": c["gender"],
                "cats": [c["category"]],
                "url": c["url"],
                "uuid": c["url"],
            }
            for c in kept
        ],
    )


def test_WPN_TITLE_03_the_url_identity_facts_use_the_same_weapon():
    """With only EPEE MALE 2 in the list, the list's weapons are épée only."""
    from python.scrapers.engarde import competition_list_facts

    xml = (ENGARDE / "competitions_madrid2026.xml").read_text()
    only = re.search(r'<comp [^>]*compe="epeemale2".*?</comp>', xml, re.S)
    assert only is not None
    _dates, weapons, _places = competition_list_facts(f"<comps>{only.group(0)}</comps>")
    assert weapons == {"EPEE"}


@pytest.mark.parametrize(
    ("name", "org", "event"),
    [
        ("competitions_crit26.xml", "fencingaddict", "crit26"),
        ("competitions_budapest.xml", "hunfencing", "2025_09_20_pbt"),
        ("competitions_madrid.xml", "aeve_esgrima", "evf_madrid_2025"),
        ("competitions_madrid2024.xml", "aeve_esgrima", "evf_madrid_2024"),
        ("competitions_sivo2025.xml", "sthlm", "sivo2025"),
    ],
)
def test_WPN_TITLE_04_earlier_engarde_tournaments_keep_their_weapons(name, org, event):
    """No false alarm: every competition keeps the weapon its arme gives."""
    import xml.etree.ElementTree as ET

    from python.scrapers.engarde import ENGARDE_WEAPON_MAP, parse_competition_list

    text = (ENGARDE / name).read_text(encoding="utf-8")
    arme = {c.get("compe"): ENGARDE_WEAPON_MAP.get(c.get("arme", "")) for c in ET.fromstring(text)}
    kept, skipped = parse_competition_list(text, org=org, event=event)
    for c in kept:
        assert c["weapon"] == arme[c["slug"]], c["slug"]
        assert "weapon_note" not in c
    for s in skipped:
        assert s["weapon"] == arme[s["slug"]], s["slug"]


def test_WPN_TITLE_04_the_fetcher_carries_the_override_on_the_parse():
    from python.pipeline.review_cli import Fetcher

    xml = _completed((ENGARDE / "competitions_madrid2026.xml").read_text(), "epeemale2")
    page = (ENGARDE / "competition_crit26_ehv2.html").read_text()

    def get(url):
        resp = MagicMock()
        resp.raise_for_status.return_value = None
        resp.text = xml if "getCompeForDisplay.php" in url else page
        return resp

    http = MagicMock()
    http.get.side_effect = get
    parsed, _ = Fetcher(http_client=http).fetch_event_url_with_skips(
        "https://engarde-service.com/tournament/aeve_esgrima/aeve_esgrima"
    )
    assert len(parsed) == 1
    assert (parsed[0].weapon, parsed[0].gender, parsed[0].category_hint) == ("EPEE", "M", "V2")
    assert parsed[0].weapon_note is not None and "SABRE" in parsed[0].weapon_note


# --------------------------------------------------------------------------
# WPN.TITLE.05 — FencingTime XML
# --------------------------------------------------------------------------


def _xml(arme: str, alt_name: str) -> bytes:
    raw = (FIXTURES / "fencingtime_xml" / "single_category.xml").read_text(encoding="utf-8")
    raw = raw.replace('Arme="E"', f'Arme="{arme}"', 1)
    raw = raw.replace('AltName="SZPADA MĘŻCZYZN v2"', f'AltName="{alt_name}"', 1)
    return raw.encode("utf-8")


def test_WPN_TITLE_05_xml_altname_wins_over_arme():
    from python.scrapers.fencingtime_xml import parse, parse_xml_metadata

    data = _xml("S", "SZPADA MĘŻCZYZN v2")
    parsed = parse(data)
    assert parsed.weapon == "EPEE"
    assert parsed.weapon_note is not None and "SABRE" in parsed.weapon_note
    meta = parse_xml_metadata(data)
    assert meta["weapon"] == "EPEE"
    assert "SABRE" in meta["weapon_note"]


def test_WPN_TITLE_05_xml_altname_without_a_weapon_keeps_arme():
    from python.scrapers.fencingtime_xml import parse, parse_xml_metadata

    data = _xml("S", "MĘŻCZYZN v2")
    assert (parse(data).weapon, parse(data).weapon_note) == ("SABRE", None)
    assert parse_xml_metadata(data)["weapon"] == "SABRE"
    assert "weapon_note" not in parse_xml_metadata(data)


@pytest.mark.parametrize("name", ["single_category.xml", "combined_v0v1.xml", "no_dob.xml"])
def test_WPN_TITLE_05_xml_fixtures_are_unchanged(name):
    from python.scrapers.fencingtime_xml import parse

    parsed = parse((FIXTURES / "fencingtime_xml" / name).read_bytes())
    assert parsed.weapon_note is None


# --------------------------------------------------------------------------
# WPN.TITLE.06 — d'Artagnan
# --------------------------------------------------------------------------


def test_WPN_TITLE_06_dartagnan_title_wins_over_the_declared_line():
    from python.scrapers.dartagnan import list_dartagnan_competitions

    html = (FIXTURES / "dartagnan" / "index.html").read_text(encoding="utf-8")
    changed = re.sub(r"(<h3>Men Epee V1</h3>\s*männlich,) Degen", r"\1 Säbel", html, count=1)
    assert changed != html
    kept, _ = list_dartagnan_competitions(changed, "https://example.org/de/index.html")
    v1 = next(c for c in kept if c["title"] == "Men Epee V1")
    assert v1["weapon"] == "EPEE"
    assert "SABRE" in v1["weapon_note"]


def test_WPN_TITLE_06_dartagnan_index_is_unchanged():
    from python.scrapers.dartagnan import list_dartagnan_competitions

    html = (FIXTURES / "dartagnan" / "index.html").read_text(encoding="utf-8")
    kept, skipped = list_dartagnan_competitions(html, "https://example.org/de/index.html")
    assert kept and all("weapon_note" not in c for c in kept)
    for c in kept:
        assert c["weapon"] == ("EPEE" if "Epee" in c["title"] else "FOIL")
    assert all(s["weapon"] in ("EPEE", "FOIL") for s in skipped)


# --------------------------------------------------------------------------
# WPN.TITLE.07 — every override is reported
# --------------------------------------------------------------------------

NOTE = "title 'EPEE MALE 2' names EPEE; the source declared SABRE; the title wins"


def test_WPN_TITLE_07_the_staging_report_lists_each_override(monkeypatch, tmp_path):
    from python.pipeline.plugins.staging_formatter import StagingFormatter
    from python.tests.test_pipeline_plugins import _ingest
    from python.tests.test_staging_report import _event_ctx, _formatter_svc

    b1 = _ingest(monkeypatch)
    ctx = _event_ctx([b1.report], event=b1.get("event"))
    ctx.data["_weapon_notes"] = [{"name": "EPEE MALE 2", "note": NOTE}]
    StagingFormatter().run(ctx, _formatter_svc(tmp_path))
    md = [p for p in tmp_path.glob("*.md") if not p.name.endswith(".diff.md")][0].read_text()
    gaps = md[md.index("## Detected automation gaps") : md.index("## Fencer matching")]
    assert "EPEE MALE 2" in gaps and NOTE in gaps


def test_WPN_TITLE_07_the_event_report_collects_the_notes_of_its_brackets():
    from python.pipeline import ingest_cli
    from python.pipeline.core.contract import Context
    from python.pipeline.ir import ParsedTournament, SourceKind
    from python.pipeline.plugins import bridge

    noted, plain = Context(), Context()
    noted.data[bridge.LEGACY] = SimpleNamespace(
        parsed=ParsedTournament(
            source_kind=SourceKind.ENGARDE, tournament_name="EPEE MALE 2", weapon_note=NOTE
        )
    )
    plain.data[bridge.LEGACY] = SimpleNamespace(
        parsed=ParsedTournament(
            source_kind=SourceKind.ENGARDE, tournament_name="TABLE SABRE MALE 2"
        )
    )
    seen = {}

    def fake_run_flow(*_args, ctx=None, **_kw):
        assert ctx is not None
        seen["notes"] = ctx.get("_weapon_notes")
        return ctx

    with (
        patch("python.pipeline.run.run_flow", side_effect=fake_run_flow),
        patch("python.pipeline.international_report.section_lines", return_value=[]),
    ):
        ingest_cli._fire_staging_report(
            {"id_event": 1, "txt_code": "X"}, [noted, plain], db=MagicMock()
        )
    assert seen["notes"] == [{"name": "EPEE MALE 2", "note": NOTE}]


def test_WPN_TITLE_07_the_run_record_keeps_the_override():
    from python.pipeline.ir import ParsedTournament, SourceKind
    from python.pipeline.promotion.run_record import ListingLog

    base = ParsedTournament(source_kind=SourceKind.ENGARDE, weapon_note=NOTE)
    rec = {
        "name": "EPEE MALE 2",
        "uuid": "u",
        "url": "u",
        "count": 0,
        "has_de": True,
        "weapon": "EPEE",
        "gender": "M",
        "cats": ["V2"],
        "_base": base,
    }
    log = ListingLog()
    log.add_round(rec, {"status": "committed", "commit_cats": ["V2"]})
    assert log.listings()["rounds"][0]["weapon_note"] == NOTE
    rec["_base"] = ParsedTournament(source_kind=SourceKind.ENGARDE)
    log.add_round(rec, {"status": "committed", "commit_cats": ["V2"]})
    assert "weapon_note" not in log.listings()["rounds"][1]
