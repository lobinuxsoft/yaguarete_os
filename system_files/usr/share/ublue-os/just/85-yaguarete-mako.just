# YaguareteOS — MAKO, Vulkan frame generation for Linux gaming.
#
# MAKO is the continuation of the two projects the Portal used to offer
# separately. Upstream states it plainly: "Decky LSFG-VK Experimental and
# LSFG-VK Experimental are now MAKO. This repository is their new home and
# continuation." So this recipe replaces both entries rather than joining them.
#
# Why a recipe instead of upstream's instructions:
#   Upstream asks the user to enable Decky's Developer Mode, download a ZIP by
#   hand and install it through "Developer > Install Plugin from Zip". That is
#   only needed for the GUI path -- a plugin is a directory under
#   ~/homebrew/plugins owned by root. Doing that here skips Developer Mode
#   entirely, and re-running this is also how you update.
#
# What this recipe deliberately does NOT do:
#   - It does not install the MAKO Renderer. The plugin has its own
#     "Install MAKO Renderer" button, which knows about Flatpak Steam layouts;
#     duplicating that logic here would mean maintaining a second copy of it.
#   - It cannot provide `Lossless.dll`. MAKO requires it from a licensed
#     Lossless Scaling installation and does not bundle, copy or modify it.
#     Without that purchase the plugin installs and does nothing useful.
#
# x86_64 only. Upstream ships no ARM64 renderer packages.

# Install, update or remove the MAKO frame generation plugin for Decky Loader.
yaguarete-mako ACTION="install":
    #!/usr/bin/bash
    set -euo pipefail

    ACTION="{{ ACTION }}"
    REPO=eugeniosegala/MAKO
    DEST="$HOME/homebrew/plugins/Mako"

    pause() {
        if [[ -t 0 ]]; then
            printf '\n'
            read -n 1 -s -r -p "Apreta una tecla para cerrar..."
            printf '\n'
        fi
    }

    installed_version() {
        [[ -r "$DEST/package.json" ]] || return 1
        python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("version","?"))' \
            "$DEST/package.json" 2>/dev/null || echo "?"
    }

    case "$ACTION" in
      status)
        if v=$(installed_version); then echo "instalado ($v)"; else echo "no instalado"; fi
        exit 0
        ;;

      remove)
        if [[ -d "$DEST" ]]; then
            sudo rm -rf "$DEST"
            systemctl is-active --quiet plugin_loader && sudo systemctl restart plugin_loader
            echo "MAKO sacado."
            echo "El renderer que haya instalado el plugin sigue en tu \$HOME;"
            echo "las opciones de lanzamiento con mako-run tambien hay que sacarlas a mano."
        else
            echo "No estaba instalado."
        fi
        pause
        exit 0
        ;;

      install|update) ;;
      *) echo "Uso: ujust yaguarete-mako [install|update|remove|status]" >&2; exit 1 ;;
    esac

    if [[ ! -d "$HOME/homebrew/plugins" ]]; then
        echo "Decky Loader no esta instalado."
        echo "Corré primero:  ujust yaguarete-setup-decky"
        pause
        exit 1
    fi

    echo "Buscando el ultimo release del plugin..."
    # Two components publish to the same repo with independent versions
    # (plugin-v* and render-v*), so filter rather than taking "latest".
    # Two components publish to the same repo with independent versions
    # (plugin-v* and render-v*), so filter rather than taking "latest".
    # Kept to one line on purpose: an unindented block inside a recipe body is
    # read as justfile syntax, not as shell.
    read -r tag url < <(curl -fsSL "https://api.github.com/repos/$REPO/releases" | jq -r '[.[] | select(.tag_name | startswith("plugin-v"))][0] as $r | "\($r.tag_name) \($r.assets[] | select(.name | endswith(".zip")) | .browser_download_url)"') || true
    if [[ -z "${tag:-}" || -z "${url:-}" || "$tag" == "null" ]]; then
        echo "No pude resolver el release. GitHub caido, o cambiaron el esquema de tags." >&2
        pause
        exit 1
    fi

    echo "Encontrado: $tag"

    # Verify the asset is really there before anything is removed. The upstream
    # Decky installer deletes first and asks later, which is how a failed
    # request leaves you without the version you already had (#yaguarete-setup-decky).
    if ! curl -fsSL -I -o /dev/null "$url"; then
        echo "La descarga no responde 200. No toco lo que ya tenes instalado." >&2
        pause
        exit 1
    fi

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    echo "Descargando $(basename "$url")..."
    curl -fSL --progress-bar -o "$tmp/mako.zip" "$url"
    unzip -q "$tmp/mako.zip" -d "$tmp/x"

    # The archive carries a single top-level `Mako/` directory. If upstream
    # ever changes that, fail loudly instead of installing an empty plugin.
    if [[ ! -r "$tmp/x/Mako/plugin.json" ]]; then
        echo "El ZIP no tiene Mako/plugin.json — cambio la estructura upstream." >&2
        pause
        exit 1
    fi

    old=$(installed_version || echo "ninguna")
    sudo rm -rf "$DEST"
    sudo cp -r "$tmp/x/Mako" "$DEST"
    sudo chown -R root:root "$DEST"

    if systemctl is-active --quiet plugin_loader; then
        echo "Reiniciando Decky..."
        sudo systemctl restart plugin_loader
    fi

    new=$(installed_version || echo "?")
    echo
    echo "MAKO $new instalado (antes: $old)."
    echo
    echo "Lo que falta, y no lo puedo hacer yo:"
    echo "  1. Tener Lossless Scaling comprado en Steam. MAKO necesita su"
    echo "     Lossless.dll y NO lo incluye. Sin eso, el plugin no sirve."
    echo "  2. En el plugin, apretar 'Install MAKO Renderer'."
    echo "  3. En las opciones de lanzamiento del juego, poner:"
    echo "       \$HOME/.local/bin/mako-run %command%"
    pause
