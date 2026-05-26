# Upstream Bazzite issues observed during QA

Companion to `yafti-recipes-matrix.md`. Tracks recipes from the Bazzite base image that we observed misbehaving on YaguareteOS variants.

Policy: do **not** open PRs upstream without explicit user consent ([feedback_no_upstream_prs_without_consent]). Document the gap, link the upstream issue if one already exists, and apply a downstream override only if necessary.

## Confirmed renames (silent breakage source)

These upstream recipes changed name in a recent Bazzite build without a release note. Our wrappers must follow the rename or break. Re-check this list whenever a Bazzite rebase is pulled.

| Old name | New name | Detected | Mitigation |
|---|---|---|---|
| `global-fsr4` | `toggle-global-fsr4` | Sesión VI (2026-05-23) | `yaguarete-fsr4` wrapper updated in PR #204. |
| `global-fsr4-rdna3` | `toggle-global-fsr4-rdna3` | Sesión VI (2026-05-23) | Same PR. |
| `toggle-cockpit` (per issue #202 body) | `cockpit` | TODO confirm | Not wrapped — `yafti.yml` already uses new name. |
| `toggle-ssh` (per issue #202 body) | `ssh` | TODO confirm | Same. |
| `toggle-tailscale` (per issue #202 body) | `tailscale` | TODO confirm | Same. |
| `setup-waydroid` (per issue #202 body) | `configure-waydroid` | TODO confirm | Same. |
| `install-emudeck` (per issue #202 body) | `get-emudeck` | TODO confirm | Same. |
| `install-steamcmd` (per issue #202 body) | `get-steamcmd` | TODO confirm | Same. |
| `install-resilio-sync` (per issue #202 body) | `resilio-sync` | TODO confirm | Same. |
| `setup-lsfg-vk` (per issue #202 body) | `get-lsfg` | TODO confirm | Same. |
| `get-decky-framegen` (per issue #202 body) | `get-framegen` | TODO confirm | Same. |

## Broken recipes

| Recipe | File | Symptom | Upstream issue | Mitigation |
|---|---|---|---|---|
| `get-framegen` | `91-bazzite-decky.just` | `FILENAME="Decky.Framegen.zip"` (dot) but real asset is `Decky-Framegen.zip` (hyphen) since v0.15.5 at `xXJSONDeruloXx/Decky-Framegen`. Download 404s → `unzip` fails → recipe prints "installed successfully" anyway (`exit 0` lies). | not filed (no upstream PR without consent) | In-place `sed` patch in `build_files/build.sh` rewrites the FILENAME constant. No-op when upstream finally renames. |
