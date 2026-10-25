"""Fail unless LOCAL's Supabase stack is the one CI tests on (WFSETUP.03–04).

1. The local CLI is the version every workflow pins. The CLI version decides which
   Postgres, PostgREST and GoTrue images `supabase start` boots (ci.yml explains the
   pin). This Mac ran 2.84.2 from Homebrew while CI pinned 2.116.0, so LOCAL tested
   on other images than CI and nothing said so (F12 on
   doc/plans/frontend-toolchain-before-after-2026-10-25.html). Install the pinned
   version the way CI does: `npm install -g supabase@<pin>`.
2. Every extension in LOCAL's database is the version its image ships, and the
   library file behind each of its C functions exists. CI starts from an empty
   database, so it always has both; LOCAL keeps its database across a CLI change,
   extensions included. After the move to 2.116.0 LOCAL still had plpgsql_check
   2.7, whose library (plpgsql_check-2.7.so) the new image does not ship, so
   postgrestools skipped plpgsql_check without a word (F16). ALTER EXTENSION ...
   UPDATE then moved it to 2.8 and left its functions on the old file, which is
   why the library itself is checked.

Usage: python scripts/check_supabase_cli.py
"""

from __future__ import annotations

import subprocess
import sys
import tomllib
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"

# Per extension that differs from its image: name, schema, installed version, the
# image's version, whether the image has an update path, and whether a member C
# function names a library file the image does not have. pg_config and pg_ls_dir
# need the superuser.
STALE_EXTENSIONS = r"""
WITH files AS (
  SELECT f FROM pg_ls_dir((SELECT setting FROM pg_config WHERE name = 'PKGLIBDIR')) AS f
), broken AS (
  SELECT DISTINCT d.refobjid AS ext
    FROM pg_proc AS p
    JOIN pg_depend AS d
      ON d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e'
   WHERE p.probin LIKE '$libdir/%'
     AND regexp_replace(p.probin, '^\$libdir/', '') || '.so' NOT IN (SELECT f FROM files)
)
SELECT x.extname, n.nspname, x.extversion, a.default_version,
       EXISTS (SELECT 1 FROM pg_extension_update_paths(x.extname) AS u
                WHERE u.source = x.extversion
                  AND u.target = a.default_version
                  AND u.path IS NOT NULL),
       x.oid IN (SELECT ext FROM broken)
  FROM pg_extension AS x
  JOIN pg_namespace AS n ON n.oid = x.extnamespace
  JOIN pg_available_extensions AS a ON a.name = x.extname
 WHERE x.extversion <> a.default_version
    OR x.oid IN (SELECT ext FROM broken)
 ORDER BY x.extname
"""


def pinned_versions() -> set[str]:
    pins: set[str] = set()
    for path in sorted(WORKFLOWS.glob("*.yml")):
        spec = yaml.safe_load(path.read_text(encoding="utf-8"))
        for job in (spec.get("jobs") or {}).values():
            for step in job.get("steps") or []:
                if str(step.get("uses", "")).startswith("supabase/setup-cli@"):
                    pins.add(str((step.get("with") or {}).get("version")))
    return pins


def check_cli() -> str | None:
    pins = pinned_versions()
    if len(pins) != 1:
        return f"the workflows must pin one Supabase CLI version; they pin {sorted(pins)}"
    want = pins.pop()
    try:
        # The CLI prints its update notice on stderr; the version is stdout's first line.
        out = subprocess.run(
            ["supabase", "--version"], capture_output=True, text=True, check=False
        ).stdout
    except FileNotFoundError:
        return f"no Supabase CLI on PATH; the workflows pin {want}: npm install -g supabase@{want}"
    have = out.strip().splitlines()[0] if out.strip() else "(no version printed)"
    if have != want:
        return f"Supabase CLI {have} is installed; the workflows pin {want}: npm install -g supabase@{want}"
    print(f"Supabase CLI {have} = the workflows' pin")
    return None


def check_extensions() -> str | None:
    project = tomllib.loads((ROOT / "supabase" / "config.toml").read_text(encoding="utf-8"))
    container = f"supabase_db_{project['project_id']}"
    # As the image's superuser, the extensions' owner. postgres is not one on
    # Supabase's image, and its ALTER EXTENSION fails with "pgaudit stack is not empty".
    run = f"docker exec {container} psql -U supabase_admin -d postgres"
    psql = [*run.split(), "-At"]
    try:
        result = subprocess.run(
            [*psql, "-c", STALE_EXTENSIONS], capture_output=True, text=True, check=False
        )
    except FileNotFoundError:
        result = None
    if result is None or result.returncode != 0:
        why = result.stderr.strip() if result is not None else "docker is not on PATH"
        return f"cannot read LOCAL's database ({container}: {why}); start it with supabase start"
    stale = [line.split("|") for line in result.stdout.splitlines() if line.strip()]
    if not stale:
        print(
            "every extension in LOCAL's database is the version its image ships, libraries present"
        )
        return None
    lines = ["LOCAL's database has extensions that differ from its image (CI's do not):"]
    for name, schema, have, want, has_path, broken in stale:
        if has_path == "t" and broken == "f":
            lines.append(f"  {name} {have}, image {want}: {run} -c 'ALTER EXTENSION {name} UPDATE'")
            continue
        why = "cannot load its library" if broken == "t" else "no update path"
        lines.append(
            f"  {name} {have}, image {want}, {why}: {run} -1 -c 'DROP EXTENSION {name}'"
            + f" -c 'CREATE EXTENSION {name} WITH SCHEMA {schema}' (refused while anything"
            + " depends on it), or ./scripts/reset-dev.sh, which replaces LOCAL's data with the seed"
        )
    return "\n".join(lines)


def main() -> int:
    for check in (check_cli, check_extensions):
        problem = check()
        if problem:
            print(problem)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
