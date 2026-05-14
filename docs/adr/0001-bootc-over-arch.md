# 0001. Use Bazzite / Universal Blue / bootc as the base, not Arch

- **Status:** Accepted (base-choice rationale still holds). Note (2026-05-14): the "nation-grade derivative" framing used as a precedent below (Astra Linux, Pardus, Kylin) no longer applies — YaguareteOS does not pursue state-aligned scope. See README "Scope" section and #99 for the realigned framing. The technical rationale for picking bootc over Arch is unchanged.
- **Date:** 2026-05-06
- **Decided by:** lobinuxsoft
- **Supersedes:** none
- **Related:** ADR-0002, ADR-0003, issue #30, #99

## Context

YaguareteOS aims to combine three properties in a single Linux distribution:

1. **Gaming-grade** — Steam, Proton-GE, gamescope, MangoHud, GameMode, recent AMD/Mesa drivers, anti-cheat compatibility.
2. **Security-grade** — immutable root, mandatory SELinux, atomic updates, signed images, supply-chain transparency.
3. **Sovereignty-grade** — Argentine identity (locale, branding, regional packages), independence from foreign-controlled infrastructure for ourselves and our users.

Two paradigms presented themselves at the start of the project:

- **Arch + Hyprland (Omarchy style)** — rolling release, AUR ecosystem, latest kernels, popular among gaming Linux enthusiasts.
- **Image-based atomic (Fedora Atomic / bootc)** — immutable root, transactional updates, container-native delivery, the model adopted by Bazzite, Bluefin, Aurora and Universal Blue.

Nation-grade derivatives in other countries — Astra Linux (Russia, Debian-based), Pardus (Turkey, Debian-based), Kylin (China, Ubuntu-based) — all chose conservative, transactional bases over rolling distributions. They derive openly and add a national layer.

## Decision

YaguareteOS derives from **Bazzite stable** (`ghcr.io/ublue-os/bazzite:stable`), which itself derives from **Universal Blue** on top of **Fedora Atomic**. The final image is built and signed in our own CI and distributed via **GHCR** under our control.

We use **`bootc`** as the update model: users `bootc switch` to our image and rebase atomically.

## Alternatives considered

- **Arch + Hyprland (Omarchy-style).** Pros: rolling release excellent for gaming, AUR coverage, vibrant enthusiast community. Rejected: paradigm incompatible with immutability and atomic rollback; AUR is not a sovereign supply chain (depends on third-party maintainers, no signing guarantees); rolling release amplifies maintenance burden for a small national-distro team; harder to harden by default.
- **Debian derivative (Astra/Pardus/Kylin pattern).** Pros: conservative, well-trodden state-distro path. Rejected: out-of-the-box gaming experience is far behind Bazzite; would require rebuilding the gaming stack from scratch (months of work); native atomic updates are still maturing in Debian.
- **Ubuntu derivative.** Pros: more recent than Debian, larger commercial ecosystem. Rejected: same atomic-immaturity story; Snap-first defaults conflict with our preference for OCI-image-native distribution.
- **Vanilla Fedora Atomic (Kinoite / Silverblue).** Pros: the same bootc/atomic core, fewer abstraction layers above us. Rejected: would mean reimplementing Bazzite's gaming layer (Steam, Proton-GE, gamescope, MangoHud, AMD driver curation, fixes for handhelds) — 6+ months of redundant work.

## Consequences

**Positive:**
- We inherit a working, widely-tested gaming stack the day we cut our first image.
- Atomic updates and rollback (`bootc rollback`) are native — users can recover from a broken update without reinstalling.
- Image signing with `cosign` is the upstream-recommended pattern; we already have it operational (issue #17).
- Universal Blue tooling (`image-template`, `bootc-image-builder`, rechunk) gives us reproducible disk images and ISOs.
- Fedora Atomic ships SELinux in enforcing mode by default — security-grade goal partially met before we add anything.

**Negative:**
- We depend on the **Fedora upstream cycle** (six-month release cadence) and on **Bazzite's** decisions. If either project pivots in a direction incompatible with ours, we either follow, fork, or rebase to a new base.
- **Hardening agressively** (secureblue-style: hardened_malloc, kernel lockdown, AppArmor strict) **breaks gaming**. Mixing both goals into one image is impossible long-term and will force a hardened-variant split (deferred to Phase 4, see ADR-0003).
- Users who culturally prefer **rolling release** may not adopt YaguareteOS.

**Neutral / to monitor:**
- Universal Blue's governance and direction. If the community pivots, we may need to fork the upstream we currently rebase from.
- The maturity of `bootc` itself (still gaining adoption); breaking changes from upstream may force workflow adjustments.

## References

- [Bazzite](https://bazzite.gg/)
- [Universal Blue](https://universal-blue.org/)
- [bootc documentation](https://docs.fedoraproject.org/en-US/bootc/)
- [secureblue](https://github.com/secureblue/secureblue) — hardening pattern we will eventually adopt for a hardened variant
- ADR-0002 (omakase) — explains *what* we layer on top of this base
- ADR-0003 (single-image first) — explains *how many* images we ship from this base
