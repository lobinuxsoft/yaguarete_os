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
    yg_info "Extracting package into $YG_OPT_DIR/antigravity"
    pushd "$deb_tmp" >/dev/null
    ar -x antigravity.deb

    # data.tar may be gz, xz or zstd; try in that order
    if   [[ -f data.tar.zst ]]; then data_tar="data.tar.zst"; tar_opts="--zstd"
    elif [[ -f data.tar.xz  ]]; then data_tar="data.tar.xz";  tar_opts="--xz"
    elif [[ -f data.tar.gz  ]]; then data_tar="data.tar.gz";  tar_opts="--gzip"
    else yg_err "Unknown data.tar.* in deb"; popd >/dev/null; exit 1
    fi
    popd >/dev/null

    # Backup existing install (rotate latest only) and replace
    if [[ -d "$YG_OPT_DIR/antigravity" ]]; then
        sudo mv "$YG_OPT_DIR/antigravity" "$YG_OPT_DIR/antigravity.bak-$(date +%Y%m%d-%H%M%S)"
    fi

    sudo mkdir -p "$YG_OPT_DIR/antigravity"
    # The deb lays out under /opt/antigravity by default in Google's package.
    # Extract to / so paths land where the package expects.
    sudo tar $tar_opts -xf "$deb_tmp/$data_tar" -C "$YG_OPT_DIR/.." \
        ./opt/antigravity 2>/dev/null || \
    sudo tar $tar_opts -xf "$deb_tmp/$data_tar" -C / ./opt/antigravity

    # Stamp version for idempotency on re-runs
    echo "$deb_version" | sudo tee "$YG_OPT_DIR/antigravity/VERSION" >/dev/null

    # Find the launcher binary (typical paths inside the deb)
    launcher=""
    for cand in "$YG_OPT_DIR/antigravity/antigravity" \
                "$YG_OPT_DIR/antigravity/bin/antigravity" \
                "$YG_OPT_DIR/antigravity/opt/Antigravity/antigravity"; do
        [[ -x "$cand" ]] && launcher="$cand" && break
    done
    if [[ -z "$launcher" ]]; then
        launcher=$(find "$YG_OPT_DIR/antigravity" -maxdepth 4 -type f -name 'antigravity' -executable 2>/dev/null | head -1)
    fi
    if [[ -n "$launcher" ]]; then
        sudo ln -sf "$launcher" /usr/local/bin/antigravity
        yg_ok "Symlinked /usr/local/bin/antigravity → $launcher"
    else
        yg_warn "Could not locate the antigravity binary inside the deb. Check $YG_OPT_DIR/antigravity manually."
    fi

    # Locate + install .desktop + icon
    desktop_src=$(find "$YG_OPT_DIR/antigravity" -maxdepth 6 -name '*antigravity*.desktop' 2>/dev/null | head -1)
    if [[ -n "$desktop_src" ]]; then
        mkdir -p "$YG_DESKTOP_DIR"
        sed "s|^Exec=.*|Exec=/usr/local/bin/antigravity %F|" "$desktop_src" > "$YG_DESKTOP_DIR/antigravity.desktop"
    fi
    icon_src=$(find "$YG_OPT_DIR/antigravity" -maxdepth 6 \( -name 'antigravity.png' -o -name 'antigravity.svg' \) 2>/dev/null | head -1)
    if [[ -n "$icon_src" ]]; then
        mkdir -p "$YG_ICON_DIR"
        cp "$icon_src" "$YG_ICON_DIR/antigravity.${icon_src##*.}"
    fi
    yg_refresh_desktop_db

    rm -rf "$deb_tmp"

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
