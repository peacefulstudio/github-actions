#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../scripts/install-dotnet-coverage.sh"

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

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

stub="$work/stub_dotnet.sh"
cat > "$stub" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$CALL_LOG"
exit "${STUB_EXIT_CODE:-0}"
STUB
chmod +x "$stub"

export CALL_LOG="$work/calls.log"
runner_temp="$work/runner-temp"
github_path="$work/github-path"
mkdir -p "$runner_temp"

run_script() {
  : > "$CALL_LOG"
  : > "$github_path"
  set +e
  RUNNER_TEMP="$runner_temp" GITHUB_PATH="$github_path" DOTNET_BIN="$stub" bash "$script" "$@" >/dev/null 2>&1
  rc=$?
  set -e
}

run_script 18.11.2
check "install exit 0" 0 "$rc"
check "installs the pinned version into a job-private tool path, never globally" \
  "tool install dotnet-coverage --version 18.11.2 --tool-path $runner_temp/dotnet-coverage-18.11.2" \
  "$(cat "$CALL_LOG")"
check "puts the job-private tool path on GITHUB_PATH" \
  "$runner_temp/dotnet-coverage-18.11.2" \
  "$(cat "$github_path")"

run_script 18.11.0
check "a different pin gets its own tool path" \
  "tool install dotnet-coverage --version 18.11.0 --tool-path $runner_temp/dotnet-coverage-18.11.0" \
  "$(cat "$CALL_LOG")"

STUB_EXIT_CODE=1 run_script 18.11.2
check "install failure exits non-zero" 1 "$rc"
check "install failure leaves GITHUB_PATH untouched" "" "$(cat "$github_path")"

run_script
check "no-args exit 1" 1 "$rc"
check "no-args calls nothing" "" "$(cat "$CALL_LOG")"

: > "$CALL_LOG"
set +e
env -u RUNNER_TEMP GITHUB_PATH="$github_path" DOTNET_BIN="$stub" bash "$script" 18.11.2 >/dev/null 2>&1
rc=$?
set -e
check "missing RUNNER_TEMP exit 1" 1 "$rc"
check "missing RUNNER_TEMP calls nothing" "" "$(cat "$CALL_LOG")"

exit $fail
