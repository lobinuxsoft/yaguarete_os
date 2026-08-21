# yafti Recipes — QA Matrix

Companion tracking document for **#202** (QA: test every yafti recipe).
Updated per audit session. Every recipe exposed through `system_files/usr/share/yafti/yafti.yml` lives here.

## Why this document exists

Sesión V & VI demonstrated that a recipe shipped with CI green can be 100% broken on the maintainer's hardware. `yaguarete-fsr4` had **three cascading bugs** that only end-to-end HW testing surfaced — and one was an upstream Bazzite silent rename. The matrix forces every recipe to be observed in the wild before claiming the Portal is trustworthy.

## Legend

| Status | Meaning |
|---|---|
| `PASS` | Validated end-to-end on at least one variant — recipe runs, side-effects verified, user-visible output OK. |
| `FAIL` | Confirmed broken — fix pending in this PR or spawned to its own issue. |
| `TODO` | Not yet audited. Default state for everything except `yaguarete-fsr4`. |
| `N/A` | Not applicable to this variant (e.g. `-deck`-only recipe on desktop). |

## Pre-flight checklist (Findings sesión VI)

Apply to every recipe **before** marking PASS:

1. **Upstream rename guard**: if the recipe wraps `ujust <upstream>`, grep `/usr/share/ublue-os/just/80-bazzite.just` on a fresh Bazzite image to confirm the upstream name still exists. Bazzite renames recipes silently between builds (see `global-fsr4` → `toggle-global-fsr4` incident).
2. **SIGPIPE guard**: any `set -euo pipefail` body containing `cmd | head`, `cmd | awk '...exit'`, `cmd | grep -m1`, or `find | head -1` aborts at exit 141 before the first `log()` runs. Refactor to defensive form (awk sentinel, `|| fallback=""`).
3. **TTY pause + log**: handled centrally since the Portal actions were routed through `/usr/libexec/yaguarete/portal-run`. It keeps the window open, tees the output to `~/.local/state/yaguarete/portal.log`, and prints the exit status. A recipe no longer needs its own `read -n 1 -s -r -p "..."`; adding one just asks the user to press Enter twice. **Every `script:` in `yafti.yml` must go through the runner** — a bare command loses its output to konsole closing, which is how Decky Loader failed silently.
   Related trap: yafti runs actions under `bash --noprofile --norc`, so `/etc/profile.d` never loads and `SUDO_ASKPASS` is empty. Every upstream Bazzite recipe calling `sudo -A` dies instantly without it. The runner sources `askpass.sh` when the variable is missing.
4. **HW smoke**: validate on the real target hardware (OneXFly for `-deck`, RX 9070 XT desktop for `desktop`, etc). CI green is not sufficient — see [feedback_ci_green_not_recipe_works].

## Hardware coverage

| Variant | Test device | Owner availability |
|---|---|---|
| `desktop` (RDNA 4) | RX 9070 XT + Ryzen 9800X3D | full access |
| `-deck` (RDNA 3.5) | OneXFly F1 Pro (Radeon 890M) | full access (SSH `192.168.0.36`) |
| `-deck` (Steam Deck OLED) | n/a | not owned — recipes marked `TODO` until borrowed |
| `-nvidia` / `-nvidia-open` | n/a | no NVIDIA hardware available — recipes marked `TODO` indefinitely |

---

## Image drop-ins (not recipes — they apply with no user action)

### `etc/environment.d/95-yaguarete-panel-rotation.conf`

Sets `ORIENTATION` for handhelds whose DMI name gamescope's `device-quirks` does
not match. Sourced by `gamescope-session-plus` after the upstream quirks file,
so it wins without forking it.

| Case | Variant | Status | Notes |
|---|---|---|---|
| `ONEXPLAYER F1Pro` | `-deck` | `PASS` | Verified on hardware 2026-08-20 against `44.20260820`: `gamescope --force-orientation left` in the process list, UI upright. Was rotated before the drop-in — `device-quirks` lists `ONEXPLAYER F1` and its EVA/OLED siblings but not the Pro. |
| Steam Deck (`Jupiter` / `Galileo`) | `-deck` | `TODO` | Must be a **no-op**. The `case` only matches the F1Pro, verified against a simulated DMI, but never run on Valve hardware. A false positive here would rotate a landscape panel sideways. |
| Desktop / nvidia | all | `PASS` | Verified: on `B850I AORUS PRO` the file leaves `ORIENTATION` empty. |

**Why it is not a `ujust` recipe:** every F1Pro needs it and nobody would think
to run it — a rotated UI is hard to navigate to reach a terminal in the first
place.

## Tier 1 — Custom recipes (lobinuxsoft/yaguarete_os direct ownership)

Every recipe under `system_files/usr/share/ublue-os/just/85-yaguarete-*.just`, `95-yaguarete.just`, `99-yaguarete-*.just`.

### `85-yaguarete-fsr4.just`

Wraps Bazzite's `toggle-global-fsr4(-rdna3)` with GPU auto-detection + Proton-fork inventory + stdout summary + pause.

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `yaguarete-fsr4 enable` | `-deck` (RDNA 3.5) | `PASS` | PR #204 — detects 890M, calls `toggle-global-fsr4-rdna3`, writes `~/.config/environment.d/99-proton-fsr4-rdna3.conf`, shows summary + pause. Confirmed `43.20260523.5` post-reboot 2026-05-23. |
| `yaguarete-fsr4 enable` | `desktop` (RDNA 4) | `TODO` | Expected path: detects 9070 XT, calls `toggle-global-fsr4` (no `-rdna3`), summary should report "no Proton-EM required (FP8 native)". Needs smoke on 9800X3D box. |
| `yaguarete-fsr4 disable` | `-deck` | `PASS` | PR #204. |
| `yaguarete-fsr4 disable` | `desktop` | `TODO` | Same as enable. |
| `yaguarete-fsr4 enable` | `-nvidia` / `-nvidia-open` | `N/A` | Recipe explicitly errors on non-AMD GPU. |

### `85-yaguarete-setup-decky.just`

Wraps Bazzite's `setup-decky` with pre-flight resolution + post-install verification. Exists because the upstream installer runs `rm -rf ~/homebrew/services` **before** querying the GitHub API, so a failed query uninstalls a working Decky and still exits 0 (observed 2026-07-31 on `-nvidia-open`: `Installing version ...` / `curl: (2) no URL specified` / service dead at 203/EXEC / `exit status: 0`).

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `yaguarete-setup-decky install` | `-nvidia-open` | `PASS` | Pre-flight resolves `v3.2.6` + asset HEAD 200 on the real box; with the API unreachable it aborts before anything is deleted. Full install smoked end-to-end. |
| `yaguarete-setup-decky install` | `desktop` / `-deck` | `TODO` | Same code path — the recipe is variant-agnostic. |
| `yaguarete-setup-decky install-prerelease` | all | `TODO` | Resolves including prereleases, otherwise identical. |
| `yaguarete-setup-decky status` / `uninstall` | all | `PASS` | Straight `exec` to upstream. |

### `85-yaguarete-install-yryvu.just`

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `install-yryvu` | all | `TODO` | Downloads Yryvu AppImage, SHA256 verify, generates `.desktop`. Pre-flight: SIGPIPE risk at `sha256sum \| awk '{print $1}'` (low — awk reads all stdin, no early exit). **Missing TTY pause** — installation summary likely invisible in yafti context. |
| `update-yryvu` | all | `TODO` | Same notes. |
| `remove-yryvu` | all | `TODO` | Same. |

### `85-yaguarete-install-tatu.just`

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `install-tatu` | all | `TODO` | Downloads Tatu AppImage. Pre-flight: SIGPIPE risk at `find squashfs-root -name '*.desktop' \| head -1` and `find ... \(...\) \| head -1` (medium — find may stream multiple results). **Missing TTY pause**. Verify rename `Game_Progress_Tracker → Tatu` reaches KDE menu. |
| `update-tatu` | all | `TODO` | Same. |
| `remove-tatu` | all | `TODO` | Same. |

### `85-yaguarete-install-eden.just`

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `install-eden` | all | `TODO` | Downloads Eden AppImage + firmware + `prod.keys` + EmuDeck SRM injection. Pre-flight: 4× `find \| head -1` with pipefail (medium SIGPIPE risk). **Missing TTY pause**. Verify EmuDeck SRM parser injection only fires when EmuDeck present. |
| `update-eden` | all | `TODO` | Same + `jq ... \| head -1` for GitHub asset selection. |
| `remove-eden` | all | `TODO` | Same. |

### `85-yaguarete-install-antigravity-ide.just`

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `install-antigravity-ide` | all | `TODO` | APT repo (Google Cloud Artifact Registry) + SHA256 verify + extract + relocate. Pre-flight: 6× `sudo find \| head -1` with pipefail (HIGH SIGPIPE risk — many candidates). **Missing TTY pause**. |
| `update-antigravity-ide` | all | `TODO` | Same. |
| `remove-antigravity-ide` | all | `TODO` | Same. |

### `85-yaguarete-install-antigravity-cli.just`

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `install-antigravity-cli` | all | `TODO` | Upstream `install.sh` pattern. **Missing TTY pause**. |
| `update-antigravity-cli` | all | `TODO` | Same. |
| `remove-antigravity-cli` | all | `TODO` | Same. |

### `95-yaguarete.just`

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `yaguarete-welcome` | all | `TODO` | Banner print only — low risk. Verify no traceback / missing font. |
| `yaguarete-install-gaming` | all | `TODO` | Interactive picker (`read -p` y/N per app) installs user-level Flatpaks. TTY pause is implicit (read inside loop). Verify each app entry resolves. |
| `yaguarete-install-dev` | all | `TODO` | Same pattern as gaming. |

### `99-yaguarete-rename.just` (drift — file name is misleading)

This file does NOT contain a `yaguarete-rename` recipe (the issue body mentions one — drift). Actual recipes:

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `yaguarete-cli enable` | all | `TODO` | Drift: invoked from `yafti.yml` (`ujust yaguarete-cli enable\|disable`). Toggles something but body not yet inspected for what. Audit needed. |
| `yaguarete-cli disable` | all | `TODO` | Same. |
| `restore-yaguarete-breeze-gtk-theme` | all | `TODO` | NOT invoked from `yafti.yml`. Likely user-runs-it-manually. Confirm purpose during audit. |
| `get-decky-yaguarete-buddy install` | `-deck` | `TODO` | Decky plugin install. Invoked from `yafti.yml`. |
| `get-decky-yaguarete-buddy uninstall` | `-deck` | `TODO` | Same. |
| `get-decky-yaguarete-buddy status` | `-deck` | `TODO` | Same. |

### `99-yaguarete-rescue.just`

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `yaguarete-rescue [ref=stable]` | all | `TODO` | Re-rebase to signed image. **Destructive — needs cautious smoke** (test on OneXFly only, not desktop). |

---

## Tier 2 — Bazzite gaming stack (invoked from yafti.yml)

These recipes ship with the Bazzite base image (`/usr/share/ublue-os/just/80-bazzite.just` and the `8*-bazzite-*.just` siblings). Status depends on both upstream maintenance AND our wrapper assumptions in `yafti.yml`.

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `setup-decky install` | `-deck` | `TODO` | Installs Decky Loader systemd unit. **Issue body uses old name `setup-decky` — confirmed still exists upstream.** |
| `setup-decky uninstall` | `-deck` | `TODO` | |
| `setup-decky status` | `-deck` | `TODO` | |
| `get-decky-lossless-scaling install` | `-deck` | `TODO` | Decky plugin. |
| `get-decky-lossless-scaling uninstall` | `-deck` | `TODO` | |
| `get-decky-lossless-scaling status` | `-deck` | `TODO` | |
| `get-framegen install` | `-deck` | `TODO` | **Renamed upstream** — issue body says `get-decky-framegen`. Verify wrapper aligned. |
| `get-framegen uninstall` | `-deck` | `TODO` | |
| `get-framegen status` | `-deck` | `TODO` | |
| `get-lsfg install` | all | `TODO` | **Renamed upstream** — issue body says `setup-lsfg-vk`. Lossless Scaling Vulkan layer. |
| `get-lsfg uninstall` | all | `TODO` | |
| `get-lsfg status` | all | `TODO` | |
| `get-emudeck install` | all | `TODO` | **Renamed upstream** — issue body says `install-emudeck`. |
| `get-emudeck uninstall` | all | `TODO` | |
| `get-emudeck status` | all | `TODO` | |
| `get-steamcmd install` | all | `TODO` | **Renamed upstream** — issue body says `install-steamcmd`. |
| `get-steamcmd uninstall` | all | `TODO` | |
| `get-steamcmd status` | all | `TODO` | |
| `setup-sunshine enable` | all | `TODO` | Game streaming server. 5 variants per body — verify each. |
| `setup-sunshine update` | all | `TODO` | |
| `setup-sunshine disable` | all | `TODO` | |
| `setup-sunshine uninstall` | all | `TODO` | |
| `setup-sunshine portal` | all | `TODO` | |
| `setup-sunshine status` | all | `TODO` | |
| `get-media-app` | all | `TODO` | Interactive picker for YouTube / Netflix / Spotify / Plex HTPC / Jellyfin (post-PR #194 cleanup). |
| `global-fsr4 enable` | `desktop` | `TODO` | **Renamed upstream → `toggle-global-fsr4`** (caught sesión VI). Standalone validation now that wrapper `yaguarete-fsr4` handles auto-routing. |
| `global-fsr4 disable` | `desktop` | `TODO` | Same. |
| `global-fsr4-rdna3 enable` | `-deck` | `TODO` | **Renamed upstream → `toggle-global-fsr4-rdna3`**. |
| `global-fsr4-rdna3 disable` | `-deck` | `TODO` | Same. |
| `global-dlss enable` | `-nvidia` / `-nvidia-open` | `TODO` | NVIDIA-only path. No HW available — cannot test. **Follow-up candidate**: wrap as `yaguarete-dlss` mirroring fsr4 wrapper. |
| `global-dlss disable` | `-nvidia` / `-nvidia-open` | `TODO` | |
| `fix-proton-hang` | all | `TODO` | Steam Proton recovery. Verify idempotent. |
| `fix-reset-steam` | all | `TODO` | Destructive — wipes Steam config. Test on OneXFly only. |
| `fix-gmod` | all | `TODO` | Garry's Mod fix. Low priority. |
| `steam-icons enable` | `-deck` | `TODO` | |
| `steam-icons disable` | `-deck` | `TODO` | |
| `steam-icons remove` | `-deck` | `TODO` | |
| `steam-icons status` | `-deck` | `TODO` | |
| `setup-boot-windows-steam` | all | `TODO` | Dual-boot Windows shortcut into Steam. |
| `steamos-automount enable` | `-deck` | `TODO` | |
| `steamos-automount disable` | `-deck` | `TODO` | |
| `steamos-automount status` | `-deck` | `TODO` | |

---

## Tier 3 — Bazzite system / services (invoked from yafti.yml)

| Recipe | Variant | Status | Notes |
|---|---|---|---|
| `cockpit enable` | all | `TODO` | **Renamed upstream** — issue body says `toggle-cockpit`. Web admin. |
| `cockpit disable` | all | `TODO` | |
| `cockpit status` | all | `TODO` | |
| `ssh enable` | all | `TODO` | **Renamed upstream** — issue body says `toggle-ssh`. |
| `ssh disable` | all | `TODO` | |
| `ssh status` | all | `TODO` | |
| `tailscale enable` | all | `TODO` | **Renamed upstream** — issue body says `toggle-tailscale`. |
| `tailscale disable` | all | `TODO` | |
| `tailscale status` | all | `TODO` | |
| `openrgb install` | all | `TODO` | OpenRGB. |
| `openrgb uninstall` | all | `TODO` | |
| `openrgb status` | all | `TODO` | |
| `opentabletdriver install` | all | `TODO` | Tablet driver. |
| `opentabletdriver uninstall` | all | `TODO` | |
| `opentabletdriver status` | all | `TODO` | |
| `resilio-sync install` | all | `TODO` | **Renamed upstream** — issue body says `install-resilio-sync`. |
| `resilio-sync uninstall` | all | `TODO` | |
| `resilio-sync status` | all | `TODO` | |
| `configure-beesd` | all | `TODO` | BTRFS dedup. |
| `configure-snapshots enable` | all | `TODO` | |
| `configure-snapshots disable` | all | `TODO` | |
| `configure-snapshots wipe` | all | `TODO` | Destructive — careful. |
| `configure-snapshots status` | all | `TODO` | |
| `configure-watchdog enable` | all | `TODO` | |
| `configure-watchdog disable` | all | `TODO` | |
| `configure-watchdog status` | all | `TODO` | |
| `configure-grub hide` | all | `TODO` | |
| `configure-grub show` | all | `TODO` | |
| `configure-grub unhide` | all | `TODO` | |
| `configure-waydroid init` | `-deck` | `TODO` | **Renamed upstream** — issue body says `setup-waydroid`. |
| `configure-waydroid configure` | `-deck` | `TODO` | |
| `configure-waydroid gpu` | `-deck` | `TODO` | |
| `configure-waydroid reset` | `-deck` | `TODO` | Destructive. |
| `configure-waydroid helper` | `-deck` | `TODO` | |
| `reisub enable` | all | `TODO` | Magic SysRq enable. |
| `reisub disable` | all | `TODO` | |
| `reisub status` | all | `TODO` | |
| `restart-pipewire` | all | `TODO` | Audio restart. Low risk. |
| `restore-input-remapper enable` | all | `TODO` | |
| `restore-input-remapper disable` | all | `TODO` | |
| `restore-input-remapper status` | all | `TODO` | |
| `password-feedback on` | all | `TODO` | sudo asterisks. |
| `password-feedback off` | all | `TODO` | |
| `automounting enable` | all | `TODO` | |
| `automounting disable` | all | `TODO` | |
| `automounting status` | all | `TODO` | |
| `cec-sleep enable` | `-deck` | `TODO` | HDMI CEC. |
| `cec-sleep disable` | `-deck` | `TODO` | |
| `cec-sleep status` | `-deck` | `TODO` | |
| `toggle-bt-mic enable` | all | `TODO` | Bluetooth mic profile. |
| `toggle-bt-mic disable` | all | `TODO` | |
| `toggle-bt-mic status` | all | `TODO` | |
| `toggle-i915-sleep-fix auto` | all | `TODO` | Intel iGPU only. May `N/A` on AMD-only handhelds. |
| `toggle-i915-sleep-fix disable` | all | `TODO` | |
| `toggle-i915-sleep-fix level` | all | `TODO` | |
| `toggle-i915-sleep-fix status` | all | `TODO` | |
| `toggle-i915-sleep-fix unset` | all | `TODO` | |
| `toggle-save-panics enable` | all | `TODO` | Kernel panic log retention. |
| `toggle-save-panics disable` | all | `TODO` | |
| `toggle-save-panics status` | all | `TODO` | |
| `wol enable` | all | `TODO` | Wake-on-LAN. |
| `wol disable` | all | `TODO` | |
| `wol force` | all | `TODO` | |
| `wol status` | all | `TODO` | |
| `setup-virtual-channels create` | all | `TODO` | Virtual audio channels. |
| `setup-virtual-channels remove` | all | `TODO` | |
| `setup-virtual-channels status` | all | `TODO` | |
| `setup-virtual-surround enable` | all | `TODO` | |
| `setup-virtual-surround disable` | all | `TODO` | |
| `setup-virtual-surround status` | all | `TODO` | |
| `setup-virtualization virt` | all | `TODO` | QEMU/libvirt setup. |
| `asus install` | n/a | `N/A` | ASUS laptop-specific. No HW available. |
| `asus uninstall` | n/a | `N/A` | |
| `asus status` | n/a | `N/A` | |
| `add-user-to-input-group add` | all | `TODO` | |
| `add-user-to-input-group remove` | all | `TODO` | |
| `add-user-to-input-group status` | all | `TODO` | |
| `grub-timeout` | all | `TODO` | |
| `grub-timeout custom` | all | `TODO` | |
| `grub-timeout instant` | all | `TODO` | |
| `regenerate-grub` | all | `TODO` | |
| `benchmark` | all | `TODO` | System benchmark. |
| `get-logs` | all | `TODO` | journalctl bundler. |
| `update` | all | `TODO` | Full system update. |
| `verify-image` | all | `TODO` | Detect unverified image + re-rebase to signed. |

### Recipes referenced in issue #202 body but NOT invoked from yafti.yml

The issue scope mentioned these — they exist in `60-bazzite.just`-era upstream but the current Portal does not surface them. Decision: track here, audit only if reintroduced.

| Recipe | Action |
|---|---|
| `install-coolercontrol` | TODO — not exposed in yafti.yml. Confirm intentional drop. |
| `setup-displaylink` | TODO — same. |
| `install-openrazer install-razer-genie` | TODO — same. |
| `install-openrazer install-polychromatic` | TODO — same. |
| `install-davinci-resolve` | TODO — same. |
| `install-boxtron` | TODO — same. |

---

## Tier 4 — Inline scripts (Flatpak / brew / brh / manage-PC)

Items in `yafti.yml` that do NOT call `ujust` — they invoke `flatpak`, `brew`, `brh`, or shell directly.

| Item | Type | Status | Notes |
|---|---|---|---|
| VLC | Flatpak | `TODO` | Creative Apps page. |
| GIMP | Flatpak | `TODO` | |
| Inkscape | Flatpak | `TODO` | |
| OBS Studio | Flatpak | `TODO` | |
| Blender | Flatpak | `TODO` | |
| Stremio | Flatpak | `TODO` | + "Browse add-ons catalogue" (xdg-open). Added PR #194 (sesión V). |
| YouTube web-app | `ujust get-media-app` | `TODO` | |
| Netflix web-app | `ujust get-media-app` | `TODO` | |
| Spotify web-app | `ujust get-media-app` | `TODO` | |
| Plex HTPC | `ujust get-media-app` | `TODO` | |
| Jellyfin | `ujust get-media-app` | `TODO` | |
| Antigravity (Google Gemini) | brew cask | `TODO` | |
| LM Studio | brew cask | `TODO` | |
| JetBrains Toolbox | brew cask | `TODO` | |
| VSCodium | brew cask | `TODO` | |
| Android Platform Tools | brew cask | `TODO` | |
| `brh rebase stable` | shell | `TODO` | Channel switch. |
| `brh rebase testing` | shell | `TODO` | |
| `brh rollback` | shell | `TODO` | |
| `reset-bazzite` | shell? | `TODO` | Confirm replacement (likely `yaguarete-rescue`). |

---

## Audit log

Append one row per session — what was audited, what changed.

| Date | Session | Recipes touched | Result | PRs |
|---|---|---|---|---|
| 2026-05-23 | VI | `yaguarete-fsr4 {enable,disable}` on `-deck` | `PASS` after 3 cascading fixes | #203, #204 |
| 2026-05-24 | VII | Matrix scaffolding + hardening campaign | 11 PRs merged | #205, #206, #208 |
| 2026-05-24 | VII | Tab 1 (App Install) — 9 items procesados | 3 PASS via SSH, 2 PASS via yafti GUI (user), 2 ya-instalados, 2 dropeados broken | #207, #214 |
| 2026-05-24 | VII | Tab 2 (Yaguareté Apps) — 5/5 items end-to-end | All PASS (install + update + uninstall ciclos) | — |
| 2026-05-24 | VII | Tab 3 (Creative Apps) — 5/5 items | All PASS (install + flatpak uninstall) | — |
| 2026-05-24 | VII | Tab 5 (Game Fixes) — REMOVED entirely | 1 NEEDS-USER-GUI; tab dropeado | #209 |
| 2026-05-24 | VII | Tab 6 (Media Apps) — 7/7 items | 3 PASS via SSH (webapp), 3 NEEDS-GUI (Flatpak system polkit), 1 PASS-by-existing (Stremio) | — |
| 2026-05-24 | VII | Tab 4 (System Fixes) — 11 items procesados | 8 PASS (cycle toggles), 4 NEEDS-GUI (pkexec), 11+ drift items renamed/dropped | #211, #212, #213 |
| 2026-05-24 | VII | Tab 9 (Troubleshooting) — 4/6 items | 3 PASS (restart-pipewire, fix-proton-hang, benchmark), 2 NEEDS-GUI (get-logs, bazzite-discord), 1 SKIPPED destructivo (fix-reset-steam) | — |
| 2026-05-24 | VII | yafti.yml normalization | 20 items (Tab 2/3/6/7) ganaron `install/update/uninstall` consistente + status_script. Cobertura status_script 28/80 → 48/80 | #210 |
| 2026-05-24 | VII | Brew tab cleanup | dropped Antigravity (duplicado) + LM Studio | #209 |
| 2026-05-24 | VII | OneXFly residue cleanup | 6 plugin orphans, 2 Antigravity/Eden backups, /tmp QA files, hrtf-sofa, input group restored | — |
| 2026-05-24 | VIII | LACT integration + README/landing refresh + backlog cleanup | 2 PRs merged, 5 issues closed | #217, #218 |
