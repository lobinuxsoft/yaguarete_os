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
