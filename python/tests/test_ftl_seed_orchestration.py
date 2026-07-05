"""
FR-125–FR-129 (RTM): FTL seed export — DB-querying orchestration layer (ADR-080).

The pure primitives (canonical name, interleave, bracket prediction, XML) are
covered in test_ftl_seed_export.py. This file covers the orchestration that ties
them to the event's data (ADR-080 §2, resolved 2026-07-05):

- POPULATION = every DECLARED tbl_registration row for the event (no payment
  gate — user 2026-07-04: "the correct list of names which declared intent to
  participate"). ORDERING within each sub-ranking comes from the current-season
  ranking fn_ranking_ppw: matched+ranked registrants seed in rank order,
  unranked ones (new fencers, or matched-but-never-scored) append after, ordered
  by registration timestamp (ts_created) for a deterministic result.
- The (N) marker is derived from the registration's DECLARED birth year (the
  read-only invariant — never tbl_fencer's), via age_split.birth_year_to_vcat.

The thin Supabase glue (FtlSeedExporter) is smoke-tested with a mocked client,
matching the test_draft_store.py convention; full E2E is validated on LOCAL.
"""

from __future__ import annotations

import io
import zipfile
from unittest.mock import MagicMock

import defusedxml.ElementTree as ET

from python.pipeline.ftl_seed_export import (
    assemble_mixall_subrankings,
    build_event_mixall_files,
    bundle_seed_zip,
    mixall_tireurs,
    mixall_title,
    registration_subranking_key,
    season_pretty,
)

# Season 2025-2026 → season_end_year 2026. Helper for readable birth years.
SEY = 2026


def _reg(idf, sur, first, gender, by, weapons, ts="2026-01-01T00:00:00Z"):
    return {
        "id_fencer": idf,
        "txt_surname": sur,
        "txt_first_name": first,
        "enum_gender": gender,
        "int_birth_year": by,
        "arr_weapons": weapons,
        "ts_created": ts,
    }


# ---------------------------------------------------------------------------
# registration_subranking_key — declared gender + declared BY → sub-ranking key
# ---------------------------------------------------------------------------
def test_subranking_key_men_v0():
    # 2026 - 1990 = 36 → V0
    assert registration_subranking_key("M", 1990, SEY) == "MV0"


def test_subranking_key_women_v2():
    # 2026 - 1970 = 56 → V2
    assert registration_subranking_key("F", 1970, SEY) == "FV2"


def test_subranking_key_too_young_is_none():
    # 2026 - 2005 = 21 → below V0 (veteran floor is 30) → no key
    assert registration_subranking_key("M", 2005, SEY) is None


# ---------------------------------------------------------------------------
# assemble_mixall_subrankings — population=registrations, order=ranking
# ---------------------------------------------------------------------------
def test_assemble_filters_by_declared_weapon():
    regs = [
        _reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE"]),
        _reg(2, "Nowak", "Piotr", "M", 1990, ["FOIL"]),  # not epee → excluded
    ]
    subr = assemble_mixall_subrankings(regs, "EPEE", {}, SEY)
    all_ids = [e.id_fencer for entries in subr.values() for e in entries]
    assert all_ids == [1]


def test_assemble_buckets_by_gender_and_vcat_with_canonical_names():
    regs = [
        _reg(1, "kowalski", "jan", "M", 1990, ["EPEE"]),  # MV0
        _reg(2, "nowak", "ANNA", "F", 1970, ["EPEE"]),  # FV2
    ]
    subr = assemble_mixall_subrankings(regs, "EPEE", {}, SEY)
    assert set(subr) == {"MV0", "FV2"}
    assert (subr["MV0"][0].surname, subr["MV0"][0].first_name) == ("KOWALSKI", "Jan")
    assert (subr["FV2"][0].surname, subr["FV2"][0].first_name) == ("NOWAK", "Anna")


def test_assemble_ranked_before_unranked_then_by_ts():
    # Three MV0 epee registrants: id 30 ranked #1, id 10 ranked #2, id None unranked.
    regs = [
        _reg(None, "Zzz", "Unranked", "M", 1990, ["EPEE"], ts="2026-02-01T00:00:00Z"),
        _reg(10, "Bbb", "Second", "M", 1990, ["EPEE"]),
        _reg(30, "Aaa", "First", "M", 1990, ["EPEE"]),
    ]
    rankings = {"MV0": [30, 10]}  # rank order: id 30 first, id 10 second
    subr = assemble_mixall_subrankings(regs, "EPEE", rankings, SEY)
    assert [e.surname for e in subr["MV0"]] == ["AAA", "BBB", "ZZZ"]


def test_assemble_multiple_unranked_ordered_by_ts_created():
    regs = [
        _reg(None, "Later", "B", "M", 1990, ["EPEE"], ts="2026-03-01T00:00:00Z"),
        _reg(None, "Earlier", "A", "M", 1990, ["EPEE"], ts="2026-01-01T00:00:00Z"),
    ]
    subr = assemble_mixall_subrankings(regs, "EPEE", {}, SEY)
    assert [e.surname for e in subr["MV0"]] == ["EARLIER", "LATER"]


# ---------------------------------------------------------------------------
# mixall_tireurs — seed order → FIE Tireur dicts
# ---------------------------------------------------------------------------
def test_mixall_tireurs_running_id_sexe_and_marker():
    regs = [
        _reg(1, "Peczek", "Sandra", "F", 1990, ["EPEE"]),  # FV0
        _reg(2, "Kowalski", "Jan", "M", 1970, ["EPEE"]),  # MV2
    ]
    subr = assemble_mixall_subrankings(regs, "EPEE", {}, SEY)
    from python.pipeline.ftl_seed_export import interleave_mixall

    tireurs = mixall_tireurs(interleave_mixall(subr))
    # FV0 comes before MV2 in the fixed order → Sandra seed 1, Jan seed 2.
    assert tireurs[0] == {
        "id": 1,
        "nom": "PECZEK",
        "prenom": "Sandra (0)",
        "sexe": "F",
        "classement": 1,
    }
    assert tireurs[1] == {
        "id": 2,
        "nom": "KOWALSKI",
        "prenom": "Jan (2)",
        "sexe": "M",
        "classement": 2,
    }


# ---------------------------------------------------------------------------
# season_pretty + mixall_title
# ---------------------------------------------------------------------------
def test_season_pretty():
    assert season_pretty("SPWS-2025-2026") == "2025/2026"


def test_mixall_title_polish_weapon_name():
    assert mixall_title("EPEE", "SPWS-2025-2026") == "SPWS Szpada ELIMINACJE (mix-all) 2025/2026"
    assert mixall_title("SABRE", "SPWS-2025-2026") == "SPWS Szabla ELIMINACJE (mix-all) 2025/2026"


# ---------------------------------------------------------------------------
# build_event_mixall_files — one mix-all file per weapon that has registrants
# ---------------------------------------------------------------------------
def test_build_event_mixall_files_one_per_weapon_with_registrants():
    regs = [
        _reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE", "SABRE"]),
        _reg(2, "Nowak", "Anna", "F", 1970, ["EPEE"]),
    ]
    files = build_event_mixall_files(
        registrations=regs,
        weapons=["EPEE", "FOIL", "SABRE"],
        rankings_by_weapon={},
        season_code="SPWS-2025-2026",
        event_code_stem="PPW5",
        season_end_year=SEY,
    )
    # EPEE has 2, SABRE has 1, FOIL has 0 → FOIL file omitted.
    assert set(files) == {
        "SPWS-2025-2026_PPW5_E_mixall.xml",
        "SPWS-2025-2026_PPW5_S_mixall.xml",
    }
    root = ET.fromstring(files["SPWS-2025-2026_PPW5_E_mixall.xml"].split("\n", 2)[-1])
    assert root.get("ID") == "SPWS-2025-2026_PPW5_E_mixall"
    assert root.get("Arme") == "E"
    assert len(root.findall(".//Tireur")) == 2


def test_build_event_mixall_files_interleave_and_marker_end_to_end():
    regs = [
        _reg(1, "Peczek", "Sandra", "F", 1990, ["EPEE"]),  # FV0
        _reg(2, "Borkowska", "Halina", "F", 1950, ["EPEE"]),  # FV3 (2026-1950=76)... V4
        _reg(3, "Kowalski", "Jan", "M", 1990, ["EPEE"]),  # MV0
    ]
    files = build_event_mixall_files(
        registrations=regs,
        weapons=["EPEE"],
        rankings_by_weapon={},
        season_code="SPWS-2025-2026",
        event_code_stem="PPW5",
        season_end_year=SEY,
    )
    root = ET.fromstring(files["SPWS-2025-2026_PPW5_E_mixall.xml"].split("\n", 2)[-1])
    tireurs = root.findall(".//Tireur")
    # Fixed order FV0,FV4,MV0 → Sandra(0), Halina(4), Jan(0); running Classement.
    assert [t.get("Nom") for t in tireurs] == ["PECZEK", "BORKOWSKA", "KOWALSKI"]
    assert [t.get("Prenom") for t in tireurs] == ["Sandra (0)", "Halina (4)", "Jan (0)"]
    assert [t.get("Classement") for t in tireurs] == ["1", "2", "3"]


# ---------------------------------------------------------------------------
# bundle_seed_zip
# ---------------------------------------------------------------------------
def test_bundle_seed_zip_roundtrips_files():
    files = {"a.xml": "<a/>", "b.xml": "<b/>"}
    blob = bundle_seed_zip(files)
    with zipfile.ZipFile(io.BytesIO(blob)) as z:
        assert set(z.namelist()) == {"a.xml", "b.xml"}
        assert z.read("a.xml").decode() == "<a/>"


# ---------------------------------------------------------------------------
# FtlSeedExporter — thin Supabase glue (mocked client)
# ---------------------------------------------------------------------------
def test_exporter_fetch_registrations_queries_event():
    from python.pipeline.ftl_seed_export_db import FtlSeedExporter

    sb = MagicMock()
    sb.table.return_value.select.return_value.eq.return_value.order.return_value.execute.return_value.data = [
        _reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE"]),
    ]
    exp = FtlSeedExporter(sb)
    rows = exp.fetch_registrations(42)
    sb.table.assert_called_with("tbl_registration")
    assert rows[0]["txt_surname"] == "Kowalski"


def test_exporter_build_bundle_wires_rankings_and_returns_files():
    from python.pipeline.ftl_seed_export_db import FtlSeedExporter

    sb = MagicMock()
    # registrations: one EPEE man
    sb.table.return_value.select.return_value.eq.return_value.order.return_value.execute.return_value.data = [
        _reg(1, "Kowalski", "Jan", "M", 1990, ["EPEE"]),
    ]
    # every fn_ranking_ppw rpc returns Jan ranked #1 in his sub-ranking
    sb.rpc.return_value.execute.return_value.data = [
        {"rank": 1, "id_fencer": 1, "fencer_name": "KOWALSKI Jan"},
    ]
    exp = FtlSeedExporter(sb)
    files = exp.build_bundle(
        id_event=42,
        weapons=["EPEE"],
        season_code="SPWS-2025-2026",
        event_code_stem="PPW5",
        season_end_year=SEY,
        season=None,
    )
    assert "SPWS-2025-2026_PPW5_E_mixall.xml" in files
    # rpc was called for the ranking lookups (10 sub-rankings for one weapon)
    assert sb.rpc.call_count >= 1
