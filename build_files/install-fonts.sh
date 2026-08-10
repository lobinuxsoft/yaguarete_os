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

fc-cache -f "$firacode_dest"

# Fail the build rather than ship the exact bug this script exists to fix:
# a family our configs name that the image does not actually resolve.
#
# fc-match always answers, so presence is not the question — whether the
# answer is the family we asked for is. Note what this must NOT be:
#
#     fc-list : family | grep -qF "$family"      # DO NOT
#
# grep -q closes the pipe on its first match, fc-list dies of SIGPIPE, and
# `pipefail` (set above) turns that into 141. Measured on a box where the
# font was installed: reported missing 10 times out of 10, which here would
# mean a build that can never go green.
for family in "FiraCode Nerd Font" "FiraCode Nerd Font Mono"; do
    matched=$(fc-match -f '%{family}' "$family")
    if [[ ",${matched}," != *",${family},"* ]]; then
        echo "ERROR: '${family}' does not resolve — fontconfig answered '${matched}'." >&2
        exit 1
    fi
done
unset family matched

unset firacode_tmp firacode_dest
