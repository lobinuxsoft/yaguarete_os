# YaguareteOS — branded helper commands.
#
# Three user-facing CLI entry points that complement the per-app
# installers shipped at 85-yaguarete-install-*.just:
#
#   yaguarete-welcome          quick reference of every yaguareté command
#   yaguarete-install-gaming   Flatpak picker — gaming apps not in yafti
#   yaguarete-install-dev      Flatpak picker — dev apps not in yafti
#
# Closes #26.

# Banner text lives at /usr/share/yaguarete/welcome.txt so the recipe
# does not need to fight justfile's heredoc parsing limits.
#
# Print a YaguareteOS-branded quick reference. Idempotent, no args.
yaguarete-welcome:
    @cat /usr/share/yaguarete/welcome.txt

# Helper: ask y/N, install a Flatpak from Flathub at user level if accepted.
# Skips silently if the app id is already present.
_yaguarete-pick-flatpak app_id app_name app_desc:
    #!/usr/bin/bash
    set -euo pipefail
    if flatpak info --user "{{app_id}}" >/dev/null 2>&1; then
        echo "  ✓ {{app_name}} already installed — skipped."
        exit 0
    fi
    read -p "  Install {{app_name}} ({{app_desc}})? [y/N] " -n 1 -r
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        flatpak install --user -y --noninteractive flathub "{{app_id}}" \
            && echo "  ✓ {{app_name}} installed."
    fi

# Apps that complement Bazzite's built-in stack but are not
# pre-installed nor in yafti's "App Install" screen. Flathub, user-level.
#
# Gaming app picker. Heroic, Bottles, Lutris, ProtonUp-Qt, Goverlay.
yaguarete-install-gaming:
    #!/usr/bin/bash
    set -euo pipefail
    echo
    echo "Gaming app picker — Flatpak, user-level, no reboot."
    echo "(answer y to install, anything else to skip)"
    echo
    just _yaguarete-pick-flatpak com.heroicgameslauncher.hgl     "Heroic Games Launcher" "Epic + GOG + Amazon Prime native client"
    just _yaguarete-pick-flatpak com.usebottles.bottles          "Bottles"               "Wine prefix manager with templates and dependencies"
    just _yaguarete-pick-flatpak net.lutris.Lutris               "Lutris"                "Universal game launcher (Wine, native, emulators)"
    just _yaguarete-pick-flatpak net.davidotek.pupgui2           "ProtonUp-Qt"           "Manage Proton-GE / Wine-GE / Luxtorpeda versions"
    just _yaguarete-pick-flatpak io.github.benjamimgois.goverlay "Goverlay"              "MangoHud + vkBasalt graphical config tool"
    echo
    echo "Gaming picker done. Launch the apps from the KDE menu."

# Dev app picker. Daily-use tools the gaming-first base does not ship.
yaguarete-install-dev:
    #!/usr/bin/bash
    set -euo pipefail
    echo
    echo "Dev app picker — Flatpak, user-level, no reboot."
    echo "(answer y to install, anything else to skip)"
    echo
    just _yaguarete-pick-flatpak io.dbeaver.DBeaverCommunity     "DBeaver Community"     "Universal database GUI (PostgreSQL, MySQL, SQLite, ...)"
    just _yaguarete-pick-flatpak com.usebruno.Bruno              "Bruno"                 "Offline-first API client (MIT, no cloud sync required)"
    just _yaguarete-pick-flatpak io.kinvolk.Headlamp             "Headlamp"              "Kubernetes UI (CNCF, OpenLens-style)"
    just _yaguarete-pick-flatpak io.github.shiftey.Desktop       "GitHub Desktop"        "Community fork of the official Git GUI"
    just _yaguarete-pick-flatpak org.localsend.localsend_app     "LocalSend"             "Send files between devices on the same LAN"
    echo
    echo "Dev picker done. Launch the apps from the KDE menu."
