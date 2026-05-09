// OVERRIDE BY YAGUARETEOS — see issues #56, #68
// Bazzite ships /usr/share/wallpapers/convergence.jxl as the vapor.desktop default.
// YaguareteOS branding requires its own default wallpaper at first-login + sane
// default fill behavior for any wallpaper the user picks afterwards.
applet.wallpaperPlugin = 'org.kde.image'
applet.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]
applet.writeConfig("Image", "/usr/share/wallpapers/yaguarete-selva-oscura/contents/images/1536x1024.png")
applet.writeConfig("FillMode", "1")
applet.writeConfig("Color", "0,0,0")
applet.reloadConfig()
