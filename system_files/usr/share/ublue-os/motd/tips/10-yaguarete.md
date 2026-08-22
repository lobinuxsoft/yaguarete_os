*This isn't a distro*, it is a custom image built on Fedora Atomic Desktop technology, on top of Bazzite~[View the project](https://github.com/lobinuxsoft/yaguarete_os)
It is **always** better to install software with Distrobox or Flatpak than to layer it with `rpm-ostree`. `ujust distrobox` makes it easy!
Packages installed in Distrobox can be exported to appear like any other application~[View documentation](https://distrobox.it/usage/distrobox-export/)
*Update break something?* You can roll back to the previous deployment from **Yaguareté Updater**, or with `bazzite-rollback-helper rollback`
*Using full disk encryption and tired of entering your password?* `ujust setup-luks-tpm-unlock` uses your CPU's TPM to unlock the device.
*Need a container?* `ujust distrobox-assemble` helps you assemble a new container image.
**H.264 hardware acceleration is supported out of the box.** No tweaks necessary!
The default terminal is **kitty**: it renders images inline (`kitten icat imagen.png`), ligatures, and true colour.
*Looking for apps?* **Yaguareté Portal** collects the recommended ones, already curated~ run `ujust yaguarete-portal`
BTRFS is used by default for internal drives, and it is also recommended for external drives including MicroSD cards. *NTFS and exFAT are not supported.*
*No Flatpak or distro packaging available?* Gear Lever is included to manage and integrate AppImages easily.
*Want to control your device from your phone?* KDE Connect works on every YaguareteOS image~[More info](https://kdeconnect.kde.org/)
*Need more control over your Flatpaks?* Warehouse and Flatseal are there to manage them.
