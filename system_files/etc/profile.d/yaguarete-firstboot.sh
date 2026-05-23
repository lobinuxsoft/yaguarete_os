# YaguareteOS first-boot autostart bootstrap. Sourced by /etc/profile in
# every login shell. The real logic lives at
# /usr/share/yaguarete/firstboot/launcher/login-profile.sh so it can be
# updated via image rebases without re-touching /etc/profile.d/.

[ -x /usr/share/yaguarete/firstboot/launcher/login-profile.sh ] || return 0
/usr/share/yaguarete/firstboot/launcher/login-profile.sh >/dev/null 2>&1 || true
