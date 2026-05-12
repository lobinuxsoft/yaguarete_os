#!/usr/bin/env bash
#
# Post-rootfs hook for YaguareteOS live ISO.
# Adapted from ublue-os/bazzite's installer. Drops: Secure Boot key enrollment
# (no YaguareteOS signing key yet), NVIDIA-specific handling (no NVIDIA variant
# today), Steam Deck specifics (handled by the sibling project
# yaguarete_os_handheld), Steam/Lutris/Bazaar/Waydroid removal (not preinstalled),
# Conky (not preinstalled), Bazzite custom KDE pins. Keeps: Bitlocker detection
# dialog (universal UX), kickstart appends, bootc switch, livesys tweaks.

set -exo pipefail

source /etc/os-release

# Remove all versionlocks to avoid dependency issues
dnf -qy versionlock clear || :

# Install Anaconda
dnf install -qy --enable-repo=fedora-cisco-openh264 --allowerasing firefox anaconda-live libblockdev-{btrfs,lvm,dm}

mkdir -p /var/lib/rpm-state # Needed for Anaconda Web UI

# Rebrand the live "Install" desktop launcher to YaguareteOS.
# anaconda-live ships /etc/skel/Desktop/liveinst.desktop (and sometimes
# /usr/share/applications/liveinst.desktop) with Icon=fedora-logo-icon
# and Name="Install to Hard Drive". Override both with YaguareteOS branding.
for liveinst_path in /etc/skel/Desktop/liveinst.desktop /usr/share/applications/liveinst.desktop; do
    if [[ -f $liveinst_path ]]; then
        cat <<'EOF' >"$liveinst_path"
[Desktop Entry]
Name=Instalar YaguareteOS
Name[en]=Install YaguareteOS
Name[es]=Instalar YaguareteOS
Name[fr]=Installer YaguareteOS
Name[pt]=Instalar YaguareteOS
Name[it]=Installa YaguareteOS
Comment=Instalar el sistema YaguareteOS en el disco duro
Comment[en]=Install the YaguareteOS system to the hard drive
Comment[es]=Instalar el sistema YaguareteOS en el disco duro
GenericName=Instalador del sistema
Icon=yaguarete-logo-icon
Type=Application
Exec=liveinst
Categories=System;
EOF
        chmod 0755 "$liveinst_path"
    fi
done

# Override Anaconda variant pixmap sidebar logos with yaguarete-logo.
# Anaconda's WebUI/GTK falls back to these pixmaps when no custom asset
# is wired in the profile. Preserves expected filenames so Anaconda code
# paths keep working.
for pixmap_dir in /usr/share/anaconda/pixmaps \
                  /usr/share/anaconda/pixmaps/atomic \
                  /usr/share/anaconda/pixmaps/cloud \
                  /usr/share/anaconda/pixmaps/server \
                  /usr/share/anaconda/pixmaps/silverblue \
                  /usr/share/anaconda/pixmaps/workstation; do
    if [[ -d $pixmap_dir ]]; then
        cp -f /usr/share/icons/hicolor/256x256/apps/yaguarete-logo-icon.png \
            "$pixmap_dir/sidebar-logo.png" 2>/dev/null || :
    fi
done

# Dialog utilities for the Bitlocker prompt
dnf install -qy --setopt=install_weak_deps=0 qrencode yad

# Variables
imageref="$(podman images --format '{{ index .Names 0 }}\n' 'yaguarete*' | head -1)"
imageref="${imageref##*://}"
imageref="${imageref%%:*}"
imagetag="$(podman images --format '{{ .Tag }}\n' "$imageref" | head -1)"

# YaguareteOS Anaconda profile
: "${VARIANT_ID:?}"

echo "YaguareteOS release $VERSION_ID ($VERSION_CODENAME)" >/etc/system-release

# Default Kickstart
cat <<EOF >>/usr/share/anaconda/interactive-defaults.ks

# Default user, locale, keyboard, timezone (skip Anaconda spokes).
# rootpw --lock is atomic-friendly: root is locked, satisfies Anaconda
# without prompting (PasswordSpoke is also hidden via yaguarete.conf).
user --name=yaguarete --password=yaguarete --plaintext --groups=wheel
lang es_AR.UTF-8
keyboard --xlayouts=latam --vckeymap=la-latin1
timezone America/Argentina/Buenos_Aires --utc
rootpw --lock

# Create log directory
%pre
mkdir -p /tmp/anacoda_custom_logs
%end

# Check if there is a bitlocker partition and ask the user to disable it
%pre --erroronfail --log=/tmp/anacoda_custom_logs/detect_bitlocker.log
DOCS_QR=/tmp/detect_bitlocker_qr.png
IS_BITLOCKER=\$(lsblk -o FSTYPE --json | jq '.blockdevices | map(select(.fstype == "BitLocker")) | . != []')
{ WARNING_MSG="\$(</dev/stdin)"; } << 'WARNINGEOF'
<span size="x-large">Partición Windows Bitlocker detectada</span>

Puede interrumpir el proceso de instalación.
Si pasa, hacé <b>una</b> de las siguientes:
    a) Desconectá la unidad.
    b) Desactivá Bitlocker en Windows.
    c) Borrá la partición en GNOME Disks.

¿Continuar?
WARNINGEOF

if [[ \$IS_BITLOCKER =~ true ]]; then
    qrencode -o \$DOCS_QR "https://www.wikihow.com/Turn-Off-BitLocker"
    _EXITLOCK=1
    _RETCODE=0
    while [[ \$_EXITLOCK -ne 0 ]]; do
        run0 --user=liveuser yad \\
            --on-top \\
            --timeout=10 \\
            --image=\$DOCS_QR \\
            --text="\$WARNING_MSG" \\
            --button="Sí, continuar":0 --button="Cancelar instalación":10
        _RETCODE=\$?
        case \$_RETCODE in
            0) _EXITLOCK=0; ;;
            10) _EXITLOCK=0; pkill liveinst; pkill firefox; exit 0 ;;
        esac
    done
fi
%end

# Remove the efi dir; must match efi_dir from the profile config
%pre-install --erroronfail
rm -rf /mnt/sysroot/boot/efi/EFI/fedora
%end

# Relabel the boot partition
%pre-install --erroronfail --log=/tmp/anacoda_custom_logs/repartitioning.log
set -x
xboot_dev=\$(findmnt -o SOURCE --nofsroot --noheadings -f --target /mnt/sysroot/boot)
if [[ -z \$xboot_dev ]]; then
  echo "ERROR: xboot_dev not found"
  exit 1
fi
e2label "\$xboot_dev" "yaguarete_xboot"
%end

# Open a dialog with the installation logs on error
%onerror
run0 --user=liveuser yad \\
    --timeout=0 \\
    --text-info \\
    --no-buttons \\
    --width=600 \\
    --height=400 \\
    --text="Ocurrió un error durante la instalación. Por favor reportá el problema en https://github.com/lobinuxsoft/yaguarete_os/issues" \\
    < /tmp/anaconda.log
%end

ostreecontainer --url=$imageref:$imagetag --transport=containers-storage --no-signature-verification
%include /usr/share/anaconda/post-scripts/install-configure-upgrade.ks
%include /usr/share/anaconda/post-scripts/disable-fedora-flatpak.ks
%include /usr/share/anaconda/post-scripts/install-flatpaks.ks
%include /usr/share/anaconda/post-scripts/flatpak-restore-selinux-labels.ks

EOF

# Switch the installed deployment to the public registry (signed by us later when we have a key)
cat <<EOF >>/usr/share/anaconda/post-scripts/install-configure-upgrade.ks
%post --erroronfail --log=/tmp/anacoda_custom_logs/bootc-switch.log
bootc switch --mutate-in-place --transport registry ghcr.io/lobinuxsoft/yaguarete_os:stable
%end
EOF

### Livecds runtime tweaks ###

# Disable services we don't want running in the live session
(
    set +e
    for s in \
        rpm-ostree-countme.service \
        tailscaled.service \
        ublue-hardware-setup.service \
        bootloader-update.service \
        rpm-ostreed-automatic.timer \
        uupd.timer \
        ublue-guest-user.service \
        ublue-os-media-automount.service \
        ublue-system-setup.service \
        ublue-flatpak-manager.service \
        flatpak-add-fedora-repos.service \
        greenboot-set-rollback-trigger.service \
        greenboot-healthcheck.service \
        switcheroo-control.service \
        check-sb-key.service; do
        if systemctl list-unit-files "$s" >/dev/null 2>&1; then
            systemctl disable "$s"
        fi
    done

    for s in \
        podman-auto-update.timer \
        ublue-user-setup.service; do
        if systemctl --global list-unit-files "$s" >/dev/null 2>&1; then
            systemctl --global disable "$s"
        fi
    done
)

### Desktop-environment specific tweaks ###

# Detect desktop env from session files
desktop_env=""
_session_file="$(find /usr/share/wayland-sessions/ /usr/share/xsessions \
    -maxdepth 1 -type f -not -name '*gamescope*.desktop' -and -name '*.desktop' -printf '%P' -quit)"
case $_session_file in
budgie*) desktop_env=budgie ;;
cosmic*) desktop_env=cosmic ;;
gnome*) desktop_env=gnome ;;
plasma*) desktop_env=kde ;;
sway*) desktop_env=sway ;;
xfce*) desktop_env=xfce ;;
esac

# Don't check for verified image (ublue motd verifier signature warning)
rm -vf /etc/profile.d/verify_motd.sh

# Install Gparted for manual partitioning in the live session
dnf -yq install gparted

# Clean up dnf cache to save space
dnf clean all
