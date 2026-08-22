// YaguareteOS: fix the panel launchers -- kitty instead of Konsole, and drop
// the pinned Lutris icon.
//
// This replaces yaguarete-terminal-pin.js, which was inert. It read the config
// from ["Configuration", "General"], where `launchers` does not live. Verified
// against a running plasmashell:
//
//   ["General"]                  -> preferred://browser,...,konsole,...
//   ["Configuration","General"]  -> (empty)
//
// Reading empty made it hit its own `continue` and do nothing, and Plasma
// still recorded it in `performed=` -- so it could never run again. A silent
// no-op that reports success is the worst shape a shipped default can take.
//
// Hence the new filename: Plasma keys these scripts by path, so a machine that
// already recorded the broken one needs a new id to get the fix at all.
//
// kitty is the terminal this image configures, themes and ships a font for.
// Konsole stays installed as the fallback; only the panel launcher changes.

const KONSOLE = "applications:org.kde.konsole.desktop";
const KITTY = "applications:kitty.desktop";

// Pinned by the Bazzite base, not by us, and not part of this image's story.
const DROP = ["applications:net.lutris.Lutris.desktop"];

const allPanels = panels();

for (let i = 0; i < allPanels.length; ++i) {
    const widgets = allPanels[i].widgets();

    for (let j = 0; j < widgets.length; ++j) {
        const widget = widgets[j];

        if (widget.type !== "org.kde.plasma.taskmanager" &&
            widget.type !== "org.kde.plasma.icontasks") {
            continue;
        }

        widget.currentConfigGroup = ["General"];
        const before = widget.readConfig("launchers", "");
        if (!before) {
            continue;
        }

        // Order is the user's; only substitute and remove, never reorder.
        let items = before.split(",").filter(function (s) { return s.length; });
        items = items.map(function (s) { return s === KONSOLE ? KITTY : s; });
        items = items.filter(function (s) { return DROP.indexOf(s) === -1; });

        const after = items.join(",");
        if (after === before) {
            continue;
        }

        widget.writeConfig("launchers", after);
        widget.reloadConfig();
    }
}
