#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

version="${1:?usage: install-dotnet-coverage.sh <version>}"
dotnet_bin="${DOTNET_BIN:-dotnet}"

installed="$("$dotnet_bin" tool list -g | awk '$1 == "dotnet-coverage" {print $2}')"

if [ "$installed" = "$version" ]; then
  echo "dotnet-coverage $version already installed"
  exit 0
fi

if [ -n "$installed" ]; then
  # `dotnet tool update` refuses to move to an older version, so a runner
  # that already carries a newer dotnet-coverage than the caller's pin
  # (shared self-hosted runners accumulate whatever the last caller
  # installed) fails outright instead of matching the pin. Uninstalling
  # first makes this idempotent in both directions.
  echo "dotnet-coverage $installed installed, want $version — reinstalling"
  "$dotnet_bin" tool uninstall -g dotnet-coverage
fi

"$dotnet_bin" tool install -g dotnet-coverage --version "$version"
