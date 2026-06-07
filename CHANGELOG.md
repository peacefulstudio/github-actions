# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `working_directory` (default `.`) and `test_filter` (default empty) inputs on `csharp-publish-public.yaml`. `working_directory` runs the restore/build/test/pack steps from a sub-path (the pack output stays at `$GITHUB_WORKSPACE/output/nuget` so the root-level push step is unaffected), letting repos whose solution lives below the root — e.g. `canton-localnet`'s `csharp/` — use the reusable workflow. `test_filter` passes a `dotnet test --filter` expression (e.g. `Category!=Integration`) to exclude tests that need live infrastructure. Both default to the previous behaviour, so existing callers are bit-for-bit unaffected.

### Changed

## [1.4.0] - 2026-06-07

### Added

- `build-matrix` input on `csharp-ci.yaml` and `scala-ci.yaml` — optional JSON array of `{ name, runner, coverage }` shards that fully replaces `os-list` when set. Lets a caller mix self-hosted and hosted runners, pass array-valued `runs-on` labels (e.g. `["self-hosted", "hetzner"]`), and pick the single shard that carries the coverage report / sticky PR comment / job summary. Backed by a new tested helper, `scripts/normalize-ci-matrix.sh`, checked out and run in a `normalize` job; it fails loud (with a `::error::` annotation) on a malformed matrix — more than one `coverage: true` shard, a missing/empty `name` or `runner`, a non-boolean `coverage`, or invalid JSON. Omitting `build-matrix` keeps `os-list` behaviour bit-for-bit.
- `runs-on` input on `build-and-test.yaml` — honoured on `workflow_call`; accepts a plain label or a JSON array string.
- `include_symbols` input (default `true`) on `csharp-publish-public.yaml` — generates and publishes `.snupkg` symbol packages to the nuget.org symbol server alongside the main packages. Set to `false` to publish `.nupkg` only. (#7)

### Changed

- **Default runner now follows repository visibility.** When a caller passes no `runs-on` (`go-ci`, `terraform-ci`, `build-and-test`) or no `os-list` / `build-matrix` (`csharp-ci`, `scala-ci`), the runner is selected by a `gh api` visibility lookup: public repos get GitHub-hosted runners (csharp/scala: `ubuntu-latest` + `windows-latest` + `macos-latest` with coverage on ubuntu; others: `ubuntu-latest`), private and internal repos get the self-hosted Hetzner pool (`["self-hosted", "hetzner"]`). The lookup fails loud on error or unexpected visibility — it never silently routes to self-hosted. Any explicit `runs-on` / `os-list` / `build-matrix` overrides this, so existing explicit callers are unaffected; a private repo with no Hetzner runner must pin `runs-on: ubuntu-latest`. The `os-list` (`csharp-ci`, `scala-ci`) and `runs-on` (`go-ci`, `terraform-ci`, `build-and-test`) input defaults changed from a literal to empty so "caller said nothing" is distinguishable from an explicit `ubuntu-latest`. Runner resolution for `go-ci` / `terraform-ci` / `build-and-test` is backed by a new tested helper, `scripts/resolve-runner.sh`, checked out and run in a `resolve-runner` job — mirroring the `normalize-ci-matrix.sh` job used by `csharp-ci` / `scala-ci`, so all five workflows share tested runner-selection helpers instead of duplicating inline shell.
- `runs-on` on `go-ci.yaml` and `terraform-ci.yaml` now accepts a JSON array string (e.g. `'["self-hosted", "hetzner"]'`) in addition to a plain label, so callers can target self-hosted runner pools that require multiple labels. Plain-label callers are unaffected.
- `csharp-publish-public.yaml` now builds with `ContinuousIntegrationBuild=true` for deterministic, path-normalized Release builds. (#7)

## [1.2.0] - 2026-06-04

### Added

- `csharp-publish-public.yaml` — reusable workflow to publish NuGet packages to nuget.org, with per-owner push routing via a new tested `scripts/route-nuget-push.sh`. (#6)

## [1.1.0] - 2026-05-27

### Added

- `scala-ci.yaml` — reusable sbt/Scala CI workflow (build, test, coverage, sticky PR comment, job summary, artifact upload). Mirrors the `csharp-ci.yaml` shape, minus the `pack:` job. (#2)
- `coverage-title` input across `csharp-ci.yaml` (default `'C# coverage'`), `scala-ci.yaml` (default `'Scala coverage'`), `go-ci.yaml` (default `'Go coverage'`), and `terraform-ci.yaml` (default `'Terraform coverage'`). Prepends a markdown H2 heading to the rendered coverage / test-summary file before the sticky-comment step picks it up, so callers can disambiguate per-language sticky comments when multiple coexist on the same PR. Loud-fails if the target file is missing. (#1, #2, #3, #4)

### Changed

- `csharp-ci.yaml` migrated to xUnit v3 + Microsoft.Testing.Platform. Coverage is now collected in-process via `Microsoft.Testing.Extensions.CodeCoverage` (pinned `18.0.6`) instead of `--collect "XPlat Code Coverage"`. ReportGenerator replaced with `dotnet-coverage merge` plus `irongut/CodeCoverageSummary@v1.3.0` (matches the go-ci / terraform-ci output style). Caller contract now expects `xunit.v3` 3.2.2+, the MTP CodeCoverage 18.0.6 pin, a `tests/Directory.Build.props`, and a `coverage.settings.xml`. Two new optional inputs preserve flexibility: `dotnet-coverage-version` (default `18.0.6`) and `tests-glob` (default `tests/**/*.cobertura.xml`). All previously exposed inputs and secrets are preserved verbatim. (#1)

## [1.0.0] - 2026-05-24

### Added

- Initial public release of the reusable workflow set:
  - `build-and-test.yaml` — actionlint validator for `.github/workflows/`.
  - `go-ci.yaml` — Go build / test / coverage / lint.
  - `csharp-ci.yaml` — .NET build / test / coverage / pack.
  - `terraform-ci.yaml` — Terraform fmt / validate / test.

[Unreleased]: https://github.com/peacefulstudio/github-actions/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/peacefulstudio/github-actions/compare/v1.2.0...v1.4.0
[1.2.0]: https://github.com/peacefulstudio/github-actions/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/peacefulstudio/github-actions/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/peacefulstudio/github-actions/releases/tag/v1.0.0
