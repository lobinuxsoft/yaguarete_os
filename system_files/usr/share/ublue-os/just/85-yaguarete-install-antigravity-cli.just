# YaguareteOS — install / update / remove Google Antigravity CLI (agy).
#
# Source: official bootstrap at https://antigravity.google/cli/install.sh
# The recipe downloads the script, prints its head for visual inspection,
# asks for confirmation, and only then runs it. This is the safer
# alternative to a blind `curl … | bash` pipeline — important post the
# 2026 GitHub / npm / PyPI supply-chain incidents we want to harden
# against across this repo.

_antigravity_cli_install_url := "https://antigravity.google/cli/install.sh"

install-antigravity-cli:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh

    yg_info "Antigravity CLI (agy) — install"
    yg_check_internet

    script=$(mktemp --suffix=.sh)
    yg_download "{{_antigravity_cli_install_url}}" "$script"

    echo
    yg_info "First lines of the bootstrap script (review before executing):"
    echo "──────────────────────────────────────────────────────────────"
    head -40 "$script"
    echo "──────────────────────────────────────────────────────────────"
    yg_info "Full script saved at $script ($(wc -l < "$script") lines, $(wc -c < "$script") bytes)."
    echo

    yg_confirm "Run the bootstrap?" || {
        yg_warn "Aborted. The script stays at $script — inspect and run manually if you want."
        exit 0
    }

    bash "$script"
    rm -f "$script"

    # Make sure ~/.local/bin is on PATH for the current shell — most
    # distros already export it from .bash_profile, just nudge if not.
    case ":$PATH:" in
        *":$YG_BIN_DIR:"*) ;;
        *) yg_warn "$YG_BIN_DIR is not in your \$PATH. Add this to your shell rc:" ;
           echo "    export PATH=\"$YG_BIN_DIR:\$PATH\"" ;;
    esac

    # Shell completions if agy supports them and the shell is present
    if command -v agy >/dev/null 2>&1; then
        if command -v bash >/dev/null 2>&1; then
            mkdir -p "$YG_DATA_DIR/bash-completion/completions"
            agy completion bash 2>/dev/null > "$YG_DATA_DIR/bash-completion/completions/agy" || true
        fi
        if command -v fish >/dev/null 2>&1; then
            mkdir -p "$YG_DATA_DIR/fish/vendor_completions.d"
            agy completion fish 2>/dev/null > "$YG_DATA_DIR/fish/vendor_completions.d/agy.fish" || true
        fi
        if command -v zsh >/dev/null 2>&1; then
            mkdir -p "$YG_DATA_DIR/zsh/site-functions"
            agy completion zsh 2>/dev/null > "$YG_DATA_DIR/zsh/site-functions/_agy" || true
        fi
        yg_ok "Shell completions installed (bash / fish / zsh as available)"
    fi

    echo
    yg_ok "Antigravity CLI installed."
    yg_info "Authenticate with: agy login (opens a browser, or prints a URL on SSH)."
    yg_pause

update-antigravity-cli:
    @just install-antigravity-cli

remove-antigravity-cli:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh
    yg_warn "About to remove the agy binary and its shell completions."
    yg_warn "Your auth and config at $YG_CONFIG_DIR/antigravity is preserved"
    yg_warn "(shared with the IDE — remove-antigravity-ide does not touch it either)."
    yg_confirm "Continue?" || { yg_info "Aborted."; exit 0; }

    # Locate the binary via PATH instead of assuming $YG_BIN_DIR/agy — the
    # upstream installer is free to land it anywhere (default ~/.local/bin
    # but configurable). Resolve symlinks too, in case install.sh stashes
    # the real binary under ~/.local/share/agy/ and symlinks into bin/.
    agy_bin=$(command -v agy 2>/dev/null || true)
    if [[ -n "$agy_bin" ]]; then
        agy_real=$(readlink -f "$agy_bin")
        rm -f "$agy_bin"
        [[ "$agy_real" != "$agy_bin" && -f "$agy_real" ]] && rm -f "$agy_real"
        yg_ok "Removed $agy_bin${agy_real:+ (real: $agy_real)}"
    else
        yg_warn "agy not found in \$PATH — nothing to remove (was it installed by this recipe?)."
    fi

    rm -f "$YG_DATA_DIR/bash-completion/completions/agy"
    rm -f "$YG_DATA_DIR/fish/vendor_completions.d/agy.fish"
    rm -f "$YG_DATA_DIR/zsh/site-functions/_agy"
    yg_ok "Antigravity CLI removed. Config preserved at $YG_CONFIG_DIR/antigravity."
