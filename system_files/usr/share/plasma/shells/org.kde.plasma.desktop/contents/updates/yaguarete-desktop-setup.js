// YaguareteOS desktop first-login setup.
//
// Plasma runs scripts under
//   /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/
// once per user session when the script id hasn't been recorded yet,
// then stores the id in ~/.config/plasma-org.kde.plasma.desktop-appletsrc
// so it does not re-apply on later logins. That makes it the right place
// to seed user defaults a first-run wizard would otherwise set manually.
//
// We use this seed for two things bazzite handles via different surfaces:
//
// 1. Wallpaper. Our override of the Vapor LookAndFeel folder.js (PR #119)
//    points the default wallpaper at /usr/share/wallpapers/yaguarete/yaguarete_01/
//    — but that setup script only fires when the LookAndFeel package is
//    explicitly applied, not on the first session a freshly-installed user
//    opens. On HW (OneXFly, see #164) the result was that new users booted
//    into the Vapor default wallpaper (Steam Deck Logo Default.jpg) instead
//    of our jungle. After validation (see #170) user prefers yaguarete_future_punk
//    (cyberpunk jaguar) over yaguarete_01 (jungle) as the seeded default.
//
// 2. Kickoff applet icon. Plasma defaults to start-here-kde.svg (the KDE
//    breeze logo) for the application launcher. We swap it to yaguarete-logo
//    here so the panel shows our brand from the first session, without
//    having to override start-here-kde across the whole breeze icon theme.
//
// Mirrors the bazzite-pins.js update-script pattern (we already use that
// same surface in installer/system_files/kde/.../yaguarete-pins.js for the
// live ISO panel pins).

const allDesktops = desktops();

for (let i = 0; i < allDesktops.length; ++i) {
    const desktop = allDesktops[i];

    // Wallpaper: yaguarete_future_punk (cyberpunk jaguar) via Plasma Wallpaper Package.
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "/usr/share/wallpapers/yaguarete/yaguarete_future_punk/");
    // FillMode=2 = PreserveAspectCrop (Plasma label "Escalado y recortado").
    desktop.writeConfig("FillMode", "2");
    desktop.writeConfig("Color", "0,0,0");
    desktop.reloadConfig();
}

const allPanels = panels();

for (let i = 0; i < allPanels.length; ++i) {
    const panel = allPanels[i];
    const widgets = panel.widgets();

    for (let j = 0; j < widgets.length; ++j) {
        const widget = widgets[j];

        if (widget.type === "org.kde.plasma.kickoff") {
            widget.currentConfigGroup = ["Configuration", "General"];
            // Only seed the icon if the user has not picked one yet —
            // respect their choice on later logins.
            const currentIcon = widget.readConfig("icon", "");
            if (!currentIcon || currentIcon.trim() === "") {
                widget.writeConfig("icon", "yaguarete-logo");
                widget.reloadConfig();
            }
        }
    }
}
