#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

coverage_data="${COVERAGE_DATA:-[]}"
matrix_data="${MATRIX_DATA:-[]}"
badge_branch="${BADGE_BRANCH:?BADGE_BRANCH is required}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

require_json_array() {
  local source_name="$1" value="$2"
  if ! jq -e 'type == "array"' <<<"$value" >/dev/null 2>&1; then
    echo "::error::$source_name is not a JSON array: $value" >&2
    exit 1
  fi
}

require_field() {
  local source_name="$1" entry="$2" field_name="$3" field_value="$4"
  if [ -z "$field_value" ] || [ "$field_value" = "null" ]; then
    echo "::error::$source_name entry is missing '$field_name': $entry" >&2
    exit 1
  fi
}

require_json_array COVERAGE_DATA "$coverage_data"
require_json_array MATRIX_DATA "$matrix_data"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

badge_ref="refs/heads/$badge_branch"
ls_remote_rc=0
git ls-remote --exit-code origin "$badge_ref" >/dev/null || ls_remote_rc=$?
if [ "$ls_remote_rc" -ne 0 ] && [ "$ls_remote_rc" -ne 2 ]; then
  echo "::error::git ls-remote for $badge_ref failed with exit code $ls_remote_rc" >&2
  exit "$ls_remote_rc"
fi

worktree_dir="$(mktemp -d)"
cleanup() {
  git worktree remove --force "$worktree_dir" 2>/dev/null || true
  rm -rf "$worktree_dir"
}
trap cleanup EXIT

if [ "$ls_remote_rc" -eq 0 ]; then
  git fetch origin "+$badge_ref:refs/remotes/origin/$badge_branch"
  git worktree add "$worktree_dir" "origin/$badge_branch"
  git -C "$worktree_dir" checkout -B "$badge_branch"
else
  git worktree add --orphan -b "$badge_branch" "$worktree_dir"
fi

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  slug="$(jq -r '.slug' <<<"$entry")"
  label="$(jq -r '.label' <<<"$entry")"
  percent="$(jq -r '.percent' <<<"$entry")"
  require_field coverage-data "$entry" slug "$slug"
  require_field coverage-data "$entry" label "$label"
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
  require_field matrix-data "$entry" lang "$lang"
  require_field matrix-data "$entry" os "$os_name"
  require_field matrix-data "$entry" arch "$arch"
  require_field matrix-data "$entry" passed "$passed"
  python3 "$script_dir/matrix_badge_json.py" "$os_name" "$arch" "$passed" > "$worktree_dir/ci-$lang-$os_name-$arch.json"
done < <(jq -c '.[]' <<<"$matrix_data")

git -C "$worktree_dir" add -A

if git -C "$worktree_dir" diff --cached --quiet; then
  echo "badges unchanged; skipping commit"
  exit 0
fi

git -C "$worktree_dir" commit -m "chore(badges): update status badges [skip ci]"
git -C "$worktree_dir" push origin "HEAD:$badge_branch"
