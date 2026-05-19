#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Base CLI tooling
dnf5 install -y tmux

# Default pre-installed apps for all 4 variants. Maintained list — decisions
# tracked in #93. Skip packages already shipped by upstream Bazzite
# (mangohud, goverlay, lutris, ffmpeg-free) to avoid duplicate layers.
dnf5 install -y \
    vlc \
    gimp \
    inkscape \
    obs-studio \
    blender \
    git-lfs

# Typography stack — decisions tracked in #12.
# - Inter (rsms-inter-fonts) is the UI font referenced by the kdeglobals
#   font keys; pre-install so the theme applies on first boot instead of
#   falling back to Noto Sans.
# - JetBrainsMono Nerd Font ships in the Bazzite nerd-fonts layer, so we
#   do not duplicate it here — it is already the mono font in
#   /etc/xdg/kdeglobals and the YaguareteOS Konsole profile.
# - Noto Serif is the document font; apps (Kate, LibreOffice) can opt in.
dnf5 install -y \
    rsms-inter-fonts \
    google-noto-serif-fonts

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

### Branding: keep /usr/share/ublue-os/motd/bazzite.md path alive as a
# symlink to the YaguareteOS-named file. Reason: /usr/libexec/ublue-motd
# hardcodes the bazzite.md path; renaming the file alone breaks login MOTD.
ln -sf yaguarete.md /usr/share/ublue-os/motd/bazzite.md

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

### Branding: yafti_gtk.py hardcodes APP_TITLE = 'Bazzite Portal' at line 18.
# It is used both for the window title (Gtk.Window) and the
# --title flag passed to the embedded webview. Patch in place so the
# YaguareteOS rebrand reaches the window decoration.
sed -i "s|^APP_TITLE = 'Bazzite Portal'|APP_TITLE = 'Portal YaguareteOS'|" \
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

### Plymouth: regenerate the initramfs so the yaguarete theme overlay
# (system_files/etc/plymouth/plymouthd.conf + the theme files under
# /usr/share/plymouth/themes/yaguarete/) actually reaches early boot.
# Without this step, the inherited initramfs from the base image ships
# unchanged and the splash shows the upstream default. Replicates the
# pattern bazzite uses at Containerfile:755 → build_files/build-initramfs.
# See #150.
/ctx/build-initramfs
