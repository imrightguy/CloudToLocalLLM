#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/agent-push.sh --message "ai(AgentName): change summary" --files <path> [<path> ...] [--verify '<command>'] [--dry-run]

Purpose:
  Stage only the listed files, create one commit, and push the current branch to origin.

Examples:
  scripts/agent-push.sh \
    --message "ai(Codex): fix app entrypoint routing" \
    --files lib/main.dart lib/utils/entrypoint_policy.dart \
    --verify './scripts/flutter_with_cleanup.sh test test/main_start_screen_test.dart'

  scripts/agent-push.sh \
    --message "ai(Hermes): update deployment workflow" \
    --files .github/workflows/deployment.yml AGENTS.md \
    --dry-run
EOF
}

message=''
verify_cmd=''
dry_run=0
files=()

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

current_branch=$(git rev-parse --abbrev-ref HEAD)
[[ "$current_branch" != "HEAD" ]] || { echo 'Detached HEAD is not supported.' >&2; exit 1; }

git remote get-url origin >/dev/null 2>&1 || {
  echo 'Remote origin is not configured.' >&2
  exit 1
}

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

echo '==> Staging files'
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
  git push origin "$current_branch"
fi

echo '==> Done'
