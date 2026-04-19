#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/sync-my-codex.sh [--dry-run] [--no-push]

Rebuilds `my-codex` from `upstream/main` plus the ordered private patch
branches listed in `scripts/private-patch-branches.txt`.

Options:
  --dry-run  Print the actions that would run without mutating branches.
  --no-push  Rebuild locally but do not push to origin.
EOF
}

dry_run=false
push_changes=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=true
      ;;
    --no-push)
      push_changes=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

repo_root="$(git rev-parse --show-toplevel)"
patch_manifest="$repo_root/scripts/private-patch-branches.txt"
target_branch="my-codex"
mirror_branch="main"
upstream_ref="upstream/main"
starting_branch="$(git branch --show-current)"

run() {
  if $dry_run; then
    printf '[dry-run] %q' "$1"
    shift
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  else
    "$@"
  fi
}

cleanup_on_error() {
  local exit_code=$?
  if (( exit_code != 0 )); then
    echo "sync-my-codex.sh failed." >&2
    if [[ -n "${current_patch_branch:-}" ]]; then
      echo "Last patch branch: ${current_patch_branch}" >&2
    fi
    echo "Resolve the conflict, then rerun the script." >&2
  fi
  exit "$exit_code"
}

trap cleanup_on_error ERR

if [[ ! -f "$patch_manifest" ]]; then
  echo "Patch manifest not found: $patch_manifest" >&2
  exit 1
fi

if [[ -n "$(git status --short)" ]]; then
  echo "Working tree must be clean before syncing my-codex." >&2
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Missing required remote: origin" >&2
  exit 1
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Missing required remote: upstream" >&2
  exit 1
fi

run git fetch origin upstream

if ! git rev-parse --verify "$upstream_ref" >/dev/null 2>&1; then
  echo "Expected ref $upstream_ref after fetch." >&2
  exit 1
fi

run git checkout "$mirror_branch"
run git reset --hard "$upstream_ref"

run git checkout -B "$target_branch" "$upstream_ref"

while IFS= read -r patch_branch || [[ -n "$patch_branch" ]]; do
  patch_branch="${patch_branch%%#*}"
  patch_branch="${patch_branch#"${patch_branch%%[![:space:]]*}"}"
  patch_branch="${patch_branch%"${patch_branch##*[![:space:]]}"}"
  [[ -z "$patch_branch" ]] && continue

  current_patch_branch="$patch_branch"

  if ! git rev-parse --verify "$patch_branch" >/dev/null 2>&1; then
    echo "Patch branch not found: $patch_branch" >&2
    exit 1
  fi

  merge_base="$(git merge-base "$upstream_ref" "$patch_branch")"
  while IFS= read -r commit; do
    [[ -z "$commit" ]] && continue
    run git cherry-pick "$commit"
  done < <(git rev-list --reverse "${merge_base}..${patch_branch}")
done < "$patch_manifest"

if $push_changes; then
  run git push --force-with-lease origin "$mirror_branch"
  run git push --force-with-lease origin "$target_branch"
fi

run git checkout "$starting_branch"

echo "my-codex sync complete."
