# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.4.1] - 2026-08-30

### Fixed

- Fix `csharp-ci.yaml` and `scala-ci.yaml` failing their Windows `build-and-test` shards in `actions/checkout` for consumers whose repositories contain long paths. The GitHub-hosted Windows images ship git with `core.longpaths` unset, so a repo path that crosses the 260-character `MAX_PATH` limit once prefixed with the runner's `D:\a\<repo>\<repo>\` workspace root aborts the checkout with `error: unable to create file <path>: Filename too long` — in step 2, before any toolchain setup, and with no lever on the caller's side because the `build-and-test` checkout takes no `with:` block. Both workflows now run `git config --system core.longpaths true` on Windows immediately before that checkout. It has to be `--system`: `actions/checkout` temporarily overrides `HOME` before making its own global git config changes, so a `--global` value written by an earlier step is not in effect during the checkout. The step is pinned to `working-directory: ${{ github.workspace }}` because the job-level `defaults.run.working-directory` points at the caller's `working-directory` input, which does not exist yet before checkout (the same pin, for the same reason, that the `pack` job's `Validate inputs` step already carries). Linux and macOS shards are untouched, and Windows consumers whose paths already fit see no change. Generated-code trees hit this most readily, since path depth follows source namespaces and grows on its own. (#39)

## [2.4.0] - 2026-07-14

### Added

- Publish the `build-matrix` shard results of `csharp-ci.yaml` and `scala-ci.yaml` as a sticky PR comment (`shard | result | duration` table, each shard linking to its job). A new `matrix-comment` job (`needs: build-and-test`, `if: !cancelled()`) queries the run's per-shard job outcomes via `gh api .../actions/runs/<run-id>/jobs` — so the table renders even when a shard fails — and upserts it via `marocchino/sticky-pull-request-comment` under a `<artifact-prefix>-build-matrix` header, distinct from the coverage sticky comment. It no-ops when the caller passes no `build-matrix`, on non-`pull_request` events, and for dependabot. Coverage comments are unaffected. (#36)

### Fixed

- Harden `scripts/write-badges.sh` (the `update-badges.yaml` helper) against silent failures. `git fetch origin "$badge_branch" || true` previously swallowed every failure — auth, network, or a genuinely absent branch alike — then fell through to the orphan-rebuild path; a real fetch failure is now aborted loud, and only the benign "branch does not exist yet" case (detected up front with `git ls-remote --exit-code`) rebuilds the orphan branch. Malformed input now fails the badge job instead of writing a bogus badge file: a non-array `coverage-data`/`matrix-data`, a coverage entry missing `slug`/`label`, or a matrix entry missing `lang`/`os`/`arch`/`passed` (which would have written `ci-null-null-null.json`) is rejected with a `::error::` annotation. Added `test/write-badges_test.sh` pinning the `coverage-<slug>.json` / `ci-<lang>-<os>-<arch>.json` filename contract, the null-percent skip, and the new fail-loud paths, wired into the `build-and-test` self-test job. Healthy consumers on the built-in `matrix-status` → `update-badges.yaml` flow see no change. (#35)

- Fix `csharp-ci.yaml` and `scala-ci.yaml` silently emitting an empty `coverage` output when the coverage-percent artifact download failed. The `coverage-output` job downloaded the artifact with `continue-on-error: true` and defaulted to empty when the file was absent, conflating "no shard set `coverage: true`" (empty is correct) with "the coverage shard uploaded the artifact but the download failed" (throttling, retention, infra) — the latter fed a blank or stale coverage badge from an otherwise green run. The job now derives whether a coverage shard was configured from the normalized matrix: when one was, the artifact download must succeed and yield a non-empty value or the job fails loud; when none was, the download step is skipped and the empty output stays intentional. Consumers whose coverage shard uploads normally see no change. (#34)

- Fix `go-ci.yaml`'s `Augment coverage report with cyclomatic complexity` step staging per-function coverage output at the fixed path `/tmp/cov-func.txt`. On shared self-hosted runners (e.g. the Hetzner pool) `/tmp` outlives the job and is shared across runner instances, so a leftover file owned by a different runner user fails the step with `permission denied`, and two Go jobs landing on the same host can interleave writes and stamp the wrong per-function coverage into each other's `Attended` column. The staging file now lives under `$RUNNER_TEMP`, which is private to the runner instance and wiped between jobs; GitHub-hosted consumers see no change. Closes out the self-hosted-runner hardening of this step begun in 2.3.2's sudo removal. (#33)

## [2.3.4] - 2026-07-10

### Fixed

- Fix the badge helper scripts silently coercing unrecognized status input into a plausible-but-wrong badge instead of erroring. `matrix_badge_json.py` treated anything outside its passing allowlist as failing, so a `cancelled` or typo'd status rendered a misleading red badge, and `aggregate_matrix_status.py` reported a malformed marker (missing status) as a failed shard. Both now reject input outside the known `success`/`failure` token sets and fail the badge job loud, with regression tests for the rejected cases. Workflows using the built-in `matrix-status` → `update-badges.yaml` flow only ever produce known tokens, so healthy consumers see no change. First outside contribution to this repo — thank you @maxi-maxima! (#30)
- Fix `csharp-ci.yaml`'s `Merge per-project cobertura reports` step finding no coverage files for consumers that bump `Microsoft.Testing.Extensions.CodeCoverage` to 18.9.0 on .NET SDK 10.0.3xx. That combination makes solution-level `dotnet test` resolve the relative `--coverage-output` against the run-level `<working-directory>/TestResults/` instead of each project's `bin/Release/<tfm>/TestResults/`, so the default `tests-glob` matched nothing and failed the coverage shard. The default now carries a second glob (`TestResults/**/*.cobertura.xml`) — the merge step word-splits the input under `globstar nullglob`, so old-layout consumers see no change and callers passing an explicit `tests-glob` are unaffected. The README caller prerequisites document both layouts and lift the stale "do not bump `CodeCoverage` past 18.0.x" ceiling: with `xunit.v3.mtp-v2` shipped, 18.x lines through 18.9.x are supported, while the 19.x empty-output warning stays. First hit by `peacefulstudio/daml-codegen-csharp-internal`. (#32)

## [2.3.3] - 2026-07-09

### Fixed

- Fix `csharp-ci.yaml`'s `Install dotnet-coverage` step failing outright on shared self-hosted runners when a previous job already left a newer `dotnet-coverage` global tool installed than the current caller's pin. `dotnet tool update` refuses to move to an older version, so a runner that has accumulated a newer version from one repo's pin hard-fails every other repo's job that pins an older one, with no way to recover short of a rerun landing on a different runner. The install step now shells out to a new `scripts/install-dotnet-coverage.sh`, which checks the currently-installed version first and uninstalls-then-reinstalls only when it differs from the pin (in either direction), making the step idempotent regardless of what any other job left behind. (#31)

## [2.3.2] - 2026-06-23

### Fixed

- Fix `go-ci.yaml` failing the `Augment coverage report with cyclomatic complexity` step on self-hosted runners. The step ran `sudo chown "$(id -un)" code-coverage-results.md` to take back a file that `irongut/CodeCoverageSummary` (a Docker action) writes as root, but self-hosted runners (e.g. the Hetzner pool) lack passwordless sudo, so the step died with `sudo: a password is required` — breaking every Go consumer's `build-and-test` job once it compiled far enough to reach coverage. Ownership is now taken without sudo: when the report is not writable it is replaced with a runner-owned copy via a same-directory `cp` + `mv -f`, which needs only workspace-directory permissions and is a no-op on GitHub-hosted runners where the file is already writable. Reported by `peacefulstudio/terraform-provider-canton-internal`. (#29)

## [2.3.1] - 2026-06-19

### Fixed

- Fix `csharp-ci.yaml` failing the `Upload shard result` step for callers that pass a non-root `working-directory` (e.g. `working-directory: csharp`). The `Record shard result` step inherited the job's `defaults.run.working-directory` and wrote `ci-result/<name>.txt` under that subdirectory, but `actions/upload-artifact` ignores `defaults.run.working-directory` and resolves its `path:` relative to the repo root, so the upload failed with `No files were found with the provided path: ci-result/<name>.txt` (`if-no-files-found: error`). The `Record shard result` step is now pinned to `working-directory: ${{ github.workspace }}` so it writes at the repo root, matching where `upload-artifact` reads — mirroring how the adjacent coverage steps are already pinned. Reported by `peacefulstudio/canton-localnet-internal`. (#28)

## [2.3.0] - 2026-06-18

### Added

- Add a `matrix-mode` input to `csharp-ci.yaml` and `scala-ci.yaml` plus a new org/repo Actions variable `CI_MATRIX_MODE` for cheap CI matrix routing: on private/internal repos `cheap` collapses the build/test matrix to a single free self-hosted Hetzner shard (`["self-hosted","hetzner"]`, coverage on), overriding any `os-list` / `build-matrix`; `full` forces the normal matrix; empty defers to `CI_MATRIX_MODE`. Precedence is input > variable > normal matrix, so the org variable can flip every consumer onto idle self-hosted runners while a single caller opts out with `matrix-mode: full`. For safety, `cheap` is ignored (with a warning) on public repositories, since self-hosted runners must not run untrusted public/fork-PR workloads. (#27)

## [2.2.0] - 2026-06-14

### Added

- Add live README status badges driven from CI: a new `update-badges.yaml` reusable workflow writes shields.io endpoint JSON to an orphan `badges` branch of the caller repo (built-in `GITHUB_TOKEN`, no gist or PAT), fed by new `coverage` and `matrix-status` outputs on `csharp-ci.yaml` and `scala-ci.yaml`, so a consumer README can show live coverage and per-platform (OS × arch) CI badges alongside the standard release/version badges. (#23)

## [2.1.0] - 2026-06-12

### Fixed

- Fix the coverage-table sort being a silent no-op for C# coverage comments — `irongut/CodeCoverageSummary` `format: markdown` emits tables without leading pipes, which the `sort-coverage-table` action did not recognize as tables; it now detects a header line followed by a `---` separator line with or without leading pipes, and emits a `::warning::` when no table is found at all. (#18, #19)
- Fix diluted C# coverage numbers when multiple test projects cover the same assemblies: `csharp-ci.yaml` again union-merges the per-project cobertura files (matched by `tests-glob`) into one report via the `dotnet-coverage` global tool (version resolved from the caller's `Directory.Packages.props` pin of `Microsoft.Testing.Extensions.CodeCoverage`, nested files under `working-directory` included — no input; a missing, non-literal, or conflicting pin fails loud) before `irongut/CodeCoverageSummary` runs, instead of letting irongut concatenate them with duplicated, partial package rows. The input/secret contract is unchanged. (#19)

## [2.0.0] - 2026-06-12

**Migration:** reference workflows and actions at `@v2` (e.g. `peacefulstudio/github-actions/.github/workflows/csharp-ci.yaml@v2`). The floating `v1` tag is frozen at the v1.5.x state and will no longer advance.

### Changed

- All reusable workflows now check out their helper scripts (`normalize-ci-matrix.sh`, `resolve-runner.sh`, `push-nuget.sh`) and the `sort-coverage-table` action at `job.workflow_sha` — the exact commit of the called workflow — instead of the floating `v1` tag. Callers pinning a SHA or an exact version tag now get the helpers matching that exact version, and cutting a release no longer risks breaking consumers at runtime by forgetting to advance a floating tag. (#17)
- **BREAKING.** `csharp-ci.yaml` `dotnet-version` input default changed from `'10.0.x'` to empty. When empty, the .NET SDK is resolved from the caller repo's `global.json` under `working-directory` — the file must exist or setup fails loud. Pass an explicit `dotnet-version` to keep overriding. Callers relying on the old default must add a `global.json` (a future SDK bump is then a caller-side change only). (#17)

### Removed

- **BREAKING.** `dotnet-coverage-version` input on `csharp-ci.yaml` — the `dotnet-coverage` global tool install and the cobertura merge step are gone; `irongut/CodeCoverageSummary` now aggregates the per-project `*.cobertura.xml` files (matched by `tests-glob`) itself. A tool-free guard still fails the job loud when the glob matches no files. No known caller passes this input; any caller that does must drop it before moving to this version. (#17)

### Fixed

- Fix `csharp-ci.yaml`, `go-ci.yaml` and `scala-ci.yaml` failing in every consumer repo that runs the coverage step with "Can't find 'action.yml' … under '.github/actions/sort-coverage-table'" — the coverage-sort step referenced the action by local path, which resolves against the **caller's** checkout, not this repo. The step now references `peacefulstudio/github-actions/.github/actions/sort-coverage-table@v1`. (#16)

## [1.5.0] - 2026-06-11

### Added

- `.github/actions/csharp-publish` composite action — builds, tests, packs and pushes .NET NuGet packages to nuget.org, enabling NuGet Trusted Publishing (OIDC) for consumer repos. The caller checks out its own code and mints the short-lived API key via `NuGet/login` in its own job, then invokes the action with `steps: - uses: peacefulstudio/github-actions/.github/actions/csharp-publish@v1`, passing `api-key`. Because the action runs inline as steps in the caller's job, `job_workflow_ref` stays the caller's publish workflow, so a per-repo nuget Trusted Publishing policy anchored on the consumer repo matches. Inputs: `api-key` (required), `version_override`, `include_symbols` (default `true`), `working-directory` (default `.`), `test-filter` (default empty).
- `working-directory` (default `.`) and `test-filter` (default empty) inputs on `csharp-publish-public.yaml`, matching the names used by `csharp-ci.yaml`. `working-directory` runs the restore/build/test/pack steps from a sub-path (the pack output stays at `$GITHUB_WORKSPACE/output/nuget` so the root-level push step is unaffected), letting repos whose solution lives below the root — e.g. `canton-localnet`'s `csharp/` — use the reusable workflow. `test-filter` passes a `dotnet test --filter` expression (e.g. `Category!=Integration`) to exclude tests that need live infrastructure. Both default to the previous behaviour, so existing callers are bit-for-bit unaffected.

### Changed

- **BREAKING.** `csharp-publish-public.yaml` now publishes to nuget.org via NuGet Trusted Publishing (short-lived OIDC token exchanged for a temporary API key through `NuGet/login`) instead of long-lived API keys. The four `NUGET_API_KEY_*` secrets (`NUGET_API_KEY_CANTON`, `NUGET_API_KEY_DAML`, `NUGET_API_KEY_SPLICE`, `NUGET_API_KEY_PEACEFUL`) are removed. Callers must instead provide an organization secret `NUGET_USER` (the nuget.org profile name), grant `permissions: id-token: write`, and register a nuget.org Trusted Publishing policy (**Workflow File** = `csharp-publish-public.yaml` — the reusable file, not the caller; **Environment** = `nuget-publish`). `scripts/route-nuget-push.sh` is renamed to `scripts/push-nuget.sh`; per-owner key routing is removed since one user/key now pushes every package.
- Coverage PR comment tables (Scala, Go, C#) now list packages alphabetically by name.
- Remove the Complexity column from the Scala coverage PR comment — `sbt` always emits 0 for this field.

### Deprecated

- **BREAKING for trusted publishing.** `csharp-publish-public.yaml` reusable workflow is deprecated. As a reusable workflow it runs the OIDC job in `peacefulstudio/github-actions`, so the `job_workflow_ref` claim is always stamped with `github-actions` and never the caller — a per-repo nuget Trusted Publishing policy anchored on the consumer repo can therefore never match (confirmed by a live HTTP 401). Consumers must switch to the `.github/actions/csharp-publish` composite action and mint the OIDC key (`NuGet/login`) in their own job.

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

[Unreleased]: https://github.com/peacefulstudio/github-actions/compare/v2.4.1...HEAD
[2.4.1]: https://github.com/peacefulstudio/github-actions/compare/v2.4.0...v2.4.1
[2.4.0]: https://github.com/peacefulstudio/github-actions/compare/v2.3.4...v2.4.0
[2.3.4]: https://github.com/peacefulstudio/github-actions/compare/v2.3.3...v2.3.4
[2.3.3]: https://github.com/peacefulstudio/github-actions/compare/v2.3.2...v2.3.3
[2.3.2]: https://github.com/peacefulstudio/github-actions/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/peacefulstudio/github-actions/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/peacefulstudio/github-actions/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/peacefulstudio/github-actions/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/peacefulstudio/github-actions/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/peacefulstudio/github-actions/compare/v1.5.0...v2.0.0
[1.5.0]: https://github.com/peacefulstudio/github-actions/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/peacefulstudio/github-actions/compare/v1.2.0...v1.4.0
[1.2.0]: https://github.com/peacefulstudio/github-actions/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/peacefulstudio/github-actions/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/peacefulstudio/github-actions/releases/tag/v1.0.0
