"""
Override YAML parser — Phase 3 (ADR-050).

Loads per-event override files at `doc/overrides/<event_code>.yaml` into the
typed Overrides dataclass (python/pipeline/types.py). Unknown top-level
keys log a warning; unknown fields within a known section raise
OverrideValidationError. Identity entries with neither id_fencer nor
create_fencer (or with both) raise.

Schema lock 2026-05-02 — five surfaces:
  identity        — list of {scraped_name, id_fencer | create_fencer{...}}
  splitter        — {birth_year_overrides{name: int}, vcat_overrides{name: V0..V4}}
  url             — {validation_url, override_reason}
  match_method    — list of {scraped_name, force_method (enum), note}
  joint_pool      — {force_flag: list of {tournament_code, siblings, note}}

EVF V0 ack is deliberately omitted — V0 + EVF/FIE = data corruption per
R005b; pipeline halts and operator fixes upstream, no override.

Tests: python/tests/test_overrides.py (15 assertions P3.OV1-P3.OV15).
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

import yaml

from python.pipeline.types import (
    IdentityOverride,
    JointPoolOverride,
    MatchMethodOverride,
    Overrides,
    SplitterOverrides,
    UrlOverride,
)

log = logging.getLogger(__name__)


VALID_FORCE_METHODS = {"PENDING", "AUTO_MATCHED", "AUTO_CREATED", "EXCLUDED"}
KNOWN_SECTIONS = {"identity", "splitter", "url", "match_method", "joint_pool"}


class OverrideValidationError(ValueError):
    """Raised when override YAML fails schema validation. Message includes file path."""


def _project_root() -> Path:
    """Locate the project root (where pyproject.toml lives)."""
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "pyproject.toml").exists():
            return parent
    return here.parent.parent.parent


def load_for_event(event_code: str, overrides_dir: Path | None = None) -> Overrides:
    """Load overrides for a given event_code.

    Args:
      event_code: e.g., "PEW3-2025-2026"
      overrides_dir: directory containing <event_code>.yaml files.
                     Defaults to <project_root>/doc/overrides/.

    Returns:
      Overrides dataclass. Empty (no entries in any section) if file missing
      or empty. Raises OverrideValidationError on schema violations.
    """
    if overrides_dir is None:
        overrides_dir = _project_root() / "doc" / "overrides"

    path = Path(overrides_dir) / f"{event_code}.yaml"
    if not path.exists():
        return Overrides()

    try:
        raw = yaml.safe_load(path.read_text())
    except yaml.YAMLError as e:
        raise OverrideValidationError(
            f"Malformed YAML in override file {path.name}: {e}"
        ) from e

    if raw is None or raw == {}:
        return Overrides()
    if not isinstance(raw, dict):
        raise OverrideValidationError(
            f"Override file {path.name}: top-level must be a mapping, got {type(raw).__name__}"
        )

    # Warn on unknown top-level keys (don't error — forward-compat).
    unknown = set(raw.keys()) - KNOWN_SECTIONS
    for key in unknown:
        log.warning("Override file %s: unknown top-level key %r — ignored", path.name, key)

    return Overrides(
        identity=_parse_identity(raw.get("identity"), path),
        splitter=_parse_splitter(raw.get("splitter"), path),
        url=_parse_url(raw.get("url"), path),
        match_method=_parse_match_method(raw.get("match_method"), path),
        joint_pool=_parse_joint_pool(raw.get("joint_pool"), path),
    )


# ---------------------------------------------------------------------------
# Section parsers
# ---------------------------------------------------------------------------

def _parse_identity(section: Any, path: Path) -> list[IdentityOverride]:
    if section is None:
        return []
    if not isinstance(section, list):
        raise OverrideValidationError(
            f"{path.name}: 'identity' must be a list, got {type(section).__name__}"
        )

    result: list[IdentityOverride] = []
    for i, entry in enumerate(section):
        if not isinstance(entry, dict):
            raise OverrideValidationError(
                f"{path.name}: identity[{i}] must be a mapping"
            )
        scraped_name = entry.get("scraped_name")
        if not scraped_name:
            raise OverrideValidationError(
                f"{path.name}: identity[{i}] missing required field 'scraped_name'"
            )
        id_fencer = entry.get("id_fencer")
        create_fencer = entry.get("create_fencer")
        if id_fencer is None and create_fencer is None:
            raise OverrideValidationError(
                f"{path.name}: identity[{i}] ({scraped_name!r}) must specify "
                f"either 'id_fencer' (link) or 'create_fencer' (auto-create)"
            )
        if id_fencer is not None and create_fencer is not None:
            raise OverrideValidationError(
                f"{path.name}: identity[{i}] ({scraped_name!r}) has both 'id_fencer' "
                f"and 'create_fencer' — these are mutually exclusive (conflict)"
            )
        if create_fencer is not None:
            _validate_create_fencer(create_fencer, scraped_name, i, path)

        result.append(IdentityOverride(
            scraped_name=str(scraped_name),
            id_fencer=int(id_fencer) if id_fencer is not None else None,
            create_fencer=create_fencer,
        ))
    return result


def _validate_create_fencer(cf: Any, scraped_name: str, idx: int, path: Path) -> None:
    if not isinstance(cf, dict):
        raise OverrideValidationError(
            f"{path.name}: identity[{idx}] ({scraped_name!r}) create_fencer must be a mapping"
        )
    required = {"surname", "first_name", "birth_year"}
    missing = required - set(cf.keys())
    if missing:
        raise OverrideValidationError(
            f"{path.name}: identity[{idx}] ({scraped_name!r}) create_fencer missing "
            f"required field(s): {sorted(missing)}"
        )


def _parse_splitter(section: Any, path: Path) -> SplitterOverrides:
    if section is None:
        return SplitterOverrides()
    if not isinstance(section, dict):
        raise OverrideValidationError(
            f"{path.name}: 'splitter' must be a mapping, got {type(section).__name__}"
        )

    by_overrides = section.get("birth_year_overrides", {}) or {}
    vcat_overrides = section.get("vcat_overrides", {}) or {}

    if not isinstance(by_overrides, dict):
        raise OverrideValidationError(
            f"{path.name}: splitter.birth_year_overrides must be a mapping"
        )
    if not isinstance(vcat_overrides, dict):
        raise OverrideValidationError(
            f"{path.name}: splitter.vcat_overrides must be a mapping"
        )

    # Coerce values: birth_year → int, vcat → str
    return SplitterOverrides(
        birth_year_overrides={str(k): int(v) for k, v in by_overrides.items()},
        vcat_overrides={str(k): str(v) for k, v in vcat_overrides.items()},
    )


def _parse_url(section: Any, path: Path) -> UrlOverride | None:
    if section is None:
        return None
    if not isinstance(section, dict):
        raise OverrideValidationError(
            f"{path.name}: 'url' must be a mapping, got {type(section).__name__}"
        )
    validation_url = section.get("validation_url")
    if not validation_url:
        raise OverrideValidationError(
            f"{path.name}: url section missing required field 'validation_url'"
        )
    return UrlOverride(
        validation_url=str(validation_url),
        override_reason=str(section.get("override_reason", "")),
    )


def _parse_match_method(section: Any, path: Path) -> list[MatchMethodOverride]:
    if section is None:
        return []
    if not isinstance(section, list):
        raise OverrideValidationError(
            f"{path.name}: 'match_method' must be a list, got {type(section).__name__}"
        )

    result: list[MatchMethodOverride] = []
    for i, entry in enumerate(section):
        if not isinstance(entry, dict):
            raise OverrideValidationError(
                f"{path.name}: match_method[{i}] must be a mapping"
            )
        scraped_name = entry.get("scraped_name")
        force_method = entry.get("force_method")
        if not scraped_name:
            raise OverrideValidationError(
                f"{path.name}: match_method[{i}] missing 'scraped_name'"
            )
        if force_method not in VALID_FORCE_METHODS:
            raise OverrideValidationError(
                f"{path.name}: match_method[{i}] ({scraped_name!r}) has invalid "
                f"force_method={force_method!r}; expected one of {sorted(VALID_FORCE_METHODS)}"
            )
        result.append(MatchMethodOverride(
            scraped_name=str(scraped_name),
            force_method=str(force_method),
            note=str(entry.get("note", "")),
        ))
    return result


def _parse_joint_pool(section: Any, path: Path) -> list[JointPoolOverride]:
    if section is None:
        return []
    if not isinstance(section, dict):
        raise OverrideValidationError(
            f"{path.name}: 'joint_pool' must be a mapping, got {type(section).__name__}"
        )

    force_flag = section.get("force_flag", []) or []
    if not isinstance(force_flag, list):
        raise OverrideValidationError(
            f"{path.name}: joint_pool.force_flag must be a list"
        )

    result: list[JointPoolOverride] = []
    for i, entry in enumerate(force_flag):
        if not isinstance(entry, dict):
            raise OverrideValidationError(
                f"{path.name}: joint_pool.force_flag[{i}] must be a mapping"
            )
        tournament_code = entry.get("tournament_code")
        if not tournament_code:
            raise OverrideValidationError(
                f"{path.name}: joint_pool.force_flag[{i}] missing 'tournament_code'"
            )
        siblings = entry.get("siblings", []) or []
        if not isinstance(siblings, list):
            raise OverrideValidationError(
                f"{path.name}: joint_pool.force_flag[{i}] 'siblings' must be a list"
            )
        result.append(JointPoolOverride(
            tournament_code=str(tournament_code),
            siblings=[str(s) for s in siblings],
            note=str(entry.get("note", "")),
        ))
    return result
