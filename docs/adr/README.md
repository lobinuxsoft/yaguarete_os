# Architecture Decision Records

This directory holds the Architecture Decision Records (ADRs) for YaguareteOS. ADRs document the *why* behind significant choices so future maintainers — or future-us — do not have to re-derive context that was clear at the time.

## Format

We follow the [Michael Nygard ADR format](https://github.com/joelparkerhenderson/architecture-decision-record), with a few project-specific fields. Use [`template.md`](template.md) as the starting point for new ADRs.

## When to write an ADR

Write an ADR when a decision:

- Is hard to reverse without significant cost.
- Affects more than one component or subsystem.
- Trades off two or more legitimate alternatives.
- Will be questioned six months from now ("why did we say no to X?").

Trivial choices (file naming, library imports, one-shot scripts) do not need an ADR.

## Status values

- **Proposed** — drafted but not yet adopted; under discussion.
- **Accepted** — currently in force.
- **Deprecated** — no longer in force; kept for historical context.
- **Superseded by ADR-NNNN** — replaced by a newer decision; link forward.

## Index

| ID | Title | Status | Date |
|----|-------|--------|------|
| [0001](0001-bootc-over-arch.md) | Use Bazzite / Universal Blue / bootc as the base, not Arch | Accepted | 2026-05-06 |
| [0002](0002-omakase-philosophy.md) | Omakase design — opinionated defaults, no user-facing toggles | Accepted | 2026-05-06 |
| [0003](0003-single-image-first.md) | Ship a single image first; defer multi-flavor splits to Phase 4 | Accepted | 2026-05-06 |

## Process

1. Copy `template.md` to `NNNN-short-slug.md`, where `NNNN` is the next available four-digit number.
2. Fill in the front matter, Context, Decision, Alternatives, Consequences.
3. Open a PR. The PR review *is* the ADR review.
4. Once merged, append a row to the index above in the same PR (or a follow-up).
5. If a new ADR supersedes an older one, mark the old one **Superseded by ADR-NNNN** and link forward.

ADRs are immutable once accepted. Updating an ADR means writing a new one that supersedes it, not editing the old file in place. The single exception is fixing typos or broken links.
