# YaguareteOS recipe wrappers that re-expose Bazzite/upstream ujust
# commands under YaguareteOS-branded names. The originals are made
# private (underscore prefix) by build_files/build.sh so they don't
# clutter `ujust --list` with Bazzite-named entries.

# Enable a Bluefin-style CLI experience
yaguarete-cli ACTION="":
    @just _bazzite-cli {{ACTION}}

# Restore the upstream Breeze GTK4 theme
restore-yaguarete-breeze-gtk-theme:
    @just _restore-bazzite-breeze-gtk-theme

# Manage Decky YaguareteOS Buddy plugin. Options: status | install | uninstall
get-decky-yaguarete-buddy ACTION="":
    @just _get-decky-bazzite-buddy {{ACTION}}
