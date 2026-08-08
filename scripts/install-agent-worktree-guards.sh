#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/install-agent-worktree-guards.sh --integration

Run once from a clean checkout on branch main or integration/main. This
registers that checkout as the only location allowed to push main and enables
tracked hooks for every worktree sharing this Git repository.
EOF
}

if [[ $# -ne 1 || "$1" != "--integration" ]]; then
  usage >&2
  exit 2
fi

repo_root=$(git rev-parse --show-toplevel)
branch=$(git symbolic-ref --quiet --short HEAD || true)

if [[ "$branch" != "main" && "$branch" != "integration/main" ]]; then
  echo "ERROR: integration branch must be main or integration/main, not ${branch:-detached}." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: integration checkout must be clean before it is registered." >&2
  exit 1
fi

repo_root=$(cd "$repo_root" && pwd -P)
git config core.hooksPath .githooks
git config spws.integrationWorktree "$repo_root"

echo "Integration checkout registered: $repo_root"
echo "Tracked Git hooks enabled from .githooks"
