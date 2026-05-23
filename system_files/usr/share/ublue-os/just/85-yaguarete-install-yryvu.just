# YaguareteOS — install / update / remove Yryvu (Git client by lobinuxsoft).
#
# Yryvu is a Tauri 2 + SolidJS Git GUI maintained at lobinuxsoft/yryvu.
# These recipes wrap the GitHub Release AppImage flow that the rest of
# YaguareteOS already uses (see install-eden), so the wizard yafti can
# offer it as a one-click install.
#
# Release naming (lobinuxsoft/yryvu releases):
#   - Tag pattern:  yryvu-v<MAJOR>.<MINOR>.<PATCH>
#   - Linux asset:  Yryvu_<version>_amd64.AppImage
#   - Sidecar:      checksums-sha256.txt (SHA256 of every asset in the release)
#
# Override knobs:
#   YAGUARETE_APPS_DIR  where Yryvu.AppImage lives (default ~/Applications)

install-yryvu:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh

    yg_info "Yryvu — Git client install"
    yg_check_internet
    yg_check_disk 200

    mkdir -p "$YG_APPS_DIR"
    YRYVU_BIN="$YG_APPS_DIR/Yryvu.AppImage"

    # Resolve latest release. lobinuxsoft/yryvu uses tag prefix `yryvu-v` so we
    # strip it down to a bare semver for the asset filename match.
    yg_info "Resolving latest Yryvu release"
    release=$(gh api repos/lobinuxsoft/yryvu/releases/latest 2>/dev/null \
        || curl -fsSL https://api.github.com/repos/lobinuxsoft/yryvu/releases/latest)
    tag=$(echo "$release" | jq -r '.tag_name')
    version="${tag#yryvu-v}"
    if [[ -z "$version" || "$version" == "$tag" ]]; then
        yg_err "Unexpected tag format '$tag' (expected yryvu-v<semver>)."
        exit 1
    fi
    asset_name="Yryvu_${version}_amd64.AppImage"
    asset_url=$(echo "$release" | jq -r --arg n "$asset_name" '.assets[] | select(.name == $n) | .browser_download_url')
    checksums_url=$(echo "$release" | jq -r '.assets[] | select(.name == "checksums-sha256.txt") | .browser_download_url')
    if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
        yg_err "Asset $asset_name not found in release $tag. Available: $(echo "$release" | jq -r '.assets[].name' | tr '\n' ' ')"
        exit 1
    fi

    # Download to a temp file first so a partial download never overwrites
    # a working install. Verify SHA256 before swapping in.
    tmp_bin="$(mktemp --tmpdir Yryvu.XXXXXX.AppImage)"
    yg_download "$asset_url" "$tmp_bin"
    if [[ -n "$checksums_url" && "$checksums_url" != "null" ]]; then
        sums="$(mktemp)"
        yg_download "$checksums_url" "$sums"
        expected=$(awk -v n="$asset_name" '$2 == n || $2 == "*"n {print $1}' "$sums")
        if [[ -n "$expected" ]]; then
            actual=$(sha256sum "$tmp_bin" | awk '{print $1}')
            if [[ "$expected" != "$actual" ]]; then
                yg_err "SHA256 mismatch for $asset_name (expected $expected, got $actual)"
                rm -f "$tmp_bin" "$sums"
                exit 2
            fi
            yg_ok "SHA256 verified."
        else
            yg_warn "No entry for $asset_name in checksums-sha256.txt — skipping verify."
        fi
        rm -f "$sums"
    fi
    mv "$tmp_bin" "$YRYVU_BIN"
    chmod +x "$YRYVU_BIN"
    yg_ok "Yryvu $version installed at $YRYVU_BIN"

    # Extract .desktop + icon from the AppImage. Yryvu ships a single
    # canonical app id; we rewrite Exec= to point at our installed path
    # and pin Icon= to a stable slug so updates do not orphan icons.
    extract_dir=$(mktemp -d)
    pushd "$extract_dir" >/dev/null
    "$YRYVU_BIN" --appimage-extract >/dev/null 2>&1
    desktop_src=$(find squashfs-root -maxdepth 2 -name '*.desktop' 2>/dev/null | head -1)
    if [[ -n "$desktop_src" ]]; then
        icon_name=$(grep -m1 '^Icon=' "$desktop_src" | sed 's/^Icon=//')
        icon_src=""
        if [[ -n "$icon_name" ]]; then
            icon_src=$(find squashfs-root \( -name "${icon_name}.svg" -o -name "${icon_name}.png" \) 2>/dev/null | head -1)
        fi
        mkdir -p "$YG_DESKTOP_DIR" "$YG_ICON_DIR"
        sed "s|^Exec=.*|Exec=$YRYVU_BIN %f|; s|^Icon=.*|Icon=yryvu|" \
            "$desktop_src" > "$YG_DESKTOP_DIR/Yryvu.desktop"
        if [[ -n "$icon_src" ]]; then
            cp "$icon_src" "$YG_ICON_DIR/yryvu.${icon_src##*.}"
        else
            yg_warn "No icon matching Icon=$icon_name in the AppImage — Yryvu will show a generic launcher icon."
        fi
        yg_refresh_desktop_db
        yg_ok "Desktop entry + icon installed (id: ${icon_name:-unknown})"
    else
        yg_warn "No .desktop file in the AppImage — Yryvu will not appear in the KDE menu (run $YRYVU_BIN by hand)."
    fi
    popd >/dev/null
    rm -rf "$extract_dir"

    echo
    yg_ok "Yryvu install complete."
    yg_info "Launch from the KDE menu or run: $YRYVU_BIN"

update-yryvu:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh
    yg_info "Refreshing Yryvu (keeps user config and repos)"
    yg_check_internet

    YRYVU_BIN="$YG_APPS_DIR/Yryvu.AppImage"
    release=$(gh api repos/lobinuxsoft/yryvu/releases/latest 2>/dev/null \
        || curl -fsSL https://api.github.com/repos/lobinuxsoft/yryvu/releases/latest)
    tag=$(echo "$release" | jq -r '.tag_name')
    version="${tag#yryvu-v}"
    asset_name="Yryvu_${version}_amd64.AppImage"
    asset_url=$(echo "$release" | jq -r --arg n "$asset_name" '.assets[] | select(.name == $n) | .browser_download_url')
    if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
        yg_err "Asset $asset_name not found in release $tag."
        exit 1
    fi
    tmp_bin="$(mktemp --tmpdir Yryvu.XXXXXX.AppImage)"
    yg_download "$asset_url" "$tmp_bin"
    mv "$tmp_bin" "$YRYVU_BIN"
    chmod +x "$YRYVU_BIN"
    yg_ok "Yryvu refreshed to $version"

remove-yryvu:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh
    yg_warn "About to remove Yryvu binary + .desktop + icon."
    yg_warn "Your Git repos and Yryvu config in $YG_CONFIG_DIR/yryvu are preserved."
    yg_confirm "Continue?" || { yg_info "Aborted."; exit 0; }

    rm -f "$YG_APPS_DIR/Yryvu.AppImage"
    rm -f "$YG_DESKTOP_DIR/Yryvu.desktop"
    rm -f "$YG_ICON_DIR/yryvu.svg" "$YG_ICON_DIR/yryvu.png"
    yg_refresh_desktop_db
    yg_ok "Yryvu uninstalled. User data preserved at $YG_CONFIG_DIR/yryvu/."
