# YaguareteOS

> 📖 **Landing pública:** **<https://lobinuxsoft.github.io/yaguarete_os/>**
> Las ISOs de cada release `:stable` se publican como GitHub Release + un item permanente por release en archive.org bajo creator `lobinuxsoft` ([listado](https://archive.org/details/@matias_galarza_lobinuxsoft_)). Cada stable crea sus cuatro items `yaguarete_os[-VARIANT]-stable-<F>.<YYYYMMDD>`, con la ISO homónima adentro (`…-live-amd64.iso`). El deck lagea un Fedora major, así que su item va con `43.` mientras el resto va con `44.`. Para usuarios bootc, `bootc switch ghcr.io/lobinuxsoft/<image>:stable` (o `:unstable` para rolling).

A bootable, image-based Linux distribution built on top of [Bazzite](https://bazzite.gg/) using the [Universal Blue](https://universal-blue.org/) toolchain.

YaguareteOS combines:

- **Gaming-ready base** — inherits Steam, Proton-GE, GameMode, gamescope, MangoHud and the latest AMD/Mesa drivers from Bazzite.
- **Image-based atomic updates** — built on `bootc`. Rebase, rollback, and reproducible builds out of the box.
- **Sovereign supply chain** — built and signed in our own CI; rebase URL points to our own OCI registry (`ghcr.io/lobinuxsoft/yaguarete_os`).
- **Argentine cultural identity** — Guaraní naming (Yaguareté, Yryvu), Spanish-first defaults, `es-AR` locale, native wallpapers. *Cultural*, not governmental: no state-identity / fiscal / control tooling is bundled.

## Status

Production. Four image variants live on `ghcr.io/lobinuxsoft/yaguarete_os{,-deck,-nvidia,-nvidia-open}`, promoted `unstable → testing → stable`. Promotion to `:stable` is **manual and trigger-driven** — a new Bazzite stable upstream, a bug worth shipping a fix for, or a new feature — mirroring how Bazzite itself cuts stable. There is no release cron. Pipeline includes signed container builds (cosign), ISO/qcow2 generation via `bootc-image-builder`, and permanent archival of every `:stable` ISO to archive.org.

## What's in the box

Beyond the Bazzite-inherited gaming stack, YaguareteOS ships:

- **`hhd-vram`** — our own [Handheld Daemon](https://github.com/hhd-dev/hhd) plugin (vendored in `build_files/hhd-vram/`, installed only where HHD is present). Adds a slider to the HHD overlay that assigns a percentage of system RAM as GPU graphics memory (GTT) via the `ttm.pages_limit` kernel argument, with a 6 GiB OS floor, applied through `rpm-ostree kargs` and persisted across reboots. On unified-memory APUs the BIOS UMA carveout is immutable at runtime; GTT is the knob that actually moves. No handheld distribution exposes this as a percentage control.
- **Portal yafti** — first-boot welcome wizard (run-once gated) plus an Apps page with install/update/uninstall for every component below. 77 items across 8 tabs, all normalised to `install/update/uninstall` with status badges where the underlying recipe supports it. All 182 actions and 43 status probes run through `/usr/libexec/yaguarete/portal-run`, which keeps `SUDO_ASKPASS` alive, holds the terminal open on failure and appends to `~/.local/state/yaguarete/portal.log` — upstream yafti drops both the environment and the output.
- **Yaguareté Apps suite** — custom installers for our own apps, [Yryvu](https://github.com/lobinuxsoft/yryvu) (Tauri 2 Git client) and [Tatu](https://github.com/lobinuxsoft/tatu) (Steam backlog tracker), plus curated recipes for third-party software: [Eden](https://eden-emu.dev) (Switch emulator with firmware + checksum-verified prod.keys + EmuDeck SRM integration), [Antigravity IDE](https://antigravity.google/) (Google Gemini, APT repo with SHA256 verify), Antigravity CLI, and [Claude Code](https://claude.com/claude-code) (Anthropic, official per-user installer — needs a Claude subscription or API key to be usable). Every third-party bootstrap script is run inspect-then-run: downloaded, its head shown, confirmed, and only then executed — never `curl | bash`.
- **Terminal and shell** — `kitty` with a config matched to the KDE colour scheme, `zsh` as the login shell for new accounts, and FiraCode Nerd Font (pinned + SHA256-verified from [nerd-fonts](https://github.com/ryanoasis/nerd-fonts), because Fedora does not package the patched build). `ujust yaguarete-setup-shell` fills in the part that lives in `$HOME` — oh-my-zsh, the Powerlevel10k prompt, autosuggestions and syntax highlighting — backing up any dotfile it would replace and leaving identical ones untouched, so re-running it is safe. Ligatures land in kitty; Konsole is Qt and renders none, which is why it gets the `Mono` face instead.
- **`ujust yaguarete-setup-decky`** — hardened [Decky Loader](https://decky.xyz) installer. The upstream script deletes `~/homebrew/services` *before* querying the GitHub API, so a failed query leaves the user without the binary they already had and still exits `0`. Ours resolves version and URL and verifies `HEAD 200` before anything is removed, backs up and restores the binary, then checks size, version, SELinux `bin_t` context and service state, with an honest exit code.
- **`ujust yaguarete-fsr4`** — auto-detect GPU (RDNA 3 / RDNA 4) and wire FSR4 upgrade with the correct Proton fork. Useful upgrade path for OneXFly / RDNA 3 handhelds.
- **`ujust yaguarete-*` helpers** — `yaguarete-welcome` (command reference), `yaguarete-rescue` (detects the right variant by DMI and rebases back after an accidental `bootc switch`), `yaguarete-install-gaming` and `yaguarete-install-dev` (per-app opt-in Flatpak pickers).
- **Aurora-style image versioning** — `rpm-ostree status` reports a human-readable `<fedora>.<YYYYMMDD>` so users can correlate updates with the release calendar.
- **LACT integration** — manual AMDGPU control (fan curve, OC/UV, live metrics) via Flathub, one-click from the Portal.
- **Multi-device target** — desktop AMD (RX 9070 XT class), handhelds (Steam Deck, OneXFly, ROG Ally), NVIDIA proprietary and open kernel module variants — single source tree, one Containerfile, matrix CI across the four.

## Roadmap

Tracked via GitHub Issues. Open items: see [milestones](https://github.com/lobinuxsoft/yaguarete_os/milestones) and the [`next-session` label](https://github.com/lobinuxsoft/yaguarete_os/issues?q=is%3Aissue+is%3Aopen+label%3Anext-session) for what is queued next. Sesión V (2026-05-23) brainstorm settled the post-pivot positioning on handheld-first multi-device with the Yaguareté apps ecosystem and Argentine cultural identity at the surface.

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

> **Branding state.** Argentine branding (Plymouth boot splash, Guaraní wallpapers, locale defaults, motd) is shipped today. Visual polish (custom Plasma theme, refined press kit assets) is still in progress under [#20](https://github.com/lobinuxsoft/yaguarete_os/issues/20). Expect a Bazzite-derived but YaguareteOS-branded desktop.

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

**If you changed your login shell to zsh**, undo that before rolling back to an image older than the release that introduced it:

```bash
chsh -s /bin/bash "$USER"
```

`/etc/passwd` persists across deployments, but `zsh` only exists in images from that release onwards. Rolling back with zsh still set as your login shell leaves the account naming a shell that is not there — terminals stop opening, and session startup may go with them. `ujust yaguarete-setup-shell remove` does the same thing along with removing oh-my-zsh.

### Lost YaguareteOS after an accidental switch?

If you accidentally ran `sudo bootc switch` to a non-YaguareteOS ref (for example you typed `ghcr.io/ublue-os/bazzite-deck:stable` while testing) and want to come back without reinstalling from ISO, run:

```bash
ujust yaguarete-rescue
```

The command detects your hardware (handheld → deck, NVIDIA GPU → nvidia, otherwise base), shows you the target image, asks for confirmation, then stages the switch. Reboot to apply. Optional argument selects the ref (`stable` by default):

```bash
ujust yaguarete-rescue testing    # pre-release
ujust yaguarete-rescue unstable   # rolling
```

If you're already on YaguareteOS, the command is a no-op and points you at `sudo bootc upgrade` instead.

## Updating by hand

The launcher entry **Yaguareté Updater** (category *System*) is the graphical way to update: it runs the same `uupd-manual.service` the timer uses, and it also offers a rollback to the previous deployment and the release notes of each version.

It is the upstream [`bazzite-updater`](https://github.com/rfrench3/bazzite-updater) — a Qt frontend explicitly written to be configurable for any distro — rebranded in place through `system_files/overrides/etc/bazzite-updater/`: `KAboutData_OS.json` carries our name, links and credits, and `config.ini` points the release feed at this repository. No fork, no patched binary.

The console path still exists (`ujust update`); its launcher entry is hidden so the menu shows a single updater. On a variant that ships without `bazzite-updater`, the Containerfile drops the rebrand and leaves the console entry visible instead, so no image is left without a way to update from the menu.

## Automatic updates

YaguareteOS enables `uupd.timer` (Universal Blue updater) by default. Once a day at 04:00 the timer runs hardware pre-flight checks (battery, network, memory, CPU load) and, if they pass, pulls the latest image of your current ref (`:stable`, `:testing` or `:unstable`) and stages it. The new deployment is applied on **your next reboot** — there is no forced reboot. If the system is off or suspended at 04:00, the timer fires on resume (`Persistent=true`).

The upstream `bootc-fetch-apply-updates.timer` is masked on purpose: its service runs `bootc upgrade --apply` which reboots the moment a new image is staged, which on `:unstable` (frequent CI builds) caused unexpected reboots every 1-3 h on handheld hardware.

To opt out of automatic updates:

```bash
sudo systemctl disable --now uupd.timer
```

To re-enable later:

```bash
sudo systemctl enable --now uupd.timer
```

You can still pull on demand with `sudo bootc upgrade` or `uupd` regardless of the timer state.

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
