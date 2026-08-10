#!/bin/bash
#
# Install the typography that YaguareteOS' own configs depend on but Fedora
# does not package. Runs inside the container build under `build.sh`.
#
# This script exists because of a bug, not a preference. build.sh used to
# state that JetBrainsMono Nerd Font came from Bazzite's nerd-fonts layer,
# and therefore shipped no mono font at all. Bazzite ships only the
# *Symbols* Nerd Font — the icon glyphs, no text family:
#
#     $ ls /usr/share/fonts/nerd-fonts/
#     SymbolsNerdFont-Regular.ttf  SymbolsNerdFontMono-Regular.ttf
#     $ fc-list | grep -i jetbrains
#     (nothing)
#
# Meanwhile /etc/xdg/kdeglobals, /etc/skel/.config/kdeglobals and the
# YaguareteOS Konsole profile all named JetBrainsMono Nerd Font, so
# fontconfig silently substituted whatever it preferred. Same class of bug
# as #245: a config naming an asset nobody installed.
#
# FiraCode Nerd Font replaces it (#254). The ligatures are the reason for
# the choice, and Powerlevel10k needs Nerd Font glyphs either way.
#
# Version + checksum are pinned. Bumping is a manual edit here followed by
# a `chore(fonts): bump nerd-fonts X -> Y` commit.

set -ouex pipefail

# ============================================================================
# FiraCode Nerd Font (ryanoasis/nerd-fonts)
#
# The .tar.xz and the .zip carry identical contents: 2.9 MB against 26 MB,
# and every byte lands in all four container variants.
#
# 18 faces ship — FiraCodeNerdFont / ...Mono / ...Propo, six weights each:
#   "FiraCode Nerd Font"      -> kitty. Its icon glyphs are double-width,
#                                which kitty renders correctly.
#   "FiraCode Nerd Font Mono" -> Konsole and the kdeglobals `fixed=` key.
#                                Strictly single-width; the non-Mono faces
#                                misalign columns in Konsole and Kate.
#
# Ligatures reach kitty only — Konsole is Qt and does not render them.
# ============================================================================
NERD_FONTS_VERSION="3.5.0"
FIRACODE_TAR_SHA256="32226dc81bb30ea421cdc49ba2134b93c2b43096992c829504a3004d2537420d"

firacode_tmp="/tmp/FiraCode.tar.xz"
firacode_dest="/usr/share/fonts/firacode-nerd-fonts"

curl -fsSL \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/FiraCode.tar.xz" \
    -o "$firacode_tmp"
echo "${FIRACODE_TAR_SHA256}  ${firacode_tmp}" | sha256sum --check --strict

mkdir -p "$firacode_dest"
# The archive is flat — no top-level directory — and carries LICENSE and
# README.md alongside the TTFs. Keep the licence, drop the readme.
tar -xJf "$firacode_tmp" -C "$firacode_dest" --no-same-owner
rm -f "$firacode_tmp" "${firacode_dest}/README.md"
chmod 0644 "${firacode_dest}"/*

# Warm whatever cache this environment keeps. Not load-bearing: /var/cache
# is a build cache mount, so nothing written here reaches the final image,
# and fontconfig regenerates per system and per user at runtime anyway.
fc-cache -f "$firacode_dest" || true

# Fail the build rather than ship the bug this script exists to fix: a
# family our configs name that the image does not contain.
#
# The instrument matters, and two obvious ones are wrong here.
#
#   fc-list : family | grep -qF "$family"       # DO NOT
#
# grep -q closes the pipe on its first match, fc-list dies of SIGPIPE, and
# `pipefail` (set above) turns that into 141 — reported missing 10 runs out
# of 10 on a machine where the font was installed.
#
#   fc-match -f '%{family}' "$family"           # DO NOT, not at build time
#
# fc-match answers from fontconfig's configuration and cache, not from the
# files. In this container the cache lives under the /var/cache mount, which
# is a build cache and therefore non-deterministic by design: the first run
# of this gate passed on base, deck and nvidia-open and returned 'Noto Sans'
# on nvidia, from identical inputs two seconds after the same fc-cache call.
# With an empty fontconfig config, fc-match returns nothing at all.
#
# fc-scan reads the font files themselves — no cache, no configuration. It
# answers the only question a build can honestly ask: did the archive land,
# and do these files declare the families our configs name? Whether
# fontconfig *resolves* them is a runtime question, and yg_has_font asks it
# there, where the cache belongs to a real system.
mapfile -t scanned_families < <(
    fc-scan --format '%{family}\n' "$firacode_dest" | tr ',' '\n' | sort -u
)

has_family() {
    local want="$1" found
    for found in "${scanned_families[@]}"; do
        [[ "$found" == "$want" ]] && return 0
    done
    return 1
}

for family in "FiraCode Nerd Font" "FiraCode Nerd Font Mono"; do
    if ! has_family "$family"; then
        echo "ERROR: '${family}' is not declared by any font in ${firacode_dest}." >&2
        echo "Families found: ${scanned_families[*]}" >&2
        exit 1
    fi
done
echo "Verified: FiraCode Nerd Font + Mono present in ${firacode_dest}"

unset family scanned_families
unset firacode_tmp firacode_dest
