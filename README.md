# github-actions

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Shared reusable GitHub Actions workflows for Peaceful Studio repos.

## Project stewardship

`github-actions` is currently developed and maintained by **Peaceful Studio
OÜ** (Estonia, VAT EE102232996). The project is licensed under Apache-2.0
with the explicit intent of community ownership: if and when adoption
warrants neutral governance, Peaceful Studio commits to transferring this
repository to a community-led organisation under the same license terms.
Contributions welcome from anywhere in the GitHub Actions / CI ecosystem;
no CLA required.

## Available workflows

### `build-and-test.yaml` — actionlint validator

Lints every workflow file in `.github/workflows/` with
[`actionlint`](https://github.com/rhysd/actionlint). Catches YAML schema
errors, shell-quoting bugs, undefined contexts, and other static issues
before they ship.

**Inputs**: none.

**Required secrets**: none.

**Required permissions**: none.

Consumer `.github/workflows/lint.yaml`:

```yaml
name: Lint workflows

on:
  push:
    branches: [dev]
    paths: ['.github/workflows/**']
  pull_request:
    branches: [dev]
    paths: ['.github/workflows/**']

jobs:
  lint:
    uses: peacefulstudio/github-actions/.github/workflows/build-and-test.yaml@v1
```

### `go-ci.yaml` — Go build, test, coverage, lint

Discovers every `go.mod` under the configured paths and, for each module, runs:

- `go build ./...`
- `go test -race -covermode=atomic -coverprofile=...`
- Cobertura conversion + a markdown coverage report (posted as a sticky PR comment, also written to the job summary)
- Cyclomatic-complexity augmentation (per-package average + top-10 production functions, annotated with their coverage)
- `golangci-lint run ./...`

If no modules are discovered the build/test/lint steps are skipped, so the workflow stays green on repos that haven't added Go code yet.

**Inputs**:

| Input                   | Default          | Description                                                                                                                                  |
| ----------------------- | ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `go-version`            | `stable`         | Passed to `actions/setup-go`.                                                                                                                |
| `module-paths`          | `go cli`         | Space-separated directories to search for `go.mod`. Missing directories are silently ignored.                                                |
| `golangci-lint-version` | `latest`         | Version selector for `go install`. Tags starting with `v2` install from `github.com/golangci/golangci-lint/v2/cmd/golangci-lint` (needed for v2 config files); anything else uses the v1 module path. Pin a tag (e.g. `v1.61.0` or `v2.12.2`) for reproducible runs. |
| `runs-on`               | `ubuntu-latest`  | Runner label for all jobs.                                                                                                                   |

**Required secrets**: none. PR comments use the default `GITHUB_TOKEN`.

**Required permissions**: declared per-job inside the workflow (`contents: read`, plus `pull-requests: write` for the sticky coverage comment) — no caller-side setup needed.

Consumer `.github/workflows/go-ci.yaml`:

```yaml
name: Go CI

on:
  push:
    branches: [dev]
    paths:
      - 'go/**'
      - 'cli/**'
      - '.github/workflows/go-ci.yaml'
  pull_request:
    branches: [dev]
    paths:
      - 'go/**'
      - 'cli/**'
      - '.github/workflows/go-ci.yaml'

jobs:
  go-ci:
    uses: peacefulstudio/github-actions/.github/workflows/go-ci.yaml@v1
```

To pin Go and lint versions, or to point at a non-default module layout:

```yaml
jobs:
  go-ci:
    uses: peacefulstudio/github-actions/.github/workflows/go-ci.yaml@v1
    with:
      go-version: '1.26'
      module-paths: 'services tools'
      golangci-lint-version: 'v1.61.0'
```

### `csharp-ci.yaml` — .NET build, test, coverage, pack

Runs `dotnet restore`, `dotnet build`, `dotnet test` (with coverage), and
optionally `dotnet pack` against the workspace at `working-directory`.
Produces a Cobertura coverage report, a markdown summary, and a sticky
PR comment with per-project coverage. Uploads `.nupkg` artifacts when
`pack: true`.

A configurable `os-list` matrix runs build + test across one or several
runners (Linux / macOS / Windows). Coverage report generation only runs
on the `ubuntu-latest` shard.

**Inputs** (selected — see the workflow file for the full set):

| Input                         | Default                  | Description                                                                                  |
| ----------------------------- | ------------------------ | -------------------------------------------------------------------------------------------- |
| `dotnet-version`              | `10.0.x`                 | Passed to `actions/setup-dotnet`.                                                            |
| `working-directory`           | `.`                      | Path of the .NET workspace.                                                                  |
| `os-list`                     | `["ubuntu-latest"]`      | JSON array of runner labels for the build-and-test matrix.                                   |
| `test-project`                | *(empty)*                | Specific test project / solution path; empty runs the workspace default `.sln` / `.slnx`.    |
| `test-filter`                 | *(empty)*                | Forwarded to `dotnet test --filter`.                                                         |
| `coverage-pr-comment-header`  | `csharp-coverage`        | Sticky-comment header (make unique per workspace if a repo calls this workflow more than once). |
| `pack`                        | `false`                  | When true, also runs `dotnet pack` and uploads `.nupkg` artifacts.                           |
| `pack-project`                | *(empty)*                | Project to pack. Required when `pack: true`.                                                 |

**Optional secrets**:

- `BOT_GITHUB_TOKEN` — PAT or GitHub App token with `read:packages` for
  `dotnet restore` against private NuGet feeds (e.g. GitHub Packages).
  Omit for public-only restores. Pass via `secrets: inherit` or an
  explicit `secrets:` block on the caller.

Consumer `.github/workflows/csharp-ci.yaml`:

```yaml
name: CSharp CI

on:
  push:
    branches: [dev]
  pull_request:
    branches: [dev]

jobs:
  csharp-ci:
    uses: peacefulstudio/github-actions/.github/workflows/csharp-ci.yaml@v1
    secrets: inherit
```

#### Caller prerequisites (xUnit v3 + Microsoft.Testing.Platform)

This workflow runs tests end-to-end on **xUnit v3 + Microsoft.Testing.Platform
(MTP)**. Callers still on xUnit v2 + coverlet cannot pin to this workflow —
stay on a previous SHA / tag until you've migrated the items below.

- **`Directory.Packages.props` pinning**:
  - `xunit.v3` — `3.2.2`
  - `Microsoft.Testing.Extensions.CodeCoverage` — same version as the
    workflow input `dotnet-coverage-version` (default `18.0.6`).
  The MTP coverage extension version is pinned deliberately and the
  `dotnet-coverage-version` workflow input is the single source of truth
  for the matching global tool used at merge time — keep them aligned.
  See [`canton-ledger-api-csharp#79`](https://github.com/peacefulstudio/canton-ledger-api-csharp/pull/79)
  for the MTP 1.x / 2.x compatibility rationale: do not bump
  `CodeCoverage` past 18.0.x until `xunit.v3` ships an MTP 2.x build —
  newer 19.x lines have produced empty Cobertura output in this pipeline.

- **`tests/Directory.Build.props`** (or equivalent) must enable MTP:

  ```xml
  <UseMicrosoftTestingPlatformRunner>true</UseMicrosoftTestingPlatformRunner>
  <TestingPlatformDotnetTestSupport>true</TestingPlatformDotnetTestSupport>
  <TestingPlatformCommandLineArguments>--coverage --coverage-output-format cobertura --settings $(MSBuildThisFileDirectory)../coverage.settings.xml</TestingPlatformCommandLineArguments>
  ```

  The exact arguments live in the caller — what matters is that MTP runs
  in-process and emits `*.cobertura.xml` files somewhere under `tests/`.

- **Multi-TFM test projects** must set a per-TFM Cobertura filename to
  avoid silent overwrites between target frameworks:

  ```xml
  <TestingPlatformCommandLineArguments>... --coverage-output $(MSBuildProjectName)_$(TargetFramework).cobertura.xml</TestingPlatformCommandLineArguments>
  ```

  Single-TFM projects can omit this.

- **`coverage.settings.xml`** at the repo root (or wherever
  `TestingPlatformCommandLineArguments` points), tuning the coverage
  collector. Prefer exclude-only `<ModulePaths>` (e.g. exclude test
  assemblies, third-party DLLs) rather than an include-list — an
  include-only `<ModulePaths>` silently drops any new production
  assembly that isn't listed and produces drifting coverage numbers
  with no error.

- **Coverlet removed** from every test `.csproj` — MTP's
  `Microsoft.Testing.Extensions.CodeCoverage` replaces it. Mixing the
  two produces duplicate or empty Cobertura reports.

### `scala-ci.yaml` — sbt build, test, coverage

Runs `sbt clean coverage test coverageReport` against the workspace at
`working-directory`, producing a Cobertura coverage report via
[`sbt-scoverage`](https://github.com/scoverage/sbt-scoverage). Posts a
sticky PR comment + job summary with the rendered coverage table and
uploads the raw Cobertura XML as a build artifact.

A configurable `os-list` matrix runs build + test across one or several
runners. Coverage report generation, the sticky PR comment, the job
summary, and the artifact upload only run on the `ubuntu-latest` shard.

**Inputs**:

| Input                         | Default                                              | Description                                                                                                                            |
| ----------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `working-directory`           | `.`                                                  | Path of the sbt/Scala workspace. Also used as the prefix for `cobertura-path` and when hashing sbt files for the cache key.            |
| `java-version`                | `21`                                                 | Passed to `actions/setup-java`.                                                                                                        |
| `java-distribution`           | `temurin`                                            | Passed to `actions/setup-java`.                                                                                                        |
| `os-list`                     | `["ubuntu-latest"]`                                  | JSON array of runner labels for the build-and-test matrix.                                                                             |
| `cobertura-path`              | `target/scala-2.13/coverage-report/cobertura.xml`    | Path (relative to `working-directory`) of the Cobertura XML emitted by `sbt coverageReport`. Override for non-2.13 Scala majors.       |
| `coverage-pr-comment-header`  | `scala-coverage`                                     | Hidden HTML-comment dedup key for the sticky PR comment. Make unique per language / per repo if multiple coverage comments coexist.    |
| `coverage-artifact-name`      | `scala-coverage`                                     | Name of the uploaded Cobertura artifact. Must not collide with other coverage artifacts uploaded by sibling jobs in the same run.      |
| `coverage-title`              | `Scala coverage`                                     | Rendered as a markdown H2 prepended to the coverage report so readers can tell the language at a glance.                               |
| `sbt-command`                 | `-batch -no-colors 'clean; coverage; test; coverageReport'` | Arguments passed to `sbt` for the build/test/coverage step. Run via `eval`, so callers must be trusted (workflow file, not user input). |

**Required secrets**: none. PR comments use the default `GITHUB_TOKEN`.

**Required permissions**: declared per-job inside the workflow (`contents: read`, `pull-requests: write` for the sticky coverage comment) — no caller-side setup needed.

Consumer `.github/workflows/scala-ci.yaml`:

```yaml
name: Scala CI

on:
  push:
    branches: [dev]
  pull_request:
    branches: [dev]

jobs:
  scala-ci:
    uses: peacefulstudio/github-actions/.github/workflows/scala-ci.yaml@v1
    with:
      working-directory: jvm-helper
```

#### Caller prerequisites

- **sbt project** rooted at `working-directory` — `build.sbt`,
  `project/build.properties`, and `project/plugins.sbt` are expected at
  that path (they're hashed into the sbt cache key).

- **`sbt-scoverage` plugin** declared in
  `<working-directory>/project/plugins.sbt`. Without it, `sbt coverage`
  and `sbt coverageReport` fail at task-lookup and the workflow exits
  non-zero before any Cobertura file is produced.

- **Cobertura XML** must land at
  `<working-directory>/target/scala-<scala-major>/coverage-report/cobertura.xml`
  after `sbt coverageReport` — this is the path the workflow stages,
  summarises, and uploads. The default `cobertura-path` input targets
  `scala-2.13`; **Scala 3 and other-major callers MUST override
  `cobertura-path`** (e.g. `target/scala-3/coverage-report/cobertura.xml`),
  otherwise the staging step fails with a missing-file error.

- **JDK compatible with the project's Scala / sbt versions**. Defaults to
  Temurin 21 — override `java-version` and `java-distribution` for
  projects pinned to an older or alternative JDK.

- **`sbt-command` is `eval`'d** in the runner shell, so the value MUST
  come from a trusted source (the caller's workflow file). Do not wire
  this input to webhook or `workflow_dispatch` payloads.

### `terraform-ci.yaml` — Terraform fmt, validate, test

Runs `terraform fmt -check -recursive`, then discovers Terraform modules
under the configured workspace and runs `terraform init -backend=false`
+ `terraform validate` against each. If any `.tftest.hcl` files exist,
it also runs `terraform test -verbose` from the appropriate module
root(s) and posts a sticky PR comment + job summary with the last 60
lines of the test output.

Module discovery (in order):

1. Explicit list via `module-paths` (relative to `working-directory`).
2. Every direct subdirectory of `modules/` if that directory exists.
3. Every directory (up to depth 3) containing `main.tf`,
   `versions.tf`, or `terraform.tf`, excluding `tests/`, `examples/`,
   and `.terraform/`. The fallback is best-effort — set `module-paths`
   explicitly on any non-trivial layout.

Test discovery: every directory that contains a `.tftest.hcl` file
(excluding `.terraform/`). When tests live anywhere under a `tests/`
subdirectory (Terraform 1.6+ supports nested test directories), the
workflow runs `terraform test` from the parent module so the module's
configuration is loaded — matching the Terraform CLI's convention.

> **Runner requirement.** Discovery uses `find -printf`, which is
> GNU-only. The default `ubuntu-latest` runner is fine; if you
> override `runs-on` to a `macos-*` or self-hosted runner without GNU
> findutils, module/test discovery silently returns empty and the job
> goes green without validating anything.

**Inputs**:

| Input                 | Default            | Description                                                                                                                                            |
| --------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `terraform-version`   | `~> 1.9`           | Version constraint passed to `hashicorp/setup-terraform`.                                                                                              |
| `working-directory`   | `terraform`        | Path (relative to the repo root) where the Terraform workspace lives. Use `.` for repos with `.tf` files at the root.                                  |
| `module-paths`        | *(empty)*          | Optional space-separated list of module directories (relative to `working-directory`). Missing entries emit a `::warning::` and are skipped.           |
| `pr-comment-header`   | `terraform-tests`  | Sticky-comment header. Set per-workspace if a repo calls this workflow more than once on the same PR.                                                  |
| `runs-on`             | `ubuntu-latest`    | Runner label for the job.                                                                                                                              |

**Required secrets**: none. PR comments use the default `GITHUB_TOKEN`.

**Required permissions**: declared inside the workflow (`contents: read`, `pull-requests: write` for the sticky test-result comment) — no caller-side setup needed.

Consumer `.github/workflows/terraform-ci.yaml` for the default `terraform/`-subdir layout:

```yaml
name: Terraform CI

on:
  push:
    branches: [dev]
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-ci.yaml'
  pull_request:
    branches: [dev]
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-ci.yaml'

jobs:
  terraform-ci:
    uses: peacefulstudio/github-actions/.github/workflows/terraform-ci.yaml@v1
```

For a repo that keeps Terraform at the root with explicit module paths:

```yaml
jobs:
  terraform-ci:
    uses: peacefulstudio/github-actions/.github/workflows/terraform-ci.yaml@v1
    with:
      terraform-version: '1.14.0'
      working-directory: '.'
      module-paths: 'deployments/deployment/internal deployments/deployment/customer modules/canton-node modules/postgres'
```

## Pinning

Pin to a major version tag (`@v1`) for stability. Float to the major tag
to pick up non-breaking updates automatically; pin to a SHA if you need
strict immutability.

## Access

This repo is public, so any other public repo can call its reusable
workflows directly. For **private** consumer repos in any GitHub org,
confirm this repo's access policy in **Settings → Actions → General →
Access → "Accessible from repositories in the organization"** on the
consumer side.

## Versioning

- Breaking changes bump the major tag (`v1` → `v2`).
- Non-breaking changes move the existing major tag forward.
- Full version tags (`v1.2.0`) are available for strict pinning.

## Contributing

Contributions are welcome from anywhere in the GitHub Actions / CI
ecosystem. See [CONTRIBUTING.md](CONTRIBUTING.md) for the dev setup,
the integration-test-against-a-real-consumer requirement, the
backwards-compatibility contract, and the release process. The per-PR
checklist itself lives in the PR template and is filled in when you
open a PR. By participating you agree to abide by the
[Code of Conduct](CODE_OF_CONDUCT.md).

For security-sensitive bugs, please follow [SECURITY.md](SECURITY.md) instead
of opening a public issue.

## License

Apache-2.0. © 2026 Peaceful Studio OÜ. See [LICENSE](LICENSE) and
[NOTICE](NOTICE).
