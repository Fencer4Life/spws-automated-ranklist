#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/integrate-agent-branch.sh <codex/task|claude/task>

Fetches origin/main and merges one completed agent branch into the registered,
clean integration checkout. The branch must be named after what it changes and
carry a branch description (scripts/branch_description.py check); the merge
commit is that description with a Branch: line. It deliberately does not push;
review and required validation must succeed before the integrator pushes the
integration branch to main (`git push origin <integration-branch>:main`).
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi
task_branch=$1
if [[ ! "$task_branch" =~ ^(codex|claude)/[a-z0-9][a-z0-9-]*$ ]]; then
  echo "ERROR: branch must match codex/<task> or claude/<task>." >&2
  exit 2
fi

current_root=$(git rev-parse --show-toplevel)
integration_root=$(git config --get spws.integrationWorktree || true)
if [[ -z "$integration_root" ]]; then
  echo "ERROR: integration checkout is not registered." >&2
  exit 1
fi
current_root=$(cd "$current_root" && pwd -P)
integration_root=$(cd "$integration_root" && pwd -P)
if [[ "$current_root" != "$integration_root" ]]; then
  echo "ERROR: run integration only from $integration_root." >&2
  exit 1
fi
integration_branch=$(git symbolic-ref --quiet --short HEAD || true)
if [[ "$integration_branch" != "main" && "$integration_branch" != "integration/main" ]]; then
  echo "ERROR: integration checkout must be on main or integration/main." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: integration checkout is not clean; refusing to absorb unrelated changes." >&2
  exit 1
fi

git fetch origin main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "ERROR: the integration branch must exactly match origin/main before integration." >&2
  echo "Resolve or push the previous integration first." >&2
  exit 1
fi
if ! git show-ref --verify --quiet "refs/heads/$task_branch"; then
  echo "ERROR: local task branch not found: $task_branch" >&2
  exit 1
fi
if ! git merge-base --is-ancestor origin/main "$task_branch"; then
  echo "ERROR: $task_branch is not based on the current origin/main." >&2
  echo "Update the worker branch in its own worktree before integrating." >&2
  exit 1
fi
# The branch's name and description are the merge's title and explanation, and
# GitHub shows that title for the CI and Release runs. Nothing is merged without.
if ! python3 "$current_root/scripts/branch_description.py" check "$task_branch"; then
  echo "ERROR: $task_branch is not named or described; nothing merged." >&2
  exit 1
fi
merge_message=$(mktemp)
trap 'rm -f "$merge_message"' EXIT
python3 "$current_root/scripts/branch_description.py" message "$task_branch" >"$merge_message"

echo "Reviewing $task_branch against origin/main"
git diff --check "origin/main...$task_branch"
git diff --stat "origin/main...$task_branch"
git diff --name-status "origin/main...$task_branch"
git merge --no-ff -F "$merge_message" "$task_branch"

echo "Integrated $task_branch into local $integration_branch; not pushed."
# HEAD:main would be refused by .githooks/pre-push on integration/main: the hook
# compares the pushed local ref with the checkout's current branch.
echo "Run the task-appropriate validation, inspect the merge, then use: git push origin $integration_branch:main"
