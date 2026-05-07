# 0002. Omakase design — editorial stance on what the image ships

- **Status:** Accepted
- **Date:** 2026-05-07
- **Decided by:** lobinuxsoft
- **Supersedes:** none
- **Related:** ADR-0001, ADR-0003, issue #29, issue #30

## Context

In a **mutable distribution** (Arch, Ubuntu) "omakase" is a *defensive* posture: the maintainer picks defaults knowing the user can mutate the system arbitrarily with `pacman -S`, `apt install`, AUR helpers, or third-party PPAs. The chosen defaults are a *starting point*, not the product. Hiding toggles is a way to nudge new users toward the intended experience while accepting they will eventually leave the rails.

YaguareteOS, however, is built on **bootc / Fedora Atomic** (ADR-0001). The constraints there are different:

- `/usr` is **immutable**. Users cannot mutate the base image without `bootc switch` (whole-image rebase) or `rpm-ostree` layering (explicit, requires reboot).
- Personalisation lives in `~/`, Flatpak, and ujust.
- The image **is** the defaults. There is no "base + your config" — there is only "the image we shipped".
- `bootc switch` to a different image is a **first-class feature**, not an escape hatch.

So the question "should we be omakase?" has to be split into two: omakase about *what we put in the image* (still meaningful, very much our job), and omakase about *restricting what users can change at runtime* (largely answered for us by the bootc model).

Issue #29 captured the principle as a manifesto. This ADR formalises the architectural commitment in the form that actually applies to an immutable image.

## Decision

YaguareteOS treats the image as an **edited product**, not a configuration substrate. The maintainer's job is curation, not configurability. Concretely:

**What we curate (omakase applies):**

- The set of system packages installed in the image.
- The default configuration files shipped under `/etc` (theme, locale, login manager, gamescope-session config, etc.).
- The set of `ujust yaguarete-*` commands — a *small, reviewed* catalogue of one-shot tasks (install Steam beta, run a hardware diagnostic). Adding a `ujust` is a curation decision.
- The default Flatpak set we suggest at first boot, if any.
- Branding everywhere it appears (Plymouth, login greeter, wallpaper, theme palette, fonts).

**What we deliberately do not add (omakase guards against):**

- `gnome-tweaks`-style "tweaks" tools whose only purpose is to surface configurability that contradicts our defaults.
- Custom GUI panels with toggles for our identity choices (theme picker, accent picker, "gaming mode" switch, etc.).
- Hidden environment-variable knobs that flip behaviour from our intended path.
- Branded "settings" surfaces that duplicate or override the upstream KDE / GNOME ones.

**What we leave alone (omakase does not apply):**

- KDE / GNOME upstream Settings panels. Removing them would break the desktop environment and is not our fight.
- `bootc switch` to a different image — first-class user freedom, by design.
- `rpm-ostree install <pkg>` layering — first-class user freedom, by design.
- Flatpak install of any application — userland is the user's space.
- Anything under `~/` — out of scope for a system image.

## Alternatives considered

- **Aggressive omakase ("strip everything that lets users deviate").** Remove tweaks tools, hide upstream settings panels, restrict layering through `bootc` configuration. Rejected: fights with KDE / GNOME upstream and with the bootc model itself. The cost in upstream divergence is higher than the gain in identity coherence.
- **Configurability-first ("expose every default as a toggle for power users").** Add custom Settings panels and `ujust` commands for every identity choice. Rejected: dilutes identity, multiplies test surface, and produces the *Bazzite-with-Argentine-wallpapers* outcome that Issue #29 was created to prevent.
- **Per-flavor opinions (different identity per variant).** Gaming variant, hardened variant, handheld variant each with their own opinionated defaults. Deferred — see ADR-0003. The *flavor axis* is the only sanctioned way to deviate from the single-image opinion.
- **MANIFESTO.md instead of an ADR.** A separate proclamation document. Rejected: ADRs are auditable, indexed, supersede-able. A manifesto would duplicate this content with less rigour.

## Consequences

**Positive:**
- Project identity stays coherent across releases. Users describe YaguareteOS in terms of *what it is*, not *what we let them tweak*.
- Test surface is bounded. We test one curated image per flavor, not 2ⁿ toggle combinations.
- Onboarding is faster: install, log in, things work the way we intended.
- The omakase posture is a **design constraint that disciplines PR review.** Every proposal that adds a tweak tool, a custom toggle panel, or a "configure X" `ujust` must justify itself against this ADR.
- Compatible with bootc culture: we do not fight `bootc switch` or layering — we trust the platform's escape hatches and curate within them.

**Negative:**
- **PR review cost.** Contributors will propose toggles in good faith ("Steam users want gaming-mode switch"). They need to be redirected toward either *changing the default* or *opening a flavor split* (ADR-0003). Issue / PR templates already flag this expectation.
- **Cultural friction.** The Linux community defaults to "configurability is good"; we will sometimes need to defend the omakase choice publicly.
- **Risk of stale defaults.** Without toggles, a wrong default hurts everyone equally. We mitigate this by treating "many users want X" as a signal to *change the default*, not to add a toggle.

**Neutral / to monitor:**
- The flavor axis (ADR-0003) is the explicit pressure valve. If demand for divergent identity is strong enough to justify a maintenance multiplier, the answer is a new flavor, not a runtime toggle.
- `ujust yaguarete-*` is a curation surface, not a configuration surface. The line is: ujust commands perform *actions* (install Steam beta, diagnose audio); they do not *flip identity defaults* (theme, branding, locale).

## References

- DHH on Omakase (Rails): <https://dhh.dk/2012/rails-is-omakase.html>
- [Omarchy](https://omarchy.org/) — adopted omakase as an explicit design pillar
- [bootc documentation](https://docs.fedoraproject.org/en-US/bootc/) — defines the immutable-image platform we curate within
- Issue #29 — Establish omakase design principle
- ADR-0001 — base choice (defines the immutable platform)
- ADR-0003 — single-image first (flavor splits as the only sanctioned deviation axis)
