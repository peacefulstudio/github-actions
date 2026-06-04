#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../scripts/route-nuget-push.sh"

fail=0
check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then
    echo "ok   - $1"
  else
    echo "FAIL - $1: expected [$2] got [$3]"
    fail=1
  fi
}

make_pkgs() { # make_pkgs <dir> <name...>
  local d="$1"; shift
  mkdir -p "$d"
  for n in "$@"; do : > "$d/$n"; done
}

stub="$here/_stub_push.sh"
cat > "$stub" <<'STUB'
#!/usr/bin/env bash
pkg="$1"; shift
key=""
while [ $# -gt 0 ]; do
  if [ "$1" = "--api-key" ]; then key="$2"; fi
  shift
done
echo "PUSH $(basename "$pkg") key=$key" >> "$PUSH_LOG"
STUB
chmod +x "$stub"

# Case 1: all four prefixes route to the right owner key
work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg Daml.Lib.2.0.0.nupkg Splice.Api.3.0.0.nupkg Peaceful.Tool.4.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
out="$(NUGET_PUSH="$stub" NUGET_API_KEY_CANTON=kC NUGET_API_KEY_DAML=kD NUGET_API_KEY_SPLICE=kS NUGET_API_KEY_PEACEFUL=kP bash "$script" "$work")"
rc=$?
set -e
check "all-matched exit 0" 0 "$rc"
check "Canton routed" "Canton.Core.1.0.0.nupkg -> Canton" "$(echo "$out" | grep 'Canton.Core')"
check "Canton key" "PUSH Canton.Core.1.0.0.nupkg key=kC" "$(grep 'Canton.Core' "$PUSH_LOG")"
check "Daml key" "PUSH Daml.Lib.2.0.0.nupkg key=kD" "$(grep 'Daml.Lib' "$PUSH_LOG")"
check "Splice key" "PUSH Splice.Api.3.0.0.nupkg key=kS" "$(grep 'Splice.Api' "$PUSH_LOG")"
check "Peaceful key" "PUSH Peaceful.Tool.4.0.0.nupkg key=kP" "$(grep 'Peaceful.Tool' "$PUSH_LOG")"

# Case 2: case-insensitive prefix
work="$(mktemp -d)"
make_pkgs "$work" canton.core.1.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
out="$(NUGET_PUSH="$stub" NUGET_API_KEY_CANTON=kC bash "$script" "$work")"
rc=$?
set -e
check "lowercase canton routed" "canton.core.1.0.0.nupkg -> Canton" "$(echo "$out" | grep -i canton)"
check "lowercase canton key" "PUSH canton.core.1.0.0.nupkg key=kC" "$(grep -i canton "$PUSH_LOG")"

# Case 3: unmatched package fails the job and pushes NOTHING
work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg Unknown.Pkg.1.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
NUGET_PUSH="$stub" NUGET_API_KEY_CANTON=kC bash "$script" "$work" >/dev/null 2>&1
rc=$?
set -e
check "unmatched exit 1" 1 "$rc"
check "unmatched pushes nothing" "" "$(cat "$PUSH_LOG")"

# Case 4: empty directory fails
work="$(mktemp -d)"
set +e
NUGET_PUSH="$stub" bash "$script" "$work" >/dev/null 2>&1
rc=$?
set -e
check "empty dir exit 1" 1 "$rc"

# Case 5: multiple packages for the same owner both push
work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg Canton.Extras.1.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
NUGET_PUSH="$stub" NUGET_API_KEY_CANTON=kC bash "$script" "$work" >/dev/null
rc=$?
set -e
check "same-owner exit 0" 0 "$rc"
check "same-owner core pushed" "PUSH Canton.Core.1.0.0.nupkg key=kC" "$(grep 'Canton.Core' "$PUSH_LOG")"
check "same-owner extras pushed" "PUSH Canton.Extras.1.0.0.nupkg key=kC" "$(grep 'Canton.Extras' "$PUSH_LOG")"

# Case 6: matched owner with unset key fails before pushing anything
work="$(mktemp -d)"
make_pkgs "$work" Canton.Core.1.0.0.nupkg
export PUSH_LOG="$work/push.log"; : > "$PUSH_LOG"
set +e
NUGET_PUSH="$stub" bash "$script" "$work" >/dev/null 2>&1
rc=$?
set -e
check "missing-key exit 1" 1 "$rc"
check "missing-key pushes nothing" "" "$(cat "$PUSH_LOG")"

exit $fail
