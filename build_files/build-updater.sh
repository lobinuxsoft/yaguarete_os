#!/usr/bin/bash
# Build yaguarete-updater from upstream source.
#
# Runs in its own Containerfile stage, FROM the same base as the image, so
# the app links against exactly the Qt6/KF6 that will be there at runtime --
# a mismatch here surfaces as a QML module that fails to load at startup,
# not as a build error.
#
# Output: one RPM in /out, consumed by build.sh through a bind mount.

set -euo pipefail

SPEC=/ctx/updater/yaguarete-updater.spec
OUT=/out

# Single source of truth for both: the spec. Duplicating the version here is
# how the tarball and the %setup directory drift apart.
version=$(awk '/^Version:/ {print $2}' "$SPEC")
commit=$(awk '/^%global +commit/ {print $3}' "$SPEC")
upname=$(awk '/^%global +upname/ {print $3}' "$SPEC")

echo "[updater] building ${upname} ${version} @ ${commit}"

dnf5 install -y \
    binutils \
    cmake \
    desktop-file-utils \
    extra-cmake-modules \
    git-core \
    libappstream-glib \
    rpm-build \
    rpmdevtools \
    systemd-rpm-macros \
    kf6-rpm-macros

dnf5 install -y \
    'cmake(KF6ColorScheme)' \
    'cmake(KF6Config)' \
    'cmake(KF6CoreAddons)' \
    'cmake(KF6I18n)' \
    'cmake(KF6IconThemes)' \
    'cmake(KF6Kirigami)' \
    'cmake(KF6KirigamiAddons)' \
    'cmake(Qt6Core)' \
    'cmake(Qt6Gui)' \
    'cmake(Qt6Qml)' \
    'cmake(Qt6QuickControls2)' \
    'cmake(Qt6Svg)' \
    'cmake(Qt6Test)' \
    'cmake(Qt6Widgets)' \
    'cmake(SDL3)'

rpmdev-setuptree
src=$(rpm --eval '%{_sourcedir}')

# Clone at the tag, then assert the commit. A tag can be moved; a commit
# hash cannot, so this is the part that actually pins the source. Fetching
# GitHub's generated tarball and checksumming it would pin nothing -- those
# archives are regenerated and the checksum is not promised to be stable.
work=$(mktemp -d)
git -C "$work" clone --quiet --depth 1 --branch "$version" \
    https://github.com/rfrench3/bazzite-updater.git "${upname}-${version}"
got=$(git -C "$work/${upname}-${version}" rev-parse HEAD)
if [[ "$got" != "$commit" ]]; then
    echo "[updater] tag ${version} points at ${got}, expected ${commit}" >&2
    exit 1
fi

# The submodule is only compiled when _INCLUDE_SUBMODULES is on, which it is
# not: controllable comes from the qt6-controllable package instead. Nothing
# to check out here.
tar -C "$work" --exclude-vcs -czf "${src}/${upname}-${version}.tar.gz" "${upname}-${version}"
cp /ctx/updater/*.patch "$src/"

rpmbuild -bb "$SPEC"

mkdir -p "$OUT"
find "$(rpm --eval '%{_rpmdir}')" -name '*.rpm' -exec cp -v {} "$OUT/" \;

test -n "$(find "$OUT" -name 'yaguarete-updater-*.rpm' -print -quit)"
