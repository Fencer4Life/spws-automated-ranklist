#!/usr/bin/env python3
"""Mint the MCP server's read-only Meilisearch key and register it with Claude.

Run after the index is built. Idempotent: an existing key of the same name is
replaced, and the Claude Code MCP entry is rewritten to match.

Why this is a script and not a one-off: Meilisearch stores its API keys inside
the data volume, so `docker compose down -v` destroys them. Without this,
rebuilding the stack would leave `~/.claude.json` holding a key that no longer
exists and the MCP server would fail with no obvious cause.

The MCP server gets search and read actions only — it cannot create, modify or
delete anything, which matters because the server exposes 26 tools including
`delete-index` and `create-key`. Indexing uses the master key instead, and only
from `ingest.py`.
"""

from __future__ import annotations

import json
import os
import pathlib
import shutil
import urllib.error
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]
MEILI_URL = "http://127.0.0.1:7700"
INDEX = "spws_docs"
KEY_NAME = "spws-docs-readonly"
KEY_FILE = HERE / ".readonly-key"
MCP_NAME = "spws-docs"
MCP_IMAGE = "getmeili/meilisearch-mcp:0.7.0"
NETWORK = "spws-docs-search_default"

READ_ONLY_ACTIONS = [
    "search",
    "documents.get",
    "indexes.get",
    "settings.get",
    "stats.get",
    "tasks.get",
]


def master_key() -> str:
    for line in (HERE / ".env").read_text(encoding="utf-8").splitlines():
        if line.startswith("MEILI_MASTER_KEY="):
            return line.split("=", 1)[1].strip()
    raise SystemExit(f"MEILI_MASTER_KEY not found in {HERE / '.env'}")


def api(method: str, path: str, key: str, payload=None) -> dict:
    req = urllib.request.Request(
        f"{MEILI_URL}{path}",
        data=None if payload is None else json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode()
    except urllib.error.HTTPError as exc:
        raise SystemExit(
            f"{method} {path} failed: {exc.code} {exc.read().decode()[:300]}"
        ) from exc
    return json.loads(body) if body else {}


def mint(master: str) -> str:
    for existing in api("GET", "/keys", master).get("results", []):
        if existing.get("name") == KEY_NAME:
            api("DELETE", f"/keys/{existing['uid']}", master)
    made = api("POST", "/keys", master, {
        "name": KEY_NAME,
        "description": "Search-only key for the MCP server.",
        "actions": READ_ONLY_ACTIONS,
        "indexes": [INDEX],
        "expiresAt": None,
    })
    KEY_FILE.write_text(made["key"] + "\n", encoding="utf-8")
    os.chmod(KEY_FILE, 0o600)
    return made["key"]


def register(key: str) -> None:
    cfg = pathlib.Path.home() / ".claude.json"
    shutil.copy2(cfg, cfg.with_suffix(".json.bak-spws-docs"))
    data = json.loads(cfg.read_text(encoding="utf-8"))
    project = data.setdefault("projects", {}).setdefault(str(REPO), {})
    project.setdefault("mcpServers", {})[MCP_NAME] = {
        "type": "stdio",
        "command": "docker",
        # `-e VAR` with no value passes it through from the environment, so the
        # key stays out of any command line visible to `ps`.
        "args": [
            "run", "-i", "--rm",
            "--network", NETWORK,
            "-e", "MEILI_HTTP_ADDR",
            "-e", "MEILI_MASTER_KEY",
            MCP_IMAGE,
        ],
        "env": {
            "MEILI_HTTP_ADDR": "http://meilisearch:7700",
            "MEILI_MASTER_KEY": key,
        },
    }
    cfg.write_text(json.dumps(data, indent=2), encoding="utf-8")
    os.chmod(cfg, 0o600)


def main() -> None:
    master = master_key()
    stats = api("GET", f"/indexes/{INDEX}/stats", master)
    print(f"Index '{INDEX}': {stats.get('numberOfDocuments')} documents")
    key = mint(master)
    print(f"Read-only key '{KEY_NAME}' minted → {KEY_FILE.name}")
    register(key)
    print(f"MCP server '{MCP_NAME}' registered for {REPO}")
    print("\nRestart Claude Code for the MCP server to be picked up.")


if __name__ == "__main__":
    main()
