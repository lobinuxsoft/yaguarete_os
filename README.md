# YaguareteOS

A bootable, image-based Linux distribution built on top of [Bazzite](https://bazzite.gg/) using the [Universal Blue](https://universal-blue.org/) toolchain.

YaguareteOS combines:

- **Gaming-ready base** — inherits Steam, Proton-GE, GameMode, gamescope, MangoHud and the latest AMD/Mesa drivers from Bazzite.
- **Image-based atomic updates** — built on `bootc`. Rebase, rollback, and reproducible builds out of the box.
- **Sovereign supply chain** — built and signed in our own CI; rebase URL points to our own OCI registry (`ghcr.io/lobinuxsoft/yaguarete_os`).
- **Argentine identity** — branding, wallpapers, locale `es-AR` and (eventually) regional packages.

## Status

Early scaffolding. Project pivoted from Archiso to Universal Blue / bootc on 2026-05-06.

## Lineage and upstream attribution

YaguareteOS does not hide its lineage. We derive from [Bazzite](https://bazzite.gg/) (Apache 2.0), which itself derives from [Universal Blue](https://universal-blue.org/) on top of Fedora Atomic, and we keep upstream references explicit throughout this repository.

**Why we attribute openly.** Digital sovereignty is about controlling the *pipeline* — signing keys, build infrastructure, distribution registry, governance, branding — not about hiding technical inheritance. Nation-grade derivatives such as Astra Linux (Debian), Pardus (Debian) and Kylin (Ubuntu) all attribute upstream openly; we follow the same principle. Honesty about what we inherit is what allows users to audit and trust what we add.

**What is sovereign in YaguareteOS:**

- The build pipeline (our CI, our runners, our policies).
- The signing keypair (`cosign.pub` in this repo, private key offline).
- The distribution registry (`ghcr.io/lobinuxsoft/yaguarete_os`).
- Branding, locale, theming and curated software layer.
- Project governance, roadmap, and release cadence.

**What is inherited and credited:**

- Base image: Bazzite stable.
- Build system and project layout: Universal Blue `image-template`.
- Atomic update model: `bootc`, Fedora Atomic.
- Gaming stack: Steam, Proton-GE, GameMode, gamescope, MangoHud, Mesa.

## Build locally

Requires `just`, `podman` and a bootc-capable host (Bazzite, Bluefin, Aurora, or Fedora Atomic).

```bash
just build           # build the container image locally
just run-vm-qcow2    # boot the image in a VM via bootc-image-builder
```

See `Justfile` for the full task list.

## Structure

```
Containerfile             FROM bazzite:stable + overlay system_files/ + run build_files/build.sh
build_files/build.sh      package installs and systemd unit enables (runs inside the build)
system_files/             overlay copied verbatim into the image rootfs (wallpapers, configs)
disk_config/              bootc-image-builder TOMLs for ISO / qcow2 / raw outputs
.github/workflows/        CI: build container + build disk images
docs/adr/                 Architecture Decision Records (the *why* behind major choices)
Justfile                  task runner (build, test, run-vm, clean, etc.)
```

## Rebase from an existing bootc system

```bash
sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os:latest
```

## Verifying image signatures

All images published to `ghcr.io/lobinuxsoft/yaguarete_os` are signed with [`cosign`](https://github.com/sigstore/cosign). The public key (`cosign.pub`) lives at the root of this repository.

```bash
# Verify the latest image
cosign verify \
  --key https://raw.githubusercontent.com/lobinuxsoft/yaguarete_os/main/cosign.pub \
  ghcr.io/lobinuxsoft/yaguarete_os:latest
```

A successful verification means the image was built and signed by the official YaguareteOS CI pipeline. If verification fails, do not rebase to that image.

## Architecture decisions

Significant choices about the project — base image, design philosophy, image variants — are documented as Architecture Decision Records under [`docs/adr/`](docs/adr/). Start with the [ADR index](docs/adr/README.md) for the catalog and the rationale behind each entry.

## License

Apache License 2.0 — see `LICENSE`.

---

*Yaguareté: the largest feline of South America, a national symbol of Argentine wildlife.*
