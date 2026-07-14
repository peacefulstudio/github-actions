#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../scripts/write-badges.sh"

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null

fail=0
check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name: expected [$expected] got [$actual]"
    fail=1
  fi
}

check_rc() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name: expected rc [$expected] got [$actual]"
    fail=1
  fi
}

check_contains() {
  local name="$1" needle="$2" hay="$3"
  case "$hay" in
    *"$needle"*) echo "ok   - $name" ;;
    *) echo "FAIL - $name: [$hay] does not contain [$needle]"; fail=1 ;;
  esac
}

sandbox=""
origin=""
work=""

setup_repos() {
  sandbox="$(mktemp -d)"
  origin="$sandbox/origin.git"
  work="$sandbox/work"
  git init -q --bare "$origin"
  git init -q -b main "$work"
  git -C "$work" config user.name test
  git -C "$work" config user.email test@example.com
  git -C "$work" remote add origin "$origin"
  git -C "$work" commit -q --allow-empty -m init
  git -C "$work" push -q origin main
}

seed_remote_badge_branch() {
  local branch="$1" filename="$2"
  local seed="$sandbox/seed"
  git clone -q "$origin" "$seed"
  git -C "$seed" config user.name test
  git -C "$seed" config user.email test@example.com
  git -C "$seed" checkout -q --orphan "$branch"
  git -C "$seed" rm -r -f -q --ignore-unmatch .
  echo '{"seed":true}' > "$seed/$filename"
  git -C "$seed" add "$filename"
  git -C "$seed" commit -qm seed
  git -C "$seed" push -q origin "$branch"
  rm -rf "$seed"
}

badge_branch_files() {
  local branch="$1"
  git -C "$origin" ls-tree --name-only "refs/heads/$branch" 2>/dev/null | sort | tr '\n' ' ' | sed 's/ $//'
}

run() {
  local coverage="$1" matrix="$2" branch="$3"
  local errf; errf="$(mktemp)"
  set +e
  out="$(cd "$work" && COVERAGE_DATA="$coverage" MATRIX_DATA="$matrix" BADGE_BRANCH="$branch" bash "$script" 2>"$errf")"
  rc=$?
  set -e
  err="$(cat "$errf")"; rm -f "$errf"
}

setup_repos
run '[{"slug":"csharp","label":"C#","percent":91}]' \
  '[{"lang":"csharp","os":"ubuntu","arch":"x64","passed":true}]' badges
check_rc "fresh repo happy path exit 0" 0 "$rc"
check "fresh repo writes contract filenames" \
  "ci-csharp-ubuntu-x64.json coverage-csharp.json" "$(badge_branch_files badges)"
check_contains "coverage badge content on branch" '"message": "91%"' \
  "$(git -C "$origin" show badges:coverage-csharp.json)"
check_contains "matrix badge content on branch" '"message": "passing"' \
  "$(git -C "$origin" show badges:ci-csharp-ubuntu-x64.json)"
rm -rf "$sandbox"

setup_repos
run '[{"slug":"csharp","label":"C#","percent":null},{"slug":"go","label":"Go","percent":""}]' '[]' badges
check_rc "all coverage percents null exit 0" 0 "$rc"
check_contains "all coverage percents null skips commit" "badges unchanged; skipping commit" "$out"
check "all coverage percents null pushes nothing" "" "$(badge_branch_files badges)"
rm -rf "$sandbox"

setup_repos
run '[{"slug":"csharp","label":"C#","percent":null},{"slug":"go","label":"Go","percent":87}]' '[]' badges
check_rc "mixed null percent exit 0" 0 "$rc"
check "mixed null percent writes only the non-null badge" \
  "coverage-go.json" "$(badge_branch_files badges)"
rm -rf "$sandbox"

setup_repos
run '[{"label":"C#","percent":91}]' '[]' badges
check_rc "coverage entry missing slug exit 1" 1 "$rc"
check_contains "coverage entry missing slug annotated" \
  "::error::coverage-data entry is missing 'slug'" "$err"
rm -rf "$sandbox"

setup_repos
run '[]' '[{"os":"ubuntu","arch":"x64","passed":true}]' badges
check_rc "matrix entry missing lang exit 1" 1 "$rc"
check_contains "matrix entry missing lang annotated" \
  "::error::matrix-data entry is missing 'lang'" "$err"
check "matrix entry missing lang pushes nothing" "" "$(badge_branch_files badges)"
rm -rf "$sandbox"

setup_repos
run '[]' '[{"lang":"csharp","os":null,"arch":"x64","passed":true}]' badges
check_rc "matrix entry null os exit 1" 1 "$rc"
check_contains "matrix entry null os annotated" \
  "::error::matrix-data entry is missing 'os'" "$err"
rm -rf "$sandbox"

setup_repos
run '[]' '[{"lang":"csharp","os":"ubuntu","arch":"x64"}]' badges
check_rc "matrix entry missing passed exit 1" 1 "$rc"
check_contains "matrix entry missing passed annotated" \
  "::error::matrix-data entry is missing 'passed'" "$err"
rm -rf "$sandbox"

setup_repos
run '[]' '[{"lang":"csharp","os":"ubuntu","arch":"x64","passed":"cancelled"}]' badges
check_rc "matrix entry unknown status exit 2" 2 "$rc"
check_contains "matrix entry unknown status surfaced" "unknown matrix status" "$err"
rm -rf "$sandbox"

setup_repos
run '[bad' '[]' badges
check_rc "malformed coverage-data json exit 1" 1 "$rc"
check_contains "malformed coverage-data annotated" \
  "::error::COVERAGE_DATA is not a JSON array" "$err"
rm -rf "$sandbox"

setup_repos
run '[]' '{"lang":"csharp"}' badges
check_rc "non-array matrix-data exit 1" 1 "$rc"
check_contains "non-array matrix-data annotated" \
  "::error::MATRIX_DATA is not a JSON array" "$err"
rm -rf "$sandbox"

setup_repos
seed_remote_badge_branch badges coverage-csharp.json
run '[{"slug":"csharp","label":"C#","percent":42}]' '[]' badges
check_rc "existing badge branch exit 0" 0 "$rc"
check "existing badge branch keeps single file" \
  "coverage-csharp.json" "$(badge_branch_files badges)"
check_contains "existing badge branch content updated" '"message": "42%"' \
  "$(git -C "$origin" show badges:coverage-csharp.json)"
check "existing badge branch fast-forwards to two commits" 2 \
  "$(git -C "$origin" rev-list --count refs/heads/badges)"
rm -rf "$sandbox"

setup_repos
seed_remote_badge_branch badges coverage-csharp.json
git -C "$work" remote set-url origin "$sandbox/does-not-exist.git"
run '[{"slug":"csharp","label":"C#","percent":42}]' '[]' badges
check_rc "unreachable origin exit non-zero" 128 "$rc"
check_contains "unreachable origin annotated" \
  "::error::git ls-remote for refs/heads/badges failed with exit code 128" "$err"
rm -rf "$sandbox"

setup_repos
run '[{"slug":"csharp","label":"C#","percent":91}]' '[]' badges
run '[{"slug":"csharp","label":"C#","percent":91}]' '[]' badges
check_rc "unchanged rerun exit 0" 0 "$rc"
check_contains "unchanged rerun skips commit" "badges unchanged; skipping commit" "$out"
check "unchanged rerun keeps single commit" 1 \
  "$(git -C "$origin" rev-list --count refs/heads/badges)"
rm -rf "$sandbox"

exit $fail
