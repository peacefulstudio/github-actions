# Contributing to github-actions

Thanks for your interest. This document covers everything you need to send a
patch — from cloning the repo to getting your PR merged.

## Code of Conduct

By participating in this project you agree to abide by the
[Code of Conduct](CODE_OF_CONDUCT.md).

## What lives here

This repo only ships **reusable GitHub Actions workflows** (under
`.github/workflows/`). Every workflow declares `on: workflow_call` and is
designed to be called by other repos via
`uses: peacefulstudio/github-actions/.github/workflows/<file>.yaml@<ref>`.

There is no source code to build or unit-test. Changes are validated by:

1. **`actionlint`** locally before pushing — catches YAML schema errors,
   shell-quoting bugs, and undefined contexts.
2. **A test consumer PR** — the only realistic integration test is
   pointing a real consumer repo at your branch and watching its CI run.

## Getting set up

```bash
git clone https://github.com/peacefulstudio/github-actions.git
cd github-actions
git checkout dev
```

You'll need:

- [`actionlint`](https://github.com/rhysd/actionlint) (`brew install actionlint`)
- [`gh`](https://cli.github.com/) for opening PRs and triggering test runs

## Branching model

| Branch  | Purpose                                  |
|---------|------------------------------------------|
| `dev`   | Default branch — open PRs here           |

All PRs target `dev`. Releases are cut as **tags** (`v1.X.Y` immutable +
moving `vN` major); see [Release process](#release-process) below.

## Making a change

1. **Branch from `dev`**:
   ```bash
   git fetch origin
   git checkout -b feat/<short-description> origin/dev
   ```
2. **Edit the workflow** under `.github/workflows/`. Keep the contract:
   every reusable workflow file must include `on: workflow_call` at the
   top, and inputs/secrets must be explicit (no environment-specific
   defaults baked in).
3. **Run `actionlint`** on every touched file:
   ```bash
   actionlint .github/workflows/<file>.yaml
   ```
4. **Cross-check against the
   [CI hardening rules](https://github.com/peacefulstudio/peaceful-skills/blob/main/oss-prep/references/ci-hardening.md)**
   — particularly: no `@latest` for installed tools, SHA-pin every
   third-party action outside `actions/*` and `github/*`, fork-PR token
   guard on any write-API step, `set -euo pipefail` in multi-line bash
   blocks.
5. **Integration test with a real consumer.** Push your branch and point
   one of the [Known consumers](./CLAUDE.md#known-consumers) (or a
   throwaway test repo) at your ref:
   ```yaml
   uses: peacefulstudio/github-actions/.github/workflows/<file>.yaml@<your-branch>
   ```
   Open a draft PR on the consumer side and verify the workflow runs
   green there before requesting review here.

## Backwards-compatibility contract

Consumers pin to one of three reference forms:

- **Moving major** (`@v1`) — most consumers. Any merge to `dev` that you
  intend to ship moves this tag, so **internal changes must remain
  contract-compatible**: same inputs (same names, same types, same
  defaults), same outputs, same secret expectations.
- **Immutable version** (`@v1.2.0`) — consumers pinning for
  reproducibility. Never re-point an existing version tag once it's
  been pushed (the only exception is the release-cut described below).
- **Branch ref** (`@dev`) — only used in test PRs, never in production.

**Breaking changes** (renamed/removed inputs, changed semantics, new
required secrets) require a major version bump: tag a new `vN+1` and
update the README to call out the migration.

## Opening a pull request

External contributors usually don't have write access to
`peacefulstudio/github-actions`, so the PR flow goes through a fork:

1. Fork `peacefulstudio/github-actions` to your own GitHub account.
2. Clone your fork and add the upstream as a second remote:
   ```bash
   git clone https://github.com/<your-username>/github-actions.git
   cd github-actions
   git remote add upstream https://github.com/peacefulstudio/github-actions.git
   ```
3. Create a feature branch from `dev`:
   ```bash
   git fetch upstream
   git checkout -b feat/<short-description> upstream/dev
   ```
4. Commit using the [Conventional Commits](https://www.conventionalcommits.org/)
   format (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`,
   `ci:`).
5. Push the branch to your fork and open a PR targeting `peacefulstudio/github-actions`'s `dev`:
   ```bash
   git push -u origin feat/<short-description>
   gh pr create --repo peacefulstudio/github-actions --base dev
   ```
6. Fill out the PR template — explicitly call out any change to a
   workflow's `inputs`, `secrets`, or `outputs` signature.
7. Make sure your consumer-side test PR run links from the PR body so a
   reviewer can see the workflow worked end-to-end.

(Maintainers with direct write access can skip the fork step.)

For user-visible changes, add an entry to the `[Unreleased]` section of
[`CHANGELOG.md`](CHANGELOG.md). Skip this for purely internal refactors
of comments/whitespace and dependency bumps that don't alter behaviour.

## Release process

After your PR merges to `dev`:

1. Maintainer tags the merge commit:
   ```bash
   git tag -a v1.X.Y -m "..."
   git tag -fa v1 -m "Latest v1 (= v1.X.Y)"
   git push origin v1.X.Y v1 --force   # vN moves; v1.X.Y is fresh
   ```
2. Update the README's "Available workflows" section if any input/output
   contract changed.
3. Notify the consumers listed in [CLAUDE.md](CLAUDE.md#known-consumers)
   if the change requires their attention.

## Reporting bugs

Open an issue using the "Bug report" template. The more reproducible the
report, the faster the fix — link the failing workflow run if you can.

For security-sensitive bugs, **do not open a public issue** — see
[SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions will be licensed under the
[Apache License 2.0](LICENSE), the same license as the project. No CLA
required.
