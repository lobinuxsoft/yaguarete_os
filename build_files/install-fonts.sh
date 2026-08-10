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

# Register the directory with fontconfig, then rebuild the cache for
# EVERY configured directory — deliberately without a path argument.
#
# `fc-cache -f "$firacode_dest"` was the first attempt and it shipped a
# font nobody could use. It builds a perfectly good cache for our own
# directory and leaves the cache for the PARENT, /usr/share/fonts,
# untouched — and the parent's cache is the thing that enumerates
# subdirectories. That parent cache comes from the base Bazzite image,
# from before our subdir existed.
#
# On a normal filesystem fontconfig would notice: it validates a
# directory cache against the directory's mtime. On ostree every mtime in
# the image is normalised to 0, so the parent looks unchanged forever, and
# /usr/lib/fontconfig/cache is read-only once deployed, so no amount of
# `fc-cache -f` on the running system can repair it.
#
# Observed on a real install of 44.20260810: 18 valid font files,
# fc-query read them happily, and fc-list/fc-match could not see a single
# one — fc-match answered 'Noto Sans'.
#
# Two independent fixes, because this class of bug is silent:
#   1. the conf.avail drop-in below names the directory outright, so the
#      parent's subdirectory listing stops mattering (this is the half
#      that was verified on hardware)
#   2. this full fc-cache regenerates the parent listing while /usr is
#      still writable, which is the actual root-cause repair
ln -sf ../../../usr/share/fontconfig/conf.avail/09-yaguarete-firacode-dir.conf \
    /etc/fonts/conf.d/09-yaguarete-firacode-dir.conf

fc-cache -f

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

# Second gate, added after 44.20260810 shipped 18 valid fonts that
# fontconfig could not see. fc-scan above proves the FILES are right; it
# cannot prove fontconfig will look in their directory, which is exactly
# the gap that bug fell through.
#
# This asks the configuration question: with the drop-in installed and the
# cache rebuilt, does fc-list report anything from our directory? That is a
# direct consequence of the <dir> element, not of a substitution chain, so
# unlike the fc-match attempt it should be deterministic. `grep -c` reads
# all of stdin, so there is no early-exit SIGPIPE to trip `pipefail` on.
#
# If this ever fails spuriously across variants, demote it to a warning
# rather than deleting it — but do not assume a green fc-scan means users
# can see the font. It does not.
listed=$(fc-list 2>/dev/null | grep -c "firacode-nerd-fonts" || true)
if [[ "${listed:-0}" -lt 1 ]]; then
    echo "ERROR: fontconfig lists 0 fonts from ${firacode_dest}." >&2
    echo "The files are installed and valid, but nothing will resolve them." >&2
    echo "Check /etc/fonts/conf.d/09-yaguarete-firacode-dir.conf and the" >&2
    echo "cache for the parent directory /usr/share/fonts." >&2
    exit 1
fi
echo "Verified: fontconfig lists ${listed} fonts from ${firacode_dest}"

unset family scanned_families listed
unset firacode_tmp firacode_dest
