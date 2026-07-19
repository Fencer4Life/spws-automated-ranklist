"""Seed FK reconstruction must identify a fencer by SURNAME + Name + BIRTH YEAR.

The monolithic seed rebuilds tbl_result's id_fencer with a name sub-SELECT
(ADR-036). Name alone is not an identity: PROD holds two same-name pairs that
are different people -- KRAWCZYK Paweł (1954 / 1989) and MŁYNEK Janusz
(1951 / 1984). An unqualified `... AND txt_first_name = 'Janusz' LIMIT 1`
resolves arbitrarily, and fn_assert_result_vcat (ADR-047) then rejects the
seed on any fresh bootstrap -- CI and ./scripts/reset-dev.sh both.

Governed by the ADR-036 amendment (2026-07-14).
"""

from python.pipeline.export_seed import fencer_lookup


def test_lookup_is_qualified_by_birth_year():
    sql = fencer_lookup("MŁYNEK", "Janusz", 1951)
    assert "int_birth_year = 1951" in sql
    assert "txt_surname = 'MŁYNEK'" in sql
    assert "txt_first_name = 'Janusz'" in sql


def test_same_name_different_birth_year_yields_different_sql():
    """The whole point: the two MŁYNEK Janusz rows must not collide."""
    a = fencer_lookup("MŁYNEK", "Janusz", 1951)
    b = fencer_lookup("MŁYNEK", "Janusz", 1984)
    assert a != b


def test_krawczyk_pair_also_disambiguates():
    a = fencer_lookup("KRAWCZYK", "Paweł", 1954)
    b = fencer_lookup("KRAWCZYK", "Paweł", 1989)
    assert a != b


def test_null_birth_year_matches_is_null_not_equals():
    """`int_birth_year = NULL` is never true and would break the FK.

    Nine PROD fencers carry no birth year; they must still resolve.
    """
    sql = fencer_lookup("KWAPISZEWSKA", "Agnieszka", None)
    assert "int_birth_year IS NULL" in sql
    assert "= NULL" not in sql


def test_quotes_are_escaped():
    sql = fencer_lookup("O'CONNOR", "Seán", 1970)
    assert "O''CONNOR" in sql
