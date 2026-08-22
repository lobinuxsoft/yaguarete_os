# YaguareteOS — rebase between our own channels.
#
# Why this exists instead of `brh rebase`:
#   bazzite-rollback-helper hardcodes the organisation. From /usr/bin/brh:
#
#       full_ref="ostree-image-signed:docker://ghcr.io/ublue-os/$DEFAULT_IMAGE:$target"
#
#   It reads the image *name* from image-info.json but not the vendor, so on
#   this image every rebase resolves to ghcr.io/ublue-os/yaguarete_os-*, which
#   does not exist. Both Portal rebase buttons pointed there.
#
#   It also hardcodes the `ostree-image-signed` prefix, while a machine
#   installed from our ISO is deployed as `ostree-unverified-registry`.
#   Switching prefix mid-rebase is a separate decision from switching channel,
#   so this keeps whichever one the booted deployment already uses.
#
# Everything needed is already in /usr/share/ublue-os/image-info.json:
# image-name, image-vendor and the full image-ref.

# Rebase to one of our channels (stable, testing, unstable) or an explicit tag.
yaguarete-rebase TARGET="stable":
    #!/usr/bin/bash
    set -euo pipefail

    INFO=/usr/share/ublue-os/image-info.json
    [[ -r "$INFO" ]] || { echo "Falta $INFO -- esta imagen no es nuestra."; exit 1; }

    name=$(jq -r '."image-name"' "$INFO")
    vendor=$(jq -r '."image-vendor"' "$INFO")
    [[ -n "$name" && "$name" != "null" ]] || { echo "image-name vacio en $INFO"; exit 1; }
    [[ -n "$vendor" && "$vendor" != "null" ]] || vendor=lobinuxsoft

    # Keep the verification mode the booted deployment already uses. Changing
    # signed <-> unverified is a different decision than changing channel.
    booted=$(rpm-ostree status --booted 2>/dev/null || true)
    if [[ "$booted" == *ostree-image-signed* ]]; then
        prefix="ostree-image-signed:docker://ghcr.io"
    else
        prefix="ostree-unverified-registry:ghcr.io"
    fi

    target="{{ TARGET }}"
    ref="$prefix/$vendor/$name:$target"

    echo "Imagen actual :"
    rpm-ostree status --booted 2>/dev/null | sed -n '2,4p'
    echo
    echo "Rebase a      : $ref"

    # Fail before touching the system if the tag is not published. A rebase to
    # a missing tag leaves a half-staged deployment and a confusing error.
    if command -v skopeo >/dev/null; then
        if ! skopeo inspect "docker://ghcr.io/$vendor/$name:$target" >/dev/null 2>&1; then
            echo
            echo "El tag '$target' no existe en ghcr.io/$vendor/$name."
            echo "Disponibles:"
            skopeo list-tags "docker://ghcr.io/$vendor/$name" 2>/dev/null \
                | jq -r '.Tags[]' | grep -E '^(stable|testing|unstable)$' | sed 's/^/  - /'
            exit 1
        fi
    fi

    echo
    read -r -p "Continuar? [s/N] " answer
    [[ "$answer" =~ ^[sSyY]$ ]] || { echo "Cancelado."; exit 0; }

    sudo rpm-ostree rebase "$ref"
    echo
    echo "Hecho. Reinicia para arrancar en '$target'."
    echo "Para volver:  ujust yaguarete-rebase stable"
