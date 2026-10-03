"""PROMO.GATE.01–22 — the CERT gate (ADR-108 §5, build step 7).

After a CERT run, the gate decides whether promote may replay it on PROD. Three
kinds of issue block, each fixed at its source, then CERT is re-ingested:

  identity        a listing refused for namesakes or a two-category gap; a
                  PENDING row; a participant whose birth year is an estimate; a
                  declaration that contradicts the bracket; a confirmed year
                  moved by the bracket alone; a confirmed year overwritten by a
                  declaration the results do not force (G2 A);
                  a new fencer the alias checker's typo rule calls an existing one
  scoring         a result without a score or components; not exactly one
                  active revision, or a result not stamped with it; a stored
                  score the preview does not reproduce; a type against its code
  joined bracket  a listing refused for a bracket reason; N or a place
                  different from the source; stored order problems

Preconditions are always required: the run finished with every kept listing
committed, the queue drained, PROD's inputs unchanged (the lock refuses only
when PROD is locked and CERT was not, G1 A), the commit on main is the run's,
and every fencer the run created has an id still free on PROD.

Information never blocks: a loose name similarity, a one-category move that
follows a declaration, the ADR-104 §7 joining check.
"""

from __future__ import annotations

import copy
from typing import Any

import pytest

from python.pipeline.promotion import gate as g

COMMIT = "a" * 40
PARTS = {
    "schema": "s1",
    "roster": "r1",
    "registrations": "g1",
    "season": "z1",
    "lock": "unlocked",
    "event": "e1",
}
URL = "https://www.fencingtimelive.com/events/results/U1"


def _run(**over: Any) -> dict:
    run = {
        "id_ingest_run": 41,
        "txt_event_code": "PPW1-2026-2027",
        "txt_status": "FINISHED",
        "txt_git_commit": COMMIT,
        "txt_error": None,
        "jsonb_input_parts": dict(PARTS),
        "jsonb_master_data": {
            "created": [],
            "deleted": [],
            "birth_year_moved": [],
            "aliases_added": [],
            "other": [],
        },
        "jsonb_listings": {
            "schedule": {"sha256": "x", "kept": 1, "skipped": []},
            "rounds": [
                {
                    "name": "Szabla Mężczyzn V1, V0",
                    "uuid": "U1",
                    "url": URL,
                    "status": "committed",
                    "rows": [[1, "GATEA Adam"], [2, "GATEC Cezary"]],
                    "outcome": {
                        "skipped": False,
                        "tournaments": [{"category": "V1", "n": 2}, {"category": "V0", "n": 2}],
                        "faults": [],
                    },
                    "identity": {"created": [], "reconciled": [], "conflicts": [], "pending": []},
                }
            ],
        },
    }
    run.update(over)
    return run


def _checks(**over: Any) -> dict:
    checks = {
        "event": "PPW1-2026-2027",
        "estimated_years": [],
        "pending_candidates": [],
        "unscored": [],
        "active_revisions": 1,
        "unstamped": [],
        "parity": [],
        "type_code": [],
        "joined": [],
        "queue": [],
        "fitting_years": {},
        "joining": [],
        "stored": [
            {
                "tournament": "PPW1-V1-M-SABRE-2026-2027",
                "url": URL,
                "category": "V1",
                "n": 2,
                "order": "10",
                "results": [{"scraped_name": "GATEA Adam", "place": 1, "id_fencer": 1}],
            },
            {
                "tournament": "PPW1-V0-M-SABRE-2026-2027",
                "url": URL,
                "category": "V0",
                "n": 2,
                "order": "10",
                "results": [{"scraped_name": "GATEC Cezary", "place": 2, "id_fencer": 3}],
            },
        ],
    }
    checks.update(over)
    return checks


ROSTER = [
    {"id_fencer": 1, "txt_surname": "GATEA", "txt_first_name": "Adam", "enum_gender": "M"},
    {"id_fencer": 3, "txt_surname": "GATEC", "txt_first_name": "Cezary", "enum_gender": "M"},
    {"id_fencer": 30, "txt_surname": "BUJKO", "txt_first_name": "Paulina", "enum_gender": "F"},
]


def _prod(**over: Any) -> g.ProdState:
    return g.ProdState(
        parts=over.get("parts", dict(PARTS)), taken_ids=frozenset(over.get("taken", ()))
    )


def _eval(run=None, checks=None, prod=None, roster=None, main=COMMIT, **kw) -> g.GateResult:
    return g.evaluate(
        _run() if run is None else run,
        _checks() if checks is None else checks,
        _prod() if prod is None else prod,
        main_commit=main,
        roster=ROSTER if roster is None else roster,
        **kw,
    )


def _kinds(result: g.GateResult) -> list[tuple[str, str]]:
    return [(f.kind, f.check) for f in result.findings]


def _with_round(**over: Any) -> dict:
    run = _run()
    run["jsonb_listings"]["rounds"][0].update(over)
    return run


def _with_identity(**over: Any) -> dict:
    run = _run()
    run["jsonb_listings"]["rounds"][0]["identity"].update(over)
    return run


class TestPreconditions:
    def test_a_clean_run_passes(self):
        """PROMO.GATE.01"""
        result = _eval()
        assert result.passed and result.findings == []

    def test_no_recorded_run_blocks(self):
        """PROMO.GATE.02"""
        result = g.evaluate(None, _checks(), _prod(), main_commit=COMMIT, roster=ROSTER)
        assert not result.passed and _kinds(result) == [("precondition", "run.missing")]

    def test_a_run_that_did_not_finish_blocks_with_its_error(self):
        """PROMO.GATE.03"""
        run = _run(txt_status="FAILED", txt_error="RuntimeError: FTL timed out")
        result = _eval(run=run)
        assert _kinds(result) == [("precondition", "run.finished")]
        assert "FTL timed out" in result.findings[0].message

    def test_an_identity_refusal_is_an_identity_issue(self):
        """PROMO.GATE.04"""
        run = _run(txt_status="FAILED", txt_error="ListingRefused: SABRE M listing not written")
        run["jsonb_listings"]["refusal"] = {
            "listing": "Szabla Mężczyzn V1, V0",
            "kind": "identity",
            "message": "SABRE M listing not written: X (place 3): namesakes",
        }
        assert _kinds(_eval(run=run)) == [("identity", "identity.listing_refused")]

    def test_a_bracket_refusal_is_a_joined_bracket_issue(self):
        """PROMO.GATE.05"""
        run = _run(txt_status="FAILED", txt_error="ListingRefused: repeats place")
        run["jsonb_listings"]["refusal"] = {
            "listing": "Floret K",
            "kind": "joined_bracket",
            "message": "A joined listing repeats place(s) [3]",
        }
        assert _kinds(_eval(run=run)) == [("joined_bracket", "joined.listing_refused")]

    def test_a_kept_listing_not_committed_blocks(self):
        """PROMO.GATE.06"""
        run = _with_round(outcome={"skipped": True, "tournaments": [], "faults": []})
        assert ("precondition", "run.listing_not_committed") in _kinds(_eval(run=run))

    def test_an_undrained_queue_blocks(self):
        """PROMO.GATE.07"""
        checks = _checks(queue=[{"event": "PPW5-2025-2026", "status": "PENDING", "n": 1}])
        result = _eval(checks=checks)
        assert _kinds(result) == [("precondition", "queue.drained")]
        assert "PPW5-2025-2026" in result.findings[0].message

    def test_a_changed_input_on_prod_blocks_and_names_the_part(self):
        """PROMO.GATE.08"""
        result = _eval(prod=_prod(parts=dict(PARTS, roster="r2", schema="s2")))
        assert _kinds(result) == [
            ("precondition", "input.schema"),
            ("precondition", "input.roster"),
        ]
        assert "refresh cert from prod" in result.findings[1].message.lower()

    def test_the_lock_refuses_only_when_prod_is_locked_and_cert_was_not(self):
        """PROMO.GATE.09 — G1 A."""
        cert_locked = _run(jsonb_input_parts=dict(PARTS, lock="locked"))
        assert _eval(run=cert_locked).passed
        result = _eval(prod=_prod(parts=dict(PARTS, lock="locked")))
        assert _kinds(result) == [("precondition", "input.lock")]

    def test_main_must_be_the_runs_commit(self):
        """PROMO.GATE.10 — both commits named in full."""
        result = _eval(main="b" * 40)
        assert _kinds(result) == [("precondition", "code.commit")]
        assert "b" * 40 in result.findings[0].message and COMMIT in result.findings[0].message

    def test_an_id_the_run_created_must_be_free_on_prod(self):
        """PROMO.GATE.11"""
        run = _run()
        run["jsonb_master_data"]["created"] = [
            {
                "id_fencer": 368,
                "surname": "ZANEUSKAYA",
                "first_name": "Hanna",
                "birth_year": 1994,
                "estimated": False,
                "gender": "F",
                "aliases": [],
            }
        ]
        result = _eval(run=run, prod=_prod(taken=[368]))
        assert _kinds(result) == [("precondition", "fencer.id_taken")]


class TestIdentity:
    def test_a_pending_row_blocks(self):
        """PROMO.GATE.12 — in a listing's identity, or as a match candidate."""
        run = _with_identity(
            pending=[{"scraped_name": "KOWAL Jan", "place": 4, "notes": "namesakes"}]
        )
        assert _kinds(_eval(run=run)) == [("identity", "identity.pending")]
        checks = _checks(
            pending_candidates=[
                {"id_result": 9, "tournament": "T", "scraped_name": "KOWAL Jan", "id_fencer": 5}
            ]
        )
        assert _kinds(_eval(checks=checks)) == [("identity", "identity.pending")]

    def test_an_estimated_birth_year_blocks(self):
        """PROMO.GATE.13"""
        checks = _checks(
            estimated_years=[
                {
                    "id_fencer": 282,
                    "surname": "STANISŁAWSKI",
                    "first_name": "Albert",
                    "birth_year": 1987,
                }
            ]
        )
        result = _eval(checks=checks)
        assert _kinds(result) == [("identity", "identity.estimated_year")]
        assert "STANISŁAWSKI Albert" in result.findings[0].message
        assert "Birth-year review" in result.findings[0].message

    def test_a_declaration_against_the_bracket_blocks(self):
        """PROMO.GATE.14"""
        run = _with_identity(
            conflicts=[
                {
                    "id_fencer": 124,
                    "scraped_name": "KIEROŃSKI Tomasz",
                    "first_vcat": "V0",
                    "second_vcat": "V1",
                    "reason": "declared_vs_bracket",
                    "declared_birth_year": 1990,
                }
            ]
        )
        assert _kinds(_eval(run=run)) == [("identity", "identity.declared_vs_bracket")]

    def test_a_confirmed_year_moved_by_the_bracket_alone_blocks(self):
        """PROMO.GATE.15"""
        run = _with_identity(
            reconciled=[
                {
                    "id_fencer": 282,
                    "scraped_name": "STANISŁAWSKI Albert",
                    "old_birth_year": 1991,
                    "new_birth_year": 1987,
                    "was_confirmed": True,
                    "anchor": "lower edge",
                }
            ]
        )
        assert _kinds(_eval(run=run)) == [("identity", "identity.confirmed_moved_by_bracket")]

    def test_a_declaration_over_a_confirmed_year_blocks_unless_the_results_force_it(self):
        """PROMO.GATE.16 — G2 A (decided 3 Oct): the only rule; no rule B to switch to."""
        moved = {
            "id_fencer": 282,
            "scraped_name": "STANISŁAWSKI Albert",
            "old_birth_year": 1991,
            "new_birth_year": 1987,
            "was_confirmed": True,
            "anchor": "declared at registration",
        }
        run = _with_identity(reconciled=[moved])
        forced = _eval(run=run, checks=_checks(fitting_years={"282": [1987]}))
        assert forced.passed
        assert _kinds(forced) == [("information", "info.declaration_forced")]
        open_ = _eval(run=run, checks=_checks(fitting_years={"282": [1985, 1986, 1987]}))
        assert _kinds(open_) == [("identity", "identity.declaration_over_confirmed")]
        assert "their results allow no other year" in forced.findings[0].message
        assert "their results allow 1985–1987" in open_.findings[0].message
        assert not hasattr(g, "DECLARATION_RULE")
        with pytest.raises(TypeError):
            _eval(run=run, declaration_rule="B")

    def test_a_new_fencer_the_typo_rule_calls_an_existing_one_blocks(self):
        """PROMO.GATE.17 — NAME.CLS, unless confirmed birth years tell them apart;
        the loose near miss stays information."""
        run = _run()
        run["jsonb_master_data"]["created"] = [
            {
                "id_fencer": 400,
                "surname": "GATEA",
                "first_name": "Adan",
                "gender": "M",
                "birth_year": 1975,
                "estimated": True,
            }
        ]
        roster = ROSTER + [
            {"id_fencer": 400, "txt_surname": "GATEA", "txt_first_name": "Adan", "enum_gender": "M"}
        ]
        assert _kinds(_eval(run=run, roster=roster)) == [
            ("identity", "identity.possible_duplicate")
        ]
        apart = copy.deepcopy(run)
        apart["jsonb_master_data"]["created"][0].update(estimated=False)
        roster_apart = [
            dict(r, int_birth_year=1981, bool_birth_year_estimated=False)
            if r["id_fencer"] == 1
            else r
            for r in roster
        ]
        told = _eval(run=apart, roster=roster_apart)
        assert told.passed
        assert _kinds(told) == [("information", "info.typo_told_apart")]
        women = copy.deepcopy(run)
        women["jsonb_master_data"]["created"][0]["gender"] = "F"
        assert _eval(run=women, roster=roster).passed
        near = _with_identity(
            created=[
                {
                    "scraped_name": "NOWAK Ewa",
                    "near_miss": {"name": "NOWAKOWSKA Ewelina", "id_fencer": 9, "confidence": 71},
                }
            ]
        )
        assert _kinds(_eval(run=near)) == [("information", "info.near_miss")]


class TestScoring:
    @pytest.mark.parametrize(
        ("over", "check"),
        [
            (
                {"unscored": [{"id_result": 1, "id_fencer": 1, "tournament": "T", "place": 1}]},
                "scoring.unscored",
            ),
            ({"active_revisions": 2}, "scoring.revisions"),
            (
                {"unstamped": [{"id_result": 1, "id_fencer": 1, "tournament": "T", "place": 1}]},
                "scoring.unstamped",
            ),
            (
                {
                    "parity": [
                        {
                            "id_result": 1,
                            "id_fencer": 1,
                            "tournament": "T",
                            "place": 1,
                            "stored": {"final": 50},
                            "preview": {"final": 49},
                        }
                    ]
                },
                "scoring.parity",
            ),
            (
                {
                    "type_code": [
                        {
                            "tournament": "PPW1-V0-M-SABRE-2026-2027",
                            "type": "MPW",
                            "expected": "PPW",
                        }
                    ]
                },
                "scoring.type_code",
            ),
        ],
    )
    def test_each_scoring_issue_blocks(self, over, check):
        """PROMO.GATE.18"""
        assert _kinds(_eval(checks=_checks(**over))) == [("scoring", check)]


class TestJoinedBracket:
    def test_n_different_from_the_source_blocks(self):
        """PROMO.GATE.19"""
        run = _with_round(rows=[[1, "GATEA Adam"], [2, "GATEC Cezary"], [3, "GATEX Xawery"]])
        assert ("joined_bracket", "joined.source_n") in _kinds(_eval(run=run))

    def test_a_place_different_from_the_source_blocks(self):
        """PROMO.GATE.20"""
        run = _with_round(rows=[[2, "GATEA Adam"], [1, "GATEC Cezary"]])
        assert _kinds(_eval(run=run)) == [
            ("joined_bracket", "joined.source_place"),
            ("joined_bracket", "joined.source_place"),
        ]

    def test_stored_order_problems_block(self):
        """PROMO.GATE.21"""
        checks = _checks(
            joined=[
                {
                    "tournament": "PPW1-V0-M-SABRE-2026-2027",
                    "listing": URL,
                    "problem": "place 2 digit 1, but the fencer is V0",
                }
            ]
        )
        assert _kinds(_eval(checks=checks)) == [("joined_bracket", "joined.order")]


class TestInformationAndRecord:
    def test_information_never_blocks(self):
        """PROMO.GATE.22 — a declaration's one-category move of an estimate, the joining check."""
        run = _with_identity(
            reconciled=[
                {
                    "id_fencer": 371,
                    "scraped_name": "TYLSKI Łukasz",
                    "old_birth_year": 1990,
                    "new_birth_year": 1982,
                    "was_confirmed": False,
                    "anchor": "declared at registration",
                }
            ]
        )
        checks = _checks(
            joining=[{"weapon": "SABRE", "gender": "M", "fenced": "V0+V1", "rule": "V0, V1"}]
        )
        result = _eval(run=run, checks=checks)
        assert result.passed
        assert _kinds(result) == [
            ("information", "info.declared_move"),
            ("information", "info.joining"),
        ]

    def test_the_outcome_is_recorded_on_the_run_row(self):
        """PROMO.GATE.22 — run_gate reads both sides and writes only the outcome, on the target."""

        class FakeTarget:
            read_only = False

            def __init__(self):
                self.sql: list[str] = []

            def fetch_json(self, sql: str) -> Any:
                self.sql.append(sql)
                if "FROM tbl_ingest_run" in sql:
                    return _run()
                if "fn_promote_gate_checks" in sql:
                    return _checks()
                if "fn_roster_snapshot" in sql:
                    return ROSTER
                if "fn_ingest_run_gate" in sql:
                    return None
                raise AssertionError(sql)

        class FakeProd:
            read_only = True

            def fetch_json(self, sql: str) -> Any:
                if "fn_event_input_fingerprint" in sql:
                    return {"fingerprint": "f", "parts": dict(PARTS)}
                if "FROM tbl_fencer" in sql:
                    return []
                raise AssertionError(sql)

        target = FakeTarget()
        result = g.run_gate(
            "PPW1-2026-2027", target, FakeProd(), main_commit=COMMIT, environment="cert"
        )
        assert result.passed
        written = [s for s in target.sql if "fn_ingest_run_gate" in s]
        assert len(written) == 1 and "41" in written[0] and '"passed": true' in written[0]

    def test_prod_is_read_through_a_read_only_transport(self):
        """PROMO.GATE.22"""

        class Writable:
            read_only = False

            def fetch_json(self, sql: str) -> Any:
                return None

        with pytest.raises(g.GateError):
            g.run_gate(
                "PPW1-2026-2027", Writable(), Writable(), main_commit=COMMIT, environment="cert"
            )
