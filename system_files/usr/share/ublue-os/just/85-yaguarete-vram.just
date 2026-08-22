# YaguareteOS — GTT (graphics memory) ceiling for AMD APUs, from the terminal.
#
# Why this exists as a recipe and not a slider:
#   `hhd-vram` (#227) put this behind a Handheld Daemon slider. Bazzite 44
#   retired HHD, so the plugin stopped being installed and the knob vanished
#   with it. Porting it to OpenGamepadUI would cost a privileged D-Bus daemon
#   to expose one integer that is set once every few months and needs a reboot
#   anyway, so the function moved here instead of the widget being rebuilt
#   (#269).
#
# What GTT is:
#   The GTT pool is system RAM the GPU may map as graphics memory. Its ceiling
#   is the `ttm.pages_limit` kernel argument, one page being 4 KiB; the kernel
#   default is roughly half of RAM. On a unified-memory APU the GTT lives in
#   the same DDR banks as the BIOS UMA carveout and runs at the same bandwidth,
#   so raising it costs nothing but the RAM the OS no longer gets.
#
# What this does NOT touch:
#   The UMA carveout itself -- the fixed slice the firmware hands the iGPU,
#   reported as VRAM. That one lives in firmware and is tracked in #267.
#
# Applied with `rpm-ostree kargs`, edited in place. Never a blind `--append`:
# that stacks a duplicate `ttm.pages_limit=` on every run and the last one on
# the command line is the one the kernel honours.

# Read or change how much system RAM the GPU may map as graphics memory.
yaguarete-vram ACTION="status" PERCENT="":
    #!/usr/bin/bash
    set -euo pipefail

    tag=yaguarete-vram
    log() { logger -t "$tag" -- "$*" 2>/dev/null || true; }

    PAGE_SIZE=4096
    # RAM always left to the OS: compositor, shader cache, gamescope. A 16 GiB
    # device set to 75% would leave 4 GiB and thrash itself.
    MIN_OS_KB=$((6 * 1024 * 1024))

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

        echo "RAM total          : $(human $((total_kb * 1024)))"
        if [[ -n "$gpu" ]]; then
            echo "GTT actual         : $(human "$(cat "$gpu/mem_info_gtt_total")")"
            [[ -e "$gpu/mem_info_vram_total" ]] &&
                echo "VRAM (UMA, firmware): $(human "$(cat "$gpu/mem_info_vram_total")")"
        else
            echo "GTT actual         : sin GPU AMD detectada"
        fi
        if [[ -n "$active" ]]; then
            echo "ttm.pages_limit    : $active  ($(human $((active * PAGE_SIZE))), activo)"
        else
            echo "ttm.pages_limit    : sin definir (default del kernel, ~50% de la RAM)"
        fi
        if [[ -n "$staged" && "$staged" != "$active" ]]; then
            echo
            echo "Hay un valor preparado que todavia no arranco: $staged"
            echo "Reinicia para que tome efecto."
        fi
    }

    apply_percent() {
        local pct="$1" total_kb target_kb pages old
        if ! [[ "$pct" =~ ^[0-9]+$ ]] || (( pct < 10 || pct > 90 )); then
            echo "El porcentaje tiene que ser un entero entre 10 y 90." >&2
            exit 1
        fi

        total_kb=$(mem_total_kb)
        target_kb=$(( total_kb * pct / 100 ))

        # Respect the OS floor no matter what was asked for.
        if (( total_kb - target_kb < MIN_OS_KB )); then
            target_kb=$(( total_kb - MIN_OS_KB ))
            if (( target_kb <= 0 )); then
                echo "Esta maquina no tiene RAM suficiente para reservar nada." >&2
                exit 1
            fi
            echo "Recortado: se dejan $(human $((MIN_OS_KB * 1024))) para el sistema."
        fi

        pages=$(( target_kb * 1024 / PAGE_SIZE ))
        echo "Objetivo: $(human $((pages * PAGE_SIZE))) de GTT ($pct% de la RAM)"

        local args=(kargs) changed=0 key
        # ttm.page_pool_size is the page cache pool; AMD's guidance is to keep
        # it matched to the limit.
        for key in ttm.pages_limit ttm.page_pool_size; do
            old=$(staged_value "$key")
            if [[ "$old" == "$pages" ]]; then
                continue
            elif [[ -n "$old" ]]; then
                args+=("--replace=$key=$old=$pages")
            else
                args+=("--append=$key=$pages")
            fi
            changed=1
        done

        if (( ! changed )); then
            echo "Ya estaba en ese valor. Nada que hacer."
            return 0
        fi

        log "staging ${args[*]:1}"
        sudo rpm-ostree "${args[@]}"
        echo
        echo "Preparado. Reinicia para que el kernel lo tome."
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

    case "{{ ACTION }}" in
        status) show_status ;;
        set)
            if [[ -z "{{ PERCENT }}" ]]; then
                echo "Falta el porcentaje: ujust yaguarete-vram set 70" >&2
                exit 1
            fi
            apply_percent "{{ PERCENT }}"
            ;;
        reset) reset_kargs ;;
        *)
            echo "Uso: ujust yaguarete-vram [status|set <10-90>|reset]" >&2
            exit 1
            ;;
    esac
