"""PROMO.ID.01–16 — comparing two environments by who people are, never by id.

ADR-108 compares CERT with PROD at several points: the refresh's dry run, the
input check before promote, the explanation when a fingerprint differs, and the
full results comparison after the first alignment. Fencer ids are not a usable
key for any of these until the alignment has run, and even afterwards a diff a
person reads must name people, not numbers.

`python.pipeline.promotion.identity` therefore keys every row by identity:
folded surname, folded first name and birth year, folded exactly the way the
exact-name step of the ingestion folds them. It diffs two normalised sets field
by field. Two rows sharing one identity in the same set are never collapsed:
they are reported as ambiguous, because nothing is guessed.
"""

from __future__ import annotations

from decimal import Decimal

from python.matcher.fuzzy_match import normalize_name
from python.pipeline.promotion import identity as idn


def _result(code, surname, first, by, place, score, method="AUTO_MATCHED", id_fencer=1):
    return {
        "txt_tournament_code": code,
        "id_fencer": id_fencer,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "int_place": place,
        "num_final_score": score,
        "enum_match_method": method,
    }


def _fencer(surname, first, by, *, gender="M", estimated=False, nat="POL", id_fencer=1):
    return {
        "id_fencer": id_fencer,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "bool_birth_year_estimated": estimated,
        "enum_gender": gender,
        "txt_nationality": nat,
    }


def _registration(surname, first, by, weapons, *, gender="M", ftl=None, club=None):
    return {
        "id_registration": 7,
        "id_fencer": 3,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "enum_gender": gender,
        "arr_weapons": weapons,
        "txt_ftl_name": ftl,
        "txt_club": club,
        "txt_email_hash": "never-compared",
        "uuid_edit_token": "never-compared",
    }


class TestIdentityKey:
    def test_folds_names_like_the_exact_name_step(self):
        """PROMO.ID.01 — the fold is the ingestion's own: diacritics, case, spacing."""
        key = idn.Identity.of("  BARAŃSKI ", "Łukasz", 1970)
        assert key == idn.Identity.of("baranski", "LUKASZ", 1970)
        assert key.surname == normalize_name("BARAŃSKI", use_diacritic_folding=True)
        assert key.first_name == normalize_name("Łukasz", use_diacritic_folding=True)

    def test_the_id_never_enters_the_key(self):
        """PROMO.ID.02 — the same person under two ids is the same identity."""
        cert = [_result("PPW1-V2-M-EPEE-2026-2027", "NOWAK", "Jan", 1975, 1, 42, id_fencer=37)]
        prod = [_result("PPW1-V2-M-EPEE-2026-2027", "NOWAK", "Jan", 1975, 1, 42, id_fencer=38)]
        assert idn.diff(idn.normalise_results(cert), idn.normalise_results(prod)).equal

    def test_birth_year_is_part_of_identity(self):
        """PROMO.ID.03 — namesakes with different birth years are two people.

        A birth-year difference is never shown as a changed field of one person:
        it is one person on each side, which is what the namesake rule needs.
        """
        left = idn.normalise_results([_result("T", "KRAWCZYK", "Paweł", 1954, 1, 10)])
        right = idn.normalise_results([_result("T", "KRAWCZYK", "Paweł", 1989, 1, 10)])
        d = idn.diff(left, right)
        assert not d.equal
        assert d.only_left == (("T", idn.Identity.of("KRAWCZYK", "Paweł", 1954)),)
        assert d.only_right == (("T", idn.Identity.of("KRAWCZYK", "Paweł", 1989)),)
        assert d.changed == ()

    def test_a_missing_birth_year_is_an_identity_of_its_own(self):
        """PROMO.ID.04 — nine fencers have no birth year; None equals None."""
        left = idn.normalise_roster([_fencer("KOWALSKA", "Anna", None, gender="F")])
        right = idn.normalise_roster([_fencer("KOWALSKA", "Anna", None, gender="F")])
        assert idn.diff(left, right).equal


class TestResults:
    def test_equal_sets_compare_equal_in_any_order(self):
        """PROMO.ID.05 — row order and ids do not matter."""
        a = [
            _result("T1", "NOWAK", "Jan", 1975, 1, 42, id_fencer=1),
            _result("T1", "WIŚNIEWSKI", "Piotr", 1980, 2, 30, id_fencer=2),
        ]
        b = [
            _result("T1", "WISNIEWSKI", "Piotr", 1980, 2, 30, id_fencer=9),
            _result("T1", "NOWAK", "Jan", 1975, 1, 42, id_fencer=8),
        ]
        d = idn.diff(idn.normalise_results(a), idn.normalise_results(b))
        assert d.equal
        assert d.only_left == d.only_right == d.changed == ()

    def test_a_changed_place_score_or_method_is_named(self):
        """PROMO.ID.06 — each differing field is one change, with both values."""
        a = idn.normalise_results([_result("T1", "NOWAK", "Jan", 1975, 1, 42, "AUTO_MATCHED")])
        b = idn.normalise_results([_result("T1", "NOWAK", "Jan", 1975, 2, 40, "AUTO_CREATED")])
        d = idn.diff(a, b)
        key = ("T1", idn.Identity.of("NOWAK", "Jan", 1975))
        assert d.changed == (
            idn.FieldChange(key, "enum_match_method", "AUTO_MATCHED", "AUTO_CREATED"),
            idn.FieldChange(key, "int_place", 1, 2),
            idn.FieldChange(key, "num_final_score", Decimal("42"), Decimal("40")),
        )

    def test_scores_compare_as_numbers(self):
        """PROMO.ID.07 — 59.16, '59.160' and Decimal('59.1600') are one score."""
        a = idn.normalise_results([_result("T1", "NOWAK", "Jan", 1975, 1, 59.16)])
        b = idn.normalise_results([_result("T1", "NOWAK", "Jan", 1975, 1, "59.160")])
        c = idn.normalise_results([_result("T1", "NOWAK", "Jan", 1975, 1, Decimal("59.1600"))])
        e = idn.normalise_results([_result("T1", "NOWAK", "Jan", 1975, 1, 59.17)])
        assert idn.diff(a, b).equal
        assert idn.diff(a, c).equal
        assert not idn.diff(a, e).equal

    def test_a_row_on_one_side_only_is_listed(self):
        """PROMO.ID.08 — someone missing on one side is listed, never ignored."""
        a = idn.normalise_results(
            [
                _result("T1", "NOWAK", "Jan", 1975, 1, 42),
                _result("T1", "ZIELIŃSKI", "Adam", 1966, 2, 30),
            ]
        )
        b = idn.normalise_results([_result("T1", "NOWAK", "Jan", 1975, 1, 42)])
        d = idn.diff(a, b)
        assert d.only_left == (("T1", idn.Identity.of("ZIELIŃSKI", "Adam", 1966)),)
        assert d.only_right == ()

    def test_two_rows_with_one_identity_are_never_collapsed(self):
        """PROMO.ID.09 — nothing is guessed: a shared identity is ambiguous.

        Both rows leave the comparison and are reported with their count, and
        the sets never compare equal while one remains.
        """
        twins = [
            _result("T1", "NOWAK", "Jan", 1975, 1, 42, id_fencer=1),
            _result("T1", "NOWAK", "Jan", 1975, 3, 20, id_fencer=2),
        ]
        a = idn.normalise_results(twins)
        assert a.ambiguous == {("T1", idn.Identity.of("NOWAK", "Jan", 1975)): 2}
        assert a.rows == {}
        d = idn.diff(a, idn.normalise_results(twins))
        assert not d.equal
        assert (
            d.ambiguous_left
            == d.ambiguous_right
            == (("T1", idn.Identity.of("NOWAK", "Jan", 1975)),)
        )


class TestTournaments:
    def test_tournaments_compare_by_code_on_n_and_joined_order(self):
        """PROMO.ID.10 — N and the joined-bracket category order, by tournament code."""
        a = idn.normalise_tournaments(
            [
                {
                    "id_tournament": 1,
                    "txt_code": "T1",
                    "int_participant_count": 9,
                    "txt_joined_order": "223",
                }
            ]
        )
        b = idn.normalise_tournaments(
            [
                {
                    "id_tournament": 5,
                    "txt_code": "T1",
                    "int_participant_count": 9,
                    "txt_joined_order": "232",
                }
            ]
        )
        assert idn.diff(a, b).changed == (idn.FieldChange("T1", "txt_joined_order", "223", "232"),)

    def test_a_digit_string_stays_text(self):
        """PROMO.ID.15 — the column, not the text, decides what is a number.

        A joined order is a string of category digits; "023" and "23" are two
        different orders, and only `num_*` columns compare as numbers.
        """
        a = idn.normalise_tournaments(
            [{"txt_code": "T1", "int_participant_count": 3, "txt_joined_order": "023"}]
        )
        b = idn.normalise_tournaments(
            [{"txt_code": "T1", "int_participant_count": 3, "txt_joined_order": "23"}]
        )
        assert idn.diff(a, b).changed == (idn.FieldChange("T1", "txt_joined_order", "023", "23"),)


class TestRosterAndRegistrations:
    def test_roster_fields_compare_by_identity(self):
        """PROMO.ID.11 — the confirmed flag, gender, nationality and spelling.

        A corrected diacritic keeps the identity (the fold matches) and shows
        as a changed spelling, so the dry run can say exactly what moves.
        """
        cert = idn.normalise_roster(
            [_fencer("BARANSKI", "Lukasz", 1970, estimated=True, id_fencer=37)]
        )
        prod = idn.normalise_roster(
            [_fencer("BARAŃSKI", "Łukasz", 1970, estimated=False, id_fencer=38)]
        )
        key = idn.Identity.of("BARAŃSKI", "Łukasz", 1970)
        assert idn.diff(cert, prod).changed == (
            idn.FieldChange(key, "bool_birth_year_estimated", True, False),
            idn.FieldChange(key, "txt_first_name", "Lukasz", "Łukasz"),
            idn.FieldChange(key, "txt_surname", "BARANSKI", "BARAŃSKI"),
        )

    def test_registrations_compare_what_the_ingestion_reads(self):
        """PROMO.ID.12 — declared year, gender, weapons (in any order), FTL name, club.

        The e-mail hash and the edit token are never part of the comparison.
        """
        a = idn.normalise_registrations(
            [_registration("NOWAK", "Jan", 1975, ["EPEE", "FOIL"], club="AZS")]
        )
        b = idn.normalise_registrations(
            [_registration("NOWAK", "Jan", 1975, ["FOIL", "EPEE"], club="AZS")]
        )
        assert idn.diff(a, b).equal
        assert "txt_email_hash" not in idn.REGISTRATION_FIELDS
        assert "uuid_edit_token" not in idn.REGISTRATION_FIELDS
        c = idn.normalise_registrations([_registration("NOWAK", "Jan", 1975, ["EPEE"], club="AZS")])
        key = idn.Identity.of("NOWAK", "Jan", 1975)
        assert idn.diff(a, c).changed == (
            idn.FieldChange(key, "arr_weapons", ("EPEE", "FOIL"), ("EPEE",)),
        )


class TestReport:
    def test_the_diff_is_sorted_and_stable(self):
        """PROMO.ID.13 — the same inputs always give the same report order."""
        rows = [
            _result("T2", "ZIELIŃSKI", "Adam", 1966, 1, 30),
            _result("T1", "NOWAK", "Jan", 1975, 1, 42),
            _result("T1", "ADAMSKI", "Ewa", 1980, 2, 20),
        ]
        d1 = idn.diff(idn.normalise_results(rows), idn.normalise_results([]))
        d2 = idn.diff(idn.normalise_results(list(reversed(rows))), idn.normalise_results([]))
        assert d1.only_left == d2.only_left
        assert d1.only_left == (
            ("T1", idn.Identity.of("ADAMSKI", "Ewa", 1980)),
            ("T1", idn.Identity.of("NOWAK", "Jan", 1975)),
            ("T2", idn.Identity.of("ZIELIŃSKI", "Adam", 1966)),
        )

    def test_lines_name_people_not_ids(self):
        """PROMO.ID.14 — the readable report names each person and both values."""
        a = idn.normalise_results([_result("T1", "NOWAK", "Jan", 1975, 1, 42, id_fencer=37)])
        b = idn.normalise_results([_result("T1", "NOWAK", "Jan", 1975, 2, 42, id_fencer=38)])
        lines = idn.diff(a, b).lines(left="CERT", right="PROD")
        assert lines == ["T1 · nowak jan (1975) · int_place: CERT 1, PROD 2"]
        assert all("37" not in line and "38" not in line for line in lines)

    def test_an_empty_list_reads_as_empty_not_as_nothing(self):
        """PROMO.ID.16 — "[]" and "—" say what is there; a blank looks cut off."""
        cert = idn.normalise_roster([{**_fencer("NOWAK", "Jan", 1975), "json_name_aliases": ["NOWAK J."]}])
        prod = idn.normalise_roster([{**_fencer("NOWAK", "Jan", 1975), "json_name_aliases": []}])
        assert idn.diff(cert, prod).lines("CERT", "PROD") == [
            "nowak jan (1975) · json_name_aliases: CERT NOWAK J., PROD []"
        ]
