#!/bin/bash
#
# Install YaguareteOS-maintained custom apps (and adopted upstream ones)
# from their GitHub Releases. Runs inside the container build under
# `build.sh`, so everything ends up baked into /usr/.
#
# Version + checksum are pinned per app. Bumping is a manual edit here
# followed by a `chore(apps): bump <app> X → Y` commit. Until an app
# matures to its own COPR / Flatpak (tracked in #16), this is the
# distribution path.
#
# Layout produced per AppImage:
#   /usr/lib/yaguarete/<app>/{AppRun,*.desktop,usr/...}
#   /usr/bin/<app>                            -> AppRun symlink
#   /usr/share/applications/<app>.desktop     (rewritten to use plain Exec)
#   /usr/share/icons/hicolor/<size>/apps/<app>.png  (when AppImage ships one)

set -ouex pipefail

YAGUARETE_LIB=/usr/lib/yaguarete
mkdir -p "$YAGUARETE_LIB"

# ----------------------------------------------------------------------------
# install_appimage_from_release
#
#   $1 — release URL of the .AppImage asset
#   $2 — expected SHA256 of the asset
#   $3 — short app name (becomes /usr/bin/<name>, /usr/lib/yaguarete/<name>/)
#   $4 — pretty name for the .desktop fallback (only used if the AppImage
#        does not ship one of its own)
# ----------------------------------------------------------------------------
install_appimage_from_release() {
    local url="$1"
    local expected_sha="$2"
    local name="$3"
    local pretty="$4"

    local tmp="/tmp/${name}.AppImage"
    local dest="${YAGUARETE_LIB}/${name}"

    curl -fsSL "$url" -o "$tmp"
    echo "${expected_sha}  ${tmp}" | sha256sum --check --strict

    chmod +x "$tmp"
    mkdir -p "$dest"

    # --appimage-extract dumps everything under ./squashfs-root/ wherever
    # we run it. Run from $dest so we can move contents up afterwards.
    (cd "$dest" && "$tmp" --appimage-extract >/dev/null)
    rm -f "$tmp"
    shopt -s dotglob
    mv "${dest}/squashfs-root/"* "${dest}/"
    shopt -u dotglob
    rmdir "${dest}/squashfs-root"

    ln -sf "${dest}/AppRun" "/usr/bin/${name}"

    # Re-publish the embedded .desktop so the launcher menu picks it up,
    # rewriting Exec to the symlink we just created (the embedded Exec
    # usually points at a relative AppRun path).
    local src_desktop
    src_desktop=$(find "$dest" -maxdepth 2 -name '*.desktop' -type f | head -1 || true)
    if [[ -n "$src_desktop" ]]; then
        install -Dm0644 "$src_desktop" "/usr/share/applications/${name}.desktop"
        sed -i "s|^Exec=.*|Exec=${name} %U|" "/usr/share/applications/${name}.desktop"
    else
        cat > "/usr/share/applications/${name}.desktop" <<EOF
[Desktop Entry]
Name=${pretty}
Exec=${name}
Icon=${name}
Type=Application
Categories=Utility;
EOF
    fi

    # Adopt the AppImage's own icon if any (.DirIcon is the canonical
    # AppImage app icon). Drop it into hicolor scalable so KDE/GTK find it.
    if [[ -L "${dest}/.DirIcon" || -f "${dest}/.DirIcon" ]]; then
        local icon_target
        icon_target=$(readlink -f "${dest}/.DirIcon")
        if [[ -f "$icon_target" ]]; then
            local ext="${icon_target##*.}"
            install -Dm0644 "$icon_target" \
                "/usr/share/icons/hicolor/scalable/apps/${name}.${ext}"
        fi
    fi
}

# ============================================================================
# Yryvu — Git client (Tauri/SolidJS), maintained by lobinuxsoft
# https://github.com/lobinuxsoft/yryvu
# ============================================================================
YRYVU_VERSION="0.1.2"
YRYVU_APPIMAGE_SHA256="a46558765553dade7889709bbc7244c93e8652630d0667327b53305fc1eede2f"

install_appimage_from_release \
    "https://github.com/lobinuxsoft/yryvu/releases/download/yryvu-v${YRYVU_VERSION}/Yryvu_${YRYVU_VERSION}_amd64.AppImage" \
    "$YRYVU_APPIMAGE_SHA256" \
    "yryvu" \
    "Yryvu"

# ============================================================================
# CapyDeploy Agent — Hub-side agent for the LAN game deploy pipeline,
# maintained by lobinuxsoft. Only the Agent is shipped here; the Hub is a
# separate AppImage that runs on the dev machine.
# https://github.com/lobinuxsoft/capydeploy
# ============================================================================
CAPYDEPLOY_VERSION="1.2.1"
CAPYDEPLOY_AGENT_SHA256="d1e209fcd02834c6428bcc0a6b7f85c82b0694ce1b48f9fe9249ead8b4669a67"

install_appimage_from_release \
    "https://github.com/lobinuxsoft/capydeploy/releases/download/v${CAPYDEPLOY_VERSION}/CapyDeploy_Agent.AppImage" \
    "$CAPYDEPLOY_AGENT_SHA256" \
    "capydeploy-agent" \
    "CapyDeploy Agent"
