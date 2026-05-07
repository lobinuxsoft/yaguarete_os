# 0003. Ship a single image first; defer multi-flavor splits to Phase 4

- **Status:** Accepted
- **Date:** 2026-05-06
- **Decided by:** lobinuxsoft
- **Supersedes:** none
- **Related:** ADR-0001, ADR-0002, issues #22, #23, #24, #25, #30

## Context

Universal Blue ships several flavors of Bazzite (desktop, deck, asus, nvidia, gnome, kde, ...). The temptation when starting YaguareteOS is to mirror that taxonomy from day one: a handheld variant for OneXFly / Steam Deck, an NVIDIA variant for desktops without AMD, a hardened variant inspired by secureblue.

Each variant is a multiplier on:

- **Build cost** — every push fans out into N image builds, N signing operations, N storage layers in GHCR.
- **Test surface** — combinations of variant × hardware × kernel × packages explode quickly.
- **Documentation burden** — install instructions, rebase paths, and troubleshooting must cover all variants.
- **Maintenance cognitive load** — issues, PRs and bug reports need to be triaged by variant.

Constraints relevant to the choice:

- The team is initially one person.
- We do not yet have telemetry telling us which hardware our users actually run.
- The Phase 1 / Phase 2 work (identity, locale, branding, national layer) is **shared by all variants** and gets done once regardless. Splitting before that work is finished spreads it thin.
- ADR-0001 anticipates that hardening (secureblue-style) is incompatible with gaming and *will* eventually force a split. That tension exists, but it is not pressing today.

## Decision

YaguareteOS ships **a single image** during Phase 0 through Phase 3. Multi-flavor splits are **deferred to Phase 4** (issues #22 through #25), where they will be evaluated against actual user feedback, hardware data, and the security/gaming tension.

The first variant we will split, when the time comes, is most likely **a hardened desktop variant** (issue #25), because hardening genuinely cannot coexist with gaming in the same image.

Other potential splits — handheld (#23), NVIDIA (#24) — require evidence that the single image cannot serve those users adequately *before* we accept the maintenance cost.

## Alternatives considered

- **Multi-image from day one (gaming/desktop/handheld/nvidia/hardened).** Mirrors Bazzite's taxonomy. Rejected: 5× build matrix, 5× test surface, 5× documentation. We do not have the team or the user-data justification for this cost yet.
- **Single binary with runtime feature flags.** A "smart image" that detects the host (handheld vs desktop, NVIDIA vs AMD) and adapts. Rejected: conflicts directly with ADR-0002 (omakase, no toggles). Runtime branching is a configurability surface in disguise, just hidden from users.
- **Per-customer / per-org forks.** Maintained downstream forks for institutions. Rejected: not our distribution model. Sovereignty for *individual users*, not B2B customization.
- **Defer everything until Phase 4 with no Phase 0–3 image at all.** Rejected: we need a working signed image *now* to validate the pipeline, attract early adopters, and bootstrap the project narrative.

## Consequences

**Positive:**
- **Focus.** The Phase 1 / Phase 2 work (identity, locale, branding, national layer) lands in one image and ships to everyone.
- **Sustainable maintenance.** One image, one CI lane, one set of bug reports.
- **Faster iteration.** Decisions about the OS apply uniformly; we are not negotiating across variants.
- **Cheap reversal.** Splitting later is straightforward — Bazzite already demonstrates the pattern. Splitting too early is hard to undo without disappointing users.

**Negative:**
- **Hardware-specific users wait.** OneXFly users get a working but generic image instead of a tuned handheld image. We accept that gap during Phase 0–3.
- **The gaming-vs-hardening tension exists from day one.** As long as we ship one image, we cannot harden aggressively without breaking gaming, and we cannot enable gaming defaults that hurt security posture. We pick gaming because it is the more visible promise; hardening waits for the split.
- **NVIDIA users are second-class** during the single-image phase (the base inherits Bazzite's AMD-first defaults).

**Neutral / to monitor:**
- **Trigger for splitting** — we split a flavor when keeping it inside the single image *demonstrably hurts* either the flavor or the rest of the users. "Demonstrably" means: a real, recurring complaint or a measurable test-matrix problem, not a hypothetical.
- **Order of splits when triggered** — hardened first (security posture incompatibility), handheld second if generic-image gaps surface on Steam Deck / OneXFly, NVIDIA third if AMD-only defaults cause regressions for NVIDIA users.

## References

- Issue #22 — Decision: single image vs multi-image strategy
- Issue #23 — Handheld flavor
- Issue #24 — NVIDIA variant
- Issue #25 — Hardened desktop variant
- ADR-0001 — bootc/Bazzite base, anticipates hardening-vs-gaming tension
- ADR-0002 — omakase (rejects runtime feature flags as a substitute for explicit flavor splits)
