#!/usr/bin/env bash
# Bring up documentation search from nothing, or rebuild it after `down -v`.
#
#   tools/docs-search/setup.sh
#
# Idempotent. Safe to re-run after changing documentation — though for that,
# `python3 tools/docs-search/ingest.py` on its own is enough.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
cd "$REPO"

if [[ ! -f "$HERE/.env" ]]; then
  echo "Generating a local master key → tools/docs-search/.env"
  ( umask 077; printf 'MEILI_MASTER_KEY=%s\n' "$(openssl rand -hex 32)" > "$HERE/.env" )
fi

echo "==> Starting Meilisearch"
docker compose -f "$HERE/docker-compose.yml" --env-file "$HERE/.env" up -d

echo "==> Waiting for it to answer"
curl -fsS -o /dev/null --retry 30 --retry-delay 2 --retry-all-errors \
  --retry-max-time 120 http://127.0.0.1:7700/health
echo "    healthy"

echo "==> Indexing the documentation"
python3 "$HERE/ingest.py"

echo "==> Minting the read-only key and registering the MCP server"
python3 "$HERE/provision_key.py"
