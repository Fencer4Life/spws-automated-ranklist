"""The PZSz calendar write rules (ADR-116 §9; RTM PZSZ.WR.01-08).

Per field the run holds three things: the value now in tbl_event, the value it
last wrote (with that value's source), and each source's last report. ``decide``
turns those plus this run's candidates into one decision — a compare-and-set
change, the reports to record, any warnings, and whether the field is held for
the operator. Pure: no I/O.

Source ranks: letter > listing > home. The rules:
  1 nothing found            -> no write
  2 the field is empty       -> write the winner
  3 current != run's value   -> a hand edit, never overwritten; disagreement noted
  4 current == run's value, an equal/higher-rank source differs -> replaced
  5 a lower-rank source disagrees -> kept; reported once
  6 a lower-rank source moved against a higher-rank one -> held for the operator
  7 the event has started    -> the run never calls decide (handled upstream)
  8 link/fee                 -> written only while empty
"""

from __future__ import annotations

from python.scrapers.pzsz_write_rules import (
    Candidate,
    FieldState,
    decide,
)


def _c(source: str, value: str, evidence: str | None = None) -> Candidate:
    return Candidate(source=source, value=value, evidence=evidence)


class TestRule1NothingFound:
    def test_no_candidates_writes_nothing(self):
        d = decide("dt_end", current="2026-10-25", state=None, candidates=[], reports={})
        assert d.change is None
        assert d.reports == []
        assert d.warnings == []
        assert d.held is False


class TestRule2EmptyField:
    def test_an_empty_field_is_written_with_the_winner(self):
        d = decide(
            "txt_venue_address",
            current=None,
            state=None,
            candidates=[_c("letter", "Hala AZS, ul. Testowa 1", "ul. Testowa 1")],
            reports={},
        )
        assert d.change is not None
        assert d.change.value == "Hala AZS, ul. Testowa 1"
        assert d.change.expected is None  # compare-and-set against the empty field
        assert d.change.source == "letter"

    def test_the_winner_is_the_highest_rank_source(self):
        d = decide(
            "dt_start",
            current="",
            state=None,
            candidates=[
                _c("home", "2026-10-20"),
                _c("letter", "2026-10-24"),
                _c("listing", "2026-10-25"),
            ],
            reports={},
        )
        assert d.change is not None and d.change.value == "2026-10-24"  # the letter wins


class TestRule8Removed:
    """ADR-118 removed rule 8: the link and fee follow rules 2-6 like every field."""

    def test_a_link_the_run_wrote_follows_the_listing(self):
        held = "https://pzszerm.pl/test/fileDownload.php?fileId=held"
        d = decide(
            "url_invitation",
            current=held,
            state=FieldState(value=held, source="listing"),
            candidates=[_c("listing", "https://pzszerm.pl/test/fileDownload.php?fileId=new")],
            reports={},
        )
        assert d.change is not None
        assert d.change.value.endswith("fileId=new")  # rule 4

    def test_an_event_page_in_the_letter_counts_as_empty(self):
        d = decide(
            "url_invitation",
            current="https://pzszerm.pl/zawody/kalendarium-zawodow/zawody/?id=4581",
            state=None,
            candidates=[_c("listing", "https://pzszerm.pl/test/fileDownload.php?fileId=new")],
            reports={},
        )
        assert d.change is not None  # C1, ADR-117 D7 A: rule 2


class TestRule3HandEdit:
    def test_a_value_the_run_did_not_write_is_never_overwritten(self):
        d = decide(
            "txt_venue_address",
            current="Changed by hand",
            state=FieldState(value="Hala AZS, ul. Testowa 1", source="letter"),
            candidates=[_c("letter", "Hala AZS, ul. Nowa 9")],
            reports={},
        )
        assert d.change is None
        assert d.held is False
        assert any("hand" in w.lower() for w in d.warnings)

    def test_a_value_with_no_provenance_is_treated_as_a_hand_value(self):
        d = decide(
            "txt_venue_address",
            current="Admin hall",
            state=None,  # never written by the run
            candidates=[_c("letter", "Letter hall")],
            reports={},
        )
        assert d.change is None


class TestRule4EqualOrHigherRankReplaces:
    def test_the_letter_replaces_the_runs_own_value(self):
        d = decide(
            "dt_end",
            current="2026-10-25",
            state=FieldState(value="2026-10-25", source="listing"),
            candidates=[_c("letter", "2026-10-24", "Data: 24.10.2026 r.")],
            reports={"listing": "2026-10-25"},
        )
        assert d.change is not None
        assert d.change.value == "2026-10-24"
        assert d.change.expected == "2026-10-25"  # compare-and-set against the run's value
        assert d.change.source == "letter"

    def test_an_equal_rank_source_also_replaces(self):
        d = decide(
            "dt_start",
            current="2026-10-24",
            state=FieldState(value="2026-10-24", source="listing"),
            candidates=[_c("listing", "2026-10-25")],
            reports={"listing": "2026-10-24"},
        )
        assert d.change is not None and d.change.value == "2026-10-25"


class TestRule5LowerRankDisagrees:
    def test_a_lower_rank_disagreement_is_kept_and_reported_once(self):
        """Gdańsk 24 (letter) vs 25 (listing): keep 24, tell the operator — but
        only when the listing's report is new."""
        first = decide(
            "dt_end",
            current="2026-10-24",
            state=FieldState(value="2026-10-24", source="letter"),
            candidates=[_c("listing", "2026-10-25")],
            reports={},  # the listing has not been recorded disagreeing yet
        )
        assert first.change is None
        assert first.held is False
        assert first.warnings  # reported this once
        assert ("listing", "2026-10-25") in first.reports

        again = decide(
            "dt_end",
            current="2026-10-24",
            state=FieldState(value="2026-10-24", source="letter"),
            candidates=[_c("listing", "2026-10-25")],
            reports={"listing": "2026-10-25"},  # already recorded
        )
        assert again.change is None
        assert again.warnings == []  # not reported again


class TestRule6LowerRankMoved:
    def test_a_moved_lower_rank_source_is_held_for_the_operator(self):
        """The listing agreed (24) then moved to 26 after the letter was
        applied: a possible event move the operator decides."""
        d = decide(
            "dt_start",
            current="2026-10-24",
            state=FieldState(value="2026-10-24", source="letter"),
            candidates=[_c("listing", "2026-10-26")],
            reports={"listing": "2026-10-24"},  # it used to agree, now it moved
        )
        assert d.change is None
        assert d.held is True
        assert any("2026-10-26" in w and "2026-10-24" in w for w in d.warnings)
