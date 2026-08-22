// YaguareteOS: repoint the pinned terminal on the panel to kitty (#254).
//
// Deliberately a separate file from yaguarete-desktop-setup.js. Plasma
// records the id of every update script it has run, so appending this to
// the existing script would never fire on installs that already ran it.
// Renaming that file to force a re-run is worse: its wallpaper block writes
// unconditionally and would stomp the wallpaper of anyone who changed it.
// A new id runs exactly once, everywhere, and touches nothing else.
//
// kitty is the terminal this image configures, themes and ships a font for,
// and the one with inline image support. Konsole stays installed as the
// fallback -- this only changes which one the panel launches.

const KONSOLE = "applications:org.kde.konsole.desktop";
const KITTY = "applications:kitty.desktop";

const allPanels = panels();

for (let i = 0; i < allPanels.length; ++i) {
    const widgets = allPanels[i].widgets();

    for (let j = 0; j < widgets.length; ++j) {
        const widget = widgets[j];

        if (widget.type !== "org.kde.plasma.taskmanager" &&
            widget.type !== "org.kde.plasma.icontasks") {
            continue;
        }

        widget.currentConfigGroup = ["Configuration", "General"];
        const launchers = widget.readConfig("launchers", "");
        if (!launchers || launchers.indexOf(KONSOLE) === -1) {
            continue;
        }

        // Leave the rest of the list, and its order, exactly as it was.
        widget.writeConfig("launchers", launchers.split(KONSOLE).join(KITTY));
        widget.reloadConfig();
    }
}
