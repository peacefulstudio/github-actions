#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../scripts/normalize-ci-matrix.sh"

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

run() {
  local errf; errf="$(mktemp)"
  set +e
  out="$(bash "$script" "$@" 2>"$errf")"
  rc=$?
  set -e
  err="$(cat "$errf")"; rm -f "$errf"
}

run "" '["ubuntu-latest"]'
check_rc "os-list single exit 0" 0 "$rc"
check "os-list single back-compat" \
  '[{"coverage":true,"name":"ubuntu-latest","runner":"ubuntu-latest"}]' "$out"

run "" '["ubuntu-latest","macos-latest","windows-latest"]'
check_rc "os-list three exit 0" 0 "$rc"
check "os-list three back-compat" \
  '[{"coverage":true,"name":"ubuntu-latest","runner":"ubuntu-latest"},{"coverage":false,"name":"macos-latest","runner":"macos-latest"},{"coverage":false,"name":"windows-latest","runner":"windows-latest"}]' \
  "$out"

run "" '["macos-latest"]'
check_rc "os-list no-ubuntu exit 0" 0 "$rc"
check "os-list no-ubuntu has no coverage shard" \
  '[{"coverage":false,"name":"macos-latest","runner":"macos-latest"}]' "$out"

run '[{"name":"linux-amd64","runner":["self-hosted","hetzner"],"coverage":true},{"name":"linux-arm64","runner":"ubuntu-24.04-arm"},{"name":"win","runner":"windows-latest","coverage":false}]' '["ubuntu-latest"]'
check_rc "build-matrix wins over os-list, exit 0" 0 "$rc"
check "build-matrix array runner + coverage default" \
  '[{"coverage":true,"name":"linux-amd64","runner":["self-hosted","hetzner"]},{"coverage":false,"name":"linux-arm64","runner":"ubuntu-24.04-arm"},{"coverage":false,"name":"win","runner":"windows-latest"}]' \
  "$out"

run '[{"name":"a","runner":"x","coverage":false},{"name":"b","runner":"y","coverage":false}]' ''
check_rc "zero coverage shards allowed exit 0" 0 "$rc"

run '[{"name":"a","runner":"ubuntu-latest","coverage":true},{"name":"b","runner":"macos-latest","coverage":true}]' ''
check_rc "two coverage shards exit 1" 1 "$rc"
check_contains "two coverage shards annotated" "::error::CI matrix has 2 coverage shards" "$err"

run '[]' ''
check_rc "empty build-matrix exit 1" 1 "$rc"

run "" '[]'
check_rc "empty os-list exit 1" 1 "$rc"

run '[{"runner":"ubuntu-latest"}]' ''
check_rc "missing name exit 1" 1 "$rc"

run '[{"name":"a"}]' ''
check_rc "missing runner exit 1" 1 "$rc"

run '[{"name":"","runner":"ubuntu-latest"}]' ''
check_rc "empty-string name exit 1" 1 "$rc"

run '[{"name":"a","runner":""}]' ''
check_rc "empty-string runner exit 1" 1 "$rc"

run '[{"name":"a","runner":[]}]' ''
check_rc "empty-array runner exit 1" 1 "$rc"

run '[{"name":"a","runner":["",  "hetzner"]}]' ''
check_rc "runner array with empty element exit 1" 1 "$rc"

run "" '[123]'
check_rc "os-list non-string element exit 1" 1 "$rc"
check_contains "os-list non-string annotated" "::error::invalid os-list" "$err"

run "" '[""]'
check_rc "os-list empty-string element exit 1" 1 "$rc"

run "" ""
check_rc "no source provided exit 1" 1 "$rc"
check_contains "no source annotated" "::error::no matrix source provided" "$err"

run '[bad' '["ubuntu-latest"]'
check_rc "malformed build-matrix does not fall back to os-list" 1 "$rc"
check_contains "malformed build-matrix annotated" "::error::invalid build-matrix" "$err"

run '[{"name":"a","runner":"ubuntu-latest","coverage":"yes"}]' ''
check_rc "non-boolean coverage exit 1" 1 "$rc"

run '[{"name":"a","runner":"ubuntu-latest"' ''
check_rc "invalid json exit 1" 1 "$rc"

run "" "" "public"
check_rc "public visibility default exit 0" 0 "$rc"
check "public visibility 3-shard matrix" \
  '[{"coverage":true,"name":"ubuntu-latest","runner":"ubuntu-latest"},{"coverage":false,"name":"windows-latest","runner":"windows-latest"},{"coverage":false,"name":"macos-latest","runner":"macos-latest"}]' \
  "$out"

run "" "" "private"
check_rc "private visibility default exit 0" 0 "$rc"
check "private visibility single hetzner shard" \
  '[{"coverage":true,"name":"linux","runner":["self-hosted","hetzner"]}]' "$out"

run "" "" "internal"
check_rc "internal visibility default exit 0" 0 "$rc"
check "internal treated as private" \
  '[{"coverage":true,"name":"linux","runner":["self-hosted","hetzner"]}]' "$out"

run "" '["ubuntu-latest"]' "private"
check_rc "explicit os-list wins over visibility exit 0" 0 "$rc"
check "explicit os-list wins over visibility" \
  '[{"coverage":true,"name":"ubuntu-latest","runner":"ubuntu-latest"}]' "$out"

run '[{"name":"a","runner":"x","coverage":false}]' '' "public"
check_rc "explicit build-matrix wins over visibility exit 0" 0 "$rc"
check "explicit build-matrix wins over visibility" \
  '[{"coverage":false,"name":"a","runner":"x"}]' "$out"

run "" "" "bogus"
check_rc "unexpected visibility exit 1" 1 "$rc"
check_contains "unexpected visibility annotated" "::error::unexpected repo visibility 'bogus'" "$err"

hetzner_leg='[{"coverage":true,"name":"linux","runner":["self-hosted","hetzner"]}]'
public_default='[{"coverage":true,"name":"ubuntu-latest","runner":"ubuntu-latest"},{"coverage":false,"name":"windows-latest","runner":"windows-latest"},{"coverage":false,"name":"macos-latest","runner":"macos-latest"}]'

run '[{"name":"a","runner":"ubuntu-latest","coverage":true}]' '["windows-latest"]' "private" "cheap"
check_rc "cheap overrides explicit build-matrix exit 0" 0 "$rc"
check "cheap overrides explicit build-matrix" "$hetzner_leg" "$out"

run "" "" "internal" "cheap"
check_rc "cheap on internal repo exit 0" 0 "$rc"
check "cheap on internal resolves hetzner leg" "$hetzner_leg" "$out"

run "" "" "" "cheap"
check_rc "cheap ignores empty visibility exit 0" 0 "$rc"
check "cheap with no other source still resolves hetzner leg" "$hetzner_leg" "$out"

run "" "" "private" "CHEAP"
check_rc "cheap is case-insensitive exit 0" 0 "$rc"
check "cheap is case-insensitive" "$hetzner_leg" "$out"

run "" "" "public" "cheap"
check_rc "cheap ignored on public repo exit 0" 0 "$rc"
check "cheap ignored on public falls back to public default" "$public_default" "$out"
check_contains "cheap ignored on public warns" "::warning::matrix-mode=cheap ignored on public repo" "$err"

run '[{"name":"a","runner":"ubuntu-latest","coverage":true}]' "" "public" "cheap"
check_rc "cheap on public keeps explicit build-matrix exit 0" 0 "$rc"
check "cheap on public keeps explicit build-matrix" '[{"coverage":true,"name":"a","runner":"ubuntu-latest"}]' "$out"

run "" "" "public" "full"
check_rc "full preserves visibility default exit 0" 0 "$rc"
check "full preserves public visibility default" \
  '[{"coverage":true,"name":"ubuntu-latest","runner":"ubuntu-latest"},{"coverage":false,"name":"windows-latest","runner":"windows-latest"},{"coverage":false,"name":"macos-latest","runner":"macos-latest"}]' \
  "$out"

run "" '["macos-latest"]' "" ""
check_rc "empty mode preserves os-list behaviour exit 0" 0 "$rc"
check "empty mode preserves os-list behaviour" \
  '[{"coverage":false,"name":"macos-latest","runner":"macos-latest"}]' "$out"

run "" "" "public" "bogus"
check_rc "unknown matrix-mode exit 1" 1 "$rc"
check_contains "unknown matrix-mode annotated" "::error::unexpected matrix-mode 'bogus'" "$err"

exit $fail
