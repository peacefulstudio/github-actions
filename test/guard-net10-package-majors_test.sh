#!/usr/bin/env bash
# Copyright (c) 2026 Peaceful Studio OÜ
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../scripts/guard-net10-package-majors.sh"

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

check_contains() {
  local name="$1" needle="$2" hay="$3"
  case "$hay" in
    *"$needle"*) echo "ok   - $name" ;;
    *)
      echo "FAIL - $name: output lacks [$needle]"
      printf '%s\n' "$hay" | sed 's/^/       | /'
      fail=1
      ;;
  esac
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

real_jq="$(command -v jq)"
real_dotnet="$(command -v dotnet)"
crlf_bin="$work/crlf-bin"
mkdir -p "$crlf_bin"
for tool in jq dotnet; do
  real="$real_jq"
  [ "$tool" = dotnet ] && real="$real_dotnet"
  cat > "$crlf_bin/$tool" <<SHIM
#!/usr/bin/env bash
out="\$(mktemp)"
rc=0
"$real" "\$@" > "\$out" || rc=\$?
awk '{ printf "%s\r\n", \$0 }' "\$out"
rm -f "\$out"
exit "\$rc"
SHIM
  chmod +x "$crlf_bin/$tool"
done

new_repo() {
  mktemp -d "$work/repo.XXXXXX"
}

add_project() {
  local repo="$1" name="$2" frameworks="$3" packable="$4" assets="$5"
  mkdir -p "$repo/$name/obj"
  cat > "$repo/$name/$name.csproj" <<XML
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFrameworks>$frameworks</TargetFrameworks>
    <IsPackable>$packable</IsPackable>
  </PropertyGroup>
</Project>
XML
  if [ -n "$assets" ]; then
    printf '%s\n' "$assets" > "$repo/$name/obj/project.assets.json"
  fi
}

add_release_only_packable_project() {
  local repo="$1" name="$2" assets="$3"
  mkdir -p "$repo/$name/obj"
  cat > "$repo/$name/$name.csproj" <<XML
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <IsPackable>false</IsPackable>
    <IsPackable Condition="'\$(Configuration)' == 'Release'">true</IsPackable>
  </PropertyGroup>
</Project>
XML
  printf '%s\n' "$assets" > "$repo/$name/obj/project.assets.json"
}

run_guard() {
  local repo="$1" exceptions="${2:-}" path_prefix="${3:-}" errf
  errf="$(mktemp)"
  set +e
  out="$(cd "$repo" && DOTNET_NOLOGO=true NET10_PACKAGE_EXCEPTIONS="$exceptions" PATH="${path_prefix:+$path_prefix:}$PATH" bash "$script" 2>"$errf")"
  rc=$?
  set -e
  out="$out$(cat "$errf")"
  rm -f "$errf"
}

SERILOG_ON_EXTENSIONS_11='{
  "version": 3,
  "targets": {
    "net10.0": {
      "Serilog.AspNetCore/10.0.0": {
        "type": "package",
        "dependencies": { "Microsoft.Extensions.Logging.Abstractions": "11.0.0" }
      },
      "Microsoft.Extensions.Logging.Abstractions/11.0.0": { "type": "package" }
    }
  },
  "projectFileDependencyGroups": { "net10.0": [ "Serilog.AspNetCore >= 10.0.0" ] }
}'

SERILOG_ON_EXTENSIONS_10='{
  "version": 3,
  "targets": {
    "net10.0": {
      "Serilog.AspNetCore/10.0.0": {
        "type": "package",
        "dependencies": { "Microsoft.Extensions.Logging.Abstractions": "10.0.0" }
      },
      "Microsoft.Extensions.Logging.Abstractions/10.0.7": { "type": "package" }
    }
  },
  "projectFileDependencyGroups": { "net10.0": [ "Serilog.AspNetCore >= 10.0.0" ] }
}'

EXTENSIONS_11_ONLY_ON_NET11='{
  "version": 3,
  "targets": {
    "net10.0": {
      "Serilog.AspNetCore/10.0.0": {
        "type": "package",
        "dependencies": { "Microsoft.Extensions.Logging.Abstractions": "10.0.0" }
      },
      "Microsoft.Extensions.Logging.Abstractions/10.0.7": { "type": "package" }
    },
    "net11.0": {
      "Serilog.AspNetCore/11.0.0": {
        "type": "package",
        "dependencies": { "Microsoft.Extensions.Logging.Abstractions": "11.0.0" }
      },
      "Microsoft.Extensions.Logging.Abstractions/11.0.0": { "type": "package" }
    }
  },
  "projectFileDependencyGroups": {
    "net10.0": [ "Serilog.AspNetCore >= 10.0.0" ],
    "net11.0": [ "Serilog.AspNetCore >= 11.0.0" ]
  }
}'

EXTENSIONS_11_ONLY_ON_RID_TARGET='{
  "version": 3,
  "targets": {
    "net10.0": {
      "Serilog.AspNetCore/10.0.0": {
        "type": "package",
        "dependencies": { "Microsoft.Extensions.Logging.Abstractions": "10.0.0" }
      },
      "Microsoft.Extensions.Logging.Abstractions/10.0.7": { "type": "package" }
    },
    "net10.0/linux-x64": {
      "Serilog.AspNetCore/10.0.0": {
        "type": "package",
        "dependencies": { "Microsoft.Extensions.Logging.Abstractions": "11.0.0" }
      },
      "Microsoft.Extensions.Logging.Abstractions/11.0.0": { "type": "package" }
    }
  },
  "projectFileDependencyGroups": { "net10.0": [ "Serilog.AspNetCore >= 10.0.0" ] }
}'

ASPNETCORE_PRERELEASE_DIRECT='{
  "version": 3,
  "targets": {
    "net10.0": {
      "Microsoft.AspNetCore.OpenApi/11.0.0-rc.2.26459.1": { "type": "package" }
    }
  },
  "projectFileDependencyGroups": { "net10.0": [ "Microsoft.AspNetCore.OpenApi >= 11.0.0-rc.2.26459.1" ] }
}'

EF_CORE_11_ONLY='{
  "version": 3,
  "targets": {
    "net10.0": {
      "Microsoft.EntityFrameworkCore/11.0.0": {
        "type": "package",
        "dependencies": { "Microsoft.Extensionsish.Thing": "11.0.0" }
      },
      "Microsoft.Extensionsish.Thing/11.0.0": { "type": "package" }
    }
  },
  "projectFileDependencyGroups": { "net10.0": [ "Microsoft.EntityFrameworkCore >= 11.0.0" ] }
}'

TWO_PATHS_TO_EXTENSIONS_11='{
  "version": 3,
  "targets": {
    "net10.0": {
      "Library.A/1.0.0": {
        "type": "package",
        "dependencies": { "Middle.Package": "1.0.0" }
      },
      "Middle.Package/1.0.0": {
        "type": "package",
        "dependencies": {
          "Microsoft.Extensions.Options": "11.0.0",
          "Microsoft.AspNetCore.Http.Abstractions": "11.0.0"
        }
      },
      "Microsoft.Extensions.Options/11.0.0": { "type": "package" },
      "Microsoft.AspNetCore.Http.Abstractions/11.0.0": { "type": "package" }
    }
  },
  "projectFileDependencyGroups": { "net10.0": [ "Library.A >= 1.0.0" ] }
}'

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo"
check "packable net10.0 target on Microsoft.Extensions 11 exits 1" 1 "$rc"
check_contains "failure names the project" "Lib/Lib.csproj" "$out"
check_contains "failure names the package and version" "Microsoft.Extensions.Logging.Abstractions 11.0.0" "$out"
check_contains "failure names the top-level package" "via Serilog.AspNetCore" "$out"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$SERILOG_ON_EXTENSIONS_10"
run_guard "$repo"
check "packable net10.0 target on Microsoft.Extensions 10 exits 0" 0 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$EXTENSIONS_11_ONLY_ON_NET11"
run_guard "$repo"
check "11.x only on the net11.0 target exits 0" 0 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0" true "$EXTENSIONS_11_ONLY_ON_RID_TARGET"
run_guard "$repo"
check "11.x on a net10.0/linux-x64 target exits 1" 1 "$rc"
check_contains "RID target offender is named" "Microsoft.Extensions.Logging.Abstractions 11.0.0 (via Serilog.AspNetCore)" "$out"

repo="$(new_repo)"
add_project "$repo" App "net10.0" false "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo"
check "non-packable project exits 0" 0 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net11.0" true "${SERILOG_ON_EXTENSIONS_11//net10.0/net11.0}"
run_guard "$repo"
check "packable net11.0-only project exits 0" 0 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0" true "$ASPNETCORE_PRERELEASE_DIRECT"
run_guard "$repo"
check "direct Microsoft.AspNetCore prerelease 11 exits 1" 1 "$rc"
check_contains "direct dependency is labelled direct" "Microsoft.AspNetCore.OpenApi 11.0.0-rc.2.26459.1 (direct dependency)" "$out"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0" true "$EF_CORE_11_ONLY"
run_guard "$repo"
check "packages outside the two prefixes at 11 exit 0" 0 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0" true "$TWO_PATHS_TO_EXTENSIONS_11"
run_guard "$repo"
check "two offenders of one project share one annotation" 1 "$(grep -c '^::error' <<< "$out")"
check_contains "second offender is in the same annotation" "Microsoft.AspNetCore.Http.Abstractions 11.0.0 (via Library.A)" "$out"
check_contains "transitive offender names its top-level package" "Microsoft.Extensions.Options 11.0.0 (via Library.A)" "$out"

repo="$(new_repo)"
add_project "$repo" Lib "netstandard2.0; net10.0" true "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo"
check "TargetFrameworks with a space after the semicolon exits 1" 1 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "netstandard2.0;
      net10.0;
      net11.0" true "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo"
check "TargetFrameworks spread over several lines exits 1" 1 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "  NET10.0  " true "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo"
check "net10.0 spelled in upper case with padding exits 1" 1 "$rc"

for spelling in True TRUE tRuE; do
  repo="$(new_repo)"
  add_project "$repo" Lib "net10.0;net11.0" "$spelling" "$SERILOG_ON_EXTENSIONS_11"
  run_guard "$repo"
  check "IsPackable spelled $spelling exits 1 on an offender" 1 "$rc"
done

repo="$(new_repo)"
add_release_only_packable_project "$repo" Lib "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo"
check "project packable only in Release exits 1 on an offender" 1 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$SERILOG_ON_EXTENSIONS_10"
add_project "$repo" Other "net10.0" true "$SERILOG_ON_EXTENSIONS_10"
add_project "$repo" App "net10.0" false "$SERILOG_ON_EXTENSIONS_10"
add_project "$repo" Legacy "netstandard2.0" true "$SERILOG_ON_EXTENSIONS_10"
run_guard "$repo"
check "clean run exits 0" 0 "$rc"
check_contains "clean run reports how many packable net10.0 projects it checked" "net10.0 package guard: checked 2 packable project(s)" "$out"

repo="$(new_repo)"
add_project "$repo" App "net10.0" false "$SERILOG_ON_EXTENSIONS_10"
run_guard "$repo"
check_contains "run with no packable net10.0 project reports zero" "net10.0 package guard: checked 0 packable project(s)" "$out"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0" true ""
run_guard "$repo"
check_contains "unrestored project is not counted as checked" "net10.0 package guard: checked 0 packable project(s)" "$out"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo" "" "$crlf_bin"
check "jq and dotnet emitting CRLF still exit 1 on an offender" 1 "$rc"
check_contains "CRLF output still names the package" "Microsoft.Extensions.Logging.Abstractions 11.0.0 (via Serilog.AspNetCore)" "$out"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$SERILOG_ON_EXTENSIONS_10"
run_guard "$repo" "" "$crlf_bin"
check "jq and dotnet emitting CRLF exit 0 on a clean project" 0 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo" "Microsoft.Extensions.Logging.Abstractions@11" "$crlf_bin"
check "CRLF output does not break the exception match" 0 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo" "Microsoft.Extensions.Logging.Abstractions@11"
check "exception matching package and major exits 0" 0 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo" "microsoft.extensions.logging.abstractions@11"
check "exception matches the package id case-insensitively" 0 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo" "Microsoft.Extensions.Logging.Abstractions@12"
check "exception for another major still exits 1" 1 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$SERILOG_ON_EXTENSIONS_11"
run_guard "$repo" "Microsoft.Extensions.Options@11"
check "exception for another package still exits 1" 1 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$TWO_PATHS_TO_EXTENSIONS_11"
run_guard "$repo" "Microsoft.Extensions.Options@11,Microsoft.AspNetCore.Http.Abstractions@11"
check "comma separated exceptions cover both offenders" 0 "$rc"

repo="$(new_repo)"
add_project "$repo" Lib "net10.0;net11.0" true "$TWO_PATHS_TO_EXTENSIONS_11"
run_guard "$repo" "Microsoft.Extensions.Options@11
  Microsoft.AspNetCore.Http.Abstractions@11"
check "newline separated exceptions cover both offenders" 0 "$rc"

for malformed in \
  "Microsoft.Extensions.Logging.Abstractions" \
  "Microsoft.Extensions.Logging.Abstractions@" \
  "Microsoft.Extensions.Logging.Abstractions@11.0" \
  "Microsoft.Extensions.Logging.Abstractions@x" \
  "\$(touch\${IFS}pwned)@11" \
  "\";exit\${IFS}0;\"@11"; do
  repo="$(new_repo)"
  add_project "$repo" Lib "net10.0;net11.0" true "$SERILOG_ON_EXTENSIONS_11"
  run_guard "$repo" "$malformed"
  check "malformed exception [$malformed] exits 2" 2 "$rc"
  check_contains "malformed exception [$malformed] is named" "$malformed" "$out"
  check "malformed exception [$malformed] runs nothing" "no" "$([ -e "$repo/pwned" ] && echo yes || echo no)"
done

repo="$(new_repo)"
add_project "$repo" Lib "net10.0" true ""
run_guard "$repo"
check "packable net10.0 project outside the restored workspace exits 0" 0 "$rc"
check_contains "unrestored project is named in a warning" "::warning::Lib/Lib.csproj" "$out"

repo="$(new_repo)"
run_guard "$repo"
check "repository without projects exits 0" 0 "$rc"

exit "$fail"
