# Upstream Bazzite issues observed during QA

Companion to `yafti-recipes-matrix.md`. Tracks recipes from the Bazzite base image that we observed misbehaving on YaguareteOS variants.

Policy: do **not** open PRs upstream without explicit user consent ([feedback_no_upstream_prs_without_consent]). Document the gap, link the upstream issue if one already exists, and apply a downstream override only if necessary.

## Confirmed renames (silent breakage source)

These upstream recipes changed name without a release note. Our wrappers must follow the rename or break silently. Re-check whenever a Bazzite rebase is pulled.

**Verified 2026-08-22 against Bazzite 44 on the F1 Pro** (`grep -rl '^<name>[ :]' /usr/share/ublue-os/just/`), not inferred from an issue body. Every rename below keeps its `ACTION=""` parameter and its verbs, so following it is a pure substitution.

| Old name | New name | Verified | Was the Portal calling it? |
|---|---|---|---|
| `global-fsr4` | `toggle-global-fsr4` | Sesión VI (2026-05-23) | wrapped in `yaguarete-fsr4`, PR #204 |
| `global-fsr4-rdna3` | `toggle-global-fsr4-rdna3` | Sesión VI (2026-05-23) | same PR |
| `toggle-ssh` | `ssh` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `enable-tailscale` | `tailscale` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `install-resilio-sync` | `resilio-sync` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `install-openrgb` | `openrgb` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `install-opentabletdriver` | `opentabletdriver` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `enable-automounting` | `automounting` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `enable-steamos-automount` | `steamos-automount` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `toggle-reisub` | `reisub` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `toggle-wol` | `wol` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `toggle-cec-sleep` | `cec-sleep` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `toggle-password-feedback` | `password-feedback` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `install-davinci` | `install-resolve` | ✅ 2026-08-22 | ❌ **dead — fixed here** |
| `toggle-cockpit` | `cockpit` | ✅ 2026-08-22 | ✅ already correct |
| `setup-waydroid` | `configure-waydroid` | ✅ 2026-08-22 | ✅ already correct |
| `install-emudeck` | `get-emudeck` | ✅ 2026-08-22 | ✅ already correct |
| `install-steamcmd` | `get-steamcmd` | ✅ 2026-08-22 | ✅ already correct |
| `setup-lsfg-vk` | `get-lsfg` | ✅ 2026-08-22 | ✅ already correct |
| `get-decky-framegen` | `get-framegen` | ✅ 2026-08-22 | not offered by the Portal |

### Removed outright, no replacement

| Recipe | Note |
|---|---|
| `toggle-iwd` | Gone from Bazzite 44. No `iwd`, `wifi` or equivalent recipe exists. The Portal entry was removed rather than repointed. |

### Why this table was not enough

The previous version of this table listed several of these renames with the mitigation "`yafti.yml` already uses new name". That was true for five of them and **false for `toggle-ssh`, `enable-tailscale` and `install-resilio-sync`**, which the Portal was still calling by the old name. Detected renames must be checked against `yafti.yml`, not assumed applied. The check is one command:

```bash
# every ujust the Portal calls, against every recipe the image has
grep -oE "ujust [a-z0-9-]+" system_files/usr/share/yafti/yafti.yml | sort -u
ujust --summary | tr ' ' '\n' | sort -u
```

## Broken recipes

| Recipe | File | Symptom | Upstream issue | Mitigation |
|---|---|---|---|---|
| `get-framegen` | `91-bazzite-decky.just` | `FILENAME="Decky.Framegen.zip"` (dot) but real asset is `Decky-Framegen.zip` (hyphen) since v0.15.5 at `xXJSONDeruloXx/Decky-Framegen`. Download 404s → `unzip` fails → recipe prints "installed successfully" anyway (`exit 0` lies). | not filed (no upstream PR without consent) | In-place `sed` patch in `build_files/build.sh` rewrites the FILENAME constant. No-op when upstream finally renames. |
