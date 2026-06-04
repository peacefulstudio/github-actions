#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

# route-nuget-push.sh — push each .nupkg in a directory to nuget.org using the
# owner API key selected by the package-ID prefix (case-insensitive). Resolves
# every package's owner first; if any package is unmatched, the job fails before
# any package is pushed, so a release never lands a partial set on nuget.org.
#
# Usage: route-nuget-push.sh <nupkg-dir>
# Env:
#   NUGET_API_KEY_CANTON | _DAML | _SPLICE | _PEACEFUL — per-owner API keys.
#   NUGET_SOURCE — push target (default https://api.nuget.org/v3/index.json).
#   NUGET_PUSH   — push command (default "dotnet nuget push"); tests override it.

nupkg_dir="${1:?usage: route-nuget-push.sh <nupkg-dir>}"
nuget_source="${NUGET_SOURCE:-https://api.nuget.org/v3/index.json}"
push_cmd="${NUGET_PUSH:-dotnet nuget push}"

owner_for() {
  case "$1" in
    canton.*)   echo Canton ;;
    daml.*)     echo Daml ;;
    splice.*)   echo Splice ;;
    peaceful.*) echo Peaceful ;;
    *)          return 1 ;;
  esac
}

key_for() {
  case "$1" in
    Canton)   echo "${NUGET_API_KEY_CANTON:-}" ;;
    Daml)     echo "${NUGET_API_KEY_DAML:-}" ;;
    Splice)   echo "${NUGET_API_KEY_SPLICE:-}" ;;
    Peaceful) echo "${NUGET_API_KEY_PEACEFUL:-}" ;;
    *)        echo "::error::no API key arm for owner '$1' in route-nuget-push.sh" >&2; return 1 ;;
  esac
}

shopt -s nullglob
packages=("$nupkg_dir"/*.nupkg)
if [ "${#packages[@]}" -eq 0 ]; then
  echo "::error::no .nupkg files found in $nupkg_dir" >&2
  exit 1
fi

owners=()
keys=()
unmatched=0
for pkg in "${packages[@]}"; do
  base="$(basename "$pkg")"
  lower="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
  if ! owner="$(owner_for "$lower")"; then
    echo "::error::no nuget.org owner key matches package '$base' — add its prefix to route-nuget-push.sh and provision the secret" >&2
    unmatched=1
    continue
  fi
  if ! key="$(key_for "$owner")" || [ -z "$key" ]; then
    echo "::error::package '$base' routes to owner '$owner' but its API key (NUGET_API_KEY_...) is unset" >&2
    unmatched=1
    continue
  fi
  echo "$base -> $owner"
  owners+=("$owner")
  keys+=("$key")
done

if [ "$unmatched" -ne 0 ]; then
  exit 1
fi

for i in "${!packages[@]}"; do
  $push_cmd "${packages[$i]}" --source "$nuget_source" --api-key "${keys[$i]}" --skip-duplicate
done
