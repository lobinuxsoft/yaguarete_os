# YaguareteOS Rescue: re-anchor bootc to the official YaguareteOS ref.
#
# Usá esto si accidentalmente hiciste `sudo bootc switch` a otra distro
# (Bazzite, Bluefin, Aurora, etc) y querés volver a YaguareteOS sin
# tener que reinstalar desde ISO.
#
# Uso:
#   ujust yaguarete-rescue            # → :stable (recomendado)
#   ujust yaguarete-rescue testing    # → :testing (pre-release)
#   ujust yaguarete-rescue unstable   # → :unstable (rolling, riesgoso)
#
# El comando detecta automáticamente la variant según el HW:
#   - handheld (Steam Deck / OneXFly / Ally / Legion Go / Aya Neo / GPD): deck
#   - GPU NVIDIA presente:                                                nvidia
#   - cualquier otro caso:                                                base (sin sufijo)

yaguarete-rescue ref="stable":
    #!/usr/bin/bash
    set -euo pipefail

    current=$(sudo bootc status --json 2>/dev/null | jq -r '.status.booted.image.image.image // ""')
    if [[ "$current" == *"lobinuxsoft/yaguarete_os"* ]]; then
        echo "✓ Ya estás en YaguareteOS: $current"
        echo "  Si querés actualizar, usá: sudo bootc upgrade"
        exit 0
    fi

    product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
    variant=""

    if echo "$product" | grep -qiE "jupiter|galileo|onex(fly|player)|onex.*player|ally|legion.go|claw|gpd.*win|aok.*zoe|aya.*neo|rog.*ally"; then
        variant="deck"
    elif lspci 2>/dev/null | grep -qiE "VGA.*NVIDIA|3D.*NVIDIA"; then
        variant="nvidia"
    fi

    suffix=""
    [[ -n "$variant" ]] && suffix="-$variant"
    target="ostree-image-signed:docker://ghcr.io/lobinuxsoft/yaguarete_os${suffix}:{{ref}}"

    echo "Hardware detectado: ${product:-desconocido}"
    echo "Variant:            ${variant:-base (sin sufijo)}"
    echo "Imagen objetivo:    $target"
    echo "Imagen actual:      ${current:-(no bootc, posible install legacy)}"
    echo
    read -rp "¿Continuar con el rescue switch? [y/N] " yn
    case "$yn" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Cancelado."; exit 1 ;;
    esac

    sudo bootc switch "$target"

    echo
    echo "✓ Switch staged. Reiniciá para aplicar:"
    echo "    sudo systemctl reboot"
