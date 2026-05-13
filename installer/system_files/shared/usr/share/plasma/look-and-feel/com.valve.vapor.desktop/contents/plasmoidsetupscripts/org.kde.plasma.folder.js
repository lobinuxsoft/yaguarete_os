// LIVE ISO OVERRIDE — applies on top of the container's vapor.desktop
// folder.js via installer/build.sh:32 (cp -a /src/system_files/shared/. /).
// Differentiates the live ISO desktop wallpaper (W4) from the installed
// system default (W1) so the smoke session feels distinct from a fresh
// install: live uses yaguarete_04, installed boots into yaguarete_01.
applet.wallpaperPlugin = 'org.kde.image'
applet.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]
applet.writeConfig("Image", "/usr/share/wallpapers/yaguarete/yaguarete_04/")
applet.writeConfig("FillMode", "2")
applet.writeConfig("Color", "0,0,0")
applet.reloadConfig()
