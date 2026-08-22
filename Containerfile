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

### Updater: commit to one entry in the menu, but only if there is one to
# commit to. `bazzite-updater` (Terra repo, pulled in by the Bazzite base)
# is a Qt GUI that runs the same update via uupd-manual.service and adds
# rollback plus a release-notes feed; system_files/overrides/ rebrands it
# to "Yaguarete Updater" and repoints its RSS feed and About data at us.
# This has to run AFTER the overrides COPY above -- that is when both the
# package and our rebrand are on disk. If a variant ever ships without the
# package, hiding our console entry would leave the image with NO updater
# in the menu and a launcher pointing at a missing binary, so in that case
# the rebrand is removed and the console entry stays visible instead.
RUN if rpm -q bazzite-updater >/dev/null 2>&1; then \
        printf 'NoDisplay=true\n' >> /usr/share/applications/system-update.desktop && \
        echo "[updater] bazzite-updater present -> Yaguarete Updater shipped, console entry hidden"; \
    else \
        rm -f /usr/share/applications/io.github.rfrench3.bazzite-updater.desktop && \
        rm -rf /etc/bazzite-updater && \
        echo "[updater] bazzite-updater ABSENT -> rebrand dropped, console entry stays visible"; \
    fi

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
