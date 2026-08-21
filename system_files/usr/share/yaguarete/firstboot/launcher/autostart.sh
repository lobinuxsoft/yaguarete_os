#!/bin/sh
# Launched by ~/.config/autostart/yaguarete-firstboot.desktop (a symlink to
# the .desktop next to this script, created by login-profile.sh on first
# graphical login).
#
# Bazzite 44 dropped the `yafti` CLI and its Python module from the image and
# kept only the GTK front-end, /usr/bin/yafti_gtk.py, which is self-contained
# (stdlib + gi + yaml) and reads /usr/share/yafti/yafti.yml directly. Launching
# the old binary here left first boot silently doing nothing.
#
# The run-once guard used to live inside yafti: with `mode: run-once` it
# returned quietly once ~/.config/yafti/last-run existed. yafti_gtk.py ignores
# that guard by design — a manual launch from the Apps menu should always open
# — so the guard has to live here instead, or the wizard would greet the user
# on every single login.
#
# The marker is written before the window opens rather than after it closes:
# a wizard that reappears because someone dismissed it is worse than one that
# has to be reopened from the Apps menu.
set -eu

portal=/usr/bin/yafti_gtk.py
config=/usr/share/yafti/yafti.yml
state="${HOME:-}/.config/yafti/last-run"

[ -n "${HOME:-}" ] || exit 0
[ -x "$portal" ] || exit 0
[ -r "$config" ] || exit 0
[ -e "$state" ] && exit 0

mkdir -p "$(dirname "$state")"
: > "$state"

exec "$portal" "$config"
