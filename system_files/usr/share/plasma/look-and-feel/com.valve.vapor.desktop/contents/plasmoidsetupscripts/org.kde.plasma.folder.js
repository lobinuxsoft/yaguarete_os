// OVERRIDE BY YAGUARETEOS — see issues #56, #68, #82
// Bazzite ships /usr/share/wallpapers/convergence.jxl as the vapor.desktop default.
// Point the first-login wallpaper at the W1 default (yaguarete-01) using the
// Plasma Wallpaper Package path — KDE resolves the highest-res image inside
// contents/images/ automatically (no need to hardcode WxH on this side).
// FillMode=2 → PreserveAspectCrop (Plasma label: 'Escalado y recortado'),
// matches the X-Plasma-DefaultFillMode in every yaguarete-* package.
applet.wallpaperPlugin = 'org.kde.image'
applet.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]
applet.writeConfig("Image", "/usr/share/wallpapers/yaguarete-01/")
applet.writeConfig("FillMode", "2")
applet.writeConfig("Color", "0,0,0")
applet.reloadConfig()
