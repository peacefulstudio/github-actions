# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/peacefulstudio/github-actions/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/peacefulstudio/github-actions/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/peacefulstudio/github-actions/releases/tag/v1.0.0
