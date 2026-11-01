"""OVR.DRIFT — every override entry names the roster it will meet (ADR-119, G43 A).

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, G43 and G46.

An identity entry pins a fencer by surname, first name and birth year. When the
roster is corrected (LEAHEY John, 1976 → 1969), the entry silently names nobody
until the next ingest of its event stops before it reads anything. This gate,
in preflight (LOCAL) and CI (CERT, read only), checks every entry of every
doc/overrides/*.yaml against the roster:

  OVR.DRIFT.01  a `fencer` entry names exactly one roster fencer, by the rule
                the ingest resolves it with (resolve_fencer_keys);
  OVR.DRIFT.02  an `id_fencer` entry is on the roster;
  OVR.DRIFT.03  a `create_fencer` entry names nobody the roster holds: a
                re-ingest would create a second;
  OVR.DRIFT.04  every file and entry is checked, every failure listed, and a
                file that does not parse is one;
  OVR.DRIFT.05  a line names the file, the line and the entry, never a fencer
                or a birth year (D12: CI's log is public);
  OVR.DRIFT.06  the command line reads LOCAL or CERT, read only, and exits 1 on
                any drift.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from python.pipeline import override_drift as od
from python.pipeline.overrides import Overrides, resolve_fencer_keys
from python.pipeline.types import IdentityOverride

ROSTER = [
    {"id_fencer": 167, "txt_surname": "LEAHEY", "txt_first_name": "John", "int_birth_year": 1969},
    {"id_fencer": 72, "txt_surname": "NOWAK", "txt_first_name": "Anna", "int_birth_year": 1972},
    {"id_fencer": 73, "txt_surname": "NOWAK", "txt_first_name": "Anna", "int_birth_year": 1980},
]


def _write(tmp_path: Path, name: str, text: str) -> Path:
    path = tmp_path / name
    path.write_text(text, encoding="utf-8")
    return path


def _fencer(name: str, surname: str, first: str, year: int | None = None) -> str:
    by = f"\n    birth_year: {year}" if year is not None else ""
    return (
        f"- scraped_name: {name}\n  fencer:\n    surname: {surname}\n    first_name: {first}{by}\n"
    )


class TestEntries:
    def test_OVR_DRIFT_01_a_fencer_entry_names_exactly_one_roster_fencer(self, tmp_path):
        _write(
            tmp_path,
            "PEW2efs-2024-2025.yaml",
            "# a comment line\nidentity:\n"
            + _fencer("LEAHEY John", "LEAHEY", "John", 1976)  # the roster says 1969
            + _fencer("NOWAK Anna", "NOWAK", "Anna")  # two namesakes, no year
            + _fencer("NOWAK Anna", "Nowak", "anna", 1972),  # case-insensitive, as the ingest
        )
        checked, drifts = od.check(tmp_path, ROSTER)
        assert checked == 3
        assert [(d.entry, d.line, d.kind, d.found) for d in drifts] == [
            (0, 3, "fencer", 0),
            (1, 8, "fencer", 2),
        ]

    def test_OVR_DRIFT_01_the_gate_and_the_ingest_apply_one_rule(self):
        key = {"surname": "Nowak", "first_name": "anna", "birth_year": 1972}
        assert od.roster_matches(key, ROSTER) == [72]
        entry = IdentityOverride(scraped_name="NOWAK Anna", fencer=key)
        resolved = resolve_fencer_keys(Overrides(identity=[entry]), ROSTER)
        assert resolved.identity[0].id_fencer == 72

    def test_OVR_DRIFT_02_an_id_fencer_entry_is_on_the_roster(self, tmp_path):
        _write(
            tmp_path,
            "PEW1-2025-2026.yaml",
            "identity:\n- scraped_name: A B\n  id_fencer: 167\n- scraped_name: C D\n  id_fencer: 999\n",
        )
        checked, drifts = od.check(tmp_path, ROSTER)
        assert checked == 2
        assert [(d.entry, d.kind, d.found) for d in drifts] == [(1, "id_fencer", 0)]

    def test_OVR_DRIFT_03_a_create_fencer_entry_names_nobody_the_roster_holds(self, tmp_path):
        _write(
            tmp_path,
            "PEW1-2025-2026.yaml",
            "identity:\n"
            "- scraped_name: LEAHEY John\n  create_fencer: {surname: LEAHEY, first_name: John, birth_year: 1969}\n"
            "- scraped_name: NEW Person\n  create_fencer: {surname: NEW, first_name: Person, birth_year: 1970}\n",
        )
        checked, drifts = od.check(tmp_path, ROSTER)
        assert checked == 2
        assert [(d.entry, d.kind, d.found) for d in drifts] == [(0, "create_fencer", 1)]


class TestFiles:
    def test_OVR_DRIFT_04_every_file_and_entry_is_checked(self, tmp_path):
        _write(tmp_path, "A-2024-2025.yaml", "identity:\n" + _fencer("X Y", "LEAHEY", "John", 1976))
        _write(tmp_path, "B-2024-2025.yaml", "identity:\n" + _fencer("X Y", "LEAHEY", "John", 1976))
        _write(
            tmp_path,
            "C-2024-2025.yaml",
            "match_method:\n- scraped_name: Z\n  force_method: EXCLUDED\n",
        )
        _write(tmp_path, "D-2024-2025.yaml", "identity:\n- scraped_name: Q\n")  # no link at all
        _write(tmp_path, "notes.txt", "not an override file")
        checked, drifts = od.check(tmp_path, ROSTER)
        assert checked == 2
        assert [(Path(d.file).name, d.kind) for d in drifts] == [
            ("A-2024-2025.yaml", "fencer"),
            ("B-2024-2025.yaml", "fencer"),
            ("D-2024-2025.yaml", "file"),
        ]

    def test_OVR_DRIFT_05_a_line_names_no_fencer_and_no_birth_year(self, tmp_path):
        _write(
            tmp_path,
            "PEW2efs-2024-2025.yaml",
            "identity:\n" + _fencer("LEAHEY John", "LEAHEY", "John", 1976),
        )
        _write(tmp_path, "PEW4ef-2024-2025.yaml", "identity:\n- scraped_name: LEAHEY John\n")
        _, drifts = od.check(tmp_path, ROSTER)
        lines = [d.text() for d in drifts]
        assert lines[0] == (
            f"{tmp_path / 'PEW2efs-2024-2025.yaml'}:2 identity[0]: its fencer key names 0 "
            "roster fencers; it must name exactly one"
        )
        assert lines[1] == (
            f"{tmp_path / 'PEW4ef-2024-2025.yaml'}: not a valid override file (OverrideValidationError)"
        )
        for line in lines:
            assert "LEAHEY" not in line and "John" not in line and "1976" not in line


class TestCommandLine:
    class _Roster:
        def __init__(self, rows):
            self.rows, self.sql, self.read_only = rows, [], True

        def fetch_json(self, sql):
            self.sql.append(sql)
            return self.rows

    def test_OVR_DRIFT_06_clean_files_pass_and_say_how_many(self, tmp_path, capsys):
        _write(tmp_path, "A-2024-2025.yaml", "identity:\n" + _fencer("X Y", "LEAHEY", "John", 1969))
        roster = self._Roster(ROSTER)
        assert od.run(tmp_path, roster, "LOCAL") == 0
        assert "FROM tbl_fencer" in roster.sql[0]
        assert capsys.readouterr().out.strip() == (
            "override files: 1 identity entry in 1 file checked against the LOCAL roster, "
            "none drifted"
        )

    def test_OVR_DRIFT_06_a_drift_fails_the_gate(self, tmp_path, capsys):
        _write(tmp_path, "A-2024-2025.yaml", "identity:\n" + _fencer("X Y", "LEAHEY", "John", 1976))
        assert od.run(tmp_path, self._Roster(ROSTER), "CERT") == 1
        out = capsys.readouterr().out
        assert "identity[0]: its fencer key names 0 roster fencers" in out
        assert out.strip().endswith(
            "override files: 1 of 1 identity entry drifted from the CERT roster"
        )

    def test_OVR_DRIFT_06_the_roster_is_read_read_only(self, monkeypatch):
        made = {}

        class Local:
            def __init__(self, *, read_only):
                made["local"] = read_only

        class Mgmt:
            def __init__(self, ref, token, *, read_only):
                made["cert"] = (ref, read_only)

        from python.pipeline.promotion import refresh

        monkeypatch.setattr(refresh, "LocalTransport", Local)
        monkeypatch.setattr(refresh, "ManagementTransport", Mgmt)
        monkeypatch.setattr(od, "supabase_access_token", lambda: "t")
        od.transport_for("local")
        od.transport_for("cert")
        assert made == {"local": True, "cert": (refresh.CERT_REF, True)}

    def test_OVR_DRIFT_06_cert_needs_the_token(self, monkeypatch):
        monkeypatch.setattr(od, "supabase_access_token", lambda: None)
        with pytest.raises(SystemExit, match="SUPABASE_ACCESS_TOKEN is required"):
            od.transport_for("cert")


def test_OVR_DRIFT_07_ci_reads_cert_and_preflight_reads_local():
    """G43 A: the gate runs in CI against CERT (read only, with the token), in
    a job of its own so no other job holds the token; its last step writes the
    job's summary section and tells Telegram unless the gate passed. Preflight
    runs it against LOCAL."""
    import yaml

    root = Path(__file__).resolve().parents[2]
    jobs = yaml.safe_load((root / ".github/workflows/ci.yml").read_text(encoding="utf-8"))["jobs"]
    holders = [n for n, j in jobs.items() if "SUPABASE_ACCESS_TOKEN" in str(j)]
    assert holders == ["override-drift"]
    steps = jobs["override-drift"]["steps"]
    (step,) = [s for s in steps if s.get("id") == "override_drift"]
    assert step["run"] == "python -m python.pipeline.override_drift --roster cert"
    assert step["env"] == {"SUPABASE_ACCESS_TOKEN": "${{ secrets.SUPABASE_ACCESS_TOKEN }}"}
    last = steps[-1]
    assert last["if"] == "always()"
    assert last["env"]["OVERRIDE_DRIFT"] == "${{ steps.override_drift.outcome }}"
    assert '--check "Override files=$OVERRIDE_DRIFT"' in last["run"]
    assert 'if [[ "$OVERRIDE_DRIFT" == "success" ]]; then\n  exit 0' in last["run"]
    assert "api.telegram.org" in last["run"]
    preflight = (root / "scripts/preflight.sh").read_text(encoding="utf-8")
    assert "python -m python.pipeline.override_drift --roster local" in preflight
