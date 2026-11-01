"""The Supabase Management API token, read by one rule everywhere.

Every Python reader of SUPABASE_ACCESS_TOKEN calls ``supabase_access_token``, and
every shell script sources scripts/supabase-token.sh, which keeps the same rule.
python/tests/test_supabase_token.py runs one table of cases through both, and fails
on a reader that goes round them (ENVTOKEN.01–08).

The checkout's .env wins over the process environment, the opposite of the usual
convention and deliberate. A stale SUPABASE_ACCESS_TOKEN in the environment shadowed
the good value in .env and produced a bare HTTP 401 that reads like an expired token:
in scripts/cloud-sql.sh on 2026-08-17, and in every Python reader on 2026-11-01,
when python/tests/test_prod_mirror.py failed on it in preflight. .env is the file a
person edits when the token is rotated, so its value is the one that takes effect.

CI ships no .env and injects the secret as an environment variable, so there the
environment's value is used. CLOUD_SQL_TOKEN_FROM_ENV=1 makes the environment win
anywhere. SUPABASE_TOKEN_ENV_FILE names a file to read instead of the checkout's
.env; python/tests/conftest.py points it at one that does not exist, so no test is
handed the real token. The value is returned, never printed.
"""

from __future__ import annotations

import os
from pathlib import Path

NAME = "SUPABASE_ACCESS_TOKEN"
ENV_FILE = Path(__file__).resolve().parents[1] / ".env"
_DROP = str.maketrans("", "", "\"'\r")


def _from_file(env_file: Path) -> str:
    """The first ``NAME=`` line's value, without quotes or carriage returns, as
    scripts/supabase-token.sh reads it; "" when there is none or no file."""
    try:
        lines = env_file.read_bytes().decode("utf-8", "replace").split("\n")
    except OSError:
        return ""
    prefix = f"{NAME}="
    for line in lines:
        if line.startswith(prefix):
            return line.removeprefix(prefix).translate(_DROP)
    return ""


def supabase_access_token(env_file: Path | None = None) -> str:
    """The token, or "" when neither the .env file nor the environment holds one."""
    path = env_file or Path(os.environ.get("SUPABASE_TOKEN_ENV_FILE") or ENV_FILE)
    from_file = _from_file(path)
    from_env = os.environ.get(NAME, "")
    if os.environ.get("CLOUD_SQL_TOKEN_FROM_ENV") == "1":
        return from_env or from_file
    return from_file or from_env
