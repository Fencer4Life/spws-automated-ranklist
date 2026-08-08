#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/start-agent-worktree.sh <codex|claude> <task> [--worktree-root PATH]

Creates <agent>/<task> from the latest origin/main in a separate worktree.
The task must use lowercase letters, digits, and hyphens. By default, the
worktree is a sibling named <repository>-<agent>-<task>. --worktree-root
changes the parent directory without changing that naming convention.
EOF
}

if [[ $# -lt 2 ]]; then
  usage >&2
  exit 2
fi

agent=$1
task=$2
shift 2
worktree_root=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --worktree-root)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      worktree_root=$2
      shift 2
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$agent" != "codex" && "$agent" != "claude" ]]; then
  echo "ERROR: agent must be codex or claude." >&2
  exit 2
fi
if [[ ! "$task" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "ERROR: task must match [a-z0-9][a-z0-9-]*." >&2
  exit 2
fi

current_root=$(git rev-parse --show-toplevel)
integration_root=$(git config --get spws.integrationWorktree || true)
if [[ -z "$integration_root" ]]; then
  echo "ERROR: integration checkout is not registered." >&2
  echo "Run scripts/install-agent-worktree-guards.sh --integration from root main first." >&2
  exit 1
fi
current_root=$(cd "$current_root" && pwd -P)
integration_root=$(cd "$integration_root" && pwd -P)
if [[ "$current_root" != "$integration_root" ]]; then
  echo "ERROR: create agent worktrees from the registered integration checkout." >&2
  exit 1
fi
integration_branch=$(git symbolic-ref --quiet --short HEAD || true)
if [[ "$integration_branch" != "main" && "$integration_branch" != "integration/main" ]]; then
  echo "ERROR: integration checkout must be on main or integration/main." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: integration checkout must be clean before creating a worker." >&2
  exit 1
fi

repository_name=$(basename "$integration_root")
repository_name=${repository_name%-integration}
if [[ -z "$worktree_root" ]]; then
  worktree_root=$(dirname "$integration_root")
fi
branch="$agent/$task"
worktree_path="$worktree_root/$repository_name-$agent-$task"

git fetch origin main
if git show-ref --verify --quiet "refs/heads/$branch"; then
  echo "ERROR: branch already exists: $branch" >&2
  exit 1
fi
if [[ -e "$worktree_path" ]]; then
  echo "ERROR: worktree path already exists: $worktree_path" >&2
  exit 1
fi

mkdir -p "$worktree_root"
git worktree add -b "$branch" "$worktree_path" origin/main

echo "Agent worktree created"
echo "  branch: $branch"
echo "  path:   $worktree_path"
