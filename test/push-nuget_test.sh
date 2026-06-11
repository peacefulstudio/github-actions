#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../scripts/push-nuget.sh"

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

make_pkgs() {
  local d="$1"; shift
  mkdir -p "$d"
  for n in "$@"; do : > "$d/$n"; done
}

stub="$here/_stub_push.sh"
cat > "$stub" <<'STUB'
#!/usr/bin/env bash
pkg="$1"; shift
key=""
src=""
skip=0
while [ $# -gt 0 ]; do
  if [ "$1" = "--api-key" ]; then key="$2"; fi
  if [ "$1" = "--source" ]; then src="$2"; fi
  if [ "$1" = "--skip-duplicate" ]; then skip=1; fi
  shift
done
base="$(basename "$pkg")"
echo "PUSH $base key=$key src=$src skip=$skip" >> "$PUSH_LOG"
if [ -n "${STUB_FAIL_MATCH:-}" ] && [[ "$base" == *"$STUB_FAIL_MATCH"* ]]; then
  exit 1
fi
STUB
chmod +x "$stub"

work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg Daml.Lib.2.0.0.nupkg Splice.Api.3.0.0.nupkg Peaceful.Tool.4.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
out="$(NUGET_PUSH="$stub" NUGET_API_KEY=kT bash "$script" "$work")"
rc=$?
set -e
check "all-pushed exit 0" 0 "$rc"
check "push count" 4 "$(wc -l < "$PUSH_LOG" | tr -d ' ')"
check "Canton key+skip" "PUSH Canton.Core.1.0.0.nupkg key=kT src=https://api.nuget.org/v3/index.json skip=1" "$(grep 'Canton.Core' "$PUSH_LOG")"
check "Daml key+skip" "PUSH Daml.Lib.2.0.0.nupkg key=kT src=https://api.nuget.org/v3/index.json skip=1" "$(grep 'Daml.Lib' "$PUSH_LOG")"
check "Splice key+skip" "PUSH Splice.Api.3.0.0.nupkg key=kT src=https://api.nuget.org/v3/index.json skip=1" "$(grep 'Splice.Api' "$PUSH_LOG")"
check "Peaceful key+skip" "PUSH Peaceful.Tool.4.0.0.nupkg key=kT src=https://api.nuget.org/v3/index.json skip=1" "$(grep 'Peaceful.Tool' "$PUSH_LOG")"
check "pushing line echoed" "pushing Canton.Core.1.0.0.nupkg" "$(echo "$out" | grep 'Canton.Core')"

work="$(mktemp -d)"
set +e
NUGET_PUSH="$stub" NUGET_API_KEY=kT bash "$script" "$work" >/dev/null 2>&1
rc=$?
set -e
check "empty dir exit 1" 1 "$rc"

work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
NUGET_PUSH="$stub" bash "$script" "$work" >/dev/null 2>&1
rc=$?
set -e
check "missing-key exit 1" 1 "$rc"
check "missing-key pushes nothing" "" "$(cat "$PUSH_LOG")"

set +e
NUGET_PUSH="$stub" NUGET_API_KEY=kT bash "$script" >/dev/null 2>&1
rc=$?
set -e
check "no-args exit 1" 1 "$rc"

work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
NUGET_PUSH="$stub" NUGET_API_KEY=kT NUGET_SOURCE="https://internal.feed/v3/index.json" bash "$script" "$work" >/dev/null
rc=$?
set -e
check "source-override exit 0" 0 "$rc"
check "source-override url" "PUSH Canton.Core.1.0.0.nupkg key=kT src=https://internal.feed/v3/index.json skip=1" "$(cat "$PUSH_LOG")"

work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg Daml.Lib.2.0.0.nupkg Splice.Api.3.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
STUB_FAIL_MATCH=Daml NUGET_PUSH="$stub" NUGET_API_KEY=kT bash "$script" "$work" >/dev/null 2>&1
rc=$?
set -e
check "push-failure exit 1" 1 "$rc"
check "push-failure aborts loop" "" "$(grep 'Splice.Api' "$PUSH_LOG")"

exit $fail
