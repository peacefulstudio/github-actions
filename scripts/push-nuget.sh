#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

nupkg_dir="${1:?usage: push-nuget.sh <nupkg-dir>}"
nuget_source="${NUGET_SOURCE:-https://api.nuget.org/v3/index.json}"
push_cmd="${NUGET_PUSH:-dotnet nuget push}"

if [ -z "${NUGET_API_KEY:-}" ]; then
  echo "::error::NUGET_API_KEY is unset; cannot push to nuget.org" >&2
  exit 1
fi

shopt -s nullglob
packages=("$nupkg_dir"/*.nupkg)
if [ "${#packages[@]}" -eq 0 ]; then
  echo "::error::no .nupkg files found in $nupkg_dir" >&2
  exit 1
fi

for pkg in "${packages[@]}"; do
  base="$(basename "$pkg")"
  echo "pushing $base"
  if ! $push_cmd "$pkg" --source "$nuget_source" --api-key "$NUGET_API_KEY" --skip-duplicate; then
    echo "::error::push failed for '$base'" >&2
    exit 1
  fi
done
