#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../scripts/route-nuget-push.sh"

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
echo "PUSH $(basename "$pkg") key=$key src=$src skip=$skip" >> "$PUSH_LOG"
STUB
chmod +x "$stub"

work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg Daml.Lib.2.0.0.nupkg Splice.Api.3.0.0.nupkg Peaceful.Tool.4.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
out="$(NUGET_PUSH="$stub" NUGET_API_KEY_CANTON=kC NUGET_API_KEY_DAML=kD NUGET_API_KEY_SPLICE=kS NUGET_API_KEY_PEACEFUL=kP bash "$script" "$work")"
rc=$?
set -e
check "all-matched exit 0" 0 "$rc"
check "Canton routed" "Canton.Core.1.0.0.nupkg -> Canton" "$(echo "$out" | grep 'Canton.Core')"
check "Canton key" "PUSH Canton.Core.1.0.0.nupkg key=kC src=https://api.nuget.org/v3/index.json skip=1" "$(grep 'Canton.Core' "$PUSH_LOG")"
check "Daml key" "PUSH Daml.Lib.2.0.0.nupkg key=kD src=https://api.nuget.org/v3/index.json skip=1" "$(grep 'Daml.Lib' "$PUSH_LOG")"
check "Splice key" "PUSH Splice.Api.3.0.0.nupkg key=kS src=https://api.nuget.org/v3/index.json skip=1" "$(grep 'Splice.Api' "$PUSH_LOG")"
check "Peaceful key" "PUSH Peaceful.Tool.4.0.0.nupkg key=kP src=https://api.nuget.org/v3/index.json skip=1" "$(grep 'Peaceful.Tool' "$PUSH_LOG")"

work="$(mktemp -d)"
make_pkgs "$work" canton.core.1.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
out="$(NUGET_PUSH="$stub" NUGET_API_KEY_CANTON=kC bash "$script" "$work")"
rc=$?
set -e
check "lowercase canton routed" "canton.core.1.0.0.nupkg -> Canton" "$(echo "$out" | grep -i canton)"
check "lowercase canton key" "PUSH canton.core.1.0.0.nupkg key=kC src=https://api.nuget.org/v3/index.json skip=1" "$(grep -i canton "$PUSH_LOG")"

work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg Unknown.Pkg.1.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
NUGET_PUSH="$stub" NUGET_API_KEY_CANTON=kC bash "$script" "$work" >/dev/null 2>&1
rc=$?
set -e
check "unmatched exit 1" 1 "$rc"
check "unmatched pushes nothing" "" "$(cat "$PUSH_LOG")"

work="$(mktemp -d)"
set +e
NUGET_PUSH="$stub" bash "$script" "$work" >/dev/null 2>&1
rc=$?
set -e
check "empty dir exit 1" 1 "$rc"

work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg Canton.Extras.1.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
NUGET_PUSH="$stub" NUGET_API_KEY_CANTON=kC bash "$script" "$work" >/dev/null
rc=$?
set -e
check "same-owner exit 0" 0 "$rc"
check "same-owner core pushed" "PUSH Canton.Core.1.0.0.nupkg key=kC src=https://api.nuget.org/v3/index.json skip=1" "$(grep 'Canton.Core' "$PUSH_LOG")"
check "same-owner extras pushed" "PUSH Canton.Extras.1.0.0.nupkg key=kC src=https://api.nuget.org/v3/index.json skip=1" "$(grep 'Canton.Extras' "$PUSH_LOG")"

work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
NUGET_PUSH="$stub" bash "$script" "$work" >/dev/null 2>&1
rc=$?
set -e
check "missing-key exit 1" 1 "$rc"
check "missing-key pushes nothing" "" "$(cat "$PUSH_LOG")"

work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg Unknown.Pkg.1.0.0.nupkg Daml.Lib.2.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
NUGET_PUSH="$stub" NUGET_API_KEY_CANTON=kC bash "$script" "$work" >/dev/null 2>&1
rc=$?
set -e
check "mixed-failure exit 1" 1 "$rc"
check "mixed-failure pushes nothing" "" "$(cat "$PUSH_LOG")"

set +e
bash "$script" >/dev/null 2>&1
rc=$?
set -e
check "no-args exit 1" 1 "$rc"

work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
NUGET_PUSH="$stub" NUGET_API_KEY_CANTON=kC NUGET_SOURCE="https://internal.feed/v3/index.json" bash "$script" "$work" >/dev/null
rc=$?
set -e
check "source-override exit 0" 0 "$rc"
check "source-override url" "PUSH Canton.Core.1.0.0.nupkg key=kC src=https://internal.feed/v3/index.json skip=1" "$(cat "$PUSH_LOG")"

exit $fail
