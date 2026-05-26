# YaguareteOS — install / update / remove the Eden Switch emulator.
#
# Eden is a community fork of Yuzu / Sudachi maintained at
# eden-emu.dev. These recipes automate the full setup:
#
#   1. Eden AppImage from the official Gitea nightly release
#   2. Switch firmware from THZoria/NX_Firmware (latest = Eden-compat)
#   3. prod.keys from files.prodkeys.net (latest stable bundle)
#   4. .desktop entry + icon extracted from the AppImage
#   5. Steam ROM Manager parser injected if EmuDeck is present
#
# Override knobs (env vars, all optional):
#   YAGUARETE_APPS_DIR     where Eden.AppImage lives (default ~/Applications)
#   YAGUARETE_PROD_KEYS    path to a user-supplied prod.keys / .zip
#   YAGUARETE_EDEN_FW_VER  pin a specific THZoria release tag (default = latest)

install-eden:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh

    yg_info "Eden — Switch emulator install"
    yg_check_internet
    yg_check_disk 600

    arch=$(yg_arch)
    EDEN_DATA="$YG_DATA_DIR/eden"
    EDEN_BIN="$YG_APPS_DIR/Eden.AppImage"

    mkdir -p "$YG_APPS_DIR" "$EDEN_DATA"/{keys,load,nand/system/Contents/registered}

    # 1. Eden AppImage (latest nightly, amd64-clang-pgo for x86, aarch64-clang-pgo for arm)
    yg_info "Resolving latest Eden release"
    pattern="Linux.*${arch}-clang-pgo\\.AppImage\$"
    # jq's first() avoids the SIGPIPE that `jq … | head -1` triggers under
    # `set -o pipefail` when the stream emits more than one match. `// empty`
    # turns a no-match into "" instead of jq's literal "null" string.
    eden_url=$(curl -fsSL "https://git.eden-emu.dev/api/v1/repos/eden-ci/nightly/releases?limit=1" \
        | jq -r --arg pat "$pattern" 'first(.[0].assets[] | select(.name | test($pat)) | .browser_download_url) // empty')
    if [[ -z "$eden_url" ]]; then
        yg_err "No Eden AppImage matching $pattern in the latest release."
        exit 1
    fi
    yg_download "$eden_url" "$EDEN_BIN"
    chmod +x "$EDEN_BIN"
    yg_ok "Eden AppImage installed at $EDEN_BIN"

    # 2. Firmware (latest THZoria release)
    yg_info "Resolving Switch firmware"
    fw_tag="${YAGUARETE_EDEN_FW_VER:-$(gh api repos/THZoria/NX_Firmware/releases --jq '.[0].tag_name' 2>/dev/null \
        || curl -fsSL https://api.github.com/repos/THZoria/NX_Firmware/releases | jq -r '.[0].tag_name')}"
    fw_url="https://github.com/THZoria/NX_Firmware/releases/download/${fw_tag}/Firmware.${fw_tag}.zip"
    fw_zip="$(mktemp -d)/firmware.zip"
    yg_download "$fw_url" "$fw_zip"

    # Backup existing firmware (if any) then replace
    reg_dir="$EDEN_DATA/nand/system/Contents/registered"
    if [[ -d "$reg_dir" && -n "$(ls -A "$reg_dir" 2>/dev/null)" ]]; then
        bak="${reg_dir}.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$reg_dir" "$bak"
        yg_warn "Previous firmware moved to $bak"
        mkdir -p "$reg_dir"
    fi
    unzip -q -o "$fw_zip" -d "$reg_dir"
    rm -rf "$(dirname "$fw_zip")"
    yg_ok "Firmware $fw_tag installed ($(ls "$reg_dir" | wc -l) .nca files)"

    # 3. prod.keys + title.keys
    if [[ -n "${YAGUARETE_PROD_KEYS:-}" ]]; then
        if [[ "$YAGUARETE_PROD_KEYS" == *.zip ]]; then
            tmpk=$(mktemp -d)
            unzip -q -o "$YAGUARETE_PROD_KEYS" -d "$tmpk"
            find "$tmpk" -name 'prod.keys' -exec cp {} "$EDEN_DATA/keys/prod.keys" \;
            find "$tmpk" -name 'title.keys' -exec cp {} "$EDEN_DATA/keys/title.keys" \; 2>/dev/null || true
            rm -rf "$tmpk"
        else
            cp "$YAGUARETE_PROD_KEYS" "$EDEN_DATA/keys/prod.keys"
        fi
        yg_ok "prod.keys imported from \$YAGUARETE_PROD_KEYS"
    else
        keys_zip="$(mktemp -d)/prodkeys.zip"
        yg_download "https://files.prodkeys.net/ProdKeys.net-v20.3.0.zip" "$keys_zip"
        tmpk=$(mktemp -d)
        unzip -q -o "$keys_zip" -d "$tmpk"
        find "$tmpk" -name 'prod.keys' -exec cp {} "$EDEN_DATA/keys/prod.keys" \;
        find "$tmpk" -name 'title.keys' -exec cp {} "$EDEN_DATA/keys/title.keys" \; 2>/dev/null || true
        rm -rf "$(dirname "$keys_zip")" "$tmpk"
        yg_ok "prod.keys installed (v20.3.0 from files.prodkeys.net — forward-compatible with newer firmware)"
    fi

    # 4. .desktop entry + icon — derive both from the AppImage's manifest
    # rather than hard-coding `dev.eden_emu.eden.{desktop,svg}` (the app id
    # already changed once during the yuzu → sudachi → eden lineage and is
    # not part of any contract).
    extract_dir=$(mktemp -d)
    pushd "$extract_dir" >/dev/null
    "$EDEN_BIN" --appimage-extract >/dev/null 2>&1

    # find -print -quit avoids SIGPIPE under `set -o pipefail` — `find … | head -1`
    # aborts the recipe with exit 141 when find emits more matches than head reads.
    desktop_src=$(find squashfs-root -maxdepth 2 -name '*.desktop' -print -quit 2>/dev/null)
    if [[ -n "$desktop_src" ]]; then
        # The AppImage's Icon= line tells us the icon stem; locate the
        # matching file at any depth (typical paths: squashfs-root/<id>.svg
        # or squashfs-root/usr/share/icons/hicolor/<size>/apps/<id>.png).
        icon_name=$(grep -m1 '^Icon=' "$desktop_src" | sed 's/^Icon=//')
        icon_src=""
        if [[ -n "$icon_name" ]]; then
            icon_src=$(find squashfs-root \( -name "${icon_name}.svg" -o -name "${icon_name}.png" \) -print -quit 2>/dev/null)
        fi

        mkdir -p "$YG_DESKTOP_DIR" "$YG_ICON_DIR"
        # Rewrite Exec= to point at our AppImage; rename Icon= to a stable
        # `eden` slug so we install one canonical icon file.
        sed "s|^Exec=.*|Exec=$EDEN_BIN %f|; s|^Icon=.*|Icon=eden|" \
            "$desktop_src" > "$YG_DESKTOP_DIR/Eden.desktop"
        if [[ -n "$icon_src" ]]; then
            cp "$icon_src" "$YG_ICON_DIR/eden.${icon_src##*.}"
        else
            yg_warn "No icon matching Icon=$icon_name in the AppImage — Eden will show a generic launcher icon."
        fi
        yg_refresh_desktop_db
        yg_ok "Desktop entry + icon installed (id: ${icon_name:-unknown})"
    else
        yg_warn "No .desktop file in the AppImage — Eden will not appear in the KDE menu (run $EDEN_BIN by hand)."
    fi
    popd >/dev/null
    rm -rf "$extract_dir"

    # 5. Steam ROM Manager parser (only if EmuDeck is present)
    srm_cfg="$YG_CONFIG_DIR/steam-rom-manager/userData/userConfigurations.json"
    roms_dir=$(yg_emudeck_setting romsPath 2>/dev/null || echo "")
    roms_dir="${roms_dir:-$HOME/Emulation/roms}/switch"
    if [[ -f "$srm_cfg" ]]; then
        already=$(jq --arg exe "$EDEN_BIN" '[.[] | select(.executable.path == $exe)] | length' "$srm_cfg")
        if [[ "$already" == "0" ]]; then
            tmpcfg=$(mktemp)
            jq --arg title "Nintendo Switch (Eden)" \
               --arg roms "$roms_dir" \
               --arg exe "$EDEN_BIN" \
               '. + [{
                 parserType: "Glob",
                 configTitle: $title,
                 steamDirectory: "${steamdirglobal}",
                 romDirectory: $roms,
                 executableArgs: "-f -g \"${filePath}\"",
                 executable: { path: $exe, shortcutPassthrough: false, appendArgsToExecutable: true },
                 parserInputs: { glob: "${title}@(.kip|.KIP|.nca|.NCA|.nro|.NRO|.nso|.NSO|.nsp|.NSP|.xci|.XCI)" },
                 imageProviders: ["sgdb"],
                 fuzzyMatch: { replaceDiacritics: true, removeCharacters: true, removeBrackets: true },
                 steamCategories: [""],
                 steamInputEnabled: "1",
                 disabled: false,
                 version: 25
               }]' "$srm_cfg" > "$tmpcfg" && mv "$tmpcfg" "$srm_cfg"
            yg_ok "Steam ROM Manager parser added (Nintendo Switch → Eden, roms at $roms_dir)"
        else
            yg_warn "SRM parser already points to Eden — skipping injection."
        fi
    elif yg_has_emudeck; then
        yg_warn "EmuDeck found but SRM config missing. Run Steam ROM Manager once to initialise, then re-run install-eden."
    fi

    echo
    yg_ok "Eden install complete."
    yg_info "Next steps:"
    echo "    • Launch Eden from the KDE menu (or run $EDEN_BIN)."
    echo "    • Drop ROMs (.nsp/.xci) in $roms_dir."
    [[ -f "$srm_cfg" ]] && echo "    • Open Steam ROM Manager and click 'Add Games' to push them to Steam."
    yg_pause

update-eden:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh
    yg_info "Refreshing Eden + firmware (keeps user keys, saves and mods)"
    yg_check_internet

    arch=$(yg_arch)
    EDEN_BIN="$YG_APPS_DIR/Eden.AppImage"
    pattern="Linux.*${arch}-clang-pgo\\.AppImage\$"
    eden_url=$(curl -fsSL "https://git.eden-emu.dev/api/v1/repos/eden-ci/nightly/releases?limit=1" \
        | jq -r --arg pat "$pattern" 'first(.[0].assets[] | select(.name | test($pat)) | .browser_download_url) // empty')
    yg_download "$eden_url" "$EDEN_BIN"
    chmod +x "$EDEN_BIN"
    yg_ok "Eden AppImage refreshed"

    fw_tag=$(curl -fsSL https://api.github.com/repos/THZoria/NX_Firmware/releases | jq -r '.[0].tag_name')
    fw_url="https://github.com/THZoria/NX_Firmware/releases/download/${fw_tag}/Firmware.${fw_tag}.zip"
    fw_zip="$(mktemp -d)/firmware.zip"
    yg_download "$fw_url" "$fw_zip"
    reg_dir="$YG_DATA_DIR/eden/nand/system/Contents/registered"
    bak="${reg_dir}.bak-$(date +%Y%m%d-%H%M%S)"
    [[ -d "$reg_dir" && -n "$(ls -A "$reg_dir" 2>/dev/null)" ]] && mv "$reg_dir" "$bak" || true
    mkdir -p "$reg_dir"
    unzip -q -o "$fw_zip" -d "$reg_dir"
    rm -rf "$(dirname "$fw_zip")"
    yg_ok "Firmware updated to $fw_tag (previous backed up at ${bak})"
    yg_pause

remove-eden:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh
    yg_warn "About to remove Eden binary + .desktop + SRM parser."
    yg_warn "Your keys, saves and cheats in $YG_DATA_DIR/eden/{keys,load,nand/save} are preserved."
    yg_confirm "Continue?" || { yg_info "Aborted."; exit 0; }

    rm -f "$YG_APPS_DIR/Eden.AppImage"
    rm -f "$YG_DESKTOP_DIR/Eden.desktop"
    rm -f "$YG_ICON_DIR/eden.svg"
    yg_refresh_desktop_db

    srm_cfg="$YG_CONFIG_DIR/steam-rom-manager/userData/userConfigurations.json"
    if [[ -f "$srm_cfg" ]]; then
        tmpcfg=$(mktemp)
        jq --arg exe "$YG_APPS_DIR/Eden.AppImage" \
            'map(select(.executable.path != $exe))' "$srm_cfg" > "$tmpcfg" && mv "$tmpcfg" "$srm_cfg"
        yg_ok "SRM parser pointing to Eden removed"
    fi

    yg_ok "Eden uninstalled. User data preserved at $YG_DATA_DIR/eden/."
