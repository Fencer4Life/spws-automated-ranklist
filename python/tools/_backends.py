"""Shared SQL backend abstractions for one-shot data tools.

Two implementations:

- LocalBackend talks to the local Supabase via `docker exec psql` (port 5432
  is blocked from outside the container; this is the only path that works
  with the dockerised stack).
- ManagementBackend talks to CERT/PROD via the Supabase Management API
  `/database/query` endpoint. Requires `SUPABASE_ACCESS_TOKEN` in env.

`query()` returns:
- LocalBackend: list of list[str] (psql `-At -F\\x1f` rows split on the
  field separator).
- ManagementBackend: list of dict (JSON parsed).

Tools that consume the result must handle both shapes — see the existing
patterns in `python/tools/refix_combined_pools.py` for the canonical
adapter calls.
"""

from __future__ import annotations

import os
import subprocess

import httpx


CERT_REF = "sdomfjncmfydlkygzpgw"
PROD_REF = "ywgymtgcyturldazcpmw"


class Backend:
    def query(self, sql: str) -> list:
        raise NotImplementedError

    def execute(self, sql: str) -> None:
        raise NotImplementedError


class LocalBackend(Backend):
    """Talk to LOCAL Supabase via docker exec psql."""

    def query(self, sql: str) -> list:
        cmd = [
            "docker", "exec", "supabase_db_SPWSranklist",
            "psql", "-U", "postgres", "-d", "postgres",
            "-At", "-F\x1f", "-c", sql,
        ]
        out = subprocess.check_output(cmd, text=True)
        rows = []
        for line in out.strip().splitlines():
            if not line:
                continue
            rows.append(line.split("\x1f"))
        return rows

    def execute(self, sql: str) -> None:
        cmd = [
            "docker", "exec", "-i", "supabase_db_SPWSranklist",
            "psql", "-U", "postgres", "-d", "postgres",
            "-v", "ON_ERROR_STOP=1",
        ]
        subprocess.run(cmd, input=sql, text=True, check=True)


class ManagementBackend(Backend):
    """Talk to CERT/PROD via Supabase Management API /database/query."""

    def __init__(self, project_ref: str):
        self.project_ref = project_ref
        self.token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
        if not self.token:
            raise RuntimeError("SUPABASE_ACCESS_TOKEN not set")
        self.endpoint = (
            f"https://api.supabase.com/v1/projects/{project_ref}/database/query"
        )

    def _post(self, sql: str) -> list:
        r = httpx.post(
            self.endpoint,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
            json={"query": sql},
            timeout=120,
        )
        r.raise_for_status()
        return r.json()

    def query(self, sql: str) -> list:
        return self._post(sql)

    def execute(self, sql: str) -> None:
        self._post(sql)


def make_backend(env: str) -> Backend:
    if env == "LOCAL":
        return LocalBackend()
    if env == "CERT":
        return ManagementBackend(CERT_REF)
    if env == "PROD":
        return ManagementBackend(PROD_REF)
    raise ValueError(f"unknown env: {env}")
