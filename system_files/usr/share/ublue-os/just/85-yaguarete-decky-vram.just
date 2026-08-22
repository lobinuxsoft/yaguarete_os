# YaguareteOS — install the Yaguarete VRAM plugin into Decky Loader.
#
# Why a recipe and not a file in the image: Decky loads plugins from
# ~/homebrew/plugins, which is the user's home. An image cannot write there, so
# the plugin ships read-only under /usr/share/yaguarete/decky/ and this copies
# it across. Re-running it re-copies, which is also how you update it after an
# image update.
#
# The plugin is the same GTT logic as `ujust yaguarete-vram`, reachable from
# Game Mode instead of a terminal. Decky's backend runs as root
# (plugin_loader.service has User=root), which is why it can call
# `rpm-ostree kargs` at all -- the reason porting this to OpenGamepadUI was
# rejected in #269.

# Install, update or remove the Yaguarete VRAM plugin for Decky Loader.
yaguarete-decky-vram ACTION="install":
    #!/usr/bin/bash
    set -euo pipefail

    SRC=/usr/share/yaguarete/decky/YaguareteVram
    DEST="$HOME/homebrew/plugins/YaguareteVram"

    pause() {
        if [[ -t 0 ]]; then
            printf '\n'
            read -n 1 -s -r -p "Apreta una tecla para cerrar..."
            printf '\n'
        fi
    }

    case "{{ ACTION }}" in
      install)
        if [[ ! -d "$HOME/homebrew/plugins" ]]; then
            echo "Decky Loader no esta instalado."
            echo "Corré primero:  ujust yaguarete-setup-decky"
            pause
            exit 1
        fi
        [[ -d "$SRC" ]] || { echo "Falta $SRC en la imagen."; pause; exit 1; }

        echo "Copiando el plugin a $DEST ..."
        sudo rm -rf "$DEST"
        sudo cp -r "$SRC" "$DEST"
        # Decky runs plugins as root and expects them owned by root.
        sudo chown -R root:root "$DEST"

        # Restart so the loader picks it up. Without this the plugin only
        # appears after the next Steam restart, which reads as "it did not
        # install".
        if systemctl is-active --quiet plugin_loader; then
            echo "Reiniciando Decky..."
            sudo systemctl restart plugin_loader
        fi

        echo
        echo "Listo. Aparece en el menu de Decky (el enchufe) dentro del QAM."
        echo "Ojo: aplicar un valor prepara un karg; toma efecto al reiniciar."
        pause
        ;;

      remove)
        if [[ -d "$DEST" ]]; then
            sudo rm -rf "$DEST"
            systemctl is-active --quiet plugin_loader && sudo systemctl restart plugin_loader
            echo "Plugin sacado. Los kargs que hayas aplicado siguen puestos:"
            echo "para revertirlos, ujust yaguarete-vram reset"
        else
            echo "No estaba instalado."
        fi
        pause
        ;;

      status)
        if [[ -d "$DEST" ]]; then
            echo "instalado"
        else
            echo "no instalado"
        fi
        ;;

      *)
        echo "Uso: ujust yaguarete-decky-vram [install|remove|status]" >&2
        exit 1
        ;;
    esac
