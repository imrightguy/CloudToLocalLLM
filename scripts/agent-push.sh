#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/agent-push.sh --message "ai(AgentName): change summary" --files <path> [<path> ...] [--verify '<command>'] [--branch agent/name-task] [--dry-run]

Purpose:
  Create or switch to an agent branch, stage only the listed files, create one commit, and push that branch to origin.

Examples:
  scripts/agent-push.sh \
    --message "ai(Codex): fix app entrypoint routing" \
    --branch agent/codex-app-entrypoint \
    --files lib/main.dart lib/utils/entrypoint_policy.dart \
    --verify './scripts/flutter_with_cleanup.sh test test/main_start_screen_test.dart'

  scripts/agent-push.sh \
    --message "ai(Hermes): update deployment workflow" \
    --branch agent/hermes-deploy-workflow \
    --files .github/workflows/deployment.yml AGENTS.md \
    --dry-run
EOF
}

message=''
verify_cmd=''
dry_run=0
branch=''
allow_protected_branch=0
allow_non_agent_branch=0
files=()
protected_branches_regex='^(main|master|production|release)$'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --message|-m)
      [[ $# -ge 2 ]] || { echo 'Missing value for --message' >&2; exit 1; }
      message="$2"
      shift 2
      ;;
    --verify)
      [[ $# -ge 2 ]] || { echo 'Missing value for --verify' >&2; exit 1; }
      verify_cmd="$2"
      shift 2
      ;;
    --branch)
      [[ $# -ge 2 ]] || { echo 'Missing value for --branch' >&2; exit 1; }
      branch="$2"
      shift 2
      ;;
    --allow-protected-branch)
      allow_protected_branch=1
      shift
      ;;
    --allow-non-agent-branch)
      allow_non_agent_branch=1
      shift
      ;;
    --files)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        files+=("$1")
        shift
      done
      ;;
    --dry-run)
      dry_run=1
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

[[ -n "$message" ]] || { echo 'Commit message is required.' >&2; usage >&2; exit 1; }
[[ ${#files[@]} -gt 0 ]] || { echo 'At least one file path is required after --files.' >&2; usage >&2; exit 1; }

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo 'Not inside a git repository.' >&2
  exit 1
}
cd "$repo_root"

git remote get-url origin >/dev/null 2>&1 || {
  echo 'Remote origin is not configured.' >&2
  exit 1
}

current_branch=$(git rev-parse --abbrev-ref HEAD)
[[ "$current_branch" != "HEAD" ]] || { echo 'Detached HEAD is not supported.' >&2; exit 1; }

if [[ -n "$branch" && "$branch" != "$current_branch" ]]; then
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "==> Switching to existing branch $branch"
    [[ $dry_run -eq 1 ]] || git switch "$branch"
  else
    echo "==> Creating branch $branch"
    [[ $dry_run -eq 1 ]] || git switch -c "$branch"
  fi
  current_branch="$branch"
fi

if [[ $allow_protected_branch -eq 0 && "$current_branch" =~ $protected_branches_regex ]]; then
  echo "Refusing to commit/push directly on protected branch: $current_branch" >&2
  echo "Use --branch agent/<name-task> or pass --allow-protected-branch intentionally." >&2
  exit 1
fi

if [[ $allow_non_agent_branch -eq 0 && ! "$current_branch" =~ ^agent/ ]]; then
  echo "Refusing to push non-agent branch: $current_branch" >&2
  echo 'Agent work must land on agent/* branches unless --allow-non-agent-branch is set.' >&2
  exit 1
fi

for path in "${files[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "File does not exist: $path" >&2
    exit 1
  fi
  if ! git diff --quiet -- "$path" || ! git diff --cached --quiet -- "$path" || [[ -n $(git ls-files --others --exclude-standard -- "$path") ]]; then
    :
  else
    echo "No changes detected for: $path" >&2
    exit 1
  fi
done

if [[ -n "$verify_cmd" ]]; then
  echo "==> Running verification"
  echo "$verify_cmd"
  if [[ $dry_run -eq 0 ]]; then
    bash -lc "$verify_cmd"
  fi
fi

echo "==> Staging files on $current_branch"
for path in "${files[@]}"; do
  echo "  $path"
  if [[ $dry_run -eq 0 ]]; then
    git add -- "$path"
  fi
done

if [[ $dry_run -eq 0 ]]; then
  if git diff --cached --quiet; then
    echo 'Nothing staged. Refusing to commit.' >&2
    exit 1
  fi
fi

echo "==> Commit message: $message"
if [[ $dry_run -eq 0 ]]; then
  git commit -m "$message"
fi

echo "==> Push target: origin $current_branch"
if [[ $dry_run -eq 0 ]]; then
  git push -u origin "$current_branch"
fi

echo '==> Branch pushed. Next step: open a PR and hand off to DevOps for merge/release.'
echo "==> Suggested command: scripts/agent-open-pr.sh --title \"$message\" --body \"Verification:\n- <exact commands>\n\nScope:\n- <changed files>\n\nDevOps notes:\n- <merge/deploy concerns>\""

echo '==> Done'
