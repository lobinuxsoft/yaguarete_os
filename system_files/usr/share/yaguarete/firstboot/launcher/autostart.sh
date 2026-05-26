#!/bin/sh
# Launched by ~/.config/autostart/yaguarete-firstboot.desktop (a symlink to
# the .desktop next to this script, created by login-profile.sh on first
# graphical login).
#
# The redisplay guard lives inside yafti itself: when mode = run-once is set
# in /usr/share/yafti/yafti.yml, yafti returns silently if the state file
# at ~/.config/yafti/last-run already exists, so this autostart is safe to
# fire on every login — the wizard only opens once.
exec /usr/bin/yafti /usr/share/yafti/yafti.yml
