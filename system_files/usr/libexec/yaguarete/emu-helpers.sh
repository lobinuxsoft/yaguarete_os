#!/usr/bin/bash
# YaguareteOS — shared helper library for `ujust install-*` recipes.
#
# Source this file from a recipe:
#     source /usr/libexec/yaguarete/emu-helpers.sh
#
# Then call `yg_*` helpers below. Variables are exported so the recipe
# body can also reference them as ${YG_APPS_DIR}, etc.

set -euo pipefail

# ---------------------------------------------------------------------
# XDG-aware paths + env-var overrides
# ---------------------------------------------------------------------

export YG_APPS_DIR="${YAGUARETE_APPS_DIR:-$HOME/Applications}"
export YG_BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
export YG_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
export YG_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
export YG_DESKTOP_DIR="$YG_DATA_DIR/applications"
export YG_ICON_DIR="$YG_DATA_DIR/icons/hicolor/scalable/apps"
# /opt is a symlink to /var/opt on bootc — writable + persistent.
export YG_OPT_DIR="${YAGUARETE_OPT_DIR:-/opt}"

# ---------------------------------------------------------------------
# Output helpers (ANSI-coloured, no-op if NO_COLOR is set)
# ---------------------------------------------------------------------

yg_info()   { printf "${NO_COLOR:+}\033[1;36m▸\033[0m %s\n" "$*"; }
yg_ok()     { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
yg_warn()   { printf "\033[1;33m!\033[0m %s\n" "$*" >&2; }
yg_err()    { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; }

# ---------------------------------------------------------------------
# System detection
# ---------------------------------------------------------------------

# Returns "amd64" or "aarch64". Exits non-zero on unsupported arch.
yg_arch() {
    case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "aarch64" ;;
        *)
            yg_err "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
}

# True if the CPU supports the x86-64-v3 microarchitecture
# (AVX2 + SSE4.2). Lets recipes pick PGO variants when available.
yg_supports_v3() {
    [[ "$(uname -m)" == "x86_64" ]] || return 1
    grep -qE "^flags.*\bavx2\b" /proc/cpuinfo && \
    grep -qE "^flags.*\bsse4_2\b" /proc/cpuinfo
}

# True if running on a handheld device (Steam Deck / OneXFly / Ally /
# Legion Go / GPD Win / Aya Neo / Claw / ROG Ally).
yg_is_handheld() {
    local product
    product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
    echo "$product" | grep -qiE "jupiter|galileo|onex(fly|player)|ally|legion.go|claw|gpd.*win|aok.*zoe|aya.*neo|rog.*ally"
}

# ---------------------------------------------------------------------
# Connectivity + disk
# ---------------------------------------------------------------------

# Quick GitHub reachability check (5s timeout). Most recipes hit GitHub
# releases or raw.githubusercontent, so this is a representative probe.
yg_check_internet() {
    if ! curl -sf --max-time 5 https://api.github.com -o /dev/null; then
        yg_err "No internet access. Check connectivity and retry."
        return 1
    fi
}

# Ensure $HOME has at least N MB free (default 500 MB).
yg_check_disk() {
    local need_mb="${1:-500}"
    local have_mb
    have_mb=$(df -m "$HOME" | awk 'NR==2 {print $4}')
    if [[ "${have_mb:-0}" -lt "$need_mb" ]]; then
        yg_err "Need at least ${need_mb} MB free in \$HOME, have ${have_mb:-?} MB."
        return 1
    fi
}

# ---------------------------------------------------------------------
# User interaction
# ---------------------------------------------------------------------

# Prompt y/N (default N). Returns 0 on yes.
yg_confirm() {
    local msg="$1"
    local yn
    read -rp "$msg [y/N] " yn
    case "$yn" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Pause until any key is pressed, but only if stdin is a TTY. yafti spawns
# recipes via `xdg-terminal-exec ... bash -lc <script>` and konsole closes
# immediately on script exit, hiding the final summary. SSH/non-interactive
# invocations skip the pause and return without blocking.
yg_pause() {
    [[ -t 0 ]] || return 0
    local msg="${1:-Press any key to close this window...}"
    read -n 1 -s -r -p "$msg"
    echo
}

# ---------------------------------------------------------------------
# Fonts
# ---------------------------------------------------------------------

# True when fontconfig resolves this exact family, rather than quietly
# substituting something else for it.
#
# Testing resolution instead of mere presence is deliberate: the bug this
# guards against (#254) was three configs naming JetBrainsMono Nerd Font on
# an image that never had it, with fontconfig handing back another mono and
# nobody noticing for months. fc-match always answers — a fallback chain
# has no concept of failure — so the only honest question is whether the
# answer is what we asked for.
#
# The obvious one-liner is a trap:
#
#     fc-list : family | grep -qF "$family"      # DO NOT
#
# grep -q closes the pipe on its first match, fc-list dies of SIGPIPE, and
# under `set -o pipefail` the pipeline reports 141. Measured: it calls every
# font missing, 10 runs out of 10. No pipe here, so no race.
#
# This is a RUNTIME instrument. Do not reuse it inside a container build:
# fc-match answers from fontconfig's cache and configuration, and in the
# build the cache lives on an ephemeral mount, so the same inputs give
# different answers per variant. build_files/install-fonts.sh uses fc-scan
# instead, which reads the font files directly.
yg_has_font() {
    local family="$1" matched
    matched=$(fc-match -f '%{family}' "$family" 2>/dev/null) || return 1
    # %{family} can answer with a comma-separated alias list.
    [[ ",${matched}," == *",${family},"* ]]
}

# ---------------------------------------------------------------------
# Privilege escalation
# ---------------------------------------------------------------------

# sudo that works both under the Portal and over plain ssh.
#
# Every upstream Bazzite recipe calls `sudo -A`, which needs SUDO_ASKPASS
# and a graphical session to pop the dialog. portal-run restores that
# variable, but over ssh there is no askpass at all and `sudo -A` dies with
# "no askpass program specified". Fall back to an ordinary sudo prompt
# there, where a TTY exists to type into.
yg_sudo() {
    if [[ -n "${SUDO_ASKPASS:-}" ]] && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
        sudo -A "$@"
    else
        sudo "$@"
    fi
}

# ---------------------------------------------------------------------
# Download + desktop integration
# ---------------------------------------------------------------------

# curl wrapper with retries + progress bar.
yg_download() {
    local url="$1" dest="$2"
    yg_info "Downloading $(basename "$dest") ← $url"
    curl -fL --retry 3 --retry-delay 2 --progress-bar "$url" -o "$dest"
}

# Refresh the desktop entry / icon caches after dropping files into
# ~/.local/share/applications + ~/.local/share/icons.
yg_refresh_desktop_db() {
    command -v update-desktop-database >/dev/null 2>&1 && \
        update-desktop-database "$YG_DESKTOP_DIR" 2>/dev/null || true
    command -v gtk-update-icon-cache >/dev/null 2>&1 && \
        gtk-update-icon-cache -f "$YG_DATA_DIR/icons/hicolor" 2>/dev/null || true
}

# ---------------------------------------------------------------------
# EmuDeck integration (optional — recipes degrade gracefully)
# ---------------------------------------------------------------------

# True if EmuDeck is installed (settings.sh present).
yg_has_emudeck() {
    [[ -f "$YG_CONFIG_DIR/EmuDeck/settings.sh" ]]
}

# Read a single setting from EmuDeck's settings.sh (e.g. yg_emudeck_setting
# romsPath). Empty stdout if EmuDeck is absent or the key is undefined.
yg_emudeck_setting() {
    local key="$1"
    yg_has_emudeck || return 0
    bash -c "source '$YG_CONFIG_DIR/EmuDeck/settings.sh' && printf '%s' \"\$$key\"" 2>/dev/null
}

# ---------------------------------------------------------------------
# Direct-execution guard
# ---------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0:-}" ]]; then
    cat <<USAGE
yaguarete emu-helpers.sh — sourceable helper library

Use from a ujust recipe:
    source /usr/libexec/yaguarete/emu-helpers.sh

Exports: YG_APPS_DIR YG_BIN_DIR YG_DATA_DIR YG_CONFIG_DIR
         YG_DESKTOP_DIR YG_ICON_DIR YG_OPT_DIR
Provides: yg_info yg_ok yg_warn yg_err
          yg_arch yg_supports_v3 yg_is_handheld
          yg_check_internet yg_check_disk
          yg_confirm yg_pause yg_sudo yg_has_font
          yg_download yg_refresh_desktop_db
          yg_has_emudeck yg_emudeck_setting
USAGE
fi
