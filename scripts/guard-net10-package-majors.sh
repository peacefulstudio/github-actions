#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for tool in jq dotnet; do
  if ! command -v "$tool" > /dev/null; then
    echo "::error::the net10.0 package guard needs '$tool' on the runner PATH"
    exit 3
  fi
done

# jq.exe and dotnet.exe print CRLF line endings under Git Bash on Windows (jq 1.7.1, windows-latest), which leaves a trailing \r on every captured value
strip_cr() { tr -d '\r'; }
jq_clean() { jq "$@" | strip_cr; }

filter="$(strip_cr < "$here/net10-package-majors.jq")"

entries="$(printf '%s' "${NET10_PACKAGE_EXCEPTIONS:-}" | tr ',[:space:]' '\n' | sed '/^$/d')"
malformed="$(grep -Ev '^[A-Za-z0-9][A-Za-z0-9._-]*@[1-9][0-9]*$' <<< "$entries" || true)"
if [ -n "$malformed" ]; then
  echo "::error::net10-package-exceptions entries must look like package@major, got: $(paste -sd ' ' - <<< "$malformed")"
  exit 2
fi
allowed="$(printf '%s\n' "$entries" | jq_clean -R -s 'split("\n") | map(select(length > 0) | ascii_downcase)')"

failed=0
checked=0
while IFS= read -r project; do
  [ -n "$project" ] || continue
  display="${project#./}"
  properties="$(dotnet msbuild "$project" -nologo -property:Configuration=Release -getProperty:IsPackable -getProperty:TargetFramework -getProperty:TargetFrameworks -getProperty:ProjectAssetsFile -getProperty:MSBuildProjectExtensionsPath | strip_cr)"
  packable="$(jq_clean -r '.Properties.IsPackable | ascii_downcase' <<< "$properties")"
  frameworks=";$(jq_clean -r '.Properties.TargetFrameworks + ";" + .Properties.TargetFramework' <<< "$properties" | tr -d '[:space:]');"
  assets="$(jq_clean -r '.Properties.ProjectAssetsFile' <<< "$properties")"
  if [ -z "$assets" ]; then
    assets="$(jq_clean -r '.Properties.MSBuildProjectExtensionsPath' <<< "$properties")project.assets.json"
  fi
  if [ "$packable" != "true" ] || ! grep -Eqi ';net10\.0(-[^;]*)?;' <<< "$frameworks"; then
    continue
  fi
  if command -v cygpath > /dev/null; then
    assets="$(cygpath -u "$assets")"
  fi
  if [ ! -f "$assets" ]; then
    echo "::warning::$display is packable for net10.0 but has no restore assets at $assets, so its package versions were not checked"
    continue
  fi
  checked=$((checked + 1))
  findings="$(jq_clean -r --argjson allowed "$allowed" "$filter" < "$assets" | sort -u | paste -sd ';' - | sed 's/;/; /g')"
  if [ -n "$findings" ]; then
    echo "::error::$display resolves $findings for its net10.0 target. A net10.0 package must not require Microsoft.Extensions or Microsoft.AspNetCore 11 or later; pin it to 10.x, or accept it with the net10-package-exceptions input."
    failed=1
  fi
done < <(find . \( -name obj -o -name bin -o -name node_modules -o -name .git -o -name .github-actions-helpers \) -prune -o \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) -print | sort)
echo "net10.0 package guard: checked $checked packable project(s)"
exit "$failed"
