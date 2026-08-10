# YaguareteOS — set up the zsh + Powerlevel10k + kitty shell environment
# for the current user (#254).
#
# Split of responsibilities:
#
#   image   — kitty, zsh and FiraCode Nerd Font are RPMs and a pinned font
#             archive. They cannot be installed at runtime on an atomic
#             system without `rpm-ostree install` and a reboot, so they are
#             baked in by build.sh / install-fonts.sh.
#   here    — everything that lives in $HOME: oh-my-zsh, the Powerlevel10k
#             theme, the two zsh plugins, and the three config files.
#
# On the plugins: zsh-autosuggestions and zsh-syntax-highlighting DO exist
# as Fedora RPMs, and they are deliberately not used. oh-my-zsh resolves
# `plugins=(...)` against $ZSH/plugins and $ZSH_CUSTOM/plugins only, never
# /usr/share, which is where those RPMs land. Cloning into $ZSH_CUSTOM is
# what both projects document.
#
# On overwriting: a user's ~/.zshrc is their work, and third-party
# installers (Claude Code, the Antigravity CLI, homebrew) append PATH lines
# to it. Nothing here overwrites a file without first copying it aside, and
# a file that already matches what we would write is left untouched so a
# second run does not litter $HOME with identical backups.

_yg_shell_templates := "/usr/share/yaguarete/shell"
_yg_omz_install_url := "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# Set up zsh + Powerlevel10k + kitty for the current user. Options: install | status | remove
[group("yaguarete")]
yaguarete-setup-shell ACTION="":
    #!/usr/bin/bash
    set -euo pipefail

    source /usr/libexec/yaguarete/emu-helpers.sh

    tag=yaguarete-setup-shell
    log() { logger -t "$tag" -- "$*" 2>/dev/null || true; }

    TEMPLATES="{{ _yg_shell_templates }}"
    OMZ_DIR="$HOME/.oh-my-zsh"
    OMZ_CUSTOM="$OMZ_DIR/custom"
    ZSH_BIN="/usr/bin/zsh"

    # theme/plugin name -> upstream repository
    declare -A THEMES=(
        [powerlevel10k]="https://github.com/romkatv/powerlevel10k.git"
    )
    declare -A PLUGINS=(
        [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions.git"
        [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    )

    # -----------------------------------------------------------------
    # Config files: write only when the content actually differs, and
    # always keep the previous version.
    # -----------------------------------------------------------------
    install_config() {
        local src="$1" dest="$2" stamp backup
        if [[ ! -r "$src" ]]; then
            yg_err "Missing template: $src"
            yg_err "The image is incomplete — this is a packaging bug, not your setup."
            return 1
        fi
        if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
            yg_info "$(basename "$dest") is already up to date."
            return 0
        fi
        mkdir -p "$(dirname "$dest")"
        if [[ -e "$dest" ]]; then
            stamp=$(date +%Y%m%d-%H%M%S)
            backup="${dest}.bak.${stamp}"
            cp -a "$dest" "$backup"
            yg_warn "Existing $(basename "$dest") saved as $(basename "$backup")"
        fi
        install -Dm0644 "$src" "$dest"
        yg_ok "Wrote $dest"
    }

    # -----------------------------------------------------------------
    # git checkouts: clone once, fast-forward afterwards. Shallow, since
    # nobody needs the history of a prompt theme.
    # -----------------------------------------------------------------
    sync_repo() {
        local url="$1" dest="$2" name
        name=$(basename "$dest")
        if [[ -d "$dest/.git" ]]; then
            yg_info "Updating $name..."
            git -C "$dest" pull --ff-only --quiet || \
                yg_warn "Could not fast-forward $name — leaving the existing checkout alone."
        elif [[ -e "$dest" ]]; then
            yg_warn "$dest exists but is not a git checkout — leaving it alone."
        else
            yg_info "Cloning $name..."
            git clone --depth=1 --quiet "$url" "$dest"
        fi
    }

    install_omz() {
        if [[ -d "$OMZ_DIR" ]]; then
            yg_info "oh-my-zsh is already installed at $OMZ_DIR."
            return 0
        fi

        # Inspect-then-run rather than `curl | sh`, the same pattern as
        # install-antigravity-cli. --unattended sets CHSH=no and RUNZSH=no
        # (we own the login shell decision, and this recipe must not be
        # replaced mid-run by an interactive zsh); --keep-zshrc stops the
        # installer writing its own template over the one we ship.
        local script
        script=$(mktemp --suffix=.sh)
        yg_download "{{ _yg_omz_install_url }}" "$script"

        echo
        yg_info "First lines of the oh-my-zsh installer (review before executing):"
        echo "──────────────────────────────────────────────────────────────"
        head -40 "$script"
        echo "──────────────────────────────────────────────────────────────"
        yg_info "Full script at $script ($(wc -l < "$script") lines, $(wc -c < "$script") bytes)."
        echo

        if ! yg_confirm "Run the oh-my-zsh installer?"; then
            yg_warn "Aborted. The script stays at $script if you want to read it."
            return 1
        fi

        sh "$script" --unattended --keep-zshrc
        rm -f "$script"
        [[ -d "$OMZ_DIR" ]] || { yg_err "oh-my-zsh did not install."; return 1; }
        yg_ok "oh-my-zsh installed."
    }

    set_login_shell() {
        local current
        current=$(getent passwd "$USER" | cut -d: -f7)

        if [[ "$current" == "$ZSH_BIN" ]]; then
            yg_info "Login shell is already $ZSH_BIN."
            return 0
        fi

        # Guards, in order of how badly each one breaks a login:
        #   - the binary has to exist, or the account cannot start a shell
        #   - /etc/shells has to list it, or chsh refuses anyway
        #   - ~/.zshrc has to be there, or the first login is a bare prompt
        if [[ ! -x "$ZSH_BIN" ]]; then
            yg_err "$ZSH_BIN is missing. Not touching your login shell."
            return 1
        fi
        if ! grep -qxF "$ZSH_BIN" /etc/shells; then
            yg_err "$ZSH_BIN is not listed in /etc/shells. Not touching your login shell."
            return 1
        fi
        if [[ ! -r "$HOME/.zshrc" ]]; then
            yg_err "No ~/.zshrc was written. Not touching your login shell."
            return 1
        fi

        yg_info "Changing your login shell from ${current} to ${ZSH_BIN}..."
        if ! yg_sudo chsh -s "$ZSH_BIN" "$USER"; then
            yg_err "chsh failed. Your login shell is unchanged (${current})."
            return 1
        fi
        yg_ok "Login shell set to $ZSH_BIN (takes effect on your next login)."
        log "login shell $current -> $ZSH_BIN"
    }

    report_rollback() {
        printf '\n'
        yg_info "If you ever want bash back:"
        printf '  chsh -s /bin/bash "$USER"\n'
        printf '\n'
        yg_warn "One thing worth knowing about rollbacks:"
        printf '  /etc/passwd persists across deployments, but zsh only exists in\n'
        printf '  images from this release onwards. If you roll back to an older\n'
        printf '  YaguareteOS, run the command above from a TTY first, or your\n'
        printf '  terminals will not open.\n'
    }

    ACTION="{{ ACTION }}"
    case "$ACTION" in
        ""|install)
            yg_info "YaguareteOS shell setup — zsh + Powerlevel10k + kitty"
            echo

            # Fail before touching $HOME rather than halfway through.
            yg_check_internet
            yg_check_disk 200
            for cmd in git zsh kitty; do
                command -v "$cmd" >/dev/null 2>&1 || {
                    yg_err "$cmd is not installed. Expected it in the image — report this."
                    exit 1
                }
            done
            # The font ships with the image, so a miss here is either a
            # stale per-user fontconfig cache or a genuinely broken image.
            # Rebuild the cache once before blaming the image — that is the
            # cheap half of the diagnosis and the common one.
            if ! yg_has_font "FiraCode Nerd Font"; then
                yg_info "Rebuilding your font cache..."
                fc-cache -f >/dev/null 2>&1 || true
            fi
            if ! yg_has_font "FiraCode Nerd Font"; then
                yg_err "FiraCode Nerd Font does not resolve, even after a cache rebuild."
                yg_err "It ships with the image, so this is a packaging bug — report it."
                yg_err "Powerlevel10k would render as a row of empty boxes without it."
                exit 1
            fi

            install_omz || exit 1

            for name in "${!THEMES[@]}"; do
                sync_repo "${THEMES[$name]}" "$OMZ_CUSTOM/themes/$name"
            done
            for name in "${!PLUGINS[@]}"; do
                sync_repo "${PLUGINS[$name]}" "$OMZ_CUSTOM/plugins/$name"
            done

            echo
            install_config "$TEMPLATES/zshrc"      "$HOME/.zshrc"
            install_config "$TEMPLATES/p10k.zsh"   "$HOME/.p10k.zsh"
            install_config "$TEMPLATES/kitty.conf" "$YG_CONFIG_DIR/kitty/kitty.conf"

            echo
            set_login_shell || yg_warn "Continuing — everything else is in place."

            # p10k caches an instant prompt per user; a stale one from a
            # previous config shows the old prompt for a beat on startup.
            rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/p10k-instant-prompt-*.zsh

            echo
            yg_ok "Shell environment ready."
            yg_info "Open a new kitty window to see it. Re-run 'p10k configure' any"
            yg_info "time you want a different prompt — it rewrites ~/.p10k.zsh."
            report_rollback
            log "install completed"
            yg_pause
            ;;
        status)
            # Printed for humans; the Portal's own status probe is a
            # separate one-liner in yafti.yml.
            row() { printf '%-26s %s\n' "${1}:" "$2"; }
            state() { [[ -e "$1" ]] && echo present || echo missing; }

            row "oh-my-zsh" "$(state "$OMZ_DIR")"
            row "powerlevel10k" "$(state "$OMZ_CUSTOM/themes/powerlevel10k")"
            for name in "${!PLUGINS[@]}"; do
                row "$name" "$(state "$OMZ_CUSTOM/plugins/$name")"
            done
            row ".zshrc" "$(state "$HOME/.zshrc")"
            row ".p10k.zsh" "$(state "$HOME/.p10k.zsh")"
            row "kitty.conf" "$(state "$YG_CONFIG_DIR/kitty/kitty.conf")"
            row "login shell" "$(getent passwd "$USER" | cut -d: -f7)"
            row "FiraCode Nerd Font" \
                "$(yg_has_font 'FiraCode Nerd Font' && echo resolves || echo MISSING)"
            row "FiraCode Nerd Font Mono" \
                "$(yg_has_font 'FiraCode Nerd Font Mono' && echo resolves || echo MISSING)"
            ;;
        remove)
            yg_warn "This removes oh-my-zsh, the Powerlevel10k theme and the zsh plugins,"
            yg_warn "and puts your login shell back to /bin/bash."
            yg_warn "Your ~/.zshrc, ~/.p10k.zsh and kitty.conf are left in place — delete"
            yg_warn "them yourself if you want them gone, along with any .bak.* copies."
            yg_confirm "Continue?" || { yg_info "Aborted."; exit 0; }

            # Login shell first. Removing oh-my-zsh while zsh is still the
            # login shell would leave the user on the fallback prompt with
            # no obvious way back.
            if [[ "$(getent passwd "$USER" | cut -d: -f7)" == "$ZSH_BIN" ]]; then
                yg_sudo chsh -s /bin/bash "$USER" && \
                    yg_ok "Login shell back to /bin/bash." || \
                    yg_warn "Could not change the login shell — do it with: chsh -s /bin/bash"
            fi

            rm -rf "$OMZ_CUSTOM/themes/powerlevel10k"
            for name in "${!PLUGINS[@]}"; do
                rm -rf "$OMZ_CUSTOM/plugins/$name"
            done
            rm -rf "$OMZ_DIR"
            rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/p10k-instant-prompt-*.zsh
            yg_ok "oh-my-zsh and its add-ons removed."
            yg_info "The .zshrc that ships with the image still works without them —"
            yg_info "it falls back to a plain prompt."
            log "remove completed"
            yg_pause
            ;;
        *)
            yg_err "Unknown option: $ACTION"
            printf 'Usage: ujust yaguarete-setup-shell [install|status|remove]\n'
            exit 2
            ;;
    esac
