#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Base CLI tooling
dnf5 install -y tmux

# Terminal + shell stack (#254). kitty is the terminal the YaguareteOS
# shell configuration targets; zsh is the login shell for new accounts
# (see /etc/default/useradd further down).
#
# WARNING: zsh cannot be dropped from this image without a migration.
# `chsh` writes /etc/passwd, /etc is a persistent per-deployment overlay,
# and rolling back to an image without zsh leaves those accounts naming a
# login shell that is not there — terminals stop opening, and session
# startup may go with them. Removing it is a breaking change with a
# recovery step attached, not a package cleanup.
dnf5 install -y \
    kitty \
    zsh

# Default pre-installed apps for all 4 variants. Maintained list — decisions
# tracked in #93. Skip packages already shipped by upstream Bazzite
# (mangohud, goverlay, lutris, ffmpeg-free) to avoid duplicate layers.
#
# Creative apps (vlc / gimp / inkscape / obs-studio / blender) moved to
# Yaguareté Portal as Flathub installs in #154 — they pushed the deck
# container past the 75 GB btrfs-zstd:2 runner budget and crashed the
# titanoboa COMMIT step. Users opt in via Portal.
dnf5 install -y \
    git-lfs

# Typography stack — decisions tracked in #12.
# - Inter (rsms-inter-fonts) is the UI font referenced by the kdeglobals
#   font keys; pre-install so the theme applies on first boot instead of
#   falling back to Noto Sans.
# - The mono font is FiraCode Nerd Font, installed by install-fonts.sh
#   below because Fedora does not package the Nerd Font patched build.
#   This comment used to claim JetBrainsMono Nerd Font "ships in the
#   Bazzite nerd-fonts layer" — it does not and never did. Bazzite ships
#   the Symbols Nerd Font only, so three configs named a family the image
#   did not contain and fontconfig substituted silently (#254).
# - Noto Serif is the document font; apps (Kate, LibreOffice) can opt in.
dnf5 install -y \
    rsms-inter-fonts \
    google-noto-serif-fonts

### Typography that Fedora does not package (FiraCode Nerd Font).
# Pinned version + SHA256 live in install-fonts.sh, which fails the build
# if the families our configs name are missing afterwards.
/ctx/install-fonts.sh

### Shell defaults: zsh for new accounts, plus the shared configuration
# templates in /etc/skel.
#
# /usr/share/yaguarete/shell/ is the single source of truth. The recipe
# `ujust yaguarete-setup-shell` writes the same files into an existing
# user's $HOME; copying them here instead of duplicating them under
# system_files/etc/skel/ keeps the two paths from drifting apart.
#
# The templates are guarded so a new account whose login shell is zsh gets
# a usable prompt before anyone runs the recipe — and, in particular, is
# never dropped into zsh-newuser-install's wizard.
sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd
grep -q '^SHELL=/usr/bin/zsh$' /etc/default/useradd

install -Dm0644 /usr/share/yaguarete/shell/zshrc /etc/skel/.zshrc
install -Dm0644 /usr/share/yaguarete/shell/kitty.conf \
    /etc/skel/.config/kitty/kitty.conf

# Same file again as the system-wide default. kitty searches
# $XDG_CONFIG_HOME/kitty/kitty.conf, ~/.config/kitty/kitty.conf and then
# $XDG_CONFIG_DIRS/kitty/kitty.conf (`kitty --help`), so /etc/xdg covers the
# accounts /etc/skel never touched -- anyone who existed before this image,
# or who never ran `ujust yaguarete-setup-shell`. Without it, promoting kitty
# to default terminal would open an unthemed kitty for exactly those users.
# A personal ~/.config/kitty/kitty.conf still wins.
install -Dm0644 /usr/share/yaguarete/shell/kitty.conf \
    /etc/xdg/kitty/kitty.conf

### Custom apps installed from GitHub Releases (yryvu, capydeploy, godots, ...)
# Pinned versions + checksums live in install-custom-apps.sh. Bumping any of
# them requires a `chore(apps): bump <app> X -> Y` commit in this repo.
/ctx/install-custom-apps.sh

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

### Auto-upgrade: daily uupd (Universal Blue updater) at 04:00 with HW
# pre-flight checks (battery / network / memory / CPU) and NO forced reboot.
# Upgrade is staged for the next reboot the user picks. Upstream Bazzite
# pattern — uupd is already in the inherited image, we only flip the timer.
#
# bootc-fetch-apply-updates.timer is MASKED on purpose: its service runs
# `bootc upgrade --apply --quiet`, and `--apply` reboots whenever a new
# image is staged. With the timer's OnBootSec=1h + OnUnitInactiveSec=8h +
# RandomizedDelaySec=2h schedule, CI builds on :unstable produced reboots
# every 1-3h on handheld HW (regression of #144).
#
# Manual on-demand pull stays available with `sudo bootc upgrade` or `uupd`.
systemctl mask bootc-fetch-apply-updates.timer
systemctl enable uupd.timer

### Game Mode autologin: patches /etc/sddm.conf.d/steamos.conf at boot
# to wire User= to whatever username UID 1000 resolves to. Replicates
# bazzite-deck's bazzite-autologin.service pattern verbatim. The service
# is gated by ConditionPathExists on the steamos sddm drop-in, so it
# silently no-ops on desktop/nvidia variants. See #151.
systemctl enable yaguarete-autologin.service

### Localization: install Spanish langpack
# Covers all es_* locales (es_AR, es_ES, es_MX, ...). LANG is set via
# system_files/etc/locale.conf and timezone via system_files/etc/localtime.
dnf5 install -y glibc-langpack-es

# glibc-langpack-es %post may rewrite /etc/locale.conf to its primary
# locale (es_ES.UTF-8); reassert es_AR after the package install so the
# image overlay value wins.
echo 'LANG=es_AR.UTF-8' >/etc/locale.conf

### Theme: Layan-KDE base Look-And-Feel.
# Provides macOS-style glass / blur / transparency effects that match the
# YaguareteOS jungle aesthetic. Our own `YaguareteOS.colors` color scheme
# stays on top of it for the #FF4500 accent — kdeglobals stitches the
# two together (Layan structure + YaguareteOS palette).
#
# Pinned to a specific commit SHA so an upstream change cannot mutate the
# theme out from under us between builds. To bump:
#   1. Verify the new SHA at https://github.com/vinceliuice/Layan-kde/commits/master
#   2. Update LAYAN_SHA below.
#   3. Commit as `chore(theme): bump Layan-kde <old> -> <new>`.
LAYAN_REPO="https://github.com/vinceliuice/Layan-kde.git"
LAYAN_SHA="a0b6a4956022276aee33309b2e07d1d0ef3db30c"
LAYAN_TMP=$(mktemp -d)
git clone --quiet --filter=blob:none "$LAYAN_REPO" "$LAYAN_TMP"
git -C "$LAYAN_TMP" checkout --quiet "$LAYAN_SHA"
# install.sh detects UID 0 and writes to /usr/share/{aurorae,color-schemes,
# Kvantum,plasma/{desktoptheme,look-and-feel},wallpapers}.
(cd "$LAYAN_TMP" && bash ./install.sh)
# SDDM theme of Layan is shipped under sddm/; install only if Layan SDDM
# is desired (left out by default — Plasma 6 plasmalogin handles login).
rm -rf "$LAYAN_TMP"

### Branding: prune upstream Bazzite/Fedora/UBlue wallpapers from the
# Plasma wallpaper switcher. Keep KDE defaults (Altai, Cascade, ...) and
# Steam Deck Logo set (useful for handheld variants).
rm -rf \
    /usr/share/wallpapers/bazzite \
    /usr/share/wallpapers/F44 \
    /usr/share/wallpapers/Fedora
rm -f /usr/share/wallpapers/ublue.png

### Branding: replace /usr/share/ublue-os/bazzite/ visual assets that
# yafti and the System Update launcher reference. Preserve filenames
# (referenced by yafti_gtk.py / .desktop Icon paths) and repoint to
# yaguarete-logo via symlinks.
for svg_asset in portal.svg logo.svg update.svg discourse.svg docs.svg; do
    ln -sf /usr/share/icons/hicolor/scalable/apps/yaguarete-logo.svg \
        "/usr/share/ublue-os/bazzite/$svg_asset"
done
ln -sf /usr/share/icons/hicolor/256x256/apps/yaguarete-logo-icon.png \
    /usr/share/ublue-os/bazzite/updatelogo.png

### Branding: repoint Bazzite's hicolor icon entries to yaguarete-logo.
# Preserves filenames (third-party code may hard-reference them) but the
# rendered glyph is YaguareteOS.
for size in 16x16 22x22 24x24 32x32 36x36 48x48 96x96 256x256; do
    bazzite_png="/usr/share/icons/hicolor/$size/bazzite-logo-icon.png"
    yaguarete_png="/usr/share/icons/hicolor/$size/apps/yaguarete-logo-icon.png"
    if [[ -f $yaguarete_png ]]; then
        ln -sf "$yaguarete_png" "$bazzite_png"
    fi
done
for variant in bazzite-logo.svg bazzite-logo-white.svg bazzite-logo-le.svg \
               distributor-logo.svg distributor-logo-white.svg distributor-logo-steamdeck.svg; do
    ln -sf /usr/share/icons/hicolor/scalable/apps/yaguarete-logo.svg \
        "/usr/share/icons/hicolor/scalable/places/$variant"
done

### Branding: the login MOTD.
# ublue-motd stopped reading a distro-named file. It now renders
# /usr/share/ublue-os/motd/template.md, expanding shell variables exported
# by env.sh (${MOTD_IMAGE_NAME}, ${MOTD_GREENBOOT}, ${MOTD_TIP}) instead of
# the old %PLACEHOLDER% syntax, and pulls one random line out of tips/*.md.
#
# We ship our own template.md through system_files/, so the banner itself is
# already ours by the time this runs. What is left is the tips directory:
# every upstream file there is Bazzite-branded prose ("Bazzite uses ZSTD
# compression", "rolling back to older Bazzite builds") with docs.bazzite.gg
# links, and one of them is picked at random on every login. Remove them by
# name -- never with a glob, which would take our own tips with them.
for upstream_tip in 10-ublue.md 15-ublue-config.md 20-bazzite.md \
                    25-bazzite-deck.md 30-kde.md; do
    rm -f "/usr/share/ublue-os/motd/tips/$upstream_tip"
done
rm -f /usr/share/ublue-os/motd/bazzite.md

# Fail loudly rather than shipping a Bazzite-branded banner: the previous
# override went stale for months precisely because nothing checked it.
if grep -q "bazzite" /usr/share/ublue-os/motd/template.md; then
    echo "[motd] FATAL: template.md still mentions bazzite" >&2
    exit 1
fi
if ! ls /usr/share/ublue-os/motd/tips/*.md >/dev/null 2>&1; then
    echo "[motd] FATAL: no tips left, the banner would render an empty line" >&2
    exit 1
fi
echo "[motd] template.md is ours, $(ls /usr/share/ublue-os/motd/tips/*.md | wc -l) tip file(s) kept"

### Default terminal: kitty (#254).
# /etc/xdg/xdg-terminals.list (shipped via system_files/) covers every helper
# that goes through xdg-terminal-exec, and kdeglobals covers KDE's own
# actions. This third path is the `x-scheme-handler/terminal` association.
#
# The file is edited in place instead of shipped: the base image already
# writes /etc/xdg/mimeapps.list with the Bazaar association for
# application/vnd.flatpak.ref, and dropping our own copy on top would
# silently take that with it.
if ! grep -q "^x-scheme-handler/terminal=" /etc/xdg/mimeapps.list 2>/dev/null; then
    if grep -q "^\[Default Applications\]" /etc/xdg/mimeapps.list 2>/dev/null; then
        sed -i '/^\[Default Applications\]/a x-scheme-handler/terminal=kitty.desktop' \
            /etc/xdg/mimeapps.list
    else
        printf '[Default Applications]\nx-scheme-handler/terminal=kitty.desktop\n' \
            >> /etc/xdg/mimeapps.list
    fi
fi
echo "[terminal] default terminal is kitty; mimeapps.list now:"
cat /etc/xdg/mimeapps.list

### Branding: privatize Bazzite-named ujust recipes so they no longer
# appear in `ujust --list`. The YaguareteOS-named wrappers in
# /usr/share/ublue-os/just/99-yaguarete-rename.just delegate to these
# private originals (just convention: leading underscore = private).
sed -i 's|^bazzite-cli ACTION="":|_bazzite-cli ACTION="":|' \
    /usr/share/ublue-os/just/80-bazzite.just
sed -i 's|^restore-bazzite-breeze-gtk-theme:|_restore-bazzite-breeze-gtk-theme:|' \
    /usr/share/ublue-os/just/90-bazzite-de.just
sed -i 's|^get-decky-bazzite-buddy ACTION="":|_get-decky-bazzite-buddy ACTION="":|' \
    /usr/share/ublue-os/just/91-bazzite-decky.just

### Upstream Bazzite bug fix: the `get-framegen` recipe hardcodes
# FILENAME="Decky.Framegen.zip" (with a dot) but the asset at
# xXJSONDeruloXx/Decky-Framegen actually ships as "Decky-Framegen.zip"
# (with a hyphen) since v0.15.5. The recipe's 404 fallback also points at
# the wrong filename, so install fails with "cannot find zipfile directory"
# while `exit 0` lies to the caller. Patch in-place; if upstream ever
# renames, this sed becomes a no-op (no error) and we drop it. Tracked in
# docs/qa/upstream-issues.md.
sed -i 's|FILENAME="Decky\.Framegen\.zip"|FILENAME="Decky-Framegen.zip"|' \
    /usr/share/ublue-os/just/91-bazzite-decky.just

### Recipes: register every YaguareteOS-shipped recipe file in the master
# justfile. /usr/share/ublue-os/justfile uses explicit `import` lines per
# file; any recipe dropped under /usr/share/ublue-os/just/ that the master
# does not import is invisible to `ujust` (and therefore to yafti's Portal,
# the yaguarete-rescue command, and the renamed Bazzite aliases). Glob all
# files matching the `*yaguarete*.just` pattern so future recipes register
# automatically without touching this script.
echo "" >> /usr/share/ublue-os/justfile
echo "# YaguareteOS-maintained recipes (install-eden, yaguarete-rescue, yaguarete-cli, etc.)" \
    >> /usr/share/ublue-os/justfile
for just_file in /usr/share/ublue-os/just/*yaguarete*.just; do
    [ -e "$just_file" ] || continue
    echo "import \"$just_file\"" >> /usr/share/ublue-os/justfile
done

### Branding: yafti_gtk.py hardcodes APP_TITLE = 'Bazzite Portal' at line 18.
# It is used both for the window title (Gtk.Window) and the
# --title flag passed to the embedded webview. Patch in place so the
# YaguareteOS rebrand reaches the window decoration.
# The argparse description is a second, separate literal further down the
# file; it only surfaces in --help, but leaving it behind means the rebrand is
# complete everywhere except the one place a curious user would look first.
sed -i -e "s|^APP_TITLE = 'Bazzite Portal'|APP_TITLE = 'Portal YaguareteOS'|" \
       -e 's|description="Bazzite Portal"|description="Portal YaguareteOS"|' \
    /usr/bin/yafti_gtk.py

### Branding: yafti registers its window icon via APP_ID
# 'io.github.ublue_os.yafti_gtk', which Gtk resolves through hicolor.
# Repoint that SVG to yaguarete-portal so Portal's window decoration
# uses variant _02 (its dedicated icon) and stays visually distinct
# from the desktop launcher / Kickoff button / kcm_about-distro,
# which all resolve to the catch-all yaguarete-logo (_01).
ln -sf /usr/share/icons/hicolor/scalable/apps/yaguarete-portal.svg \
    /usr/share/icons/hicolor/scalable/apps/io.github.ublue_os.yafti_gtk.svg

### Branding: plasmalogin (Plasma 6 display manager) + desktop default
# wallpaper. Bazzite pattern: do not override
# /usr/lib/plasmalogin/defaults.conf (upstream Fedora ships it referencing
# file:///usr/share/backgrounds/default.jxl). Instead, swap the
# destination of that path so the upstream default resolution lands on
# the YaguareteOS wallpaper. Bazzite redirects to convergence.jxl this
# same way; we redirect to yaguarete_selva_oscura.png — dark jungle
# texture that pairs with the Layan-KDE glass / blur (see #118).
#
# Extension stays .jxl even though the target is .png — Plasma 6 / Qt 6
# decodes by magic bytes, not by extension. Same trade-off applied to
# the bazzite-logo.svg → yaguarete-logo.svg redirect block above.
ln -sf /usr/share/wallpapers/yaguarete/yaguarete_selva_oscura.png \
    /usr/share/backgrounds/default.jxl
ln -sf /usr/share/wallpapers/yaguarete/yaguarete_selva_oscura.png \
    /usr/share/backgrounds/default-dark.jxl

### Branding: pre-flatten the 256x256 yaguarete logo onto solid black so
# fastfetch's sixel renderer outputs the glyph without an opaque-black
# ribbon around the silhouette. libsixel does not honour the source PNG
# alpha channel; pre-multiplying onto the terminal background colour
# (Konsole Vapor profile = solid black) makes the transparent regions
# match the terminal background, so the logo looks "transparent" in
# practice. Keep the alpha-carrying logo in hicolor for KDE/GTK
# consumers; only the fastfetch source is the flattened variant.
mkdir -p /usr/share/yaguarete/branding/fastfetch
magick /usr/share/icons/hicolor/256x256/apps/yaguarete-logo-icon.png \
    -background black -flatten \
    /usr/share/yaguarete/branding/fastfetch/yaguarete-logo-flat-256.png

### Identity: rewrite YaguareteOS-specific fields on the inherited
# /usr/lib/os-release in place (Bazzite/Fedora keeps every version /
# date field up to date for us, so we only own the identity fields).
# Done with `sed -i` so version-related lines pass through untouched.
#
# Closes the systemd-boot loader entries gap (#57) as a side-effect:
# bootupd reads BOOTLOADER_NAME from this file when populating the
# entry titles, so rewriting the value here propagates to the boot
# menu at next image deploy.
sed -i \
    -e 's|^NAME=.*|NAME="YaguareteOS"|' \
    -e 's|^ID=.*|ID=yaguarete|' \
    -e 's|^ID_LIKE=.*|ID_LIKE="bazzite fedora"|' \
    -e 's|^PRETTY_NAME=.*|PRETTY_NAME="YaguareteOS"|' \
    -e 's|^VARIANT_ID=.*|VARIANT_ID=yaguarete|' \
    -e 's|^LOGO=.*|LOGO=yaguarete-logo-icon|' \
    -e 's|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="yaguarete"|' \
    -e 's|^HOME_URL=.*|HOME_URL="https://github.com/lobinuxsoft/yaguarete_os"|' \
    -e 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/lobinuxsoft/yaguarete_os/wiki"|' \
    -e 's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/lobinuxsoft/yaguarete_os/discussions"|' \
    -e 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/lobinuxsoft/yaguarete_os/issues"|' \
    -e 's|^VENDOR_NAME=.*|VENDOR_NAME="YaguareteOS"|' \
    -e 's|^VENDOR_URL=.*|VENDOR_URL="https://github.com/lobinuxsoft/yaguarete_os"|' \
    -e '/^CPE_NAME=/s|:bazzite:|:yaguarete:|' \
    -e '/^BOOTLOADER_NAME=/s|Bazzite|YaguareteOS|g' \
    -e '/^IMAGE_ID=/s|bazzite|yaguarete|g' \
    -e '/^BUILD_ID=/s|Bazzite|YaguareteOS|g' \
    /usr/lib/os-release

### Identity: rewrite the four identity fields of image-info.json. The
# numeric version / date fields stay verbatim from the inherited file
# so ublue-motd and other consumers keep reading accurate Fedora-level
# version data without us having to re-stamp it on every build.
INHERITED_IMAGE_INFO=/usr/share/ublue-os/image-info.json
TMP_IMAGE_INFO=$(mktemp)
jq \
    --arg name "${YAGUARETE_IMAGE_NAME:-yaguarete_os}" \
    --arg ref "ostree-image-signed:docker://ghcr.io/lobinuxsoft/${YAGUARETE_IMAGE_NAME:-yaguarete_os}" \
    '.["image-name"] = $name
     | .["image-vendor"] = "lobinuxsoft"
     | .["image-ref"] = $ref' \
    "$INHERITED_IMAGE_INFO" > "$TMP_IMAGE_INFO"
install -m 0644 "$TMP_IMAGE_INFO" "$INHERITED_IMAGE_INFO"
rm -f "$TMP_IMAGE_INFO"

### Branding: refresh the hicolor icon cache so all the new symlinks
# (yafti_gtk, bazzite-logo-icon, /usr/share/ublue-os/bazzite/*.svg)
# and added launchers (Instalar YaguareteOS, etc.) resolve correctly
# in KDE / GTK lookups.
gtk-update-icon-cache -f -t /usr/share/icons/hicolor

### HHD-UI branding: replace bazzite logo + violet palette inside the
# hhd-ui Electron AppImage with yaguareté assets, without forking
# hhd-dev/hhd-ui. See patch-hhd-ui.sh header for the full rationale.
# Non-fatal — exits 0 if /usr/bin/hhd-ui is absent in this variant.
#
# Bazzite 44 retired Handheld Daemon on the deck image (InputPlumber +
# OpenGamepadUI took over), so on that base this skips and the branding simply
# has nothing to brand. That is expected; the loud banner below exists because
# the skip used to be indistinguishable from success in a green build.
/ctx/patch-hhd-ui.sh

### HHD plugin: hhd-vram — GTT (graphics memory) allocation slider for AMD APUs.
# Adds a slider to the HHD overlay that maps a chosen % of system RAM as GPU
# graphics memory (GTT) via the ttm.pages_limit kernel argument, applied with
# rpm-ostree kargs + reboot. On unified-memory APUs GTT shares the same DDR as
# the BIOS UMA carveout at full bandwidth, so this is the Linux-native
# equivalent of OneXConsole's VRAM tuning on Windows — no BIOS trip required.
#
# Source is vendored under build_files/hhd-vram/ (self-contained with its own
# pyproject; extract to a standalone repo later if it ever ships to the wider
# handheld community). Gated on Handheld Daemon being present so it only lands
# on the deck variant and no-ops on desktop/nvidia. --no-deps because hhd is
# already in the deck base; without it pip rebuilds pycairo (needs cairo/cmake)
# and fails. Installs to /usr site-packages so HHD discovers it by entry point
# with no drop-in or PYTHONPATH.
#
# Bazzite 44 retired HHD on the deck image, so `import hhd` now fails there and
# this block is skipped. A skipped feature must not read like a built one: the
# else branch prints a banner so the loss is visible in the build log instead
# of being inferred later from a device that no longer has the slider.
if python3 -c "import hhd" 2>/dev/null; then
    # /ctx is a read-only bind mount; setuptools writes .egg-info in-tree
    # while building, so copy the source to writable tmpfs (/tmp) first.
    cp -r /ctx/hhd-vram /tmp/hhd-vram-src
    # --prefix=/usr so pip lands in /usr/lib/pythonX.Y/site-packages (where HHD
    # discovers plugins, next to adjustor) instead of Fedora pip's default
    # /usr/local, which does not exist in the image and is off HHD's path.
    python3 -m pip install --no-deps --break-system-packages --prefix=/usr /tmp/hhd-vram-src
    rm -rf /tmp/hhd-vram-src
    echo "[hhd-vram] installed: Handheld Daemon present in this base"
else
    echo "======================================================================"
    echo "[hhd-vram] NOT INSTALLED — Handheld Daemon is absent from this base."
    echo "[hhd-vram] The GTT/VRAM slider does not exist on the resulting image."
    echo "[hhd-vram] Expected on Bazzite >= 44 deck, which replaced HHD with"
    echo "[hhd-vram] InputPlumber + OpenGamepadUI. Port the plugin or drop it."
    echo "======================================================================"
fi

### Plymouth: set yaguarete as the default theme and regenerate the
# initramfs so it reaches early boot.
#
# `plymouth-set-default-theme` creates the
# /usr/share/plymouth/themes/default.plymouth symlink that points to the
# requested theme. Without that symlink Plymouth in early boot falls back
# to whichever theme it finds alphabetically (spinner, in our case — and
# spinner's watermark.png is bazzite-branded by the bazzite-deck base, so
# the user sees a bazzite logo instead of the yaguarete jaguar). Validated
# on OneXFly F1 Pro real install — see #164. Plymouth in SHUTDOWN mode
# loads `spinner` regardless of plymouthd.conf default (root cause not
# fully diagnosed — possibly attach-to-session quirk). To cover that path
# we ALSO ship our own spinner/watermark.png override (see system_files/
# usr/share/plymouth/themes/spinner/watermark.png). See #170.
#
# `system_files/etc/plymouth/plymouthd.conf` already declares
# `Theme=yaguarete`, but Plymouth checks the default.plymouth symlink
# regardless, so both pieces need to be in place.
#
# Then build-initramfs regenerates the initramfs the same way bazzite does
# at Containerfile:755 → build_files/build-initramfs. See #150 for that
# half of the fix.
plymouth-set-default-theme yaguarete
/ctx/build-initramfs

### Make sure everything we ship under /usr/libexec/yaguarete is executable.
#
# The repo lives on an NTFS volume, which has no POSIX permission bits, so
# a local `chmod +x` never reaches the git index and the file lands in the
# image as 0644. A non-executable helper fails with "Permission denied"
# and, when it is the Portal action wrapper, konsole closes before the
# message can be read — which looks exactly like the silent failure the
# wrapper exists to prevent (#237). Belt and braces: the mode is also
# correct in git.
chmod 0755 /usr/libexec/yaguarete/*
