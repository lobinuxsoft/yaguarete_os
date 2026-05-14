# YaguareteOS

A bootable, image-based Linux distribution built on top of [Bazzite](https://bazzite.gg/) using the [Universal Blue](https://universal-blue.org/) toolchain.

YaguareteOS combines:

- **Gaming-ready base** — inherits Steam, Proton-GE, GameMode, gamescope, MangoHud and the latest AMD/Mesa drivers from Bazzite.
- **Image-based atomic updates** — built on `bootc`. Rebase, rollback, and reproducible builds out of the box.
- **Sovereign supply chain** — built and signed in our own CI; rebase URL points to our own OCI registry (`ghcr.io/lobinuxsoft/yaguarete_os`).
- **Argentine cultural identity** — Guaraní naming (Yaguareté, Yryvu), Spanish-first defaults, `es-AR` locale, native wallpapers. *Cultural*, not governmental: no state-identity / fiscal / control tooling is bundled.

## Status

Early scaffolding. Project pivoted from Archiso to Universal Blue / bootc on 2026-05-06.

## Lineage and upstream attribution

YaguareteOS does not hide its lineage. We derive from [Bazzite](https://bazzite.gg/) (Apache 2.0), which itself derives from [Universal Blue](https://universal-blue.org/) on top of Fedora Atomic, and we keep upstream references explicit throughout this repository.

**Why we attribute openly.** Digital sovereignty here means controlling the *pipeline* — signing keys, build infrastructure, distribution registry, project governance, branding — not hiding technical inheritance. Sibling Universal Blue derivatives such as [Bluefin](https://projectbluefin.io/) and [Aurora](https://getaurora.dev/) attribute upstream openly; we follow the same principle. Honesty about what we inherit is what allows users to audit and trust what we add.

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

## Scope: what YaguareteOS is and is not

**Is** a free, image-based, gaming-and-development-first KDE distribution with Argentine cultural identity at the surface. Optimised for desktop and handheld play, dev tooling, and privacy-respecting defaults. Argentine because the maintainer is Argentine — Guaraní project naming, Spanish-first UI, AR locale, native wallpapers.

**Is not** a state-aligned platform. YaguareteOS deliberately does **not** ship:

- Government-issued root certificates or trust-store extensions (ONTI, etc.).
- Pre-installed shortcuts or apps tied to state identity, fiscal control, social registries or surveillance pipelines (AFIP, ANSES, Mi Argentina, billetera estatal, etc.).
- Mirrors hosted on state infrastructure as the canonical pull path.
- Compliance tooling that requires user identification to use the OS.

Privacy and freedom take precedence over locale compliance. If you want those integrations, fork — the model exists for exactly that. The maintainer's roadmap stays on dev + gaming + privacy, with a hardened variant ([#25](https://github.com/lobinuxsoft/yaguarete_os/issues/25)) as the natural escalation for security-conscious users.

## Build locally

Requires `just`, `podman` and a bootc-capable host (Bazzite, Bluefin, Aurora, or Fedora Atomic).

### Host pre-requisites

Verified on **Bazzite Stable F43**. Other bootc hosts should work but are untested.

- `just` >= 1.47
- `podman` >= 5.8
- Sudo access — the `bootc-image-builder` step writes its output as root inside a `--privileged` container
- ~17 GB free disk — ~12 GB for the OCI image (in podman storage) and ~5 GB for the qcow2 (sparse; peaks higher mid-build)
- Storage on a real POSIX filesystem (btrfs / ext4 / xfs). NTFS via `fuseblk` is **not** supported — qcow2 generation requires real ownership, sparse files and extended attributes
- A graphical session (X11 or Wayland) for `run-vm-qcow2` — it opens a QEMU window

### Workflow

```bash
just build           # build OCI image  -> localhost/yaguarete_os:latest
just build-qcow2     # build VM disk    -> output/qcow2/disk.qcow2
just run-vm-qcow2    # boot the qcow2 in a QEMU VM
```

`just build-qcow2` pulls `quay.io/centos-bootc/bootc-image-builder:latest` (~500 MB) on first run. Subsequent builds reuse the cached builder.

Total time on a Ryzen-class workstation with NVMe: ~6 min for `build`, ~5 min for `build-qcow2`.

See `Justfile` for the full task list (ISO, raw, rebuild variants, `spawn-vm` via systemd-vmspawn for headless hosts).

### Troubleshooting

**Sudo password prompt at the end of `build-qcow2`.** Expected. The `_build-bib` recipe ends with `sudo mv -f` to relocate root-owned output from the privileged container into `output/`. Enter your password when prompted.

**`run-vm-qcow2` fails to open a window over SSH.** No graphical session attached. Use `just spawn-vm` (systemd-vmspawn) for headless boot, or run from a local TTY with `$DISPLAY` / `$WAYLAND_DISPLAY` set.

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

If you already run a `bootc`-based system (Bazzite, Bluefin, Aurora, or any Fedora Atomic image), you can rebase to YaguareteOS without reinstalling.

> **Phase 0 caveat.** The image today is functionally Bazzite with our pipeline, signing key and registry. Argentine branding (logo, Plymouth, theme, locale defaults) lands in Phase 1. If you rebase now, expect a Bazzite-looking desktop until those issues close.

### Prerequisites

- A working `bootc` system (run `sudo bootc status` to confirm).
- Root access on the target host.
- Network access to `ghcr.io` and `raw.githubusercontent.com`.
- `cosign` available (`rpm-ostree install cosign` if missing, then reboot).

### Variant selection

YaguareteOS ships four KDE variants. Pick the one that matches your hardware:

| Image                              | When to use                                                       | Upstream base               |
|------------------------------------|-------------------------------------------------------------------|-----------------------------|
| `yaguarete_os`                      | AMD / Intel desktop. Default for most users.                       | `bazzite:stable`            |
| `yaguarete_os-nvidia`               | NVIDIA GPU with the proprietary driver.                            | `bazzite-nvidia:stable`     |
| `yaguarete_os-nvidia-open`          | NVIDIA GPU with the open kernel module (Turing+, server use).      | `bazzite-nvidia-open:stable`|
| `yaguarete_os-deck`                 | Handheld (Steam Deck, OneXFly, ROG Ally) — boots into game mode.   | `bazzite-deck:stable`       |

GNOME variants are intentionally not offered; this is a KDE-only project. NVIDIA via `nouveau` is not a separate variant — users on NVIDIA hardware should pick `-nvidia` or `-nvidia-open` and stay there.

### Tag selection

Within each variant, three channels are available:

| Tag         | When to use                                                                                |
|-------------|--------------------------------------------------------------------------------------------|
| `:stable`   | **Recommended.** Latest validated build (manually promoted from `testing`). What you want for daily use. |
| `:testing`  | Rolling tip of `testing`. Pre-release validation.                                          |
| `:unstable` | Rolling tip of `unstable`. Tester / contributor channel. May break.                        |
| `:<channel>-<fedora>.<YYYYMMDD>` | Pin to a specific build (e.g. `:stable-44.20260514`).                  |

The examples below use the base variant on `:stable`. Substitute `<variant>` and `<tag>` for your case.

### Step 1 — Verify the image signature *before* switching

Never switch to an unverified image. Pull the public key from `testing` and verify the target tag:

```bash
VARIANT=yaguarete_os            # or yaguarete_os-nvidia | yaguarete_os-nvidia-open | yaguarete_os-deck
cosign verify \
  --key https://raw.githubusercontent.com/lobinuxsoft/yaguarete_os/testing/cosign.pub \
  ghcr.io/lobinuxsoft/${VARIANT}:stable
```

A successful verification prints the signed claims (issuer, subject, digest). If it fails, **stop**: do not rebase.

### Step 2 — Switch

```bash
sudo bootc switch ghcr.io/lobinuxsoft/${VARIANT}:stable
```

`bootc switch` stages the new image as the next boot entry. Your current system stays untouched on disk until you reboot.

### Step 3 — Reboot

```bash
sudo systemctl reboot
```

### Step 4 — Confirm the rebase

After login, verify you booted into YaguareteOS:

```bash
sudo bootc status
```

The `Booted image` should be `ghcr.io/lobinuxsoft/${VARIANT}:stable` with the digest from Step 1.

### Rolling back

`bootc` keeps the previous deployment as a rollback target. If anything is wrong:

```bash
sudo bootc rollback
sudo systemctl reboot
```

This swaps the boot order back to your previous image (e.g. Bazzite). The YaguareteOS deployment is preserved on disk and can be re-promoted with `bootc rollback` again.

To pin yourself permanently back to the source image, run `bootc switch` against its registry URL (e.g. `ghcr.io/ublue-os/bazzite:stable`) and reboot.

## Verifying image signatures

All images published to `ghcr.io/lobinuxsoft/yaguarete_os` are signed with [`cosign`](https://github.com/sigstore/cosign). The public key (`cosign.pub`) lives at the root of this repository, and is also reachable at `https://raw.githubusercontent.com/lobinuxsoft/yaguarete_os/testing/cosign.pub`.

```bash
# Verify any tag
cosign verify \
  --key https://raw.githubusercontent.com/lobinuxsoft/yaguarete_os/testing/cosign.pub \
  ghcr.io/lobinuxsoft/yaguarete_os:stable
```

A successful verification means the image was built and signed by the official YaguareteOS CI pipeline. If verification fails, do not rebase to that image.

## Architecture decisions

Significant choices about the project — base image, design philosophy, image variants — are documented as Architecture Decision Records under [`docs/adr/`](docs/adr/). Start with the [ADR index](docs/adr/README.md) for the catalog and the rationale behind each entry.

## License

Apache License 2.0 — see `LICENSE`.

---

*Yaguareté: the largest feline of South America, a national symbol of Argentine wildlife.*
