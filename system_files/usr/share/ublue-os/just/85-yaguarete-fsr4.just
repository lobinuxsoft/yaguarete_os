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
#
# What the wrapper does:
#   1. Force-exports HOME so the upstream recipe can resolve
#      `$HOME/.config/environment.d/` even under yafti's subprocess.
#   2. Reads the GPU name via glxinfo (preferred) or lspci (fallback)
#      and maps it to RDNA4 vs RDNA3/3.5. Unknown AMD GPUs fall through
#      to the RDNA3 path (safer — FP8 emulation degrades gracefully,
#      while RDNA4-only flag is a no-op on older silicon).
#   3. Logs every step to `journalctl --user -t yaguarete-fsr4` so the
#      silent fail is traceable after the fact — even when yafti hides
#      stderr.
#   4. Post-write validation: confirms the env flag file actually landed
#      under `$HOME/.config/environment.d/` and aborts loudly otherwise.

yaguarete-fsr4 ACTION="enable":
    #!/usr/bin/bash
    set -euo pipefail

    tag=yaguarete-fsr4
    log() { logger -t "$tag" -- "$*" 2>/dev/null || true; printf '[%s] %s\n' "$tag" "$*"; }

    action="{{ACTION}}"
    case "$action" in
        enable|disable) ;;
        *) log "ERROR: usage: ujust yaguarete-fsr4 {enable|disable}"; exit 2 ;;
    esac

    # yafti's subprocess context can leave HOME unset; expand explicitly.
    if [[ -z "${HOME:-}" ]]; then
        HOME=$(getent passwd "$(id -un)" | cut -d: -f6)
        export HOME
        log "HOME was unset, defaulted to $HOME"
    fi

    # GPU identification. vulkaninfo is the canonical source on Bazzite
    # (always shipped via mesa-vulkan-drivers, no extra package) and exposes
    # the RADV codename (GFX1201 / STRIX1 / PHX1 / NAVI31 etc.) right in the
    # deviceName line — skipping the llvmpipe software fallback. lspci is the
    # second-best fallback BUT must run WITHOUT the `-d ::0300` class filter:
    # integrated GPUs on Strix/Phoenix/Steam Deck report class 0x0380
    # (Display controller, other), NOT 0x0300 (VGA), so filtering for VGA
    # silently misses them. /sys/class/drm uevent is the final hardware
    # source when neither tool is around.
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
        log "ERROR: could not detect GPU (tried vulkaninfo, lspci, /sys/class/drm)"
        exit 3
    fi
    log "Detected GPU: $gpu_name"

    # Bail on non-AMD — FSR4 upgrade has no effect on NVIDIA or Intel.
    if ! echo "$gpu_name" | grep -qiE 'AMD|ATI|Radeon|Ryzen|RADV'; then
        log "ERROR: non-AMD GPU detected. FSR4 upgrade is AMD-only."
        exit 4
    fi

    # Family detection. Order matters: match RDNA4 first (smaller / newer set),
    # then RDNA3 family (includes 3.5 = Strix / Phoenix / Hawk Point APUs).
    if echo "$gpu_name" | grep -qiE 'GFX120[0-9]|RDNA[_ ]?4|Navi 4[48]|RX[[:space:]]*9[0-9]{3}'; then
        family=rdna4
        recipe=global-fsr4
    elif echo "$gpu_name" | grep -qiE 'GFX11[0-9]+|Strix|Phoenix|Hawk|NAVI[23][0-9]|RDNA[_ ]?[23]|RX[[:space:]]*[67][0-9]{3}|Radeon[[:space:]]*[78][0-9]{2}M?'; then
        family=rdna3
        recipe=global-fsr4-rdna3
    else
        # Unknown AMD silicon — RDNA3 path is the safer default: it requires
        # Proton GE/EM and is a no-op without it, vs RDNA4 path which writes a
        # flag that may be silently ignored on older GPUs.
        family=rdna3-fallback
        recipe=global-fsr4-rdna3
        log "WARN: unknown AMD GPU, defaulting to RDNA3 path."
    fi
    log "GPU family: $family → ujust $recipe $action"

    if ! ujust "$recipe" "$action"; then
        log "ERROR: ujust $recipe $action exited non-zero"
        exit 5
    fi

    # Post-write validation. The Bazzite recipe writes one of:
    #   $HOME/.config/environment.d/99-proton-fsr4.conf       (RDNA4)
    #   $HOME/.config/environment.d/99-proton-fsr4-rdna3.conf (RDNA3)
    env_dir="$HOME/.config/environment.d"
    if [[ "$action" == "enable" ]]; then
        flag_files=$(ls -1 "$env_dir"/*proton-fsr4*.conf 2>/dev/null || true)
        if [[ -z "$flag_files" ]]; then
            log "ERROR: $recipe reported success but no FSR4 flag file landed in $env_dir/"
            log "Likely cause: yafti subprocess env stripped HOME or shell context."
            log "Re-run from a terminal: 'ujust yaguarete-fsr4 enable'"
            exit 6
        fi
        log "OK: wrote $(echo "$flag_files" | tr '\n' ' ')"
        log "Log out and back in for environment.d/ to be picked up by the session."
    else
        log "OK: disable flow completed."
    fi
