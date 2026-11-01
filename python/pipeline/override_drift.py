"""The override-drift gate (ADR-119, G43 A).

An identity entry of doc/overrides/<event>.yaml pins a fencer by surname, first
name and birth year (or by id). When the roster is corrected, the entry silently
names nobody, and the next ingest of its event stops before it reads anything:
LEAHEY John's three entries said 1976 after the roster had 1969 (G46, 1 Nov
2026). This gate checks every entry of every file against the roster the run
will meet, LOCAL in preflight and CERT in CI (read only; CERT holds PROD's
master data, refreshed before every ingest):

  a `fencer` key      names exactly one roster fencer, by the rule the ingest
                      resolves it with (overrides.roster_matches);
  an `id_fencer`      is on the roster;
  a `create_fencer`   names nobody the roster already holds: a re-ingest would
                      create a second.

A file that does not parse fails it too. A line names the file, the line and the
entry, never a fencer or a birth year: CI's log is public (D12).

Usage: python -m python.pipeline.override_drift --roster local|cert
Tests: python/tests/test_override_drift.py (OVR.DRIFT.01-06).
"""

from __future__ import annotations

import argparse
import os
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml

from python.pipeline.overrides import OverrideValidationError, load_for_event, roster_matches
from python.supabase_token import supabase_access_token

__all__ = ["Drift", "check", "main", "roster_matches", "run", "transport_for"]

OVERRIDES_DIR = Path(__file__).resolve().parents[2] / "doc" / "overrides"
ROSTER_SQL = (
    "SELECT coalesce(jsonb_agg(jsonb_build_object('id_fencer', id_fencer, "
    "'txt_surname', txt_surname, 'txt_first_name', txt_first_name, "
    "'int_birth_year', int_birth_year) ORDER BY id_fencer), '[]'::jsonb) AS j FROM tbl_fencer"
)


@dataclass(frozen=True)
class Drift:
    """One entry, or one file, that does not name the roster as it must."""

    file: str
    line: int | None
    entry: int | None
    kind: str  # fencer | id_fencer | create_fencer | file
    found: int
    error: str = ""

    def text(self) -> str:
        """The gate's line: where, and what is wrong; never who."""
        where = f"{self.file}:{self.line} identity[{self.entry}]"
        if self.kind == "fencer":
            return (
                f"{where}: its fencer key names {self.found} roster fencers; "
                "it must name exactly one"
            )
        if self.kind == "id_fencer":
            return f"{where}: its id_fencer is not on the roster"
        if self.kind == "create_fencer":
            return (
                f"{where}: create_fencer names a fencer the roster already holds; "
                "a re-ingest would create a second (link it with a fencer key)"
            )
        return f"{self.file}: not a valid override file ({self.error})"


def _entry_lines(path: Path) -> list[int]:
    """The line (1-based) each identity entry starts on."""
    root = yaml.compose(path.read_text(encoding="utf-8"))
    if isinstance(root, yaml.MappingNode):
        for key, value in root.value:
            if getattr(key, "value", None) == "identity" and isinstance(value, yaml.SequenceNode):
                return [item.start_mark.line + 1 for item in value.value]
    return []


def check(overrides_dir: Path, roster: list[dict[str, Any]]) -> tuple[int, list[Drift]]:
    """Every identity entry of every override file against the roster: the
    number of entries checked, and every drift, file by file."""
    ids = {f["id_fencer"] for f in roster}
    checked = 0
    drifts: list[Drift] = []
    for path in sorted(Path(overrides_dir).glob("*.yaml")):
        try:
            overrides = load_for_event(path.stem, path.parent)
            lines = _entry_lines(path)
        except (OverrideValidationError, yaml.YAMLError) as e:
            drifts.append(Drift(str(path), None, None, "file", 0, type(e).__name__))
            continue
        for i, entry in enumerate(overrides.identity):
            checked += 1
            line = lines[i] if i < len(lines) else None
            if entry.fencer is not None:
                found = len(roster_matches(entry.fencer, roster))
                if found != 1:
                    drifts.append(Drift(str(path), line, i, "fencer", found))
            elif entry.id_fencer is not None:
                if entry.id_fencer not in ids:
                    drifts.append(Drift(str(path), line, i, "id_fencer", 0))
            elif entry.create_fencer is not None:
                found = len(roster_matches(entry.create_fencer, roster))
                if found:
                    drifts.append(Drift(str(path), line, i, "create_fencer", found))
    return checked, drifts


def _count(n: int, one: str, many: str) -> str:
    return f"{n} {one if n == 1 else many}"


def run(overrides_dir: Path, transport: Any, label: str) -> int:
    """The gate: read the roster, check every file, print every drift and one
    summary line; 1 when anything drifted."""
    roster = transport.fetch_json(ROSTER_SQL) or []
    checked, drifts = check(overrides_dir, roster)
    for d in drifts:
        print(d.text())
    entries = _count(checked, "identity entry", "identity entries")
    if not drifts:
        files = len(list(Path(overrides_dir).glob("*.yaml")))
        print(
            f"override files: {entries} in {_count(files, 'file', 'files')} checked against "
            f"the {label} roster, none drifted"
        )
        return 0
    bad = [d for d in drifts if d.kind != "file"]
    parts = [f"{len(bad)} of {entries} drifted from the {label} roster"]
    if len(bad) < len(drifts):
        parts.append(f"{_count(len(drifts) - len(bad), 'file', 'files')} not valid")
    print("override files: " + "; ".join(parts))
    return 1


def transport_for(which: str) -> Any:
    """LOCAL (the Docker stack) or CERT (the Management API), read only."""
    from python.pipeline.promotion import refresh

    if which == "local":
        return refresh.LocalTransport(read_only=True)
    token = supabase_access_token()
    if not token:
        raise SystemExit("SUPABASE_ACCESS_TOKEN is required to read the CERT roster")
    return refresh.ManagementTransport(refresh.CERT_REF, token, read_only=True)


def main(argv: Iterable[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Every override entry names the roster (G43).")
    ap.add_argument("--roster", choices=("local", "cert"), required=True)
    ap.add_argument("--dir", type=Path, default=OVERRIDES_DIR, help="the override files")
    args = ap.parse_args(list(argv) if argv is not None else None)
    shown = Path(os.path.relpath(args.dir)) if args.dir.is_absolute() else args.dir
    return run(shown, transport_for(args.roster), args.roster.upper())


if __name__ == "__main__":
    raise SystemExit(main())
