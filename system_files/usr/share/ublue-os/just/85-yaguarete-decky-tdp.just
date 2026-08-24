# YaguareteOS — install the Yaguarete TDP plugin into Decky Loader.
#
# Why this plugin exists: PowerStation is where TDP control belongs, and on
# most handhelds it works. On Strix/Phoenix APUs it does not -- it links
# RyzenAdj statically, pinned to a build from before Strix Point support
# existed, so the one backend that can write a limit refuses to initialise.
# The slider in Steam's QAM shows a range and moving it does nothing.
# Reported: https://github.com/ShadowBlip/PowerStation/issues/41
#
# This is a STOPGAP until that lands upstream. It talks to the system's own,
# current libryzenadj.so directly and reproduces PowerStation's own algorithm
# for STAPM/slow/fast, so the numbers behave the way a working PowerStation
# would have produced them. Remove it once #41 ships.
#
# Why a recipe and not a file in the image: same reason as yaguarete-vram --
# Decky loads plugins from ~/homebrew/plugins, which is the user's home, so
# the plugin ships read-only under /usr/share/yaguarete/decky/ and this copies
# it across. Decky's backend runs as root (plugin_loader.service has
# User=root), which is what lets it call into libryzenadj.so without a helper.

# Install, update or remove the Yaguarete TDP plugin for Decky Loader.
yaguarete-decky-tdp ACTION="install":
    #!/usr/bin/bash
    set -euo pipefail

    SRC=/usr/share/yaguarete/decky/YaguareteTdp
    DEST="$HOME/homebrew/plugins/YaguareteTdp"

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

        if systemctl is-active --quiet plugin_loader; then
            echo "Reiniciando Decky..."
            sudo systemctl restart plugin_loader
        fi

        echo
        echo "Listo. Aparece en el menu de Decky (el enchufe) dentro del QAM."
        echo "Si tu equipo no esta en la base de datos de TDP, el panel lo va a decir."
        pause
        ;;

      remove)
        if [[ -d "$DEST" ]]; then
            sudo rm -rf "$DEST"
            systemctl is-active --quiet plugin_loader && sudo systemctl restart plugin_loader
            echo "Plugin sacado."
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
        echo "Uso: ujust yaguarete-decky-tdp [install|remove|status]" >&2
        exit 1
        ;;
    esac
