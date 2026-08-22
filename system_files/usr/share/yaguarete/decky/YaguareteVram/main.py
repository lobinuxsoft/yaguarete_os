"""Firmware VRAM control for AMD APUs, exposed in Game Mode through Decky.

The carveout is the fixed slice the firmware hands the iGPU, reported as VRAM.
amdgpu exposes it at `<card>/device/uma/carveout`; Decky runs this plugin as
root, so setting it is a plain write.

The panel reports the GTT pool but does not move it. Raising `ttm.pages_limit`
was the workaround for a carveout nobody could reach -- now that the carveout
itself moves, inflating GTT on top of it only competes for the same DDR. The
terminal keeps that knob (`ujust yaguarete-vram`) for anyone who still needs it.

Nothing here spawns a process: every value is a sysfs or procfs read, and the
one write is a sysfs write.
"""

import glob
import os
import re

import decky

def _read_int(path):
    with open(path) as f:
        return int(f.read().strip())


def _find_gpu():
    """sysfs path of an AMD GPU reporting a GTT pool, or None."""
    fallback = None
    for dev in sorted(glob.glob("/sys/class/drm/card*/device")):
        if not os.path.exists(os.path.join(dev, "mem_info_gtt_total")):
            continue
        if fallback is None:
            fallback = dev
        try:
            with open(os.path.join(dev, "uevent")) as f:
                if "DRIVER=amdgpu" in f.read():
                    return dev
        except OSError:
            continue
    return fallback


def _ram_bytes():
    with open("/proc/meminfo") as f:
        for line in f:
            if line.startswith("MemTotal:"):
                return int(line.split()[1]) * 1024
    raise RuntimeError("MemTotal missing from /proc/meminfo")


_OPTION_PAT = re.compile(r"^\s*(\d+)\s*:\s*(.*?)\s*\(([^)]*)\)\s*$")


def _uma_dir(gpu):
    """sysfs directory of the firmware carveout controls, or None.

    amdgpu only creates it when the platform answers the ACPI method, so its
    absence is the honest signal that this machine cannot move the carveout --
    not a reason to fall back to poking the firmware by hand (#267).
    """
    if not gpu:
        return None
    uma = os.path.join(gpu, "uma")
    return uma if os.path.exists(os.path.join(uma, "carveout")) else None


def _option_mib(size):
    """'512 MB' -> 512, '8 GB' -> 8192. Unparseable -> None."""
    m = re.search(r"\d+", size)
    if not m:
        return None
    n = int(m.group())
    return n if "m" in size.lower() else n * 1024


def _uma_options(uma):
    """The sizes the firmware accepts, in the order it lists them."""
    options = []
    with open(os.path.join(uma, "carveout_options")) as f:
        for line in f:
            m = _OPTION_PAT.match(line)
            if not m:
                continue
            index, word, size = int(m.group(1)), m.group(2), m.group(3)
            mib = _option_mib(size)
            if mib is None:
                continue
            # The firmware labels only three of them; the rest carry the size
            # alone, so the size is what the panel always shows.
            options.append({"index": index, "mib": mib,
                            "label": f"{size} ({word})" if word else size})
    return options


class Plugin:
    async def _main(self):
        decky.logger.info("Yaguarete VRAM loaded")

    async def _unload(self):
        pass

    async def get_status(self):
        """Everything the panel needs, in one call."""
        gpu = _find_gpu()
        uma = _uma_dir(gpu)
        options = _uma_options(uma) if uma else []
        current = _read_int(os.path.join(uma, "carveout")) if uma else -1
        selected = next((o for o in options if o["index"] == current), None)

        vram_path = os.path.join(gpu, "mem_info_vram_total") if gpu else ""
        vram = _read_int(vram_path) if vram_path and os.path.exists(vram_path) else 0

        return {
            "ram": _ram_bytes(),
            "gtt": _read_int(os.path.join(gpu, "mem_info_gtt_total")) if gpu else 0,
            "vram": vram,
            "has_gpu": bool(gpu),
            "uma_options": options,
            "uma_current": current,
            # A carveout that disagrees with the VRAM the driver reports is one
            # the firmware has not applied yet -- it only divides memory at
            # POST. That disagreement is the whole "reboot pending" state, and
            # it costs two reads instead of a subprocess.
            "pending": bool(selected and vram and selected["mib"] * 1024 ** 2 != vram),
            "pending_label": selected["label"] if selected else "",
        }

    async def set_carveout(self, index: int):
        """Ask the firmware for carveout option `index`. Applied on next boot.

        The kernel validates the index against what the platform offers, so a
        rejected write fails here with EINVAL instead of turning into a bad
        value that only shows up after a reboot.
        """
        decky.logger.info("set_carveout(%r) requested", index)
        uma = _uma_dir(_find_gpu())
        if not uma:
            return {"ok": False, "message": "Este equipo no expone el carveout."}

        options = {o["index"]: o for o in _uma_options(uma)}
        if index not in options:
            return {"ok": False, "message": "Esa opcion no la ofrece el firmware."}

        current = _read_int(os.path.join(uma, "carveout"))
        if index == current:
            decky.logger.info("set_carveout(%s): already current, nothing written", index)
            return {"ok": True, "message": "Ya estaba en ese valor.", "pending": False}

        try:
            with open(os.path.join(uma, "carveout"), "w") as f:
                f.write(str(index))
        except OSError as err:
            decky.logger.error("carveout write failed: %s", err)
            return {"ok": False, "message": f"El firmware rechazo el cambio: {err}"}

        decky.logger.info("set_carveout(%s): %s written", index, options[index]["label"])
        return {"ok": True,
                "message": f"{options[index]['label']} pedidos. Reinicia para aplicar.",
                "pending": True}
