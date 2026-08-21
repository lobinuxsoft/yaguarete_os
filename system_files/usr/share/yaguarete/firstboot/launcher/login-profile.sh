#!/bin/sh
# Per-user first-boot wire-up. Sourced from /etc/profile.d via the
# yaguarete-firstboot.sh bootstrap on every login shell, but acts only
# the first time: creates ~/.config/autostart/yaguarete-firstboot.desktop
# as a symlink to the system-wide launcher .desktop, so the graphical
# session picks it up via the standard XDG autostart pipeline.
#
# /etc/skel/ is unreliable on bootc/rpm-ostree (it does not seed users
# that already existed before the image-shipped skel landed), so the
# uBlue convention is profile.d + symlink-on-login. Yafti's run-once
# guard inside the wizard handles the "already seen" case — this script
# only worries about wiring the launcher into the user's autostart.

set -eu

target=/usr/share/yaguarete/firstboot/launcher/autostart.desktop
link="${HOME:-$(getent passwd "$(id -un)" | cut -d: -f6)}/.config/autostart/yaguarete-firstboot.desktop"

# Bail quietly when invoked in a non-interactive context with no usable
# HOME (e.g. cron, ssh ForceCommand, container build). Nothing to wire
# up there.
[ -n "${HOME:-}" ] || exit 0

# Bazzite 44 removed the `yafti` CLI and kept only the GTK front-end, so the
# check is against yafti_gtk.py now. Guarding on the old path made this exit 0
# on every login and the first-boot Portal never appeared at all.
#
# If the user has no Portal front-end (custom image variant, manual removal)
# do nothing rather than seed a broken autostart.
[ -x /usr/bin/yafti_gtk.py ] || exit 0
[ -r "$target" ] || exit 0

# Already wired (symlink present, even if dangling — we do not second-guess
# the user once they have touched it).
[ -L "$link" ] && exit 0
[ -e "$link" ] && exit 0

mkdir -p "$(dirname "$link")"
ln -s "$target" "$link"
