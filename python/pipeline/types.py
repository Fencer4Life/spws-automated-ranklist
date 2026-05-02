"""
Phase 3 (ADR-050) shared dataclasses for the unified pipeline.

Single source of truth for the pipeline's data shape. Every stage in the
S1-S7 dispatcher reads/writes a PipelineContext; every override surface
is typed via Overrides; every halt is signalled via HaltError.

Architectural decisions (Phase 3 design RFC, 2026-05-02):
  - Procedural pipeline: stages are free functions that mutate ctx.
    PipelineContext is a typed @dataclass (not a class with methods).
  - Halt-by-exception: HaltError is raised by a stage; the dispatcher
    catches it, populates ctx.halted_at_stage + ctx.halt_reason, breaks
    the loop. Cleaner than every-stage `if ctx.halted: return` checks.
  - Overrides have 5 typed sections; missing sections default to empty
    so consumers can call ctx.overrides.identity safely without None checks.

Tests: python/tests/test_pipeline_stages.py exercises each stage's
read/write contract against a hand-built PipelineContext.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any


# ===========================================================================
# Halt signal
# ===========================================================================

class HaltReason(str, Enum):
    """Why a stage halted the pipeline. Reflected in ctx.halt_reason."""
    IR_INVALID = "IR_INVALID"
    EVENT_NOT_RESOLVED = "EVENT_NOT_RESOLVED"
    EVENT_AMBIGUOUS = "EVENT_AMBIGUOUS"
    SPLITTER_UNRESOLVED = "SPLITTER_UNRESOLVED"
    V0_PROHIBITED_ON_INTERNATIONAL = "V0_PROHIBITED_ON_INTERNATIONAL"
    COUNT_MISMATCH = "COUNT_MISMATCH"
    URL_DATA_MISMATCH = "URL_DATA_MISMATCH"
    OVERRIDE_INVALID = "OVERRIDE_INVALID"


class HaltError(Exception):
    """Raised by a stage to signal pipeline halt with a structured reason.

    The dispatcher catches it and writes the reason + stage name to ctx.
    Stages MUST raise this (not bare exceptions) for expected halts.
    Unexpected exceptions propagate as bugs.
    """
    def __init__(self, reason: HaltReason, detail: str) -> None:
        super().__init__(f"{reason.value}: {detail}")
        self.reason = reason
        self.detail = detail


# ===========================================================================
# Override surfaces — typed shape, see doc/overrides/<event_code>.yaml
# ===========================================================================

@dataclass(frozen=True)
class IdentityOverride:
    """Single identity override entry. Either id_fencer (link) OR create_fencer."""
    scraped_name: str
    id_fencer: int | None = None
    create_fencer: dict[str, Any] | None = None  # {surname, first_name, birth_year, nationality}


@dataclass(frozen=True)
class SplitterOverrides:
    """Per-event splitter hints for combined-pool resolution."""
    birth_year_overrides: dict[str, int] = field(default_factory=dict)  # scraped_name → birth_year
    vcat_overrides: dict[str, str] = field(default_factory=dict)        # scraped_name → V-cat


@dataclass(frozen=True)
class UrlOverride:
    """Per-event URL override for validation."""
    validation_url: str
    override_reason: str = ""


@dataclass(frozen=True)
class MatchMethodOverride:
    """Force a row's enum_match_method regardless of confidence score."""
    scraped_name: str
    force_method: str  # PENDING | AUTO_MATCHED | AUTO_CREATED | EXCLUDED
    note: str = ""


@dataclass(frozen=True)
class JointPoolOverride:
    """Force bool_joint_pool_split for a tournament + its siblings."""
    tournament_code: str
    siblings: list[str] = field(default_factory=list)
    note: str = ""


@dataclass
class Overrides:
    """Aggregate of all override surfaces for one event.

    All sections default to empty so downstream code can read them without
    None checks. Construct empty via `Overrides()` if no override file exists.
    """
    identity: list[IdentityOverride] = field(default_factory=list)
    splitter: SplitterOverrides = field(default_factory=SplitterOverrides)
    url: UrlOverride | None = None
    match_method: list[MatchMethodOverride] = field(default_factory=list)
    joint_pool: list[JointPoolOverride] = field(default_factory=list)

    def identity_for(self, scraped_name: str) -> IdentityOverride | None:
        """Find identity override for a scraped name (case-insensitive exact match)."""
        target = scraped_name.upper()
        for o in self.identity:
            if o.scraped_name.upper() == target:
                return o
        return None

    def match_method_for(self, scraped_name: str) -> MatchMethodOverride | None:
        target = scraped_name.upper()
        for o in self.match_method:
            if o.scraped_name.upper() == target:
                return o
        return None

    def joint_pool_for(self, tournament_code: str) -> JointPoolOverride | None:
        for o in self.joint_pool:
            if o.tournament_code == tournament_code:
                return o
        return None


# ===========================================================================
# PipelineContext — mutated by each stage S1-S7
# ===========================================================================

@dataclass
class StageMatchResult:
    """One identity-resolution result for a single scraped row.

    Populated by S6. The 3-way diff and commit code consume this.
    """
    scraped_name: str
    place: int
    id_fencer: int | None              # None if EXCLUDED
    confidence: float                   # 0-100
    method: str                         # AUTO_MATCHED | PENDING | AUTO_CREATED | EXCLUDED
    alternatives: list[dict] = field(default_factory=list)  # top-N candidates for ambiguous
    notes: str = ""                     # operator-facing detail (override applied, V0 halt, etc.)


@dataclass
class PipelineContext:
    """State shared across pipeline stages S1-S7.

    Each stage reads what it needs and writes what it produces. Field
    annotations document the read/write contract. Stages SHOULD NOT
    add ad-hoc attributes outside this dataclass.

    Lifecycle:
      - Constructed by run_pipeline() with parsed + overrides + db.
      - Mutated by S1 → ... → S7 in order.
      - Returned to caller; caller reads halted_at_stage + matches + splits.
    """
    # Inputs (set at construction; read by all stages)
    parsed: Any                         # ParsedTournament from python/pipeline/ir.py
    overrides: Overrides
    season_end_year: int

    # Stage outputs (written by the stage that owns them)
    event: dict | None = None           # S2 writes: {id_event, txt_code, organizer_hint, ...}
    is_combined_pool: bool = False      # S3 writes
    splits: dict[str, list] | None = None  # S4 writes: {V-cat: [ParsedResult, ...]}
    joint_pool_siblings: list[str] = field(default_factory=list)  # S5 writes (tournament_codes)
    matches: list[StageMatchResult] = field(default_factory=list)  # S6 writes
    count_validation: dict | None = None  # S7 writes: {expected, actual, ok}
    url_validation: Any = None             # S7 writes: ValidationResult (Phase 4 ADR-052)
    pew_cascade_pending: bool = False      # S7 sets True on PEW weapon-mismatch (ADR-046)

    # Halt state (set by dispatcher when HaltError caught)
    halted_at_stage: str | None = None
    halt_reason: HaltReason | None = None
    halt_detail: str = ""

    # Diagnostic accumulator (any stage may append)
    warnings: list[str] = field(default_factory=list)

    @property
    def halted(self) -> bool:
        return self.halted_at_stage is not None
