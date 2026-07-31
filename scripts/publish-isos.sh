#!/usr/bin/env bash
#
# Publish the stable ISOs of a release to archive.org, from a workstation.
#
# This used to live in generate_release.yml. archive.org throttles a
# multi-GB transfer from ~15 MiB/s down to ~1 MiB/s, which puts the four
# ISOs (~40 GB) at ~11 h — well past the 360-minute GitHub Actions job cap
# (#234). From a workstation the same upload sustains ~11 MB/s and can be
# watched, resumed and corrected.
#
# One variant at a time: download → upload → wait for archive.org to index
# → delete the local copy. Peak disk usage is one ISO (~14 GB), not four.
#
# Usage:
#   scripts/publish-isos.sh [options]
#
#   --run-id ID        build-iso run to publish (default: latest on testing)
#   --variants LIST    comma-separated subset, e.g. yaguarete_os-deck
#   --workdir DIR      scratch dir (default: /var/mnt/DATA/_yaguarete_iso)
#   --keep             do not delete the local ISO after a verified upload
#   --dry-run          resolve and verify everything, upload nothing
#
# Requires: gh (authenticated), ia (pip install internetarchive, configured
# with `ia configure`), jq, curl.

set -euo pipefail

readonly VARIANTS_ALL=(
  yaguarete_os
  yaguarete_os-nvidia
  yaguarete_os-nvidia-open
  yaguarete_os-deck
)

# Label that goes into the archive.org title/description/subject.
variant_label() {
  case "$1" in
    yaguarete_os) echo "desktop" ;;
    yaguarete_os-nvidia) echo "nvidia" ;;
    yaguarete_os-nvidia-open) echo "nvidia-open" ;;
    yaguarete_os-deck) echo "deck" ;;
    *) return 1 ;;
  esac
}

# Resolve which variant a filename belongs to, by LONGEST matching prefix.
#
# This is the fix for #233. The old workflow globbed `${variant}-*`, which
# for the base variant also matches `yaguarete_os-nvidia-*`, `-nvidia-open-*`
# and `-deck-*`; `find | head -1` then picked whichever the filesystem
# returned first. On 2026-07-30 that uploaded the 13 GB deck ISO into the
# base item. Longest-prefix wins is deterministic and unambiguous.
variant_of_name() {
  local name="$1" best=""
  local variant
  for variant in "${VARIANTS_ALL[@]}"; do
    if [[ "$name" == "${variant}-"* ]] && (( ${#variant} > ${#best} )); then
      best="$variant"
    fi
  done
  [ -n "$best" ] || return 1
  echo "$best"
}

log() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

RUN_ID=""
WORKDIR="/var/mnt/DATA/_yaguarete_iso"
KEEP=false
DRY_RUN=false
variants=("${VARIANTS_ALL[@]}")

while [ $# -gt 0 ]; do
  case "$1" in
    --run-id) RUN_ID="$2"; shift 2 ;;
    --variants) IFS=',' read -r -a variants <<< "$2"; shift 2 ;;
    --workdir) WORKDIR="$2"; shift 2 ;;
    --keep) KEEP=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

for tool in gh ia jq curl; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done

for variant in "${variants[@]}"; do
  variant_label "$variant" >/dev/null || die "unknown variant: $variant"
done

mkdir -p "$WORKDIR"
# `gh run download` stages the artifact zip in $TMPDIR before extracting.
# /tmp is a RAM-backed tmpfs on Bazzite and blows up at ~6 GB with "disk
# quota exceeded" regardless of what `df -h` claims.
export TMPDIR="$WORKDIR/.tmp"
mkdir -p "$TMPDIR"

if [ -z "$RUN_ID" ]; then
  RUN_ID=$(gh run list --workflow=build-iso.yml --branch=testing --limit 1 \
    --json databaseId --jq '.[0].databaseId // empty')
  [ -n "$RUN_ID" ] || die "no build-iso run found on testing"
fi
log "build-iso run: $RUN_ID"

# Map artifact name → variant, so each variant gets its own artifact and
# only its own. Artifacts are named "<variant>-<channel>-<version>-iso".
mapfile -t artifact_names < <(
  gh api "repos/{owner}/{repo}/actions/runs/${RUN_ID}/artifacts" \
    --jq '.artifacts[] | select(.expired == false) | .name'
)
[ ${#artifact_names[@]} -gt 0 ] || die "run $RUN_ID has no unexpired artifacts (retention is 2 days — rebuild)"

declare -A ARTIFACT_OF=()
for name in "${artifact_names[@]}"; do
  owner_variant=$(variant_of_name "$name") || continue
  ARTIFACT_OF["$owner_variant"]="$name"
done

# The canonical thumbnail already lives on archive.org — reuse it instead of
# re-rendering the SVG (local ImageMagick has no rsvg delegate and mangles
# the vector).
THUMB="$WORKDIR/__ia_thumb.png"
if [ ! -s "$THUMB" ]; then
  log "fetching canonical thumbnail"
  curl -fsSL -o "$THUMB" \
    "https://archive.org/download/yaguarete_os-nvidia-open-stable-44.20260515/___ia_thumb.png" \
    || die "could not fetch the canonical __ia_thumb.png"
fi

publish_variant() {
  local variant="$1"
  local label artifact dest iso iso_name iso_variant version identifier

  label=$(variant_label "$variant")
  artifact="${ARTIFACT_OF[$variant]:-}"
  if [ -z "$artifact" ]; then
    log "SKIP $variant — no artifact in run $RUN_ID"
    return 0
  fi

  dest="$WORKDIR/$artifact"
  if [ -z "$(ls -A "$dest"/*.iso 2>/dev/null || true)" ]; then
    if $DRY_RUN; then
      log "(dry-run) would download $artifact into $dest"
      return 0
    fi
    log "downloading $artifact"
    gh run download "$RUN_ID" --name "$artifact" --dir "$dest"
  else
    log "reusing already-downloaded $artifact"
  fi

  iso=$(ls "$dest"/*.iso | head -1)
  iso_name=$(basename "$iso")

  # Guard: never publish an ISO whose own filename disagrees with the item
  # it is going into. This is what silently failed in #233.
  iso_variant=$(variant_of_name "$iso_name") \
    || die "$iso_name does not belong to any known variant"
  [ "$iso_variant" = "$variant" ] \
    || die "refusing to upload $iso_name (variant $iso_variant) into the $variant item"

  # yaguarete_os[-VARIANT]-<channel>-<F>.<YYYYMMDD>-live-amd64.iso
  version=$(sed -E 's/.*-([0-9]+\.[0-9]{8})-live-.*/\1/' <<< "$iso_name")
  [[ "$version" =~ ^[0-9]+\.[0-9]{8}$ ]] || die "cannot parse a version out of $iso_name"
  identifier="${variant}-stable-${version}"

  log "$variant → https://archive.org/details/${identifier} ($(du -h "$iso" | cut -f1))"
  if $DRY_RUN; then
    log "(dry-run) would upload $iso_name"
    return 0
  fi

  cp -f "$THUMB" "$dest/__ia_thumb.png"
  local -a files=("$iso" "$dest/__ia_thumb.png")
  if [ -f "${iso}-CHECKSUM" ]; then files+=("${iso}-CHECKSUM"); fi
  if [ -f "${iso}.json" ]; then files+=("${iso}.json"); fi

  ia upload "$identifier" "${files[@]}" \
    --no-derive \
    --retries 5 \
    --metadata="title:YaguareteOS ${label} ${version}" \
    --metadata="creator:lobinuxsoft" \
    --metadata="description:YaguareteOS ${label} variant — stable release ${version}. Bootable ISO, offline installable. Source: https://github.com/lobinuxsoft/yaguarete_os" \
    --metadata="subject:linux;distro;bazzite;yaguarete;gaming;kde;${label}" \
    --metadata="licenseurl:https://www.apache.org/licenses/LICENSE-2.0" \
    --metadata="mediatype:software" \
    --metadata="collection:opensource" \
    || log "ia upload returned non-zero — verifying server-side before giving up"

  # `ia upload` exits 0 while archive.org is still running archive.php on
  # the item. A 13 GB ISO takes ~25 min to appear in the metadata API.
  # Deleting the local copy before that is how you lose an upload.
  log "waiting for archive.org to index $identifier"
  local waited=0
  until curl -fsSL "https://archive.org/metadata/${identifier}" 2>/dev/null \
      | jq -e --arg n "$iso_name" '(.files // []) | any(.name == $n)' >/dev/null; do
    (( waited += 60 ))
    [ "$waited" -le 3600 ] || die "$identifier not indexed after 60 min — check \`ia tasks $identifier\`"
    sleep 60
  done
  log "indexed after ~$((waited / 60)) min"

  if $KEEP; then
    log "keeping $dest (--keep)"
  else
    rm -rf "$dest"
    log "local copy deleted"
  fi
}

for variant in "${variants[@]}"; do
  publish_variant "$variant"
done

rmdir "$TMPDIR" 2>/dev/null || true
log "done. Update the download URLs in web/src/utils/i18n/{en,es}.ts and the README."
