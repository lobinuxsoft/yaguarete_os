# YaguareteOS -- graphics memory on AMD APUs, from the terminal.
#
# What the carveout is:
#   The UMA carveout is the fixed slice the firmware hands the iGPU, reported
#   as VRAM. amdgpu exposes it at `<card>/device/uma/carveout`, with the sizes
#   the firmware accepts listed in `carveout_options`; writing an index there
#   asks for that size on the next boot, through the same ACPI path the vendor
#   tool uses -- no SMI, no EFI variable, no out-of-tree module (#267).
#
# Why there is no GTT setter any more:
#   The GTT pool is system RAM the GPU may map as graphics memory, capped by
#   the `ttm.pages_limit` kernel argument. Raising it was the workaround for a
#   carveout nobody could reach: it bought address space in the same DDR banks,
#   at the same bandwidth, without the firmware's cooperation. Now that the
#   carveout moves, inflating GTT on top of it only takes RAM away from the OS
#   to duplicate what the carveout already did.
#
#   `reset` stays, because a machine that was set up before this can still be
#   carrying a raised ceiling, and getting rid of it needs a command.
#
# `status` still reports GTT: not moving it is not a reason to hide it.

# Report the graphics memory pools, and set the firmware VRAM carveout.
yaguarete-vram ACTION="status" VALUE="":
    #!/usr/bin/bash
    set -euo pipefail

    tag=yaguarete-vram
    log() { logger -t "$tag" -- "$*" 2>/dev/null || true; }

    PAGE_SIZE=4096

    mem_total_kb() { awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo; }

    # Prefer a card whose driver is amdgpu; fall back to any card that reports
    # a GTT pool at all.
    find_gpu() {
        local dev fallback=""
        for dev in /sys/class/drm/card*/device; do
            [[ -e "$dev/mem_info_gtt_total" ]] || continue
            [[ -n "$fallback" ]] || fallback="$dev"
            if grep -q '^DRIVER=amdgpu$' "$dev/uevent" 2>/dev/null; then
                echo "$dev"
                return 0
            fi
        done
        [[ -n "$fallback" ]] && echo "$fallback"
    }

    human() { numfmt --to=iec --suffix=B --format='%.1f' "$1" 2>/dev/null || echo "$1"; }

    # Width of the longest label, so every line reads as one column.
    field() { printf '%-20s: %s\n' "$1" "$2"; }

    active_pages() {
        local m
        m=$(grep -o '\bttm\.pages_limit=[0-9]\+' /proc/cmdline | tail -1) || true
        [[ -n "$m" ]] && echo "${m#*=}" || echo ""
    }

    staged_value() {
        rpm-ostree kargs 2>/dev/null \
            | grep -o "\b$1=[0-9]\+" | tail -1 | sed 's/.*=//' || true
    }

    show_status() {
        local total_kb gpu active staged
        total_kb=$(mem_total_kb)
        gpu=$(find_gpu)
        active=$(active_pages)
        staged=$(staged_value ttm.pages_limit)

        field "RAM total" "$(human $((total_kb * 1024)))"
        if [[ -n "$gpu" ]]; then
            field "GTT actual" "$(human "$(cat "$gpu/mem_info_gtt_total")")"
            [[ -e "$gpu/mem_info_vram_total" ]] &&
                field "VRAM (UMA, firmware)" "$(human "$(cat "$gpu/mem_info_vram_total")")"
            [[ -e "$gpu/uma/carveout" ]] &&
                field "carveout" "opcion $(cat "$gpu/uma/carveout")  (ujust yaguarete-vram firmware)"
        else
            field "GTT actual" "sin GPU AMD detectada"
        fi
        if [[ -n "$active" ]]; then
            field "ttm.pages_limit" "$active  ($(human $((active * PAGE_SIZE))), activo)"
        else
            field "ttm.pages_limit" "sin definir (default del kernel, ~50% de la RAM)"
        fi
        if [[ -n "$staged" && "$staged" != "$active" ]]; then
            echo
            echo "Hay un valor preparado que todavia no arranco: $staged"
            echo "Reinicia para que tome efecto."
        fi
    }

    reset_kargs() {
        local args=(kargs) changed=0 key old
        for key in ttm.pages_limit ttm.page_pool_size; do
            old=$(staged_value "$key")
            [[ -n "$old" ]] || continue
            args+=("--delete=$key=$old")
            changed=1
        done
        if (( ! changed )); then
            echo "No hay nada que sacar: el kernel ya usa su default."
            return 0
        fi
        sudo rpm-ostree "${args[@]}"
        echo "Sacado. Reinicia para volver al default del kernel."
    }

    uma_dir() {
        local gpu
        gpu=$(find_gpu)
        [[ -n "$gpu" && -e "$gpu/uma/carveout" ]] && echo "$gpu/uma"
    }

    require_uma() {
        local uma
        uma=$(uma_dir)
        if [[ -z "$uma" ]]; then
            echo "Este kernel no expone el carveout UMA." >&2
            echo "Hace falta amdgpu con /sys/class/drm/card*/device/uma/." >&2
            exit 1
        fi
        echo "$uma"
    }

    # "512 MB" -> 512, "8 GB" -> 8192, and a bare "8" -> 8192: every option the
    # firmware offers above the floor is whole gigabytes, so gigabytes are what
    # an unqualified number means. Only megabytes need saying out loud.
    to_mib() {
        awk -v s="$1" 'BEGIN {
            n = "";
            if (match(s, /[0-9]+/)) n = substr(s, RSTART, RLENGTH);
            if (n == "") exit;
            if (s ~ /[Mm]/) print n; else print n * 1024;
        }'
    }

    # The size each option stands for, taken from the text in parentheses.
    option_mib() {
        local paren="${1##*\(}"
        to_mib "${paren%%\)*}"
    }

    show_uma() {
        local uma now line idx
        uma=$(require_uma)
        now=$(cat "$uma/carveout")
        echo "Carveout de firmware (VRAM). Reinicia para que un cambio tome efecto."
        echo
        while IFS= read -r line; do
            idx="${line%%:*}"
            if [[ "$idx" == "$now" ]]; then
                echo "  * $line   <- actual"
            else
                echo "    $line"
            fi
        done < "$uma/carveout_options"
        echo
        echo "Para cambiarlo: ujust yaguarete-vram firmware <tamano>"
        echo "Un numero pelado son gigabytes: 8, 16, 32. Megabytes se dicen: 512M."
    }

    set_uma() {
        local want="$1" uma now want_mib line idx target=""
        uma=$(require_uma)
        want_mib=$(to_mib "$want")
        if [[ -z "$want_mib" ]]; then
            echo "No entiendo \"$want\". Se espera un tamano: 8, 8G, 512M." >&2
            exit 1
        fi

        while IFS= read -r line; do
            [[ "$(option_mib "$line")" == "$want_mib" ]] || continue
            target="${line%%:*}"
            break
        done < "$uma/carveout_options"

        if [[ -z "$target" ]]; then
            # Only the sizes, never the indices: printing "3: (4 GB)" next to a
            # rejected "3" is an invitation to read the index as the size.
            echo "El firmware no ofrece $want_mib MiB. Ofrece:" >&2
            awk -F'[()]' 'NF > 1 { printf "  %s\n", $2 }' "$uma/carveout_options" >&2
            echo "Un numero pelado son gigabytes; megabytes se dicen: 512M." >&2
            exit 1
        fi

        now=$(cat "$uma/carveout")
        if [[ "$target" == "$now" ]]; then
            echo "Ya esta en ese valor. Nada que hacer."
            return 0
        fi

        log "carveout $now -> $target ($want_mib MiB)"
        # The kernel validates the index and asks the firmware; a bad write
        # fails here rather than at the next boot.
        printf '%s\n' "$target" | sudo tee "$uma/carveout" >/dev/null
        echo "Pedido: $want_mib MiB (opcion $target)."
        echo "Reinicia para que el firmware lo aplique."
    }

    case "{{ ACTION }}" in
        status) show_status ;;
        reset) reset_kargs ;;   # only undoes a GTT ceiling set before #290
        firmware)
            if [[ -z "{{ VALUE }}" ]]; then
                show_uma
            else
                set_uma "{{ VALUE }}"
            fi
            ;;
        *)
            echo "Uso: ujust yaguarete-vram [status|firmware [tamano]|reset]" >&2
            exit 1
            ;;
    esac
