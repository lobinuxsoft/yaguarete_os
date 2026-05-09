// OVERRIDE BY YAGUARETEOS — see issue #56
// Bazzite ships /usr/share/wallpapers/convergence.jxl as the vapor.desktop default.
// YaguareteOS branding requires its own default wallpaper at first-login.
applet.wallpaperPlugin = 'org.kde.image'
applet.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]
applet.writeConfig("Image", "/usr/share/wallpapers/yaguarete-selva-oscura/contents/images/1536x1024.png")
applet.reloadConfig()
