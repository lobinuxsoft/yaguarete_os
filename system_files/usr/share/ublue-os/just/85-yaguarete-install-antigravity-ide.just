# YaguareteOS — install / update / remove Google Antigravity IDE.
#
# Source of truth: Google's APT repo on Artifact Registry. The Packages
# index lists every .deb release; we parse the latest entry, verify
# SHA256, then extract it into /opt/antigravity (the symlink to
# /var/opt/antigravity that bootc gives us) without invoking dpkg —
# Fedora Atomic has no dpkg, and we don't need a real APT installation
# anyway, just the contents.
#
# Override knobs:
#   YAGUARETE_OPT_DIR  override /opt (default /opt, symlink to /var/opt on bootc)

_antigravity_apt_base := "https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev"

install-antigravity-ide:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh

    yg_info "Antigravity IDE — install"
    yg_check_internet
    yg_check_disk 800

    case "$(uname -m)" in
        x86_64)  apt_arch="amd64" ;;
        aarch64) apt_arch="arm64" ;;
        *) yg_err "Unsupported arch: $(uname -m)"; exit 1 ;;
    esac

    apt_base="{{_antigravity_apt_base}}"
    index_url="${apt_base}/dists/antigravity-debian/main/binary-${apt_arch}/Packages"

    yg_info "Fetching Google APT Packages index ($apt_arch)"
    packages=$(mktemp)
    curl -fsSL "$index_url" -o "$packages"

    read -r deb_version deb_filename deb_sha256 <<< "$(awk '
        BEGIN { pkg=""; ver=""; file=""; sha=""; lver=""; lfile=""; lsha=""; }
        /^Package: antigravity$/ { pkg="antigravity"; ver=""; file=""; sha=""; next; }
        pkg=="antigravity" && /^Version:/  { ver=$2  }
        pkg=="antigravity" && /^Filename:/ { file=$2 }
        pkg=="antigravity" && /^SHA256:/   { sha=$2  }
        NF==0 && pkg=="antigravity" && ver!="" && file!="" && sha!="" {
            lver=ver; lfile=file; lsha=sha; pkg="";
        }
        END {
            if (pkg=="antigravity" && ver!="" && file!="" && sha!="") {
                lver=ver; lfile=file; lsha=sha;
            }
            if (lver && lfile && lsha) print lver, lfile, lsha;
        }
    ' "$packages")"
    rm -f "$packages"

    if [[ -z "$deb_version" || -z "$deb_filename" || -z "$deb_sha256" ]]; then
        yg_err "Could not parse antigravity entry from APT index"
        exit 1
    fi
    yg_ok "Latest published version: $deb_version"

    # Idempotency: skip if already on latest
    if [[ -f "$YG_OPT_DIR/antigravity/VERSION" ]] && \
       [[ "$(cat "$YG_OPT_DIR/antigravity/VERSION")" == "$deb_version" ]]; then
        yg_ok "Antigravity IDE $deb_version already installed — nothing to do."
        exit 0
    fi

    deb_url="${apt_base}/${deb_filename}"
    deb_tmp=$(mktemp -d)
    deb_path="$deb_tmp/antigravity.deb"
    yg_download "$deb_url" "$deb_path"

    yg_info "Verifying SHA256"
    echo "${deb_sha256}  ${deb_path}" | sha256sum -c -
    yg_ok "Checksum verified"

    # Extract .deb (ar archive) without dpkg
    pushd "$deb_tmp" >/dev/null
    ar -x antigravity.deb

    # data.tar may be gz, xz or zstd; try in that order
    if   [[ -f data.tar.zst ]]; then data_tar="data.tar.zst"; tar_opts="--zstd"
    elif [[ -f data.tar.xz  ]]; then data_tar="data.tar.xz";  tar_opts="--xz"
    elif [[ -f data.tar.gz  ]]; then data_tar="data.tar.gz";  tar_opts="--gzip"
    else yg_err "Unknown data.tar.* in deb"; popd >/dev/null; exit 1
    fi
    popd >/dev/null

    # Extract the full payload into a staging tree, then DERIVE the layout
    # by reading the .desktop's Exec= line (the package's own manifest)
    # instead of hard-coding /opt/antigravity vs /usr/share/antigravity.
    # Google has shipped both layouts across releases and may shift again.
    yg_info "Extracting package into staging area"
    stage="$(sudo mktemp -d)"
    sudo tar $tar_opts -xf "$deb_tmp/$data_tar" -C "$stage"

    desktop_src=$(sudo find "$stage" -path '*/applications/antigravity.desktop' 2>/dev/null | head -1)
    if [[ -z "$desktop_src" ]]; then
        yg_err "Could not locate antigravity.desktop in the package — layout unrecognised"
        sudo rm -rf "$stage"; exit 1
    fi

    exec_target=$(grep -m1 '^Exec=' "$desktop_src" | sed 's/^Exec=//' | awk '{print $1}')
    launcher_staged="${stage}${exec_target}"
    if [[ ! -x "$launcher_staged" ]]; then
        launcher_staged=$(sudo find "$stage" -type f -name "$(basename "$exec_target")" -executable 2>/dev/null | head -1)
    fi
    if [[ -z "$launcher_staged" || ! -x "$launcher_staged" ]]; then
        yg_err "Could not locate the antigravity launcher (Exec=$exec_target)"
        sudo rm -rf "$stage"; exit 1
    fi

    # The app payload = directory containing the launcher. If the launcher
    # is inside a bin/ subdir, walk one level up to capture the full tree
    # (Electron shared libs, locales, resources/).
    payload_dir="$(dirname "$launcher_staged")"
    [[ "$(basename "$payload_dir")" == "bin" ]] && payload_dir="$(dirname "$payload_dir")"

    # Backup previous install + move new payload into place. /opt is a
    # symlink to /var/opt on bootc systems, so we operate on $YG_OPT_DIR.
    if [[ -d "$YG_OPT_DIR/antigravity" ]]; then
        sudo mv "$YG_OPT_DIR/antigravity" "$YG_OPT_DIR/antigravity.bak-$(date +%Y%m%d-%H%M%S)"
    fi
    sudo mkdir -p "$YG_OPT_DIR"
    sudo mv "$payload_dir" "$YG_OPT_DIR/antigravity"

    # Stamp version for idempotency on re-runs
    echo "$deb_version" | sudo tee "$YG_OPT_DIR/antigravity/VERSION" >/dev/null

    # Re-derive the launcher's path inside its new home
    launcher_rel="${launcher_staged#${payload_dir}/}"
    launcher_final="$YG_OPT_DIR/antigravity/$launcher_rel"
    if [[ ! -x "$launcher_final" ]]; then
        launcher_final=$(sudo find "$YG_OPT_DIR/antigravity" -type f -name "$(basename "$exec_target")" -executable 2>/dev/null | head -1)
    fi
    sudo ln -sf "$launcher_final" /usr/local/bin/antigravity
    yg_ok "Symlinked /usr/local/bin/antigravity → $launcher_final"

    # Patch + install the .desktop (Exec= now points to /usr/local/bin/antigravity
    # so it survives future layout shuffles inside /opt/antigravity).
    mkdir -p "$YG_DESKTOP_DIR"
    sed "s|^Exec=.*|Exec=/usr/local/bin/antigravity %F|" "$desktop_src" > "$YG_DESKTOP_DIR/antigravity.desktop"

    # Icon: prefer /pixmaps/, fall back to hicolor, fall back to any
    # antigravity.{png,svg} outside the app's internal resources/ (which
    # holds UI assets, not launcher icons).
    icon_src=$(sudo find "$stage" -path '*/pixmaps/antigravity.*' 2>/dev/null | head -1)
    [[ -z "$icon_src" ]] && icon_src=$(sudo find "$stage" -path '*/icons/hicolor/*/apps/antigravity.*' 2>/dev/null | head -1)
    [[ -z "$icon_src" ]] && icon_src=$(sudo find "$stage" \( -name 'antigravity.png' -o -name 'antigravity.svg' \) -not -path '*/resources/*' 2>/dev/null | head -1)
    if [[ -n "$icon_src" ]]; then
        mkdir -p "$YG_ICON_DIR"
        cp "$icon_src" "$YG_ICON_DIR/antigravity.${icon_src##*.}"
    fi
    yg_refresh_desktop_db

    sudo rm -rf "$stage" "$deb_tmp"

    echo
    yg_ok "Antigravity IDE $deb_version installed."
    yg_info "Launch it from the KDE menu or by running: antigravity"
    yg_info "First launch will prompt Google OAuth in your browser."

update-antigravity-ide:
    @just install-antigravity-ide

remove-antigravity-ide:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh
    yg_warn "About to remove the Antigravity IDE binary, launcher and icon."
    yg_warn "Your config and auth at $YG_CONFIG_DIR/antigravity is preserved."
    yg_confirm "Continue?" || { yg_info "Aborted."; exit 0; }

    sudo rm -rf "$YG_OPT_DIR/antigravity"
    sudo rm -f /usr/local/bin/antigravity
    rm -f "$YG_DESKTOP_DIR/antigravity.desktop"
    rm -f "$YG_ICON_DIR"/antigravity.{png,svg}
    yg_refresh_desktop_db
    yg_ok "Antigravity IDE removed. Config preserved at $YG_CONFIG_DIR/antigravity."
