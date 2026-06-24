"""
Structural pool-only skip — SPWS ELIMINACJE qualifier rounds.

Background
----------
SPWS events often have a combined-V-cat ELIMINACJE qualifier round in
addition to the per-V-cat DE brackets. The qualifier file has `<Poule>`
elements but **no `<Tableau>`** (or equivalently, no `<SuiteDeTableaux>`
inside `<Phases>`). Pool-only files must NEVER be ingested as if they
were ranking-relevant tournaments — only DE brackets contribute to the
ranklist.

The earlier `Sexe="X"` skip rule is the wrong signal: it catches
ELIMINACJE files by coincidence but also wrongly skips per-V-cat
brackets that happen to have `Sexe="X"` (e.g. PPW5 'Floret kobiet
kat. 3-4', RESULTS_XF_2026-20.xml).

The correct rule (user instruction 2026-05-27): structural detection,
not name-based. **A file with no `<Tableau>` elements anywhere in the
tree is a pool-only qualifier and must be skipped, regardless of
`Sexe`, `AltName`, or filename.**

This applies to both the new `ingest_xml_unified` path and the
deprecated `process_xml_file` (so anyone hitting either path doesn't
reproduce the bug).
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock

import pytest

FIXTURES = Path(__file__).parent / "fixtures" / "fencingtime_xml"
LIVE_XML = Path("/Users/aleks/coding/SPWSranklist/doc/external_files/Sezon_2025-2026")


# Build small in-line XML fixtures so we don't depend on the live files
# (those move around; we want hermetic tests).

POOL_ONLY_XML = b"""<?xml version="1.0" encoding="utf-8"?>
<CompetitionIndividuelle Arme="E" Sexe="X" AltName="SZPADA ELIMINACJE"
    Annee="2025/2026" Date="11.04.2026" TitreLong="Pool only" Federation="POL">
  <Tireurs>
    <Tireur ID="P1" Nom="KOWALSKI" Prenom="Jan" Classement="1" Nation="POL"/>
    <Tireur ID="P2" Nom="NOWAK"    Prenom="Ada" Classement="2" Nation="POL"/>
  </Tireurs>
  <Phases>
    <TourDePoules>
      <Poule ID="1">
        <Match/>
      </Poule>
    </TourDePoules>
  </Phases>
</CompetitionIndividuelle>
"""

DE_BRACKET_XML = b"""<?xml version="1.0" encoding="utf-8"?>
<CompetitionIndividuelle Arme="E" Sexe="M" AltName="Szpada mezczyzn kat. 1"
    Annee="2025/2026" Date="11.04.2026" TitreLong="V1 DE" Federation="POL">
  <Tireurs>
    <Tireur ID="D1" Nom="KOWALSKI" Prenom="Jan"  Classement="1" Nation="POL"/>
    <Tireur ID="D2" Nom="WISNIEWSKI" Prenom="An" Classement="2" Nation="POL"/>
  </Tireurs>
  <Phases>
    <PhaseDeTableaux>
      <SuiteDeTableaux>
        <Tableau/>
      </SuiteDeTableaux>
    </PhaseDeTableaux>
  </Phases>
</CompetitionIndividuelle>
"""

# Same shape as the real PPW5 'Floret kobiet kat. 3-4': Sexe="X" but is a
# valid per-V-cat DE bracket. The old Sexe="X" rule would have wrongly
# dropped it; the new structural rule keeps it because <Tableau> is present.
DE_BRACKET_SEXE_X_XML = b"""<?xml version="1.0" encoding="utf-8"?>
<CompetitionIndividuelle Arme="F" Sexe="X" AltName="Floret kobiet kat. 3-4"
    Annee="2025/2026" Date="11.04.2026" TitreLong="V3-V4 F-Foil" Federation="POL">
  <Tireurs>
    <Tireur ID="D1" Nom="KOWALSKA" Prenom="Anna" Classement="1" Nation="POL"/>
  </Tireurs>
  <Phases>
    <PhaseDeTableaux>
      <SuiteDeTableaux>
        <Tableau/>
      </SuiteDeTableaux>
    </PhaseDeTableaux>
  </Phases>
</CompetitionIndividuelle>
"""


# =============================================================================
# Parser-level structural detection
# =============================================================================


class TestParsedTournamentPoolOnlyFlag:
    """The IR ParsedTournament must expose an is_pool_only_qualifier flag
    that the parser sets based on structure, not name."""

    def test_pool_only_file_flagged_true(self):
        """ELIMINACJE-shape file: <Poule> present, no <Tableau> → flag True."""
        from python.scrapers.fencingtime_xml import parse

        parsed = parse(POOL_ONLY_XML, source_url="https://example.test/pool")
        assert parsed.is_pool_only_qualifier is True

    def test_de_bracket_file_flagged_false(self):
        """Normal DE bracket: <Tableau> present → flag False (ingest)."""
        from python.scrapers.fencingtime_xml import parse

        parsed = parse(DE_BRACKET_XML, source_url="https://example.test/de")
        assert parsed.is_pool_only_qualifier is False

    def test_sexe_x_is_NOT_what_we_skip_on(self):
        """A bracket with Sexe='X' but <Tableau> present is a real DE
        bracket and must NOT be flagged for skip. Regression test for the
        old name-based skip rule that wrongly dropped these."""
        from python.scrapers.fencingtime_xml import parse

        parsed = parse(DE_BRACKET_SEXE_X_XML, source_url="https://example.test/x")
        assert parsed.is_pool_only_qualifier is False


# =============================================================================
# Pipeline-level halt
# =============================================================================


class TestPipelineHaltsOnPoolOnly:
    """The S1 (or new) stage must halt the pipeline when the parsed IR
    is flagged is_pool_only_qualifier=True. Other stages do not run."""

    def test_run_pipeline_halts_on_pool_only(self):
        """A pool-only IR halts at the validation stage with
        HaltReason.POOL_ROUND_DETECTED."""
        from python.pipeline.orchestrator import run_pipeline
        from python.pipeline.types import HaltReason, Overrides
        from python.scrapers.fencingtime_xml import parse

        parsed = parse(POOL_ONLY_XML, source_url="https://example.test/pool")
        # No real DB needed because we expect to halt before S2.
        ctx = run_pipeline(
            parsed=parsed,
            overrides=Overrides(),
            db=MagicMock(),
            season_end_year=2026,
        )
        assert ctx.halted, "pool-only IR must halt the pipeline"
        assert ctx.halt_reason == HaltReason.POOL_ROUND_DETECTED, (
            f"expected POOL_ROUND_DETECTED, got {ctx.halt_reason!r}"
        )


# =============================================================================
# Legacy process_xml_file path — same rule must apply
# =============================================================================


class TestLegacyProcessXmlPoolOnlySkip:
    """The deprecated `orchestrator.process_xml_file` path must also
    apply the structural skip — otherwise any remaining caller keeps
    reproducing the bug for the time the function lingers."""

    def test_legacy_skips_pool_only_via_structural_check(self):
        """Pool-only XML: process_xml_file appends to result.skipped_files
        and never calls db.ingest_results."""
        import warnings

        from python.pipeline.notifications import TelegramNotifier
        from python.pipeline.orchestrator import process_xml_file

        db = MagicMock()
        db.find_event_by_date.return_value = None
        db.find_tournament.return_value = None
        notifier = TelegramNotifier(None, None)

        with warnings.catch_warnings():
            warnings.simplefilter("ignore", DeprecationWarning)
            result = process_xml_file(
                file_bytes=POOL_ONLY_XML,
                filename="RESULTS_GRVETXE_2026-1.xml",
                db=db,
                notifier=notifier,
                season_end_year=2026,
            )
        assert "RESULTS_GRVETXE_2026-1.xml" in result.skipped_files, (
            "legacy path must structurally skip pool-only files"
        )
        db.ingest_results.assert_not_called()

    def test_legacy_INGESTS_sexe_x_de_bracket(self):
        """Conversely: Sexe='X' alone is not a skip signal. A bracket
        with <Tableau> present but Sexe='X' must reach the ingest call."""
        import warnings

        from python.pipeline.notifications import TelegramNotifier
        from python.pipeline.orchestrator import process_xml_file

        db = MagicMock()
        # Mock a found event + tournament so the call chain reaches ingest.
        db.find_event_by_date.return_value = {"id_event": 1, "txt_code": "TEST"}
        db.find_or_create_tournament.return_value = 1
        db.has_existing_results.return_value = False
        db.fetch_fencer_db.return_value = []
        notifier = TelegramNotifier(None, None)

        with warnings.catch_warnings():
            warnings.simplefilter("ignore", DeprecationWarning)
            result = process_xml_file(
                file_bytes=DE_BRACKET_SEXE_X_XML,
                filename="RESULTS_XF_2026-20.xml",
                db=db,
                notifier=notifier,
                season_end_year=2026,
                tournament_type="PPW",
            )
        assert "RESULTS_XF_2026-20.xml" not in result.skipped_files, (
            "Sexe='X' with <Tableau> present is a valid DE bracket — must NOT skip"
        )


# =============================================================================
# Live-file sanity checks (skipped if files moved)
# =============================================================================


@pytest.mark.skipif(
    not (LIVE_XML / "PPW5-GDANSK" / "RESULTS_GRVETXE_2026-0.xml").exists(),
    reason="live fixture files not present",
)
class TestLiveFiles:
    """Spot-check the live PPW4/PPW5 files match the rule we just enforced."""

    def test_ppw5_eliminacje_flagged_pool_only(self):
        from python.scrapers.fencingtime_xml import parse

        f = LIVE_XML / "PPW5-GDANSK" / "RESULTS_GRVETXE_2026-0.xml"
        parsed = parse(f.read_bytes(), source_url=f"file://{f}")
        assert parsed.is_pool_only_qualifier is True

    def test_ppw5_v1_de_not_flagged(self):
        from python.scrapers.fencingtime_xml import parse

        f = LIVE_XML / "PPW5-GDANSK" / "RESULTS_ME_2026-8.xml"
        parsed = parse(f.read_bytes(), source_url=f"file://{f}")
        assert parsed.is_pool_only_qualifier is False
