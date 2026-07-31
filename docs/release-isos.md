# Publishing the stable ISOs

ISOs are published **manually, from a workstation**. `generate_release.yml`
creates the git tag and the GitHub Release and stops there.

## Why not from CI

archive.org throttles a long transfer: measured on run `30582309198`
(2026-07-30), ~15 MiB/s at the start, ~3 MiB/s after an hour, ~0.7 MiB/s at
the 1 h 45 m mark — 45 % of a single 13 GB ISO. Extrapolated across the four
variants (~40 GB) that is ~11 h against a GitHub Actions job cap of 360 min.
The run would have timed out mid-upload, leaving truncated ISOs that look
present. The same upload from the maintainer's workstation sustains ~11 MB/s.

See #234. The May 2026 release did upload from CI — archive.org simply
throttled less that day.

## Procedure

ISOs are optional per cycle. Installed devices update through `uupd`; an ISO
only matters for a fresh install. Most cycles skip this entirely.

### 1. Build the ISOs

```bash
gh workflow run build-iso.yml --ref testing -f channel=stable
```

`channel=stable` is what the installed system will track (#229). Takes
~37 min for four variants. **Artifacts expire after 2 days** — publish
promptly or rebuild.

### 2. Upload

```bash
scripts/publish-isos.sh                       # all four variants
scripts/publish-isos.sh --variants yaguarete_os-deck
scripts/publish-isos.sh --dry-run             # resolve + verify, upload nothing
```

The script works one variant at a time: download → upload → wait for
archive.org to index it → delete the local copy. Peak disk usage is one ISO,
not four. Expect ~20-40 min per variant plus indexing (~25 min for the 13 GB
deck ISO).

Requirements: `gh` authenticated, `ia` configured (`pip install
internetarchive && ia configure`), `jq`, `curl`.

Notes:

- The scratch dir defaults to `/var/mnt/DATA/_yaguarete_iso` and `TMPDIR` is
  pointed there. `/tmp` is a RAM-backed tmpfs on Bazzite and dies at ~6 GB
  with "disk quota exceeded" no matter what `df -h` says.
- Each variant resolves to its artifact by longest matching prefix, and an
  ISO whose filename disagrees with its target item aborts the run. The old
  workflow globbed `yaguarete_os-*` and uploaded the deck ISO into the base
  item (#233).
- The thumbnail is reused from an existing item, not re-rendered. Local
  ImageMagick has no rsvg delegate and mangles the vector.
- Every item ships ISO + `-CHECKSUM` + `.json` + `__ia_thumb.png`, with the
  full metadata set (title, creator, description, subject, license,
  mediatype, collection). Never a bare item.

### 3. Point the site at the new items

Identifiers are `yaguarete_os[-VARIANT]-stable-<F>.<YYYYMMDD>`, one per
release (deck carries `43.`, the rest `44.`). Update:

- `web/src/utils/i18n/en.ts` and `es.ts` — four download URLs each
- `README.md` — the archive.org paragraph

Verify each URL before committing:

```bash
curl -sI -r 0-1023 "https://archive.org/download/<identifier>/<iso>" | head -1
# expect: HTTP/1.1 206 Partial Content
```
