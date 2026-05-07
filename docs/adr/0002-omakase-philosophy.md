# 0002. Omakase design — opinionated defaults, no user-facing toggles

- **Status:** Accepted
- **Date:** 2026-05-06
- **Decided by:** lobinuxsoft
- **Supersedes:** none
- **Related:** ADR-0001, ADR-0003, issue #29, issue #30

## Context

A national distribution can take two postures toward its users:

1. **Configurability-first** — expose every choice as a toggle in System Settings or `ujust` so users can tailor everything. This is the implicit norm in many community distros: `theme picker`, `compositor switch`, `gaming-mode toggle`, `kernel selector`, etc.
2. **Opinionated defaults** — pick the right defaults, ship them, and treat configuration as the exception, not the rule.

The first posture is friendly to power users but corrosive for project identity, testing surface, and onboarding. The second is the **omakase** principle (Japanese: *I leave it to you, chef*) popularized in software by DHH (Rails) and recently adopted by **Omarchy** (DHH's Hyprland distro) as an explicit design pillar.

Constraints relevant to the choice:

- YaguareteOS is maintained by a very small team (initially one person).
- Identity matters: the distro must feel like *YaguareteOS* and not like Bazzite-with-Argentine-wallpapers.
- Testing matrix grows multiplicatively with toggles — every combination is a potential bug source.
- Onboarding cost: new users who face a wall of switches lose confidence; users who get a working OS that "just looks right" trust the project.

Issue #29 captured the principle as a manifesto/charter. This ADR formalizes the architectural commitment.

## Decision

YaguareteOS ships **opinionated defaults** for branding, theming, locale, fonts, wallpapers, gaming stack, security posture, and curated software. **No user-facing toggles** are added to surface these choices through GUI settings panels or branded CLI commands.

Power users who need to deviate have two escape hatches, **both of which are acceptable and documented**:

1. **`bootc switch`** to vanilla Bazzite (or any other compatible image) if they want a different opinionated stack.
2. **Fork the repository** and customize their own derivative — sovereignty cuts both ways.

Toggles for **transient runtime state** (volume, brightness, network, etc.) are obviously not affected by this rule — only choices that define the project's identity.

## Alternatives considered

- **System Settings panel with toggles for everything.** The Universal Blue and KDE/GNOME defaults give us this for free. Rejected because it conflicts with identity and multiplies the test matrix; YaguareteOS would become a configurability layer over Bazzite rather than its own thing.
- **`ujust yaguarete-*` commands for fine-tuning.** A middle ground: power users opt in via CLI, casual users see opinionated defaults. Partially accepted in spirit (issue #26 plans `ujust` commands) but only for *one-shot tasks* (e.g. install a Steam beta), not for *flipping identity defaults*.
- **Per-flavor opinions (gaming/desktop/handheld variants each with different defaults).** Closer to the multi-image strategy. Deferred — see ADR-0003.

## Consequences

**Positive:**
- Project identity stays coherent across releases. Users describe YaguareteOS in terms of *what it is*, not *what we let them tweak*.
- Test surface is bounded. We test one configuration, not 2^N.
- Onboarding is faster: install, log in, things work the way we intended.
- The omakase posture is a **design constraint that disciplines PR review** — every proposal that adds a toggle must justify itself against this ADR.

**Negative:**
- **Power users churn out.** Some will rebase to vanilla Bazzite or fork. We accept this; it is the cost of identity.
- **PR review cost** — contributors will inevitably propose toggles in good faith and need to be redirected to the escape hatches above. Issue/PR templates already mention this constraint.
- **Cultural cost** — the Linux community defaults to "configurability is good"; we will need to defend the omakase choice publicly when criticized.

**Neutral / to monitor:**
- If a toggle gets proposed often enough, that is a signal the default is wrong, not that the omakase principle is wrong. The fix is to **change the default**, not to add the toggle.
- ADR-0003's eventual multi-flavor split partially relaxes this constraint along the *flavor* axis (gaming vs hardened can have different opinions). The flavor axis is a *small finite set*, not a per-user toggle.

## References

- DHH on Omakase (Rails): <https://dhh.dk/2012/rails-is-omakase.html>
- [Omarchy](https://omarchy.org/)
- Issue #29 — Establish omakase design principle
- ADR-0001 (base choice)
- ADR-0003 (single-image first; flavor splits as the only allowed deviation axis)
