#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux 

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
for variant in bazzite-logo.svg bazzite-logo-white.svg bazzite-logo-le.svg; do
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
