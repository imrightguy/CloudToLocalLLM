#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/agent-open-pr.sh --title "title" --body "body" [--base main] [--head agent/name-task] [--draft]

Purpose:
  Open a pull request from an agent branch to the integration branch so DevOps can review and merge it.
EOF
}

title=''
body=''
base='main'
head=''
draft=0
allow_non_agent_branch=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      title="$2"
      shift 2
      ;;
    --body)
      body="$2"
      shift 2
      ;;
    --base)
      base="$2"
      shift 2
      ;;
    --head)
      head="$2"
      shift 2
      ;;
    --draft)
      draft=1
      shift
      ;;
    --allow-non-agent-branch)
      allow_non_agent_branch=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ -n "$title" ]] || { echo 'PR title is required.' >&2; exit 1; }
[[ -n "$body" ]] || { echo 'PR body is required.' >&2; exit 1; }

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo 'Not inside a git repository.' >&2
  exit 1
}
cd "$repo_root"

current_branch=$(git rev-parse --abbrev-ref HEAD)
[[ "$current_branch" != "HEAD" ]] || { echo 'Detached HEAD is not supported.' >&2; exit 1; }

if [[ -z "$head" ]]; then
  head="$current_branch"
fi

if [[ $allow_non_agent_branch -eq 0 && ! "$head" =~ ^agent/ ]]; then
  echo "Refusing to open a PR from non-agent branch: $head" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo 'gh CLI is required.' >&2
  exit 1
fi

git remote get-url origin >/dev/null 2>&1 || {
  echo 'Remote origin is not configured.' >&2
  exit 1
}

args=(pr create --base "$base" --head "$head" --title "$title" --body "$body")
if [[ $draft -eq 1 ]]; then
  args+=(--draft)
fi

gh "${args[@]}"
