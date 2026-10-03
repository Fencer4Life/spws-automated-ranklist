"""PROMO.REFRESH.01–23 — CERT starts from PROD's master data with identical fencer ids.

ADR-108 §2–§3. The administrator's rule: the fencer id is the same on LOCAL, CERT
and PROD, and nothing is guessed. `python.pipeline.promotion.refresh`:

  - pairs every target fencer with its PROD row, per folded surname and first
    name: one fencer of the name on each side is the same person; namesakes are
    paired only by an equal confirmed birth year; a name only on PROD is created
    at PROD's id; a name only on the target is deleted when nothing refers to it;
    anything else stops the refresh before it writes, listed for a decision that
    is recorded in doc/overrides/fencer-alignment.yaml;
  - reads PROD only inside read-only transactions;
  - writes only LOCAL or CERT, through fn_align_fencers_to and
    fn_replace_event_registrations, with a database dry run first;
  - drains the target's recompute queue to empty, then re-reads the roster and
    requires it to equal PROD's.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from python.pipeline.promotion import refresh as rf


def _f(
    id_fencer, surname, first, by, *, estimated=False, gender="M", aliases=None, nat="PL", club=None
):
    return {
        "id_fencer": id_fencer,
        "txt_surname": surname,
        "txt_first_name": first,
        "int_birth_year": by,
        "bool_birth_year_estimated": estimated,
        "enum_gender": gender,
        "txt_nationality": nat,
        "txt_club": club,
        "json_name_aliases": aliases,
        "json_revoked_aliases": [],
        "json_user_confirmed_aliases": [],
        "ts_created": "2026-01-01T00:00:00+00:00",
        "ts_updated": "2026-01-01T00:00:00+00:00",
    }


def _ids(pairs):
    return {(p.cert_id, p.prod_id) for p in pairs}


class TestPairing:
    def test_one_fencer_of_a_name_on_each_side_is_the_same_person(self):
        """PROMO.REFRESH.01 — whatever the ids and birth years; diacritics fold."""
        target = [_f(37, "CHUDY", "Tomasz", 1980), _f(5, "BARANSKI", "Lukasz", 1970)]
        prod = [_f(38, "CHUDY", "Tomasz", 1977), _f(6, "BARAŃSKI", "Łukasz", 1970)]
        plan = rf.pair_rosters(target, prod, references={})
        assert plan.ready
        assert _ids(plan.pairs) == {(37, 38), (5, 6)}
        assert {p.rule for p in plan.pairs} == {"one_each"}

    def test_namesakes_pair_by_an_equal_confirmed_birth_year(self):
        """PROMO.REFRESH.02 — the two KRAWCZYK Paweł, under each other's ids."""
        target = [_f(355, "KRAWCZYK", "Paweł", 1989), _f(356, "KRAWCZYK", "Paweł", 1954)]
        prod = [_f(354, "KRAWCZYK", "Paweł", 1989), _f(355, "KRAWCZYK", "Paweł", 1954)]
        plan = rf.pair_rosters(target, prod, references={355: 3, 356: 9})
        assert plan.ready
        assert _ids(plan.pairs) == {(355, 354), (356, 355)}
        assert {p.rule for p in plan.pairs} == {"namesake_birth_year"}

    def test_namesakes_the_birth_year_does_not_decide_stop_the_refresh(self):
        """PROMO.REFRESH.03 — an estimated year, or no equal year, is never a match."""
        target = [_f(1, "NOWAK", "Jan", 1970, estimated=True), _f(2, "NOWAK", "Jan", 1980)]
        prod = [_f(1, "NOWAK", "Jan", 1970), _f(2, "NOWAK", "Jan", 1981)]
        plan = rf.pair_rosters(target, prod, references={1: 1, 2: 1})
        assert not plan.ready
        assert plan.pairs == ()
        assert {(u.side, u.id_fencer) for u in plan.unpaired} == {
            ("target", 1),
            ("target", 2),
            ("prod", 1),
            ("prod", 2),
        }

    def test_a_leftover_namesake_on_one_side_only_is_created_or_deleted(self):
        """PROMO.REFRESH.04 — leftovers on one side cannot be anyone on the other.

        A PROD namesake left over while every target namesake is paired is a new
        person, created at PROD's id. Leftovers on both sides might be the same
        person under different years, so they stop the refresh.
        """
        target = [_f(10, "MŁYNEK", "Janusz", 1951)]
        prod = [_f(197, "MŁYNEK", "Janusz", 1951), _f(356, "MŁYNEK", "Janusz", 1984)]
        plan = rf.pair_rosters(target, prod, references={10: 4})
        assert plan.ready
        assert _ids(plan.pairs) == {(10, 197)}
        assert plan.creates == (356,)

        target = [_f(10, "MŁYNEK", "Janusz", 1951), _f(11, "MŁYNEK", "Janusz", 1985)]
        plan = rf.pair_rosters(target, prod, references={10: 4, 11: 1})
        assert not plan.ready
        assert {(u.side, u.id_fencer) for u in plan.unpaired} == {("target", 11), ("prod", 356)}

    def test_a_name_only_on_prod_is_created_at_prods_id(self):
        """PROMO.REFRESH.05"""
        plan = rf.pair_rosters([], [_f(368, "NOWA", "Ewa", 1990, gender="F")], references={})
        assert plan.ready
        assert plan.creates == (368,)

    def test_a_name_only_on_the_target_is_deleted_only_when_nothing_refers_to_it(self):
        """PROMO.REFRESH.06"""
        plan = rf.pair_rosters([_f(400, "TESTOWY", "Test", 1970)], [], references={})
        assert plan.ready
        assert plan.deletes == (400,)

        plan = rf.pair_rosters([_f(400, "TESTOWY", "Test", 1970)], [], references={400: 2})
        assert not plan.ready
        assert plan.unpaired[0].side == "target"
        assert "2" in plan.unpaired[0].why


class TestRecordedDecisions:
    def test_a_recorded_pair_holds_only_while_the_target_row_still_matches(self, tmp_path: Path):
        """PROMO.REFRESH.07 — a name corrected on PROD, paired by a written decision.

        Target ids change after an alignment, so each record names the target row
        by id and identity; a record that no longer matches stops the refresh.
        """
        target = [_f(41, "KOWALSKY", "Jan", 1970)]
        prod = [_f(42, "KOWALSKI", "Jan", 1970)]
        assert not rf.pair_rosters(target, prod, references={41: 3}).ready

        recorded = (
            rf.RecordedPair(
                cert_id=41, surname="KOWALSKY", first_name="Jan", birth_year=1970, prod_id=42
            ),
        )
        plan = rf.pair_rosters(target, prod, references={41: 3}, recorded=recorded)
        assert plan.ready
        assert {(p.cert_id, p.prod_id, p.rule) for p in plan.pairs} == {(41, 42, "recorded")}

        stale = (
            rf.RecordedPair(
                cert_id=41, surname="KOWALSKY", first_name="Jan", birth_year=1971, prod_id=42
            ),
        )
        plan = rf.pair_rosters(target, prod, references={41: 3}, recorded=stale)
        assert not plan.ready
        assert any("no longer matches" in u.why for u in plan.unpaired)

    def test_the_decisions_file_holds_complete_pair_entries_only(self, tmp_path: Path):
        """PROMO.REFRESH.08"""
        good = tmp_path / "fencer-alignment.yaml"
        good.write_text(
            "pair:\n  - {cert_id: 41, surname: KOWALSKY, first_name: Jan, birth_year: 1970, prod_id: 42}\n"
        )
        assert rf.load_recorded_pairs(good) == (
            rf.RecordedPair(
                cert_id=41, surname="KOWALSKY", first_name="Jan", birth_year=1970, prod_id=42
            ),
        )
        assert rf.load_recorded_pairs(tmp_path / "missing.yaml") == ()

        for bad in (
            "merge:\n  - {cert_id: 1}\n",
            "pair:\n  - {cert_id: 41, surname: KOWALSKY, prod_id: 42}\n",
            "pair: 7\n",
        ):
            good.write_text(bad)
            with pytest.raises(rf.RefreshError):
                rf.load_recorded_pairs(good)


class TestPayloadAndReport:
    def test_the_payload_covers_every_paired_fencer_and_prods_whole_roster(self):
        """PROMO.REFRESH.09"""
        target = [_f(1, "A", "A", 1970), _f(2, "B", "B", 1971), _f(9, "Z", "Z", 1972)]
        prod = [_f(1, "A", "A", 1970), _f(3, "B", "B", 1971), _f(4, "C", "C", 1973)]
        plan = rf.pair_rosters(target, prod, references={})
        payload = plan.payload(prod, prod_sequence=370)
        assert sorted((p["cert_id"], p["prod_id"]) for p in payload["p_pairs"]) == [(1, 1), (2, 3)]
        assert payload["p_prod_roster"] == prod
        assert payload["p_deletes"] == [9]
        assert payload["p_prod_sequence"] == 370

    def test_the_report_counts_and_names_what_will_change(self):
        """PROMO.REFRESH.10"""
        target = [
            _f(37, "CHUDY", "Tomasz", 1980),
            _f(1, "STAŁY", "Adam", 1970),
            _f(400, "TESTOWY", "Test", 1970),
            _f(77, "NOWAK", "Jan", 1970, estimated=True),
            _f(78, "NOWAK", "Jan", 1980),
        ]
        prod = [
            _f(38, "CHUDY", "Tomasz", 1977),
            _f(1, "STAŁY", "Adam", 1970),
            _f(368, "NOWA", "Ewa", 1990, gender="F"),
            _f(77, "NOWAK", "Jan", 1970),
            _f(78, "NOWAK", "Jan", 1981),
        ]
        plan = rf.pair_rosters(target, prod, references={77: 1, 78: 1})
        report = rf.describe(plan, target, prod)
        assert report.counts == {
            "target_fencers": 5,
            "prod_fencers": 5,
            "paired": 2,
            "renumbered": 1,
            "same_id": 1,
            "created": 1,
            "deleted": 1,
            "values_changed": 1,
            "unpaired": 4,
        }
        text = "\n".join(report.lines)
        assert "37 → 38" in text and "chudy tomasz" in text.lower()
        assert "int_birth_year: target 1980, PROD 1977" in text
        assert "NOWAK Jan" in text


class _FakeTransport:
    """Answers each query by the first key found in it; records every statement."""

    def __init__(
        self,
        answers: dict[str, Any],
        *,
        read_only: bool = False,
        errors: dict[str, str] | None = None,
    ):
        self.answers = answers
        self.read_only = read_only
        self.errors = errors or {}
        self.sql: list[str] = []

    def fetch_json(self, sql: str) -> Any:
        self.sql.append(sql)
        for key, message in self.errors.items():
            if key in sql:
                raise rf.SqlError(message)
        for key, value in self.answers.items():
            if key in sql:
                return value
        raise AssertionError(f"unexpected query: {sql[:120]}")


class TestTransports:
    def test_prod_is_read_only_inside_a_read_only_transaction(self):
        """PROMO.REFRESH.11 — the database itself refuses a write on PROD.

        The Management API returns the SELECT's rows from inside
        BEGIN TRANSACTION READ ONLY … COMMIT, and PostgreSQL refuses any write
        there (probed on PROD with a temp table, 3 Oct 2026).
        """
        with pytest.raises(rf.RefreshError):
            rf.ProdReader(_FakeTransport({}, read_only=False))

        sent: list[str] = []

        class _Resp:
            status_code = 200
            text = ""

            def json(self):
                return [{"j": [1]}]

        def post(url, headers, json):  # noqa: A002
            sent.append(json["query"])
            return _Resp()

        t = rf.ManagementTransport("ref", "token", read_only=True, post=post)
        assert t.fetch_json("SELECT 1 AS j") == [1]
        assert sent == ["BEGIN TRANSACTION READ ONLY; SELECT 1 AS j; COMMIT;"]

    def test_only_local_and_cert_can_be_written(self):
        """PROMO.REFRESH.12"""
        for name in ("prod", "PROD", "staging"):
            with pytest.raises(rf.RefreshError):
                rf.TargetDb(name, _FakeTransport({}))
        assert rf.TargetDb("cert", _FakeTransport({})).name == "cert"

    def test_registrations_are_read_without_hash_token_or_consent(self):
        """PROMO.REFRESH.17 — what PROD sends is only what the ingestion reads."""
        sql = rf.registrations_sql("PPW1-2026-2027")
        for never in ("txt_email_hash", "uuid_edit_token", "ts_consent", "txt_consent_version"):
            assert never not in sql
        for column in (
            "txt_surname",
            "txt_first_name",
            "enum_gender",
            "int_birth_year",
            "arr_weapons",
            "txt_ftl_name",
            "txt_club",
            "id_fencer",
        ):
            assert column in sql

    def test_an_event_code_is_an_exact_code(self):
        """PROMO.REFRESH.18 — nothing but a code reaches the SQL text."""
        for bad in ("PPW1'; DROP TABLE tbl_fencer; --", "PPW1 2026", "", "PPW1%"):
            with pytest.raises(rf.RefreshError):
                rf.registrations_sql(bad)

    def test_the_database_dry_run_answer_is_read_as_a_summary(self):
        """PROMO.REFRESH.19 — ALIGN_DRY_RUN_OK carries the summary; anything else fails."""
        summary = {
            "renumbered": 344,
            "created": 0,
            "deleted": 0,
            "values_changed": 10,
            "sequence": 367,
        }
        ok = _FakeTransport(
            {}, errors={"fn_align_fencers_to": f"ERROR:  ALIGN_DRY_RUN_OK {json.dumps(summary)}"}
        )
        assert (
            rf.TargetDb("cert", ok).align(
                {"p_pairs": [], "p_prod_roster": [], "p_deletes": [], "p_prod_sequence": 1},
                dry_run=True,
            )
            == summary
        )
        bad = _FakeTransport({}, errors={"fn_align_fencers_to": "ERROR:  ALIGN_UNPAIRED: 400"})
        with pytest.raises(rf.RefreshError, match="ALIGN_UNPAIRED: 400"):
            rf.TargetDb("cert", bad).align(
                {"p_pairs": [], "p_prod_roster": [], "p_deletes": [], "p_prod_sequence": 1},
                dry_run=True,
            )

    def test_the_drain_runs_only_against_the_target(self):
        """PROMO.REFRESH.20 — the queue drained is the target's, never PROD's."""
        rf.check_drain_target("local", "http://127.0.0.1:54321")
        rf.check_drain_target("cert", f"https://{rf.CERT_REF}.supabase.co")
        for target, url in (
            ("cert", f"https://{rf.PROD_REF}.supabase.co"),
            ("local", f"https://{rf.CERT_REF}.supabase.co"),
            ("cert", ""),
        ):
            with pytest.raises(rf.RefreshError):
                rf.check_drain_target(target, url)


def _world(target_rows, prod_rows, *, refs=None, after=None):
    prod = _FakeTransport(
        {
            "FROM tbl_fencer f": prod_rows,
            "tbl_fencer_id_fencer_seq": 367,
            "FROM tbl_registration": [
                {
                    "txt_surname": "CHUDY",
                    "txt_first_name": "Tomasz",
                    "enum_gender": "M",
                    "int_birth_year": 1977,
                    "arr_weapons": ["EPEE"],
                    "txt_ftl_name": None,
                    "txt_club": None,
                    "id_fencer": 38,
                }
            ],
        },
        read_only=True,
    )
    rosters = [target_rows, after if after is not None else prod_rows]

    class _Target(_FakeTransport):
        def fetch_json(self, sql: str) -> Any:
            if "FROM tbl_fencer f" in sql:
                self.sql.append(sql)
                return rosters.pop(0)
            return super().fetch_json(sql)

    target = _Target(
        {
            "pg_constraint": [{"tbl": "tbl_result", "col": "id_fencer"}],
            "AS n FROM": refs or {},
            "fn_replace_event_registrations": {"deleted": 8, "inserted": 1},
            "fn_align_fencers_to(": {
                "renumbered": 1,
                "created": 0,
                "deleted": 0,
                "values_changed": 1,
                "sequence": 367,
            },
        },
        errors={"p_dry_run => true": 'ERROR:  ALIGN_DRY_RUN_OK {"renumbered": 1}'},
    )
    return rf.ProdReader(prod), rf.TargetDb("local", target), target


class TestRun:
    def test_an_unpaired_fencer_stops_before_any_write(self):
        """PROMO.REFRESH.13"""
        prod, target, t = _world([_f(400, "TESTOWY", "Test", 1970)], [], refs={"400": 2})
        out = rf.run_refresh(prod, target, mode="apply", event_code="PPW1-2026-2027")
        assert out.status == "stopped_unpaired"
        assert not any("fn_align_fencers_to" in s or "fn_replace_event" in s for s in t.sql)

    def test_plan_mode_only_reads(self):
        """PROMO.REFRESH.14 — the report for a sign-off, before the function exists."""
        prod, target, t = _world(
            [_f(37, "CHUDY", "Tomasz", 1980)], [_f(38, "CHUDY", "Tomasz", 1977)]
        )
        out = rf.run_refresh(prod, target, mode="plan")
        assert out.status == "planned"
        assert out.report.counts["renumbered"] == 1
        assert not any("fn_" in s for s in t.sql)

    def test_dry_run_mode_runs_the_database_dry_run_only(self):
        """PROMO.REFRESH.15"""
        prod, target, t = _world(
            [_f(37, "CHUDY", "Tomasz", 1980)], [_f(38, "CHUDY", "Tomasz", 1977)]
        )
        out = rf.run_refresh(prod, target, mode="dry-run")
        assert out.status == "dry_run"
        assert out.align_summary == {"renumbered": 1}
        assert [s for s in t.sql if "fn_" in s and "p_dry_run => false" in s] == []
        assert not any("fn_replace_event_registrations" in s for s in t.sql)

    def test_apply_aligns_copies_registrations_drains_and_verifies(self):
        """PROMO.REFRESH.16 — and a roster that still differs afterwards fails loudly."""
        drained: list[int] = []

        def drain():
            drained.append(1)
            return [12] if len(drained) == 1 else []

        prod, target, t = _world(
            [_f(37, "CHUDY", "Tomasz", 1980)], [_f(38, "CHUDY", "Tomasz", 1977)]
        )
        out = rf.run_refresh(prod, target, mode="apply", event_code="PPW1-2026-2027", drain=drain)
        assert out.status == "applied"
        calls = [s for s in t.sql if "fn_" in s]
        assert "p_dry_run => true" in calls[0] and "p_dry_run => false" in calls[1]
        assert "fn_replace_event_registrations('PPW1-2026-2027'" in calls[2]
        assert len(drained) == 2
        assert out.registrations == {"deleted": 8, "inserted": 1}

        prod, target, _ = _world(
            [_f(37, "CHUDY", "Tomasz", 1980)],
            [_f(38, "CHUDY", "Tomasz", 1977)],
            after=[_f(38, "CHUDY", "Tomasz", 1980)],
        )
        with pytest.raises(rf.RefreshError, match="int_birth_year"):
            rf.run_refresh(prod, target, mode="apply", drain=lambda: [])


class TestRestore:
    def test_apply_saves_the_restore_point_before_it_writes(self):
        """PROMO.REFRESH.21 — the target's roster and the pairing, before the real call."""
        saved: list[dict[str, Any]] = []
        prod, target, t = _world(
            [_f(37, "CHUDY", "Tomasz", 1980), _f(400, "TESTOWY", "Test", 1970)],
            [_f(38, "CHUDY", "Tomasz", 1977), _f(368, "NOWA", "Ewa", 1990, gender="F")],
        )

        def snapshot(point: dict[str, Any]) -> None:
            assert not any("p_dry_run => false" in s for s in t.sql), "saved after the write"
            saved.append(point)

        rf.run_refresh(prod, target, mode="apply", drain=lambda: [], snapshot=snapshot)
        point = saved[0]
        assert [r["id_fencer"] for r in point["target_roster"]] == [37, 400]
        assert point["pairs"] == [{"cert_id": 37, "prod_id": 38}]
        assert point["created"] == [368]
        assert point["target"] == "local"

    def test_restore_sends_the_inverse_pairing_and_the_saved_roster(self):
        """PROMO.REFRESH.22 — the alignment undone by the same function.

        The created fencers are deleted (they must still be unreferenced) and the
        deleted ones come back from the saved roster; then the roster must equal
        the saved one.
        """
        point = {
            "target": "cert",
            "target_roster": [_f(37, "CHUDY", "Tomasz", 1980), _f(400, "TESTOWY", "Test", 1970)],
            "pairs": [{"cert_id": 37, "prod_id": 38}],
            "created": [368],
        }
        target_t = _FakeTransport(
            {
                "FROM tbl_fencer f": point["target_roster"],
                "fn_align_fencers_to(": {"renumbered": 1},
            },
            errors={"p_dry_run => true": 'ERROR:  ALIGN_DRY_RUN_OK {"renumbered": 1}'},
        )
        out = rf.run_restore(rf.TargetDb("cert", target_t), point)
        assert out == {"renumbered": 1}
        real = next(s for s in target_t.sql if "p_dry_run => false" in s)
        assert '"cert_id": 38, "prod_id": 37' in real
        assert "[368]" in real
        with pytest.raises(rf.RefreshError, match="restore point was taken on cert"):
            rf.run_restore(rf.TargetDb("local", target_t), point)

    def test_apply_and_restore_need_a_restore_point_path(self, monkeypatch: pytest.MonkeyPatch):
        """PROMO.REFRESH.23 — refused before anything is read or written."""
        monkeypatch.setenv("SUPABASE_ACCESS_TOKEN", "not-a-real-token")
        assert rf.main(["--target", "cert", "--mode", "apply"]) == 1
        assert rf.main(["--target", "cert", "--mode", "restore"]) == 1
