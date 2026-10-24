"""SEEDNAME.01–04 — a seed file is named for the environment it was read from (ADR-036).

seed_prod_latest.sql is what CI, a LOCAL boot and seed-remote.sh load (config.toml
[db.seed]). export-seed.yml with source=cert used to write CERT's data as
seed_prod_<date>.sql and point seed_prod_latest.sql at it, so the next CI run and
LOCAL boot loaded CERT's data under PROD's name (question E1 on the W2 sign-off
sheet, answered A on 25 Oct 2026). Now a CERT export is seed_cert_<date>.sql and
leaves the PROD seed alone.
"""

from __future__ import annotations

import os
import re
import sys
from datetime import date
from pathlib import Path

import pytest
import yaml

from python.pipeline import export_seed

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "export-seed.yml"


@pytest.fixture
def run_export(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    """Run export_seed.main() in an empty checkout whose PROD seed points at an old file."""
    seeds = tmp_path / "supabase"
    seeds.mkdir()
    _ = (seeds / "seed_prod_2026-01-01.sql").write_text("-- old PROD seed\n")
    os.symlink("seed_prod_2026-01-01.sql", seeds / "seed_prod_latest.sql")
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv("SUPABASE_ACCESS_TOKEN", "test-token")
    monkeypatch.setattr(export_seed, "export_monolithic", lambda ref, token: f"-- data of {ref}\n")

    def run(*args: str) -> Path:
        monkeypatch.setattr(sys, "argv", ["export_seed", "--ref", "abc", *args])
        export_seed.main()
        return seeds

    return run


def test_SEEDNAME_01_a_prod_export_becomes_the_latest_prod_seed(run_export):
    seeds = run_export()
    stamp = date.today().isoformat()
    assert (seeds / f"seed_prod_{stamp}.sql").read_text() == "-- data of abc\n"
    assert os.readlink(seeds / "seed_prod_latest.sql") == f"seed_prod_{stamp}.sql"


def test_SEEDNAME_02_a_cert_export_is_named_cert_and_leaves_the_prod_seed(run_export):
    seeds = run_export("--env", "cert")
    stamp = date.today().isoformat()
    assert (seeds / f"seed_cert_{stamp}.sql").read_text() == "-- data of abc\n"
    assert not (seeds / f"seed_prod_{stamp}.sql").exists()
    assert os.readlink(seeds / "seed_prod_latest.sql") == "seed_prod_2026-01-01.sql"
    assert not (seeds / "seed_cert_latest.sql").exists()


def test_SEEDNAME_03_an_unknown_environment_is_refused(run_export):
    with pytest.raises(SystemExit):
        run_export("--env", "local")


def test_SEEDNAME_04_the_workflow_names_the_source_and_stages_only_its_files():
    """export-seed.yml hands its source to the export and commits only that source's files,
    so a CERT export never stages seed_prod_latest.sql."""
    steps = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))["jobs"]["export"]["steps"]
    export = next(s for s in steps if s.get("name") == "Export seed")
    commit = next(s for s in steps if s.get("name") == "Commit seed file")
    assert re.search(r'--env "\$SOURCE"', export["run"])
    assert re.findall(r"git add [^\n]*", commit["run"]) == [
        'git add "supabase/seed_${SOURCE}_"*.sql'
    ]
