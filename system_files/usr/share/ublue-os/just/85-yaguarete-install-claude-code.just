# YaguareteOS — install / update / remove Anthropic's Claude Code CLI (#255).
#
# Source: the official installer at https://claude.ai/install.sh, run with
# the inspect-then-run pattern (download, show the head, confirm, execute)
# rather than a blind `curl | bash`.
#
# What that installer actually does, from reading it rather than assuming:
#
#   - Everything lands under $HOME: the launcher at ~/.local/bin/claude,
#     builds under ~/.local/share/claude/versions/, downloads cached in
#     ~/.claude/downloads. No root, no image layer, no reboot.
#   - It refuses to run under sudo, with an explicit check, because $HOME
#     would resolve to root's. Every other recipe in this repo reaches for
#     `sudo -A`; this one must not, and does not.
#   - It takes an optional target argument validated against
#     `stable | latest | <x.y.z>`. We pass `stable`, which keeps us on the
#     current stable release without a version number to bump here — the
#     pin is the word, not a digit.
#   - It finishes by running `claude install`, which wires up shell
#     integration by appending to the shell rc files.
#
# That last point is why the shell templates in /usr/share/yaguarete/shell
# are never written over an existing ~/.zshrc in place: this installer's
# PATH line lives at the end of that file, and so does the Antigravity
# CLI's. See 85-yaguarete-setup-shell.just.
#
# Updates do NOT re-run the installer — the CLI updates itself with
# `claude update`.

_claude_code_install_url := "https://claude.ai/install.sh"
# stable | latest | an explicit x.y.z
_claude_code_target := "stable"

# Install Anthropic's Claude Code CLI (per-user, requires an Anthropic account)
[group("yaguarete")]
install-claude-code:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh

    yg_info "Claude Code — install (target: {{ _claude_code_target }})"
    yg_check_internet
    yg_check_disk 500

    if [[ "$(id -u)" -eq 0 ]]; then
        yg_err "Do not run this as root. Claude Code installs into your own \$HOME,"
        yg_err "and the upstream installer refuses to run under sudo for that reason."
        exit 1
    fi

    script=$(mktemp --suffix=.sh)
    yg_download "{{ _claude_code_install_url }}" "$script"

    echo
    yg_info "First lines of the installer (review before executing):"
    echo "──────────────────────────────────────────────────────────────"
    head -40 "$script"
    echo "──────────────────────────────────────────────────────────────"
    yg_info "Full script saved at $script ($(wc -l < "$script") lines, $(wc -c < "$script") bytes)."
    echo

    yg_confirm "Run the installer?" || {
        yg_warn "Aborted. The script stays at $script — inspect and run it manually if you want."
        exit 0
    }

    bash "$script" "{{ _claude_code_target }}"
    rm -f "$script"

    # The installer edits shell rc files, so `claude` is on PATH in the
    # next shell but not necessarily this one. Look it up directly before
    # declaring success.
    claude_bin="$YG_BIN_DIR/claude"
    if [[ ! -x "$claude_bin" ]]; then
        claude_bin=$(command -v claude 2>/dev/null || true)
    fi
    if [[ -z "$claude_bin" ]]; then
        yg_err "The installer finished but no claude binary turned up."
        yg_err "Expected $YG_BIN_DIR/claude."
        exit 1
    fi

    version=$("$claude_bin" --version 2>/dev/null || true)
    if [[ -z "$version" ]]; then
        yg_err "$claude_bin exists but will not report a version."
        yg_err "On the handheld variant this is usually a glibc mismatch — run"
        yg_err "'$claude_bin --version' by hand to see the linker error."
        exit 1
    fi
    yg_ok "Installed: $version"

    case ":$PATH:" in
        *":$YG_BIN_DIR:"*) ;;
        *) yg_warn "$YG_BIN_DIR is not in your \$PATH for this shell. Open a new one," ;
           yg_warn "or add: export PATH=\"$YG_BIN_DIR:\$PATH\"" ;;
    esac

    echo
    yg_warn "Claude Code needs an Anthropic account to do anything at all."
    printf '  A Claude subscription, or an API key from console.anthropic.com.\n'
    printf '  Sign in with:  claude auth login\n'
    printf '  Long-lived token for scripts:  claude setup-token\n'
    printf '  Then check the install with:   claude doctor\n'
    yg_pause

# Update Claude Code to the latest release
[group("yaguarete")]
update-claude-code:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh

    if ! command -v claude >/dev/null 2>&1; then
        yg_err "Claude Code is not installed. Run: ujust install-claude-code"
        exit 1
    fi

    yg_info "Claude Code — update"
    yg_check_internet
    # The CLI self-updates; re-running the installer would work but would
    # also redo the shell-integration step and append to the rc files a
    # second time.
    claude update
    yg_ok "Now at: $(claude --version 2>/dev/null || echo unknown)"
    yg_pause

# Remove Claude Code (settings and history are preserved)
[group("yaguarete")]
remove-claude-code:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh

    yg_warn "About to remove the claude binary, its installed versions and its"
    yg_warn "download cache."
    yg_warn "Your settings, auth and history in $HOME/.claude are preserved —"
    yg_warn "delete that directory yourself if you want a clean slate."
    yg_confirm "Continue?" || { yg_info "Aborted."; exit 0; }

    # Resolve through PATH instead of assuming ~/.local/bin: the launcher
    # is a symlink into ~/.local/share/claude/versions/, and the installer
    # is free to move either end.
    claude_bin=$(command -v claude 2>/dev/null || true)
    if [[ -n "$claude_bin" ]]; then
        rm -f "$claude_bin"
        yg_ok "Removed $claude_bin"
    else
        yg_warn "claude not found in \$PATH — nothing to unlink."
    fi

    rm -rf "$YG_DATA_DIR/claude"
    rm -rf "$HOME/.claude/downloads"
    yg_ok "Claude Code removed. Settings kept at $HOME/.claude."
