# YaguareteOS — auto-detect GPU and call the matching upstream Bazzite
# FSR4 upgrade recipe (`toggle-global-fsr4` for RDNA4, `toggle-global-fsr4-rdna3` for
# RDNA 3 / 3.5).
#
# Why this wrapper exists:
#   - Bazzite exposes the two FSR4 recipes side by side and lets the user
#     pick. yafti rendered both items without any hardware filtering, so
#     OneXFly users (Radeon 890M = RDNA 3.5 = gfx1150) were picking the
#     RDNA4 recipe and silently getting the wrong env flag.
#   - The upstream recipe also fails silently when invoked from yafti:
#     yafti spawns scripts via subprocess with a stripped env, so
#     `$HOME` is sometimes empty / `~` does not expand, and `set -e`
#     aborts mid-recipe without any output reaching the GUI.
#   - yafti closes the spawned konsole as soon as the script exits, so
#     even when the recipe succeeds the user never sees the "Log out and
#     back in" instruction, the detected GPU, or the Proton fork list
#     they need to pick in Steam.
#
# What the wrapper does:
#   1. Force-exports HOME so the upstream recipe can resolve
#      `$HOME/.config/environment.d/` even under yafti's subprocess.
#   2. Reads the GPU name via vulkaninfo (preferred — RADV codename
#      survives the llvmpipe fallback), lspci (no `-d ::0300` filter:
#      integrated GPUs report class 0x0380, not VGA), and finally
#      `/sys/class/drm/*/device/uevent`. Maps to RDNA4 vs RDNA3/3.5;
#      unknown AMD GPUs fall through to RDNA3 (FP8 emulation degrades
#      gracefully, vs RDNA4 flag silently ignored on older silicon).
#   3. Inventories Proton GE / Proton EM forks under both Steam paths.
#      RDNA 3/3.5 path needs one of these — vanilla Proton has no FSR4
#      RDNA3 patch and the env flag is a no-op without them.
#   4. Logs every step to `journalctl --user -t yaguarete-fsr4` so the
#      silent fail is traceable after the fact.
#   5. Post-write validation: confirms the env flag file actually landed
#      under `$HOME/.config/environment.d/` and aborts loudly otherwise.
#   6. Prints the full summary to stdout and pauses the konsole with
#      `read -n 1` so the user actually sees: detected GPU, family,
#      recipe invoked, flag file path, Proton forks present, and the
#      exact next steps to take in Steam. No GUI dependencies — works
#      in Plasma desktop and gamescope alike.

yaguarete-fsr4 ACTION="enable":
    #!/usr/bin/bash
    set -euo pipefail

    tag=yaguarete-fsr4
    log() { logger -t "$tag" -- "$*" 2>/dev/null || true; }

    # Pause so the konsole yafti spawns doesn't vanish before the user
    # reads the summary. Skips the pause when not on a TTY (e.g. direct
    # ssh non-interactive) so headless invocations still work.
    pause() {
        if [[ -t 0 ]]; then
            printf '\n'
            read -n 1 -s -r -p "Press any key to close this window..."
            printf '\n'
        fi
    }

    # Walk both Steam compatibilitytools.d locations and pick directories
    # that look like Proton GE / EM forks. Echoes a newline-separated
    # bullet list (or empty if none).
    detect_proton_forks() {
        local found="" dir entry name
        for dir in "$HOME/.local/share/Steam/compatibilitytools.d" "$HOME/.steam/root/compatibilitytools.d"; do
            [[ -d "$dir" ]] || continue
            for entry in "$dir"/*; do
                [[ -d "$entry" ]] || continue
                name=$(basename "$entry")
                case "$name" in
                    GE-Proton*|Proton-GE*|Proton-EM*|ProtonEM*|*-EM-*|GE-Latest|EM-Latest)
                        case "$found" in
                            *"  • $name"*) ;;
                            *) found+="  • $name"$'\n' ;;
                        esac
                        ;;
                esac
            done
        done
        printf '%s' "${found%$'\n'}"
    }

    rule="=============================================================="

    action="{{ACTION}}"
    case "$action" in
        enable|disable) ;;
        *)
            log "ERROR: usage: ujust yaguarete-fsr4 {enable|disable}"
            printf '%s\n' "" "$rule" "  ERROR — invalid action: '$action'" "$rule" "" "Usage: ujust yaguarete-fsr4 {enable|disable}" ""
            pause
            exit 2
            ;;
    esac

    # yafti's subprocess context can leave HOME unset; expand explicitly.
    if [[ -z "${HOME:-}" ]]; then
        HOME=$(getent passwd "$(id -un)" | cut -d: -f6)
        export HOME
        log "HOME was unset, defaulted to $HOME"
    fi

    # Note on awk style: we intentionally avoid `exit` inside the awk
    # block. With `set -o pipefail`, the upstream `vulkaninfo` still
    # has more bytes to write when awk closes its stdin, gets SIGPIPE,
    # the whole pipeline returns 141, and `set -e` aborts the script
    # before any log() call lands. Using a `found` sentinel processes
    # the full input and emits only the first match — no SIGPIPE.
    gpu_name=""
    if command -v vulkaninfo >/dev/null 2>&1; then
        gpu_name=$(vulkaninfo --summary 2>/dev/null | awk '
            /deviceName/ && !/llvmpipe/ && !found {
                sub(/^[[:space:]]*deviceName[[:space:]]*=[[:space:]]*/, "")
                print
                found = 1
            }
        ' 2>/dev/null) || gpu_name=""
    fi
    if [[ -z "$gpu_name" ]]; then
        # Same SIGPIPE risk with `head -1` upstream; wrap the whole
        # substitution so a failure leaves gpu_name empty instead of
        # aborting.
        gpu_name=$(lspci -nn 2>/dev/null | grep -iE 'VGA|Display|3D' | grep -iE 'AMD|ATI|Radeon' | head -1 2>/dev/null) || gpu_name=""
    fi
    if [[ -z "$gpu_name" ]]; then
        for uev in /sys/class/drm/card*/device/uevent; do
            [[ -r "$uev" ]] || continue
            if grep -q '^DRIVER=amdgpu' "$uev"; then
                pci_id=$(awk -F'=' '/^PCI_ID=/ { print tolower($2); exit }' "$uev")
                if [[ -n "$pci_id" ]]; then
                    gpu_name="AMD PCI $pci_id"
                    break
                fi
            fi
        done
    fi
    if [[ -z "$gpu_name" ]]; then
        log "ERROR: could not detect GPU (tried vulkaninfo, lspci, /sys/class/drm)"
        printf '%s\n' "" "$rule" "  ERROR — Could not detect any GPU" "$rule" "" "Tried vulkaninfo, lspci, /sys/class/drm/*/device/uevent — all empty." "" "Diagnostics: journalctl --user -t yaguarete-fsr4" ""
        pause
        exit 3
    fi
    log "Detected GPU: $gpu_name"

    if ! echo "$gpu_name" | grep -qiE 'AMD|ATI|Radeon|Ryzen|RADV'; then
        log "ERROR: non-AMD GPU detected: $gpu_name"
        printf '%s\n' "" "$rule" "  ERROR — Non-AMD GPU detected" "$rule" "" "GPU: $gpu_name" "" "FSR4 upgrade is AMD-only." "NVIDIA users: see 'Global DLSS Upgrade' instead." ""
        pause
        exit 4
    fi

    # Family detection. Order matters: match RDNA4 first (smaller / newer set),
    # then RDNA3 family (includes 3.5 = Strix / Phoenix / Hawk Point APUs).
    if echo "$gpu_name" | grep -qiE 'GFX120[0-9]|RDNA[_ ]?4|Navi 4[48]|RX[[:space:]]*9[0-9]{3}'; then
        family="RDNA 4 (native FSR4)"
        family_short=rdna4
        recipe=toggle-global-fsr4
        proton_req="RDNA 4 has native FSR4 — vanilla Proton 10+ is enough. Proton GE / EM forks work too but are not required."
    elif echo "$gpu_name" | grep -qiE 'GFX11[0-9]+|Strix|Phoenix|Hawk|NAVI[23][0-9]|RDNA[_ ]?[23]|RX[[:space:]]*[67][0-9]{3}|Radeon[[:space:]]*[78][0-9]{2}M?'; then
        family="RDNA 3 / 3.5 (FP8 emulation)"
        family_short=rdna3
        recipe=toggle-global-fsr4-rdna3
        proton_req="RDNA 3/3.5 REQUIRES Proton GE or Proton EM — vanilla Proton lacks the FSR4 RDNA3 patch and the env flag is a no-op without them."
    else
        family="Unknown AMD silicon (defaulting to RDNA 3 path)"
        family_short=rdna3-fallback
        recipe=toggle-global-fsr4-rdna3
        proton_req="Unknown AMD GPU — defaulted to the RDNA 3 path, which REQUIRES Proton GE or EM. If your card is actually RDNA 4, run 'ujust toggle-global-fsr4 enable' manually."
        log "WARN: unknown AMD GPU, defaulting to RDNA3 path."
    fi
    log "GPU family: $family_short → ujust $recipe $action"

    if ! ujust "$recipe" "$action"; then
        log "ERROR: ujust $recipe $action exited non-zero"
        printf '%s\n' "" "$rule" "  ERROR — Upstream recipe failed" "$rule" "" "Command: ujust $recipe $action" "GPU: $gpu_name" "Family: $family" "" "Diagnostics: journalctl --user -t yaguarete-fsr4" ""
        pause
        exit 5
    fi

    env_dir="$HOME/.config/environment.d"

    if [[ "$action" == "disable" ]]; then
        log "OK: disable flow completed."
        printf '%s\n' "" "$rule" "  YaguareteOS — FSR4 Upgrade DISABLED" "$rule" "" "GPU detected:" "  $gpu_name" "" "Family:" "  $family" "" "Recipe invoked:" "  ujust $recipe disable" "" "Flag file removed from:" "  $env_dir/" "" "Next step:" "  Log out and back in (or reboot) for the change to" "  propagate to Steam." "" "Logs: journalctl --user -t yaguarete-fsr4" ""
        pause
        exit 0
    fi

    # Enable path — validate the flag file actually landed.
    flag_files=$(ls -1 "$env_dir"/*proton-fsr4*.conf 2>/dev/null || true)
    if [[ -z "$flag_files" ]]; then
        log "ERROR: $recipe reported success but no FSR4 flag file landed in $env_dir/"
        printf '%s\n' "" "$rule" "  ERROR — Flag file did not land" "$rule" "" "$recipe reported success but no FSR4 flag file was found in:" "  $env_dir/" "" "Likely cause: yafti subprocess env stripped HOME or shell context." "" "Re-run from a terminal:" "  ujust yaguarete-fsr4 enable" "" "Diagnostics: journalctl --user -t yaguarete-fsr4" ""
        pause
        exit 6
    fi

    proton_list=$(detect_proton_forks)
    log "OK: wrote $(echo "$flag_files" | tr '\n' ' ')"

    # Build the success block as a single printf argument list. Each
    # quoted string becomes one output line; %s\n adds the newline.
    printf '%s\n' \
        "" \
        "$rule" \
        "  YaguareteOS — FSR4 Upgrade ENABLED" \
        "$rule" \
        "" \
        "GPU detected:" \
        "  $gpu_name" \
        "" \
        "Family:" \
        "  $family" \
        "" \
        "Recipe invoked:" \
        "  ujust $recipe enable" \
        ""

    printf '%s\n' "Flag file written:"
    while IFS= read -r f; do
        [[ -n "$f" ]] && printf '  %s\n' "$f"
    done <<< "$flag_files"
    printf '\n'

    if [[ -z "$proton_list" ]]; then
        if [[ "$family_short" == "rdna4" ]]; then
            printf '%s\n' \
                "Proton GE / EM forks installed:" \
                "  (none detected — optional for RDNA 4, vanilla Proton 10+ works)" \
                ""
        else
            printf '%s\n' \
                "Proton GE / EM forks installed:" \
                "  ⚠ NONE DETECTED." \
                "     RDNA 3/3.5 needs Proton GE or EM, the env flag alone is useless." \
                "     Install via:" \
                "       - Decky → ProtonGE plugin, OR" \
                "       - Drop a release into ~/.local/share/Steam/compatibilitytools.d/" \
                ""
        fi
    else
        printf '%s\n' "Proton GE / EM forks installed:"
        printf '%s\n' "$proton_list"
        printf '\n'
    fi

    printf '%s\n' \
        "Proton requirement:" \
        "  $proton_req" \
        "" \
        "Next steps:" \
        "  1. Log out and back in (or reboot) — Steam reads environment.d/" \
        "     only at session start. Without this, Steam keeps the OLD env." \
        "  2. In each game's Properties → Compatibility, force a Proton GE" \
        "     or Proton EM fork (vanilla Proton lacks the FSR4 RDNA3 patch)." \
        "  3. The game must use FSR 3.1 or higher upscaler — FSR4 hijacks" \
        "     the FSR 3.1+ DLL. Games using DLSS / FSR 2 / no upscaler are" \
        "     unaffected by this flag." \
        "" \
        "Logs: journalctl --user -t yaguarete-fsr4" \
        ""

    log "Log out and back in for environment.d/ to be picked up by the session."
    pause
