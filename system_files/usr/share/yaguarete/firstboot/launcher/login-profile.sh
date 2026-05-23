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

# If the user has no yafti binary (custom image variant, manual removal)
# do nothing rather than seed a broken autostart.
[ -x /usr/bin/yafti ] || exit 0
[ -r "$target" ] || exit 0

# Already wired (symlink present, even if dangling — we do not second-guess
# the user once they have touched it).
[ -L "$link" ] && exit 0
[ -e "$link" ] && exit 0

mkdir -p "$(dirname "$link")"
ln -s "$target" "$link"
