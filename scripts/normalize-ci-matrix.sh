#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

build_matrix="${1:-}"
os_list="${2:-}"
visibility="${3:-}"
matrix_mode="${4:-}"

public_default='[{"name":"ubuntu-latest","runner":"ubuntu-latest","coverage":true},{"name":"windows-latest","runner":"windows-latest","coverage":false},{"name":"macos-latest","runner":"macos-latest","coverage":false}]'
private_default='[{"name":"linux","runner":["self-hosted","hetzner"],"coverage":true}]'

case "$(printf '%s' "$matrix_mode" | tr '[:upper:]' '[:lower:]')" in
  cheap)
    build_matrix="$private_default"
    os_list=""
    visibility=""
    ;;
  ""|full) ;;
  *)
    echo "::error::unexpected matrix-mode '$matrix_mode' (expected cheap, full, or empty)" >&2
    exit 1
    ;;
esac

transform() {
  local program="$1" input="$2" what="$3"
  local errfile out
  errfile=$(mktemp)
  if out=$(jq -ceS "$program" <<<"$input" 2>"$errfile"); then
    rm -f "$errfile"
    printf '%s' "$out"
  else
    local msg
    msg=$(tr '\n' ' ' <"$errfile" | sed -e 's/jq: error ([^)]*): //g' -e 's/jq: //g' -e 's/  */ /g')
    rm -f "$errfile"
    echo "::error::invalid $what: ${msg}" >&2
    return 1
  fi
}

if [ -z "$build_matrix" ] && [ -z "$os_list" ] && [ -n "$visibility" ]; then
  case "$visibility" in
    public)            build_matrix="$public_default" ;;
    private|internal)  build_matrix="$private_default" ;;
    *)
      echo "::error::unexpected repo visibility '$visibility' (expected public, private, or internal)" >&2
      exit 1
      ;;
  esac
fi

if [ -z "$build_matrix" ] && [ -z "$os_list" ]; then
  echo "::error::no matrix source provided: pass a non-empty build-matrix, os-list, or visibility" >&2
  exit 1
fi

if [ -n "$build_matrix" ]; then
  # shellcheck disable=SC2016  # the single-quoted argument is a jq program; $-tokens are jq syntax, not shell expansions
  matrix=$(transform '
    if type != "array" then error("build-matrix must be a JSON array") else . end
    | [ .[]
        | { name: (
              if (.name | type) == "string" and .name != "" then .name
              else error("build-matrix entry requires a non-empty string \"name\"") end),
            runner: (
              if (.runner | type) == "string" and .runner != "" then .runner
              elif (.runner | type) == "array" and (.runner | length) > 0 and all(.runner[]; type == "string" and . != "") then .runner
              else error("build-matrix entry requires \"runner\" as a non-empty label string or array of non-empty label strings") end),
            coverage: (
              if has("coverage")
              then (if (.coverage | type) == "boolean" then .coverage else error("build-matrix entry \"coverage\" must be a boolean") end)
              else false
              end) } ]
  ' "$build_matrix" "build-matrix") || exit 1
else
  # shellcheck disable=SC2016  # the single-quoted argument is a jq program; $-tokens are jq syntax, not shell expansions
  matrix=$(transform '
    if type != "array" then error("os-list must be a JSON array") else . end
    | [ .[]
        | (if type == "string" and . != "" then . else error("os-list entries must be non-empty runner-label strings") end) as $os
        | { name: $os, runner: $os, coverage: ($os == "ubuntu-latest") } ]
  ' "$os_list" "os-list") || exit 1
fi

if [ "$(jq 'length' <<<"$matrix")" -eq 0 ]; then
  echo "::error::resolved CI matrix is empty; supply a non-empty build-matrix or os-list" >&2
  exit 1
fi

coverage_count=$(jq '[ .[] | select(.coverage) ] | length' <<<"$matrix")
if [ "$coverage_count" -gt 1 ]; then
  echo "::error::CI matrix has $coverage_count coverage shards; at most one entry may set coverage:true (more would race the merged report and duplicate the sticky PR comment)" >&2
  exit 1
fi

printf '%s\n' "$matrix"
