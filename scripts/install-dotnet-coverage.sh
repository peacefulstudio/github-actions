#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

version="${1:?usage: install-dotnet-coverage.sh <version>}"
dotnet_bin="${DOTNET_BIN:-dotnet}"
job_tool_path="${RUNNER_TEMP:?RUNNER_TEMP must be set}/dotnet-coverage-${version}"
github_path_file="${GITHUB_PATH:?GITHUB_PATH must be set}"

"$dotnet_bin" tool install dotnet-coverage --version "$version" --tool-path "$job_tool_path"
echo "$job_tool_path" >> "$github_path_file"
echo "dotnet-coverage $version installed to $job_tool_path"
