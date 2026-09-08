#!/usr/bin/bash
# Build yaguarete-ui (fork of ShadowBlip/OpenGamepadUI) from source.
#
# Runs in its own Containerfile stage, FROM the same base as the image, for
# the same reason build-updater.sh does: whatever native bits this links
# against at build time need to match what is actually on the image, and a
# mismatch here should fail loudly at build time, not silently at runtime.
#
# Output: one RPM in /out, consumed by build.sh through a bind mount.

set -euo pipefail

SPEC=/ctx/opengamepadui/yaguarete-ui.spec
OUT=/out

version=$(awk '/^Version:/ {print $2}' "$SPEC")
commit=$(awk '/^%global +commit/ {print $3}' "$SPEC")

echo "[opengamepadui] building yaguarete-ui ${version} @ ${commit}"

# Godot editor pin: must match exactly what the Rust GDExtension core
# (extensions/) gets built against by the same Makefile run, and what the
# base image's own opengamepadui was itself built with — a mismatch here
# does not fail the build, it fails at runtime with the core .so refusing to
# load. Fedora's own `godot` package is 4.7.2, one patch release off; rather
# than gamble on GDExtension ABI compatibility across that gap, this
# downloads the exact upstream binary, the same one this fork's own Godot
# project was authored and tested against.
GODOT_PIN_VERSION=4.7.1-stable
GODOT_PIN_SHA256=c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba

dnf5 install -y \
    cargo \
    git-core \
    make \
    rpm-build \
    rust \
    systemd-rpm-macros \
    unzip \
    wget

topdir=/build/rpmbuild
mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
src="$topdir/SOURCES"

godot_dir=$(mktemp -d)
wget -q -O "$godot_dir/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_PIN_VERSION}/Godot_v${GODOT_PIN_VERSION}_linux.x86_64.zip"
echo "${GODOT_PIN_SHA256}  $godot_dir/godot.zip" | sha256sum -c -
unzip -q "$godot_dir/godot.zip" -d "$godot_dir"
chmod +x "$godot_dir/Godot_v${GODOT_PIN_VERSION}_linux.x86_64"
GODOT_BIN="$godot_dir/Godot_v${GODOT_PIN_VERSION}_linux.x86_64"

# Clone at the tag, then assert the commit — same reasoning as
# build-updater.sh: a tag can move, a commit hash cannot.
work=$(mktemp -d)
git -C "$work" clone --quiet --depth 1 --branch v${version}-yaguarete1 \
    https://github.com/lobinuxsoft/yaguarete-ui.git yaguarete-ui
got=$(git -C "$work/yaguarete-ui" rev-parse HEAD)
if [[ "$got" != "$commit" ]]; then
    echo "[opengamepadui] tag v${version}-yaguarete1 points at ${got}, expected ${commit}" >&2
    exit 1
fi

# make dist/opengamepadui-x86_64.tar.gz needs the Godot editor to export the
# project and cargo to build the Rust GDExtension core (extensions/) — cargo
# is installed above, GODOT points at the pinned editor downloaded above.
# The Makefile's own $(EXPORT_TEMPLATE) rule downloads the matching export
# templates on demand from this same GODOT binary's reported version.
make -C "$work/yaguarete-ui" GODOT="$GODOT_BIN" TARGET_ARCH=x86_64 \
    dist/opengamepadui-x86_64.tar.gz

# The spec's Source0 is a bare filename (built from source here, not
# downloaded), so rpmbuild just needs it present under SOURCES.
cp "$work/yaguarete-ui/dist/opengamepadui-x86_64.tar.gz" "$src/"

rpmbuild --define "_topdir $topdir" -bb --target=x86_64 "$SPEC"

mkdir -p "$OUT"
find "$topdir/RPMS" -name '*.rpm' -exec cp -v {} "$OUT/" \;

test -n "$(find "$OUT" -name 'yaguarete-ui-*.rpm' -print -quit)"
