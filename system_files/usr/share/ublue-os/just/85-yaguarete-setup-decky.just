# YaguareteOS — install Decky Loader with the checks the upstream
# installer skips.
#
# Why this wrapper exists (observed 2026-07-31 on a -nvidia-open box):
#
#   The upstream installer (decky-installer/install_release.sh, invoked by
#   Bazzite's `ujust setup-decky install`) does this, in this order:
#
#       rm -rf "${HOMEBREW_FOLDER}/services"          # destroy first
#       RELEASE=$(curl -s .../releases | jq ...)      # then go online
#       curl -L $DOWNLOADURL --output .../PluginLoader
#
#   When that API call comes back empty the URL is empty, curl writes
#   nothing, and the binary that was working five seconds ago is already
#   gone. It then installs the systemd unit, enables it, and exits 0.
#   Real output from that run:
#
#       Installing version ...
#       curl: (2) no URL specified
#       chmod: cannot access '.../PluginLoader': No such file or directory
#       chcon: cannot access '.../PluginLoader': No such file or directory
#       --- exit status: 0
#
#   The service then fails with 203/EXEC forever, Steam shows no Decky,
#   and every layer above — Bazzite, yafti, the Portal — reports success
#   because the installer said 0. A five-second network hiccup uninstalls
#   Decky and tells you it went fine.
#
# What this wrapper does:
#   1. Resolves version + download URL BEFORE anything is deleted, and
#      refuses to continue if either is empty or the asset does not
#      answer 200. Nothing is touched when the network is down.
#   2. Backs the current PluginLoader up, and puts it back if the install
#      leaves nothing behind — a failed run can no longer be destructive.
#   3. Verifies afterwards that the binary exists and is a plausible
#      size, that .loader.version is not empty, that the SELinux context
#      is bin_t (Decky cannot inject into Steam without it), and that the
#      service actually came up.
#   4. Exits non-zero when any of that fails, so the Portal stops calling
#      a broken install a success.
#
# Upstream is left alone: this calls `ujust setup-decky` and only adds
# the guard rails around it.

# Install Decky Loader with pre-flight and post-install verification. Options: status | install | install-prerelease | uninstall
[group("gaming")]
yaguarete-setup-decky ACTION="":
    #!/usr/bin/bash
    set -euo pipefail

    source /usr/libexec/yaguarete/emu-helpers.sh

    tag=yaguarete-setup-decky
    log() { logger -t "$tag" -- "$*" 2>/dev/null || true; }

    HOMEBREW_DIR="$HOME/homebrew"
    LOADER_BIN="$HOMEBREW_DIR/services/PluginLoader"
    VERSION_FILE="$HOMEBREW_DIR/services/.loader.version"
    BACKUP_DIR="$HOME/.cache/yaguarete/decky"
    # The real binary is ~26 MB; anything under this is an error page or
    # a truncated download wearing the right filename.
    MIN_BIN_BYTES=1000000
    API_RELEASES="https://api.github.com/repos/SteamDeckHomebrew/decky-loader/releases"

    # `sudo -A` needs an askpass, which exists under the Portal and the
    # desktop session but not over plain ssh. Fall back to a normal sudo
    # prompt there instead of failing with "no askpass program".
    yg_sudo() {
        if [[ -n "${SUDO_ASKPASS:-}" ]] && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
            sudo -A "$@"
        else
            sudo "$@"
        fi
    }

    # Resolve tag_name + PluginLoader asset URL for the newest release.
    # Prints "<version> <url>"; returns non-zero when anything is missing.
    resolve_release() {
        local include_prerelease="$1" releases filter version url
        releases=$(curl -fsSL --max-time 20 "$API_RELEASES") || return 1
        if [[ "$include_prerelease" == "true" ]]; then
            filter='first(.[])'
        else
            filter='first(.[] | select(.prerelease == false))'
        fi
        version=$(jq -r "${filter} | .tag_name // empty" <<< "$releases") || return 1
        url=$(jq -r "${filter} | .assets[]?.browser_download_url | select(endswith(\"PluginLoader\"))" <<< "$releases") || return 1
        [[ -n "$version" && "$version" != "null" ]] || return 1
        [[ -n "$url" && "$url" != "null" ]] || return 1
        printf '%s %s\n' "$version" "$url"
    }

    preflight() {
        local include_prerelease="$1" resolved version url code
        yg_info "Checking that Decky Loader can actually be downloaded..."
        if ! resolved=$(resolve_release "$include_prerelease"); then
            yg_err "Could not resolve the latest Decky Loader release."
            yg_err "GitHub's API did not return a usable version + PluginLoader asset."
            yg_err "This is the failure that silently uninstalls Decky. Nothing was touched."
            yg_err "Check your connection and try again in a minute."
            return 1
        fi
        version="${resolved%% *}"
        url="${resolved#* }"
        code=$(curl -fsSIL --max-time 20 -o /dev/null -w '%{http_code}' "$url" || echo "000")
        if [[ "$code" != "200" ]]; then
            yg_err "The asset for ${version} answered HTTP ${code}, not 200."
            yg_err "Refusing to run the installer — it deletes the working binary first."
            return 1
        fi
        yg_ok "Decky Loader ${version} is reachable."
        log "preflight ok version=$version"
    }

    backup_current() {
        if [[ -s "$LOADER_BIN" ]]; then
            mkdir -p "$BACKUP_DIR"
            yg_sudo cp -f "$LOADER_BIN" "$BACKUP_DIR/PluginLoader"
            [[ -f "$VERSION_FILE" ]] && yg_sudo cp -f "$VERSION_FILE" "$BACKUP_DIR/.loader.version" || true
            yg_info "Current install backed up to $BACKUP_DIR"
            return 0
        fi
        return 1
    }

    restore_backup() {
        [[ -s "$BACKUP_DIR/PluginLoader" ]] || return 1
        yg_warn "Restoring the previous Decky Loader..."
        yg_sudo mkdir -p "$HOMEBREW_DIR/services"
        yg_sudo cp -f "$BACKUP_DIR/PluginLoader" "$LOADER_BIN"
        [[ -f "$BACKUP_DIR/.loader.version" ]] && yg_sudo cp -f "$BACKUP_DIR/.loader.version" "$VERSION_FILE" || true
        yg_sudo chmod +x "$LOADER_BIN"
        fix_selinux
        yg_sudo systemctl restart plugin_loader 2>/dev/null || true
        yg_ok "Previous install restored."
    }

    # Decky cannot inject into Steam when the binary is not bin_t and
    # SELinux is enforcing. The upstream installer does this too, but
    # only when its own chcon step is reached.
    fix_selinux() {
        command -v getenforce >/dev/null 2>&1 || return 0
        [[ "$(getenforce)" == "Enforcing" ]] || return 0
        [[ -s "$LOADER_BIN" ]] || return 0
        if ! ls -Z "$LOADER_BIN" 2>/dev/null | grep -q ':bin_t:'; then
            yg_info "Fixing the SELinux context on PluginLoader..."
            yg_sudo chcon -R -t bin_t "$LOADER_BIN"
        fi
    }

    verify_install() {
        local size version
        if [[ ! -s "$LOADER_BIN" ]]; then
            yg_err "PluginLoader is missing after the install — the download failed."
            return 1
        fi
        size=$(stat -c %s "$LOADER_BIN")
        if (( size < MIN_BIN_BYTES )); then
            yg_err "PluginLoader is only ${size} bytes — that is not the real binary."
            return 1
        fi
        version=$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null || true)
        if [[ -z "$version" ]]; then
            yg_err "No version was recorded — the installer never learned what to fetch."
            return 1
        fi
        fix_selinux
        yg_ok "PluginLoader ${version} installed ($(numfmt --to=iec "$size"))."

        # The unit restarts on failure, so give it a moment to settle
        # rather than reading a state it is still climbing out of.
        sleep 3
        if ! systemctl is-active --quiet plugin_loader; then
            yg_err "plugin_loader.service did not come up:"
            systemctl status plugin_loader --no-pager 2>&1 | tail -5 || true
            return 1
        fi
        yg_ok "plugin_loader.service is running."
    }

    report_steam() {
        printf '\n'
        yg_info "Last step, and Decky will not appear without it:"
        printf '  Close Steam completely — including the system tray icon — and open it again.\n'
        printf '  Decky lives in the Quick Access menu (the ... button), not in the library.\n'
    }

    ACTION="{{ ACTION }}"
    case "$ACTION" in
        status)
            exec ujust setup-decky status
            ;;
        ""|install|install-prerelease)
            [[ -z "$ACTION" ]] && ACTION="install"
            prerelease=false
            [[ "$ACTION" == "install-prerelease" ]] && prerelease=true

            preflight "$prerelease" || exit 1

            had_backup=false
            backup_current && had_backup=true

            log "invoking upstream setup-decky $ACTION"
            # Upstream exits 0 even when it fails, so its status is
            # informational; verify_install is what decides.
            ujust setup-decky "$ACTION" || yg_warn "The upstream installer reported an error."

            if verify_install; then
                report_steam
                exit 0
            fi

            yg_err "The install did not complete correctly."
            if $had_backup; then
                restore_backup || yg_err "Could not restore the backup either."
            else
                yg_err "There was no previous install to fall back to."
            fi
            yg_err "Nothing was lost that was not already broken — try again in a minute."
            exit 1
            ;;
        uninstall)
            exec ujust setup-decky uninstall
            ;;
        *)
            yg_err "Unknown option: $ACTION"
            printf 'Usage: ujust yaguarete-setup-decky [status|install|install-prerelease|uninstall]\n'
            exit 2
            ;;
    esac
