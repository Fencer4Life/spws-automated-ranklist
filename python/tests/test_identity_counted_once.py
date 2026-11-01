"""IDENTITY.ONCE — a fencer the identity step finds twice is one fit (ADR-119 G59 A).

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, G59.

The first source re-read (1 Nov 2026) found Tbilisi 2026 (MSW-2026-2027) and
IMSW 2025 refused: "SEKOWSKI Maciej: two roster fencers fit". The roster holds
one SĘKOWSKI Maciej, whose confirmed alias is "SEKOWSKI Maciej". At an FIE
event the row is matched by identity (Polish letters folded) and by alias;
both find id 263, and since G41's rewrite (732ca516, released d5947612) the
step de-duplicated a text's hits only against earlier texts, never within
them, so 263 counted twice. Before it, alias hits were de-duplicated against
the identity hits.

  IDENTITY.ONCE.01  an FIE row found by identity and by its alias is stored;
  IDENTITY.ONCE.02  the same with an SPWS start;
  IDENTITY.ONCE.03  a reading naming the same fencer as the name is one fit;
  IDENTITY.ONCE.04  two fencers who both fit are still two (namesakes).
"""

from __future__ import annotations

import pytest

from python.pipeline.international_admission import PENDING, STORED, admit


def _fencer(fid, surname, first, year, aliases=()):
    return {
        "id_fencer": fid,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": year,
        "json_user_confirmed_aliases": list(aliases),
        "json_revoked_aliases": [],
    }


# The three fencers of the refusals, as LOCAL (PROD's mirror) holds them.
ROSTER = [
    _fencer(263, "SĘKOWSKI", "Maciej", 1981, ["SĘKOWSKI Maciej (1) O.", "SEKOWSKI Maciej"]),
    _fencer(139, "KORONA", "Przemysław", 1976, ["KORONA Przemyslaw", "KORONA-TRZEBSKI Przemysław"]),
    _fencer(140, "KORONA", "Radosław", 1981),
    _fencer(138, "KORNAŚ", "Jarosław", 1985, ["KORNAS Jaroslaw"]),
]


@pytest.mark.parametrize(
    ("printed", "category", "fid"),
    [
        ("SEKOWSKI Maciej", "V1", 263),
        ("KORONA Przemyslaw", "V2", 139),
        ("KORNAS Jaroslaw", "V1", 138),
    ],
)
def test_IDENTITY_ONCE_01_an_fie_row_found_by_identity_and_alias_is_stored(printed, category, fid):
    got = admit(
        printed,
        "POL",
        category=category,
        season_end_year=2027,
        roster=ROSTER,
        spws_starters=set(),
        tournament_type="MSW",
    )
    assert (got.decision, got.id_fencer) == (STORED, fid)
    assert got.reason == "identity, entered by POL at an FIE event"


def test_IDENTITY_ONCE_02_with_an_spws_start():
    got = admit(
        "SEKOWSKI Maciej",
        "POL",
        category="V1",
        season_end_year=2027,
        roster=ROSTER,
        spws_starters={263},
        tournament_type="MSW",
    )
    assert (got.decision, got.id_fencer, got.reason) == (STORED, 263, "identity, SPWS start")


@pytest.mark.parametrize("tournament_type", ["MSW", None])
def test_IDENTITY_ONCE_03_a_reading_naming_the_same_fencer_is_one_fit(tournament_type):
    got = admit(
        "SĘKOWSKI SĘKOWSKI Maciej",
        "POL",
        category="V1",
        season_end_year=2027,
        roster=ROSTER,
        spws_starters={263},
        tournament_type=tournament_type,
        readings=("SĘKOWSKI Maciej", "SEKOWSKI Maciej"),
    )
    assert (got.decision, got.id_fencer) == (STORED, 263)


def test_IDENTITY_ONCE_04_two_fencers_who_both_fit_are_still_two():
    namesakes = [*ROSTER, _fencer(900, "SĘKOWSKI", "Maciej", 1983)]
    got = admit(
        "SEKOWSKI Maciej",
        "POL",
        category="V1",
        season_end_year=2027,
        roster=namesakes,
        spws_starters=set(),
        tournament_type="MSW",
    )
    assert (got.decision, got.reason) == (PENDING, "two roster fencers fit")
