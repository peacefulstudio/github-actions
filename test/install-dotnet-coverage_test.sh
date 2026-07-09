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

stub="$here/_stub_dotnet.sh"
cat > "$stub" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = "tool" ] && [ "$2" = "list" ]; then
  echo "Package Id      Version      Commands"
  echo "-----------------------------------------"
  if [ -n "${STUB_INSTALLED_VERSION:-}" ]; then
    echo "dotnet-coverage      $STUB_INSTALLED_VERSION      dotnet-coverage"
  fi
  exit 0
fi
if [ "$1" = "tool" ] && [ "$2" = "uninstall" ]; then
  echo "UNINSTALL" >> "$CALL_LOG"
  exit 0
fi
if [ "$1" = "tool" ] && [ "$2" = "install" ]; then
  shift 2
  ver=""
  while [ $# -gt 0 ]; do
    if [ "$1" = "--version" ]; then ver="$2"; fi
    shift
  done
  echo "INSTALL $ver" >> "$CALL_LOG"
  exit 0
fi
echo "unexpected dotnet invocation: $*" >&2
exit 1
STUB
chmod +x "$stub"

work="$(mktemp -d)"
export CALL_LOG="$work/calls.log"

# Not installed at all — the common fresh-runner case.
: > "$CALL_LOG"
set +e
out="$(STUB_INSTALLED_VERSION= DOTNET_BIN="$stub" bash "$script" 18.8.0)"
rc=$?
set -e
check "not-installed exit 0" 0 "$rc"
check "not-installed calls" "INSTALL 18.8.0" "$(cat "$CALL_LOG")"

# Installed at an older version — the ordinary update case.
: > "$CALL_LOG"
set +e
STUB_INSTALLED_VERSION=18.7.0 DOTNET_BIN="$stub" bash "$script" 18.8.0 >/dev/null
rc=$?
set -e
check "older-installed exit 0" 0 "$rc"
check "older-installed calls" "$(printf 'UNINSTALL\nINSTALL 18.8.0')" "$(cat "$CALL_LOG")"

# Installed at a NEWER version than the pin — the actual regression this
# script exists to fix (`dotnet tool update` refuses to downgrade and fails
# outright here; a shared self-hosted runner can easily end up in this state
# because a different caller's pin installed a newer version first).
: > "$CALL_LOG"
set +e
STUB_INSTALLED_VERSION=18.9.0 DOTNET_BIN="$stub" bash "$script" 18.8.0 >/dev/null
rc=$?
set -e
check "newer-installed exit 0" 0 "$rc"
check "newer-installed calls" "$(printf 'UNINSTALL\nINSTALL 18.8.0')" "$(cat "$CALL_LOG")"

# Already at the exact pinned version — should be a pure no-op, no reinstall.
: > "$CALL_LOG"
set +e
out="$(STUB_INSTALLED_VERSION=18.8.0 DOTNET_BIN="$stub" bash "$script" 18.8.0)"
rc=$?
set -e
check "already-current exit 0" 0 "$rc"
check "already-current calls nothing" "" "$(cat "$CALL_LOG")"
check "already-current message" "dotnet-coverage 18.8.0 already installed" "$out"

# No version argument — usage error.
set +e
DOTNET_BIN="$stub" bash "$script" >/dev/null 2>&1
rc=$?
set -e
check "no-args exit 1" 1 "$rc"

exit $fail
