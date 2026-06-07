#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

runs_on="${1:-}"
visibility="${2:-}"

if [ -n "$runs_on" ]; then
  printf '%s\n' "$runs_on"
  exit 0
fi

case "$visibility" in
  public)
    printf '%s\n' 'ubuntu-latest'
    ;;
  private|internal)
    printf '%s\n' '["self-hosted", "hetzner"]'
    ;;
  '')
    echo "::error::no runner source provided: pass a non-empty runs-on or repository visibility" >&2
    exit 1
    ;;
  *)
    echo "::error::unexpected repo visibility '$visibility' (expected public, private, or internal)" >&2
    exit 1
    ;;
esac
