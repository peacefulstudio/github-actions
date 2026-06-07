#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../scripts/resolve-runner.sh"

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

run "hetzner" ""
check_rc "explicit plain label exit 0" 0 "$rc"
check "explicit plain label passthrough" "hetzner" "$out"

run '["self-hosted", "hetzner"]' ""
check_rc "explicit array label exit 0" 0 "$rc"
check "explicit array label passthrough" '["self-hosted", "hetzner"]' "$out"

run '["self-hosted", "hetzner"]' "public"
check_rc "explicit wins over visibility exit 0" 0 "$rc"
check "explicit wins over visibility" '["self-hosted", "hetzner"]' "$out"

run "" "public"
check_rc "public visibility exit 0" 0 "$rc"
check "public visibility default" "ubuntu-latest" "$out"

run "" "private"
check_rc "private visibility exit 0" 0 "$rc"
check "private visibility default" '["self-hosted", "hetzner"]' "$out"

run "" "internal"
check_rc "internal visibility exit 0" 0 "$rc"
check "internal treated as private" '["self-hosted", "hetzner"]' "$out"

run "" "private"
check "private default is a JSON array starting with [" "[" "$(printf '%s' "$out" | cut -c1)"
check "private default round-trips through jq" '["self-hosted","hetzner"]' "$(jq -cS . <<<"$out")"

run "" ""
check_rc "no source exit 1" 1 "$rc"
check_contains "no source annotated" "no runner source provided" "$err"

run "" "bogus"
check_rc "unexpected visibility exit 1" 1 "$rc"
check_contains "unexpected visibility annotated" "unexpected repo visibility 'bogus'" "$err"

run "" "Public"
check_rc "visibility is case-sensitive exit 1" 1 "$rc"

exit "$fail"
