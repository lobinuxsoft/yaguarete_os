#!/usr/bin/env bash
#
# Pre-initramfs hook for YaguareteOS live ISO.
# Adapted from ublue-os/bazzite's installer (drops nvidia-gpu-firmware install,
# yaguarete_os does not ship NVIDIA variants today).

set -exo pipefail

# Swap kernel with vanilla and rebuild initramfs.
# The vanilla Fedora kernel is required so the initramfs is signed by Fedora's
# Secure Boot chain (the kernel that ships in the bootc container may carry
# downstream modifications that are not signed by the same chain).
kernel_pkgs=(
    kernel
    kernel-core
    kernel-devel
    kernel-devel-matched
    kernel-modules
    kernel-modules-core
    kernel-modules-extra
)
dnf -y versionlock delete "${kernel_pkgs[@]}" || :
dnf --setopt=protect_running_kernel=False -y remove "${kernel_pkgs[@]}"
(cd /usr/lib/modules && rm -rf -- ./*)
dnf -y --repo fedora,updates --setopt=tsflags=noscripts install kernel kernel-core
kernel=$(find /usr/lib/modules -maxdepth 1 -type d -printf '%P\n' | grep .)
depmod "$kernel"

dnf clean all -yq
