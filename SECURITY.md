# Security Policy

YaguareteOS treats supply chain integrity and responsible disclosure as first-class concerns. This document explains how to report vulnerabilities and how to verify that the image you booted is the one we published.

## Reporting a vulnerability

**Do not open a public issue for security-sensitive reports.** Public issues expose users before a fix is available.

Use one of the following private channels:

1. **Preferred — GitHub Security Advisories:**
   [`github.com/lobinuxsoft/yaguarete_os/security/advisories/new`](https://github.com/lobinuxsoft/yaguarete_os/security/advisories/new)

2. **Fallback — email:** `lobinuxsoft@gmail.com`
   Subject: `[YaguareteOS Security] <short summary>`

When reporting, please include:

- Affected image tag(s) (`:latest`, `:vX.Y.Z`) or commit SHA.
- Reproduction steps or proof-of-concept.
- Impact assessment (what an attacker can achieve).
- Your suggested severity (informational / low / medium / high / critical).
- Whether you would like public credit in the eventual advisory.

## Response expectations

- **Acknowledgement:** within 72 hours of receipt.
- **Triage:** initial severity assessment within 7 days.
- **Fix or mitigation timeline:** communicated after triage. Critical issues are prioritized.
- **Coordinated disclosure:** we publish a GitHub Security Advisory with credit (unless you opt out) once a fix is available.

This is a small, early-stage project maintained on a best-effort basis. We will be transparent if a report exceeds our capacity to address it quickly.

## Scope

In scope:

- The OCI image at `ghcr.io/lobinuxsoft/yaguarete_os` and any signed tags.
- The build pipeline under `.github/workflows/`.
- The `cosign` signing flow and key management documented in this repo.
- Files committed to this repository (`Containerfile`, `build_files/`, `system_files/`, `disk_config/`).

Out of scope:

- Vulnerabilities inherited from upstream Bazzite, Universal Blue, Fedora Atomic, or the Linux kernel — those should be reported to their respective projects.
- Vulnerabilities in third-party packages installed at build time — report upstream first; we will track downstream impact once a CVE exists.

## Verifying image integrity

Every image published to `ghcr.io/lobinuxsoft/yaguarete_os` is signed with [`cosign`](https://github.com/sigstore/cosign) using the keypair documented in [`cosign.pub`](cosign.pub). The private key is held offline by the maintainer.

```bash
cosign verify \
  --key https://raw.githubusercontent.com/lobinuxsoft/yaguarete_os/main/cosign.pub \
  ghcr.io/lobinuxsoft/yaguarete_os:latest
```

A successful verification means:

- The image was built and signed by the official YaguareteOS CI pipeline.
- The signature is recorded in the public Rekor transparency log (Sigstore).
- The image manifest digest matches what was signed.

**If verification fails, do not rebase to that image.** Open a Security Advisory immediately so we can investigate registry tampering or pipeline compromise.

## Cryptographic key rotation

If we suspect the cosign private key has been compromised, the rotation procedure is:

1. Generate a new keypair offline.
2. Publish the new `cosign.pub` to `main` in a clearly-marked commit.
3. Issue a Security Advisory announcing the rotation, the date, and the last image signed by the old key.
4. Sign all subsequent builds with the new key.

Users should re-pin their verification step to the new public key from `main` after each rotation announcement.

## Disclosure track record

No advisories published yet (project initiated 2026-05-06).
