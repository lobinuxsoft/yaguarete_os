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

Empty — populated as auditing progresses. Each entry: recipe, variant, symptom, upstream issue link (if any), downstream mitigation (override path or "wait upstream").
