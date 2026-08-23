# Base image is parameterised so the same Containerfile feeds every variant
# in the build matrix:
#   - ghcr.io/ublue-os/bazzite:stable             — AMD/Intel desktop (KDE)
#   - ghcr.io/ublue-os/bazzite-nvidia:stable      — NVIDIA proprietary (KDE)
#   - ghcr.io/ublue-os/bazzite-nvidia-open:stable — NVIDIA open kernel (KDE)
#   - ghcr.io/ublue-os/bazzite-deck:stable        — handheld (KDE + gamescope-session)
# Default keeps `podman build .` (without --build-arg) reproducible to the
# desktop AMD base — the most common local dev path.
#
# IMPORTANT: this `ARG` MUST be declared *before* the first `FROM` so it has
# global scope and is visible to every subsequent `FROM`. Declaring it after
# the first FROM scopes it to that stage only and the second FROM resolves
# to an empty string ("no FROM statement found").
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite:stable

# Image name is also parameterised so build.sh can stamp it into
# /usr/share/ublue-os/image-info.json without hardcoding the variant.
# Default matches the desktop base; matrix entries override it.
ARG IMAGE_NAME=yaguarete_os

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

### Updater built from source.
# Terra's `bazzite-updater` says "Bazzite" on every screen and none of it is
# reachable from /etc: the strings are compiled into the executable as UTF-16
# inside the precompiled QML. This stage rebuilds the same upstream release
# with the product name changed. See build_files/updater/.
#
# It builds FROM the image base rather than a plain Fedora so the app links
# against exactly the Qt6/KF6 that ships in the final image -- a mismatch
# here does not fail the build, it fails at startup with a QML module that
# will not load.
FROM ${BASE_IMAGE} AS updater
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build-updater.sh

FROM ${BASE_IMAGE}

# Persist the build-time image name so /ctx/build.sh can read it.
ARG IMAGE_NAME
ENV YAGUARETE_IMAGE_NAME=${IMAGE_NAME}

# Overlay system_files/ into rootfs (wallpapers, branding, configs).
# Top-level subdirs are copied individually so `system_files/overrides/`
# (the in-place asset replacement layer, applied last — see end of file)
# does not end up as a stray /overrides/ directory at the root of the
# image. Mirrors the bazzite Containerfile pattern (Containerfile:62 for
# desktop COPYs, :460 for the trailing overrides COPY).
COPY system_files/etc /etc
COPY system_files/usr /usr

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=updater,source=/out,target=/rpms \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### Cleanup & Finalize
# Apply asset overrides last so the contents of system_files/overrides/
# overwrite the Fedora/bazzite-shipped pixmaps, hicolor logo PNGs, places
# SVGs and favicon in-place. This is the canonical bazzite pattern (their
# Containerfile:460 does the same trailing COPY). Anything in this overlay
# replaces the same path that was provided earlier by the base image or by
# packages installed in build.sh.
COPY system_files/overrides /

### Updater: commit to one entry in the menu.
# `yaguarete-updater` is our build of rfrench3/bazzite-updater -- a Qt GUI
# that runs the same update through uupd-manual.service and adds rollback
# plus a release-notes feed. build.sh installs it and fails the build if the
# swap against Terra's package does not take, so by this point the package
# is guaranteed present and the old "is it installed?" fallback is gone.
#
# This still has to run AFTER the overrides COPY above: that is when the
# .desktop rebrand and the icon are on disk.
RUN printf 'NoDisplay=true\n' >> /usr/share/applications/system-update.desktop && \
    echo "[updater] console entry hidden, Yaguarete Updater is the menu entry"

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
