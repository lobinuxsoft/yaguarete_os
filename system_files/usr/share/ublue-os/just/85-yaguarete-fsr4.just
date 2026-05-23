# YaguareteOS — auto-detect GPU and call the matching upstream Bazzite
# FSR4 upgrade recipe (`global-fsr4` for RDNA4, `global-fsr4-rdna3` for
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
#      silent fail is traceable after the fact — even when yafti hides
#      stderr.
#   5. Post-write validation: confirms the env flag file actually landed
#      under `$HOME/.config/environment.d/` and aborts loudly otherwise.
#   6. Shows a kdialog (zenity / notify-send / journal fallbacks) at the
#      end with: detected GPU, family, recipe invoked, flag file path,
#      Proton forks present, and the exact next steps the user has to
#      take in Steam to actually see FSR4 kick in.

yaguarete-fsr4 ACTION="enable":
    #!/usr/bin/bash
    set -euo pipefail

    tag=yaguarete-fsr4
    log() { logger -t "$tag" -- "$*" 2>/dev/null || true; printf '[%s] %s\n' "$tag" "$*"; }

    # GUI feedback helpers. yafti spawns the recipe in a konsole that
    # closes the instant the script exits, so the journal trail alone is
    # useless to the user. Fall back through kdialog → zenity →
    # notify-send → log-only so we cover Plasma desktop, GNOME-ish
    # sessions, and gamescope (where only notify-send via libnotify
    # might reach the overlay).
    notify_success() {
        local title="YaguareteOS — FSR4 Upgrade"
        local body="$1"
        log "GUI feedback (success): showing summary"
        if command -v kdialog >/dev/null 2>&1; then
            kdialog --title "$title" --msgbox "$body" >/dev/null 2>&1 && return 0
        fi
        if command -v zenity >/dev/null 2>&1; then
            zenity --info --title="$title" --no-wrap --text="$body" >/dev/null 2>&1 && return 0
        fi
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -t 30000 "$title" "$body" >/dev/null 2>&1 && return 0
        fi
        log "GUI feedback unavailable — journal log is the only record."
    }

    notify_error() {
        local title="YaguareteOS — FSR4 Upgrade FAILED"
        local body="$1"
        log "GUI feedback (error): $body"
        if command -v kdialog >/dev/null 2>&1; then
            kdialog --title "$title" --error "$body" >/dev/null 2>&1 && return 0
        fi
        if command -v zenity >/dev/null 2>&1; then
            zenity --error --title="$title" --text="$body" >/dev/null 2>&1 && return 0
        fi
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u critical -t 60000 "$title" "$body" >/dev/null 2>&1 && return 0
        fi
    }

    # Walk both Steam compatibilitytools.d locations and pick directories
    # that look like Proton GE / EM forks. Returns a newline-separated
    # bullet list, or empty if none.
    detect_proton_forks() {
        local found=""
        local dir entry name
        for dir in "$HOME/.local/share/Steam/compatibilitytools.d" "$HOME/.steam/root/compatibilitytools.d"; do
            [[ -d "$dir" ]] || continue
            for entry in "$dir"/*; do
                [[ -d "$entry" ]] || continue
                name=$(basename "$entry")
                case "$name" in
                    GE-Proton*|Proton-GE*|Proton-EM*|ProtonEM*|*-EM-*|GE-Latest|EM-Latest)
                        # Dedupe — both paths often point at the same dir via symlink.
                        case "$found" in
                            *"  • $name"$'\n'*) ;;
                            *) found+="  • $name"$'\n' ;;
                        esac
                        ;;
                esac
            done
        done
        printf '%s' "$found"
    }

    action="{{ACTION}}"
    case "$action" in
        enable|disable) ;;
        *)
            msg="Usage: ujust yaguarete-fsr4 {enable|disable}"$'\n'"Received: '$action'"
            notify_error "$msg"
            log "ERROR: $msg"
            exit 2
            ;;
    esac

    # yafti's subprocess context can leave HOME unset; expand explicitly.
    if [[ -z "${HOME:-}" ]]; then
        HOME=$(getent passwd "$(id -un)" | cut -d: -f6)
        export HOME
        log "HOME was unset, defaulted to $HOME"
    fi

    gpu_name=""
    if command -v vulkaninfo >/dev/null 2>&1; then
        gpu_name=$(vulkaninfo --summary 2>/dev/null \
            | awk '/deviceName/ && !/llvmpipe/ { sub(/^[[:space:]]*deviceName[[:space:]]*=[[:space:]]*/, ""); print; exit }')
    fi
    if [[ -z "$gpu_name" ]]; then
        gpu_name=$(lspci -nn 2>/dev/null | grep -iE 'VGA|Display|3D' | grep -iE 'AMD|ATI|Radeon' | head -1 || true)
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
        msg="Could not detect any GPU."$'\n\n'"Tried vulkaninfo, lspci, /sys/class/drm/*/device/uevent — all empty."$'\n\n'"Diagnostics: journalctl --user -t yaguarete-fsr4"
        notify_error "$msg"
        exit 3
    fi
    log "Detected GPU: $gpu_name"

    if ! echo "$gpu_name" | grep -qiE 'AMD|ATI|Radeon|Ryzen|RADV'; then
        msg="Non-AMD GPU detected: $gpu_name"$'\n\n'"FSR4 upgrade is AMD-only. NVIDIA users: see 'Global DLSS Upgrade' instead."
        notify_error "$msg"
        exit 4
    fi

    # Family detection. Order matters: match RDNA4 first (smaller / newer set),
    # then RDNA3 family (includes 3.5 = Strix / Phoenix / Hawk Point APUs).
    if echo "$gpu_name" | grep -qiE 'GFX120[0-9]|RDNA[_ ]?4|Navi 4[48]|RX[[:space:]]*9[0-9]{3}'; then
        family="RDNA 4 (native FSR4)"
        family_short=rdna4
        recipe=global-fsr4
        proton_requirement="RDNA 4 has native FSR4 — vanilla Proton 10+ is enough. Proton GE / EM forks work too but are not required."
    elif echo "$gpu_name" | grep -qiE 'GFX11[0-9]+|Strix|Phoenix|Hawk|NAVI[23][0-9]|RDNA[_ ]?[23]|RX[[:space:]]*[67][0-9]{3}|Radeon[[:space:]]*[78][0-9]{2}M?'; then
        family="RDNA 3 / 3.5 (FP8 emulation)"
        family_short=rdna3
        recipe=global-fsr4-rdna3
        proton_requirement="RDNA 3/3.5 REQUIRES Proton GE or Proton EM — vanilla Proton lacks the FSR4 RDNA3 patch and the env flag is a no-op without them."
    else
        family="Unknown AMD silicon (defaulting to RDNA 3 path)"
        family_short=rdna3-fallback
        recipe=global-fsr4-rdna3
        proton_requirement="Unknown AMD GPU — defaulted to the RDNA 3 path, which REQUIRES Proton GE or EM. If your card is actually RDNA 4, run 'ujust global-fsr4 enable' manually."
        log "WARN: unknown AMD GPU, defaulting to RDNA3 path."
    fi
    log "GPU family: $family_short → ujust $recipe $action"

    if ! ujust "$recipe" "$action"; then
        msg="Upstream recipe failed: ujust $recipe $action exited non-zero."$'\n\n'"GPU: $gpu_name"$'\n'"Family: $family"$'\n\n'"Diagnostics: journalctl --user -t yaguarete-fsr4"
        notify_error "$msg"
        exit 5
    fi

    env_dir="$HOME/.config/environment.d"

    if [[ "$action" == "disable" ]]; then
        log "OK: disable flow completed."
        msg="FSR4 Upgrade disabled."$'\n\n'"GPU: $gpu_name"$'\n'"Family: $family"$'\n'"Recipe: ujust $recipe disable"$'\n\n'"Flag file removed from $env_dir/."$'\n\n'"Log out and back in (or reboot) for the change to propagate to Steam."$'\n\n'"Logs: journalctl --user -t yaguarete-fsr4"
        notify_success "$msg"
        exit 0
    fi

    # Enable path — validate the flag file actually landed.
    flag_files=$(ls -1 "$env_dir"/*proton-fsr4*.conf 2>/dev/null || true)
    if [[ -z "$flag_files" ]]; then
        msg="The upstream recipe reported success but no FSR4 flag file landed in $env_dir/."$'\n\n'"Likely cause: yafti subprocess env stripped HOME or shell context."$'\n\n'"Re-run from a terminal:"$'\n'"  ujust yaguarete-fsr4 enable"$'\n\n'"Diagnostics: journalctl --user -t yaguarete-fsr4"
        notify_error "$msg"
        exit 6
    fi

    proton_list=$(detect_proton_forks)
    if [[ -z "$proton_list" ]]; then
        if [[ "$family_short" == "rdna4" ]]; then
            proton_block="Proton GE / EM forks installed:"$'\n'"  (none detected — optional for RDNA 4, vanilla Proton 10+ works)"
        else
            proton_block="Proton GE / EM forks installed:"$'\n'"  ⚠ NONE DETECTED."$'\n'"     RDNA 3/3.5 needs Proton GE or EM, the env flag alone is useless."$'\n'"     Install via:"$'\n'"       - Decky → ProtonGE plugin, OR"$'\n'"       - Drop a release into ~/.local/share/Steam/compatibilitytools.d/"
        fi
    else
        proton_block="Proton GE / EM forks installed:"$'\n'"${proton_list%$'\n'}"
    fi

    # Trim trailing newlines from flag_files for display.
    flag_block=""
    while IFS= read -r f; do
        [[ -n "$f" ]] && flag_block+="  $f"$'\n'
    done <<< "$flag_files"
    flag_block="${flag_block%$'\n'}"

    log "OK: wrote $(echo "$flag_files" | tr '\n' ' ')"
    log "Log out and back in for environment.d/ to be picked up by the session."

    msg="FSR4 Upgrade enabled."$'\n\n'\
"GPU detected:"$'\n'"  $gpu_name"$'\n\n'\
"Family:"$'\n'"  $family"$'\n\n'\
"Recipe invoked:"$'\n'"  ujust $recipe enable"$'\n\n'\
"Flag file written:"$'\n'"$flag_block"$'\n\n'\
"$proton_block"$'\n\n'\
"Proton requirement:"$'\n'"  $proton_requirement"$'\n\n'\
"Next steps:"$'\n'\
"  1. Log out and back in (or reboot) — Steam reads environment.d/"$'\n'\
"     only at session start. Without this, Steam keeps the OLD env."$'\n'\
"  2. In each game's Properties → Compatibility, force a Proton GE"$'\n'\
"     or Proton EM fork (vanilla Proton lacks the FSR4 RDNA3 patch)."$'\n'\
"  3. The game must use FSR 3.1 or higher upscaler — FSR4 hijacks"$'\n'\
"     the FSR 3.1+ DLL. Games using DLSS / FSR 2 / no upscaler are"$'\n'\
"     unaffected by this flag."$'\n\n'\
"Logs: journalctl --user -t yaguarete-fsr4"

    notify_success "$msg"
