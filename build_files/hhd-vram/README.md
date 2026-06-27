# hhd-vram

A [Handheld Daemon](https://github.com/hhd-dev/hhd) plugin that lets you allocate
a share of system RAM as GPU graphics memory (GTT) on AMD APUs, from a slider in
the HHD overlay — no BIOS trip, no manual kernel-argument editing.

## Why

On unified-memory APUs (Steam Deck, OneXFly, ROG Ally, Legion Go…) the
BIOS-reserved "VRAM" (UMA carveout) is small and immutable at runtime. The real
knob is the **GTT** pool — system RAM the GPU maps as graphics memory via the
`ttm.pages_limit` kernel argument. The kernel default is ~50% of RAM. Widening it
helps texture-heavy games and on-device LLM inference; because GTT lives in the
same DDR banks as the UMA carveout, there is no bandwidth penalty.

No handheld distro (Bazzite, ChimeraOS, SteamOS) exposes this as a percentage
control. This plugin does.

## How it works

- A slider sets the GTT share of RAM (25–90%, 75% recommended ceiling).
- An OS floor (6 GiB) is always reserved to prevent out-of-memory.
- "Apply and Reboot" stages `ttm.pages_limit` + `ttm.page_pool_size` via
  `rpm-ostree kargs` (idempotent, edits in place) and reboots.

## Install

```bash
pip install --user hhd-vram   # or bake into the image
systemctl restart hhd@$USER
```

The plugin is an external HHD plugin (entry point `hhd.plugins`); it does not
patch or fork HHD. Set `HHD_VRAM_DISABLE=1` to disable it.

## Requirements

- An AMD GPU exposing a GTT pool (`/sys/class/drm/card*/device/mem_info_gtt_total`).
- An `rpm-ostree`-based image (Fedora Atomic / bootc).

## License

MIT
