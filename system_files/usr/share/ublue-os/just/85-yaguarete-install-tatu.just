# YaguareteOS — install / update / remove Tatu (Steam backlog tracker).
#
# Tatu is a Tauri 2 frontend + Aurora-style Win32 bridge backend maintained
# at lobinuxsoft/tatu. The repo was renamed from game-progress-tracker on
# 2026-05-20 (PR #107); the release asset filenames caught up to that name
# starting with v0.8.0 (2026-08-23) — that release and every one after it
# ship "Tatu.AppImage" with a properly Tatu-branded .desktop baked in
# (Name=Tatu, Icon=com.lobinux.tatu-tracker, verified by extracting v0.9.0).
# Only v0.7.0 and earlier still carry the legacy Game_Progress_Tracker name.
#
# This recipe was written against that older name, before the asset rename
# landed. Filtering "the newest release that ships $ASSET_NAME" against a
# name upstream stopped publishing meant every install silently settled on
# v0.7.0 while v0.8.0 and v0.9.0 sat right above it -- the fallback in this
# recipe existed for a tag published with no assets at all (v0.6.0), not for
# an asset that upstream deliberately renamed. Read the actual releases API
# before touching this again; do not assume the filename is stable.
#
# The extract-and-rewrite step below (Name=/Icon=/Exec=) is redundant now
# that upstream's own .desktop already says "Tatu" -- kept anyway, since it
# is harmless and self-heals if a future release ever regresses the
# branding, rather than something this recipe needs to keep working today.
#
# Release naming (lobinuxsoft/tatu releases):
#   - Tag pattern:  v<MAJOR>.<MINOR>.<PATCH>   (no `tatu-` prefix)
#   - Linux asset:  Tatu.AppImage   (frontend only; the Win32 cheats bridge
#                   ships as tatu-tracker-linux-amd64.tar.gz and is
#                   configured separately via Steam compat tool — out of
#                   scope for this recipe)
#   - Sidecar:      checksums-sha256.txt
#
# Override knobs:
#   YAGUARETE_APPS_DIR  where Tatu.AppImage lives (default ~/Applications)

install-tatu:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh

    yg_info "Tatu — Steam backlog tracker install"
    yg_check_internet
    yg_check_disk 200

    mkdir -p "$YG_APPS_DIR"
    TATU_BIN="$YG_APPS_DIR/Tatu.AppImage"
    ASSET_NAME="Tatu.AppImage"

    # Pick the newest release that actually ships the AppImage, not simply
    # the newest release. A tag published without assets — v0.6.0 went out
    # that way — otherwise dead-ends the install even though a perfectly
    # good build sits one release below.
    yg_info "Resolving latest Tatu release with $ASSET_NAME"
    releases=$(gh api repos/lobinuxsoft/tatu/releases 2>/dev/null \
        || curl -fsSL https://api.github.com/repos/lobinuxsoft/tatu/releases)
    release=$(echo "$releases" | jq -c --arg n "$ASSET_NAME" \
        'first(.[] | select(.prerelease == false) | select(.assets[]?.name == $n))')
    if [[ -z "$release" || "$release" == "null" ]]; then
        newest=$(echo "$releases" | jq -r 'first(.[] | select(.prerelease == false)) | .tag_name // "none"')
        yg_err "No published Tatu release contains $ASSET_NAME."
        yg_err "Newest release is $newest; its assets: $(echo "$releases" | jq -r 'first(.[] | select(.prerelease == false)) | (.assets // []) | map(.name) | join(", ") | if . == "" then "(none — published without binaries)" else . end')"
        exit 1
    fi
    tag=$(echo "$release" | jq -r '.tag_name')
    asset_url=$(echo "$release" | jq -r --arg n "$ASSET_NAME" '.assets[] | select(.name == $n) | .browser_download_url')
    checksums_url=$(echo "$release" | jq -r '.assets[] | select(.name == "checksums-sha256.txt") | .browser_download_url')
    newest_tag=$(echo "$releases" | jq -r 'first(.[] | select(.prerelease == false)) | .tag_name')
    if [[ "$tag" != "$newest_tag" ]]; then
        yg_warn "$newest_tag ships no $ASSET_NAME — falling back to $tag."
    fi

    tmp_bin="$(mktemp --tmpdir Tatu.XXXXXX.AppImage)"
    yg_download "$asset_url" "$tmp_bin"
    if [[ -n "$checksums_url" && "$checksums_url" != "null" ]]; then
        sums="$(mktemp)"
        yg_download "$checksums_url" "$sums"
        expected=$(awk -v n="$ASSET_NAME" '$2 == n || $2 == "*"n {print $1}' "$sums")
        if [[ -n "$expected" ]]; then
            actual=$(sha256sum "$tmp_bin" | awk '{print $1}')
            if [[ "$expected" != "$actual" ]]; then
                yg_err "SHA256 mismatch for $ASSET_NAME (expected $expected, got $actual)"
                rm -f "$tmp_bin" "$sums"
                exit 2
            fi
            yg_ok "SHA256 verified."
        else
            yg_warn "No entry for $ASSET_NAME in checksums-sha256.txt — skipping verify."
        fi
        rm -f "$sums"
    fi
    mv "$tmp_bin" "$TATU_BIN"
    chmod +x "$TATU_BIN"
    yg_ok "Tatu $tag installed at $TATU_BIN"

    # Extract .desktop + icon. Upstream's own entry already says "Tatu" as
    # of v0.8.0; rewritten anyway so Exec= points at our installed path
    # rather than the AppImage's self-reference, and so an older release
    # still installable by hand does not regress to the legacy branding.
    extract_dir=$(mktemp -d)
    pushd "$extract_dir" >/dev/null
    "$TATU_BIN" --appimage-extract >/dev/null 2>&1
    # find -print -quit avoids SIGPIPE under `set -o pipefail` — `find … | head -1`
    # aborts the recipe with exit 141 when find emits more matches than head reads.
    desktop_src=$(find squashfs-root -maxdepth 2 -name '*.desktop' -print -quit 2>/dev/null)
    if [[ -n "$desktop_src" ]]; then
        icon_name=$(grep -m1 '^Icon=' "$desktop_src" | sed 's/^Icon=//')
        icon_src=""
        if [[ -n "$icon_name" ]]; then
            icon_src=$(find squashfs-root \( -name "${icon_name}.svg" -o -name "${icon_name}.png" \) -print -quit 2>/dev/null)
        fi
        mkdir -p "$YG_DESKTOP_DIR" "$YG_ICON_DIR"
        sed "s|^Name=.*|Name=Tatu|; s|^Exec=.*|Exec=$TATU_BIN %f|; s|^Icon=.*|Icon=tatu|; s|^Comment=.*|Comment=Steam backlog tracker (Tatu)|" \
            "$desktop_src" > "$YG_DESKTOP_DIR/Tatu.desktop"
        if [[ -n "$icon_src" ]]; then
            cp "$icon_src" "$YG_ICON_DIR/tatu.${icon_src##*.}"
        else
            yg_warn "No icon matching Icon=$icon_name in the AppImage — Tatu will show a generic launcher icon."
        fi
        yg_refresh_desktop_db
        yg_ok "Desktop entry + icon installed (renamed Game Progress Tracker → Tatu)"
    else
        yg_warn "No .desktop file in the AppImage — Tatu will not appear in the KDE menu (run $TATU_BIN by hand)."
    fi
    popd >/dev/null
    rm -rf "$extract_dir"

    echo
    yg_ok "Tatu install complete."
    yg_info "Launch from the KDE menu or run: $TATU_BIN"
    yg_info "Win32 cheats bridge (Aurora-style) is a separate Steam compat tool — see lobinuxsoft/tatu README."
    yg_pause

update-tatu:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh
    yg_info "Refreshing Tatu (keeps user library and config)"
    yg_check_internet

    TATU_BIN="$YG_APPS_DIR/Tatu.AppImage"
    ASSET_NAME="Tatu.AppImage"
    release=$(gh api repos/lobinuxsoft/tatu/releases/latest 2>/dev/null \
        || curl -fsSL https://api.github.com/repos/lobinuxsoft/tatu/releases/latest)
    tag=$(echo "$release" | jq -r '.tag_name')
    asset_url=$(echo "$release" | jq -r --arg n "$ASSET_NAME" '.assets[] | select(.name == $n) | .browser_download_url')
    if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
        yg_err "Asset $ASSET_NAME not found in release $tag."
        exit 1
    fi
    tmp_bin="$(mktemp --tmpdir Tatu.XXXXXX.AppImage)"
    yg_download "$asset_url" "$tmp_bin"
    mv "$tmp_bin" "$TATU_BIN"
    chmod +x "$TATU_BIN"
    yg_ok "Tatu refreshed to $tag"
    yg_pause

remove-tatu:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh
    yg_warn "About to remove Tatu binary + .desktop + icon."
    yg_warn "Your library / config in $YG_CONFIG_DIR/tatu (or legacy $YG_CONFIG_DIR/game-progress-tracker) are preserved."
    yg_confirm "Continue?" || { yg_info "Aborted."; exit 0; }

    rm -f "$YG_APPS_DIR/Tatu.AppImage"
    rm -f "$YG_DESKTOP_DIR/Tatu.desktop"
    rm -f "$YG_ICON_DIR/tatu.svg" "$YG_ICON_DIR/tatu.png"
    yg_refresh_desktop_db
    yg_ok "Tatu uninstalled. User data preserved."
