# Contributing to YaguareteOS

Thanks for your interest in YaguareteOS. This document defines how the project is developed and how external contributions are handled.

## Current contribution policy

YaguareteOS is in **early scaffolding**. External contributions are intentionally restricted while the foundations stabilize:

- **Repository interaction-limits are active** until **2026-05-13** (`collaborators_only`). After that date, the policy will be reviewed and either lifted, narrowed, or extended.
- **Drive-by PRs without prior issue discussion will be closed.** Open an issue first, get a green light, then submit.
- Contributions that bypass the workflow below — even when well-intentioned — will be rejected on procedural grounds.

We will open the door wider once the project has stable governance, a public roadmap with `good first issue` markers, and reproducible local builds. We are not there yet.

## Workflow

The branch model is strict and non-negotiable:

```
testing       ← stable channel (image cuts, signed builds, :stable tag)
  ↑ promotion PR (manual, post smoke-validation)
unstable      ← rolling integration branch (all feature work merges here, :unstable tag)
  ↑ PR
feat/<id>-<slug> | fix/<id>-<slug> | chore/<id>-<slug>
```

### Step-by-step

1. **Open an issue first.** Describe the problem, the proposed change, and the acceptance criteria. Wait for a maintainer ack.
2. **Create a branch from `unstable`** using `gh issue develop <NUM> --base unstable --checkout`. Do not branch from `testing`.
3. **One PR per issue.** Keep PRs scoped — split unrelated changes.
4. **Target `unstable`**, never `testing`. Promotions to `testing` happen via maintainer-opened PRs after the build is smoke-validated.
5. **Open the PR with `Closes #<NUM>`** in the body so the issue links correctly.
6. **Stop after PR creation.** Do not continue to the next issue while a PR is open.
7. **Maintainers handle merges.** Never merge your own PR unless explicitly told to.

## Commit conventions

- **Conventional Commits** in **English**: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`, `style:`, `perf:`, `build:`.
- **No AI signatures.** No `Generated with Claude`, `Co-Authored-By: <bot>`, or similar trailers. Commits represent human accountability.
- **Short imperative subject** (≤72 chars), wrapped body explaining the *why*.
- **One logical change per commit** when feasible. Subtask checklists in issues map cleanly to one commit per subtask.

### Channels and promotion (Bazzite model)

Two long-running branches, three GHCR channels:

- `unstable` → `:unstable` — rolling integration channel. Every PR merge triggers a container + ISO build.
- `testing` → `:testing` — pre-release channel. Manual PR `testing ← unstable` opened when a smoke build is ready.
- (promoted) → `:stable` / `:latest` — validated release channel. **Never built**, only promoted by digest from a chosen `:testing` tag via [`retag.yml`](.github/workflows/retag.yml).

#### Tag format (Bazzite-literal)

`<channel>-<fedora>.<YYYYMMDD>[.N]`

The `<fedora>.<YYYYMMDD>` suffix is **not invented locally** — it is read from the `org.opencontainers.image.version` label of `ghcr.io/ublue-os/bazzite:stable` at build time, so YaguareteOS stays in lockstep with Bazzite's actual Fedora cadence. The `.N` collision suffix only appears when rebuilding the same upstream tag on the same day.

Rolling pointers always exist alongside the dated tags:

- `:unstable`, `:unstable-<fedora>` — newest unstable build of that Fedora major.
- `:testing`, `:testing-<fedora>` — newest testing build.
- `:stable`, `:stable-<fedora>`, `:latest` — current promoted stable.

#### Cadence

- **`:unstable`** — pushes to `unstable` always rebuild. A daily cron (`0 5 * * *` UTC) also runs but the [`check_upstream`](.github/workflows/build.yml) gate skips the build when Bazzite's `:stable` digest has not changed since our last unstable build. Worst-case latency vs upstream: ~24h.
- **`:testing`** — pushes to `testing` rebuild on demand. No cron — `testing` is only updated by a maintainer-opened promotion PR.
- **`:stable`** — manual two-step promotion:
  1. Run [`retag.yml`](.github/workflows/retag.yml) with the `:testing-<fedora>.<YYYYMMDD>` tag to promote. This re-points the digest to `:stable`, `:stable-<fedora>`, `:stable-<fedora>.<YYYYMMDD>` and `:latest` without rebuilding.
  2. Run [`generate_release.yml`](.github/workflows/generate_release.yml) to publish the matching git tag + GitHub Release with auto-generated notes.

There is no auto-promotion cron. Stable always requires a human button-press, by design.

#### Retention

GHCR is cleaned weekly by [`clean.yml`](.github/workflows/clean.yml) (Sundays 00:15 UTC): tags older than 90 days are deleted, keeping the most recent 7 tagged and 7 untagged manifests regardless of age.

#### Client auto-update default

`/etc/rpm-ostreed.conf` keeps `AutomaticUpdatePolicy=check` (the upstream Bazzite default). The bootc layer is notified of new images but the user decides when to deploy. Not changing this without an explicit decision tracked in an issue.

Conventional Commits (`feat:`, `fix:`, `chore:`, etc.) are kept for readability and grep-ability of history, but no longer drive automatic version bumps — release-please has been removed (Bazzite does not use it).

### Anti-patterns rejected

- Force-pushing to shared branches.
- Squash merges (they break git graph connectivity and lose branch history). We always use `--merge`.
- Amending merged commits.
- Commits that mix feature + refactor + style changes.
- PRs without an attached issue.

## Local development

Requirements: `just`, `podman`, and a bootc-capable host (Bazzite, Bluefin, Aurora, or Fedora Atomic).

```bash
just build           # build the container image locally
just run-vm-qcow2    # boot the image in a VM via bootc-image-builder
```

See `Justfile` for the full task list.

## Reporting issues

- **Bugs:** use the **Bug report** issue template.
- **Features / ideas:** use the **Feature request** template.
- **Security vulnerabilities:** **do not file public issues.** See [`SECURITY.md`](SECURITY.md) for the disclosure process.

## Code of Conduct

All participants — contributors, issue authors, reviewers — are expected to follow the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). Violations will be enforced.

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).
