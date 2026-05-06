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
main          ← release branch (image cuts, signed builds)
  ↑ PR
development   ← integration branch (all feature work merges here)
  ↑ PR
feat/<id>-<slug> | fix/<id>-<slug> | chore/<id>-<slug>
```

### Step-by-step

1. **Open an issue first.** Describe the problem, the proposed change, and the acceptance criteria. Wait for a maintainer ack.
2. **Create a branch from `development`** using `gh issue develop <NUM> --base development --checkout`. Do not branch from `main`.
3. **One PR per issue.** Keep PRs scoped — split unrelated changes.
4. **Target `development`**, never `main`. Promotions to `main` happen via internal sync PRs.
5. **Open the PR with `Closes #<NUM>`** in the body so the issue links correctly.
6. **Stop after PR creation.** Do not continue to the next issue while a PR is open.
7. **Maintainers handle merges.** Never merge your own PR unless explicitly told to.

## Commit conventions

- **Conventional Commits** in **English**: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`, `style:`, `perf:`, `build:`.
- **No AI signatures.** No `Generated with Claude`, `Co-Authored-By: <bot>`, or similar trailers. Commits represent human accountability.
- **Short imperative subject** (≤72 chars), wrapped body explaining the *why*.
- **One logical change per commit** when feasible. Subtask checklists in issues map cleanly to one commit per subtask.

### SemVer impact (release-please)

Only three prefixes affect version bumps on `main`:

- `feat:` → MINOR bump.
- `fix:` → PATCH bump.
- Any commit with `BREAKING CHANGE:` footer → MAJOR bump.

Other prefixes (`docs:`, `chore:`, `refactor:`, etc.) are recorded in history but do not trigger a release.

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
