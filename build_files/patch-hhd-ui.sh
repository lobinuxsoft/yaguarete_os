#!/usr/bin/env bash
# Replace bazzite branding inside the hhd-ui Electron AppImage with
# yaguareté assets, WITHOUT forking upstream hhd-dev/hhd-ui.
#
# Why this script exists:
#   - hhd-ui is shipped as a Fedora Copr RPM that drops a single
#     117 MB Electron AppImage at /usr/bin/hhd-ui.
#   - Bazzite branding (logo SVG, color palette, scrollbar/background
#     hue-rotates) is baked into the AppImage's resources/app.asar:
#         - distro/bazzite.svg inline as a URL-encoded data: URL
#         - minified JS theme palettes (brand + gray scales)
#         - hue-rotate filter values per distro `case` block
#   - hhd-ui has no override mechanism, no plugin system and no CSS
#     injection seam. The asset bundle is the only seam.
#   - The user vetoed upstream PRs (see hhd-ui#20 / hhd#320 closed
#     2026-05-19) — local override is preferred.
#
# Approach:
#   1. Extract the AppImage to a temporary squashfs-root/.
#   2. Unpack resources/app.asar to a patchable directory using
#      @electron/asar (installed transiently via dnf-provided nodejs).
#   3. Apply patches:
#        - swap the inline bazzite distro SVG (path + gradient) for a
#          yaguareté-jaguar SVG (asset shipped at
#          /usr/share/yaguarete/hhd-ui-yaguarete-logo.svg).
#        - sed bazzite/Chakra-purple/Chakra-pink hex codes to orange
#          (`#FF4500` family) — these are unique-occurrence in the
#          minified bundle, so a global sed is collision-free.
#        - sed bazzite-case `hue-rotate(200deg|202deg|210deg)` to the
#          orange-producing equivalents (`320deg|315deg|338deg`).
#   4. Repack the asar, drop the extracted dir at /opt/hhd-ui-yaguarete/,
#      and replace /usr/bin/hhd-ui with a 51-byte wrapper script that
#      execs the dir's AppRun. Replacing the dir (instead of repacking
#      the AppImage with appimagetool) avoids a runtime-init bug that
#      appimagetool's repacked AppImages exhibit on this Electron build
#      (process launches but never paints a window — root cause not
#      fully diagnosed; the wrapper-script workaround is equivalent and
#      simpler).
#
# This script is intentionally non-fatal: if the hhd-ui binary is absent
# (some variants do not include it) or upstream restructures the bundle
# (filename hashes, asar paths), it logs a warning and exits 0 so the
# image build does not break for a missing-overlay feature.
#
# Reapplied on every yaguarete_os build, so each new hhd-ui RPM upgrade
# automatically gets the yaguareté override on next ISO build.

set -euo pipefail

HHD_UI_BIN="/usr/bin/hhd-ui"
YAGUARETE_SVG_ASSET="/usr/share/yaguarete/hhd-ui-yaguarete-logo.svg"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

log() { echo "[patch-hhd-ui] $*"; }

if [ ! -f "$HHD_UI_BIN" ]; then
    log "skip: $HHD_UI_BIN not present in this variant"
    exit 0
fi

if [ ! -f "$YAGUARETE_SVG_ASSET" ]; then
    log "ERROR: yaguareté asset missing at $YAGUARETE_SVG_ASSET — refusing to patch"
    exit 1
fi

# Detect whether the binary is already a wrapper from a previous build
if head -c 4 "$HHD_UI_BIN" | grep -q '^#!'; then
    log "skip: $HHD_UI_BIN is already a wrapper script (re-run from cache?)"
    exit 0
fi

log "installing transient build deps (nodejs + npm)"
dnf5 install -y --setopt=install_weak_deps=False nodejs npm

# bazzite-deck base image has /root as non-directory — redirect npm/npx
# scratch state to $WORK_DIR so it never touches /root.
export HOME="$WORK_DIR"
export NPM_CONFIG_CACHE="$WORK_DIR/.npm-cache"
export npm_config_cache="$WORK_DIR/.npm-cache"

cd "$WORK_DIR"

log "extracting AppImage"
cp "$HHD_UI_BIN" ./hhd-ui-orig
chmod +x ./hhd-ui-orig
./hhd-ui-orig --appimage-extract >/dev/null

log "extracting app.asar"
npx --yes @electron/asar extract squashfs-root/resources/app.asar app-extracted/

# Locate the minified JS bundle (filename hash changes per release).
JS_BUNDLE=$(find app-extracted/static/build/assets/ -maxdepth 1 -name 'index-*.js' | head -1)
if [ -z "$JS_BUNDLE" ]; then
    log "WARN: minified bundle not found, structure changed upstream — exiting 0"
    exit 0
fi
log "patching bundle: $JS_BUNDLE"

# Swap the inline bazzite distro SVG (URL-encoded data URL containing the
# 'paint0_linear_1016_105' gradient id) with a 600x600 yaguareté logo
# wrapped in a transform so the original 5453x5133 aspect ratio fits
# centered inside the square slot the UI expects.
python3 - "$YAGUARETE_SVG_ASSET" "$JS_BUNDLE" <<'PYEOF'
import re, sys, urllib.parse

svg_path, js_path = sys.argv[1], sys.argv[2]

with open(svg_path) as f:
    yag = f.read()
inner_match = re.search(r'<svg[^>]*>(.*)</svg>', yag, re.DOTALL)
if not inner_match:
    print("[patch-hhd-ui:py] WARN: yaguareté SVG could not be parsed, skipping inline swap")
    sys.exit(0)
inner = inner_match.group(1)
inner = re.sub(r'<title>[^<]*</title>', '', inner)
inner = re.sub(r'<desc>[^<]*</desc>', '', inner)

# Original viewBox of the shipped yaguareté logo (5453.44 x 5133.707).
scale = 600 / 5453.44
ty = (600 - 5133.707 * scale) / 2
new_svg = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">'
    f'<g transform="translate(0,{ty:.2f}) scale({scale:.5f})">{inner}</g></svg>'
)
encoded = "data:image/svg+xml," + urllib.parse.quote(new_svg, safe="")

with open(js_path) as f:
    js = f.read()

pat = re.compile(r'data:image/svg\+xml,[^"]*paint0_linear_1016_105[^"]*')
m = pat.search(js)
if not m:
    print("[patch-hhd-ui:py] WARN: bazzite inline SVG marker not found, skipping inline swap")
else:
    js = js.replace(m.group(), encoded)
    with open(js_path, 'w') as f:
        f.write(js)
    print(f"[patch-hhd-ui:py] swapped bazzite inline SVG ({len(m.group())} -> {len(encoded)} bytes)")
PYEOF

log "applying hex code replacements"
# Bazzite brand (theme.tsx: distroThemes.bazzite.brand) — UPPERCASE in source.
sed -i 's/3A18E7/F06429/g; s/816BF0/EF5514/g; s/5E42EB/E14D0F/g; s/EBE8FD/FDE8DE/g; s/2F13B9/8F270A/g; s/0C052E/300D03/g; s/170A5C/5F1A07/g' "$JS_BUNDLE"
# Bazzite gray (theme.tsx: distroThemes.bazzite.gray) — lowercase in source.
sed -i 's/ECE6FE/FDE8DE/g; s/C9BAFC/F06226/g; s/A68EFB/EF5514/g; s/8362F9/EF5514/g; s/4a25cf/742807/g; s/3e1fad/4f1b05/g; s/0e0b3c/030100/g' "$JS_BUNDLE"
# Chakra `purple` colorScheme palette — some components use it directly
# regardless of distro theme (e.g. bazzite-style scrollbar fallback).
sed -i 's/6d49b6/8F270A/g; s/805AD5/f06429/g; s/6B46C1/8F270A/g; s/553C9A/742807/g; s/44337A/5F1A07/g; s/322659/300D03/g' "$JS_BUNDLE"
sed -i 's/FAF5FF/FFF5F0/g; s/E9D8FD/FFEEE6/g; s/D6BCFA/FFD0BD/g; s/B794F4/FFAD8E/g; s/9F7AEA/FF8A5F/g' "$JS_BUNDLE"
# Chakra `pink` colorScheme palette — dark pinks read as violet on dark backgrounds.
sed -i 's/FFF5F7/FFF5F0/g; s/FED7E2/FFEEE6/g; s/FBB6CE/FFD0BD/g; s/F687B3/FFAD8E/g; s/ED64A6/FF8A5F/g; s/D53F8C/F06429/g; s/B83280/D9551A/g; s/97266D/8F270A/g; s/702459/742807/g; s/521B41/4F1B05/g' "$JS_BUNDLE"
# CobaltBlue and BlueViolet — used as gradient stops inside the bazzite distro SVG.
sed -i 's/%230047AB/%23F06429/g; s/#0047AB/#F06429/g; s/%238A2BE2/%23F06429/g; s/#8A2BE2/#F06429/g' "$JS_BUNDLE"
# Bazzite-case hue-rotate filter values that produce violet from the
# yellow HHD wordmark base (200/202/210 deg). Remap to the orange-
# producing rotations used by the blood_orange case (315/320/338 deg).
sed -i 's/hue-rotate(200deg)/hue-rotate(320deg)/g; s/hue-rotate(202deg)/hue-rotate(315deg)/g; s/hue-rotate(210deg)/hue-rotate(338deg)/g' "$JS_BUNDLE"

log "repacking asar"
npx --yes @electron/asar pack app-extracted/ squashfs-root/resources/app.asar

log "deploying extracted bundle to /opt/hhd-ui-yaguarete and replacing /usr/bin/hhd-ui with wrapper"
rm -rf /opt/hhd-ui-yaguarete
mv squashfs-root /opt/hhd-ui-yaguarete
chmod -R a+rX /opt/hhd-ui-yaguarete
rm -f "$HHD_UI_BIN"
cat > "$HHD_UI_BIN" <<'WRAPPER'
#!/bin/bash
exec /opt/hhd-ui-yaguarete/AppRun "$@"
WRAPPER
chmod +x "$HHD_UI_BIN"

log "removing transient build deps"
dnf5 remove -y nodejs npm
dnf5 clean all

log "done"
