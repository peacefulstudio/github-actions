#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

coverage_data="${COVERAGE_DATA:-[]}"
matrix_data="${MATRIX_DATA:-[]}"
badge_branch="${BADGE_BRANCH:?BADGE_BRANCH is required}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git fetch origin "$badge_branch" || true

worktree_dir="$(mktemp -d)"
cleanup() {
  git worktree remove --force "$worktree_dir" 2>/dev/null || true
  rm -rf "$worktree_dir"
}
trap cleanup EXIT

if git rev-parse --verify "origin/$badge_branch" >/dev/null 2>&1; then
  git worktree add "$worktree_dir" "origin/$badge_branch"
  git -C "$worktree_dir" checkout -B "$badge_branch"
else
  git worktree add --orphan -b "$badge_branch" "$worktree_dir"
  git -C "$worktree_dir" rm -rf . 2>/dev/null || true
fi

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  slug="$(jq -r '.slug' <<<"$entry")"
  label="$(jq -r '.label' <<<"$entry")"
  percent="$(jq -r '.percent' <<<"$entry")"
  if [ -z "$percent" ] || [ "$percent" = "null" ]; then
    continue
  fi
  python3 "$script_dir/coverage_badge_json.py" "$percent" "$label" > "$worktree_dir/coverage-$slug.json"
done < <(jq -c '.[]' <<<"$coverage_data")

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  lang="$(jq -r '.lang' <<<"$entry")"
  os_name="$(jq -r '.os' <<<"$entry")"
  arch="$(jq -r '.arch' <<<"$entry")"
  passed="$(jq -r '.passed' <<<"$entry")"
  python3 "$script_dir/matrix_badge_json.py" "$os_name" "$arch" "$passed" > "$worktree_dir/ci-$lang-$os_name-$arch.json"
done < <(jq -c '.[]' <<<"$matrix_data")

git -C "$worktree_dir" add -A

if git -C "$worktree_dir" diff --cached --quiet; then
  echo "badges unchanged; skipping commit"
  exit 0
fi

git -C "$worktree_dir" commit -m "chore(badges): update status badges [skip ci]"
git -C "$worktree_dir" push origin "HEAD:$badge_branch"
