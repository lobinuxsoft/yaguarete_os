"""GTT ceiling control for AMD APUs, exposed in Game Mode through Decky.

The GTT pool is system RAM the GPU may map as graphics memory. Its ceiling is
the `ttm.pages_limit` kernel argument, one page being 4 KiB. On a unified-memory
APU the GTT lives in the same DDR banks as the firmware's UMA carveout and runs
at the same bandwidth, so this is the pool that moves without a firmware trip.

Same logic as `ujust yaguarete-vram`, reachable without leaving the game.
"""

import asyncio
import glob
import os
import re

import decky

PAGE_SIZE = 4096
# RAM always left to the OS: compositor, shader cache, gamescope. A 16 GiB
# device asked for 75% would leave 4 GiB and thrash itself.
MIN_OS_BYTES = 6 * 1024 * 1024 * 1024

_KARG_PAT = re.compile(r"\bttm\.pages_limit=(\d+)")


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


def _active_pages():
    with open("/proc/cmdline") as f:
        m = _KARG_PAT.search(f.read())
    return int(m.group(1)) if m else None


async def _run(*args):
    proc = await asyncio.create_subprocess_exec(
        *args, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT
    )
    out, _ = await proc.communicate()
    return proc.returncode, out.decode(errors="replace")


async def _staged(key):
    """Value of `key` in the staged kargs, or None."""
    code, out = await _run("rpm-ostree", "kargs")
    if code != 0:
        return None
    m = re.search(rf"\b{re.escape(key)}=(\d+)", out)
    return int(m.group(1)) if m else None


class Plugin:
    async def _main(self):
        decky.logger.info("Yaguarete VRAM loaded")

    async def _unload(self):
        pass

    async def get_status(self):
        """Everything the panel needs, in one call."""
        gpu = _find_gpu()
        ram = _ram_bytes()
        active = _active_pages()
        staged = await _staged("ttm.pages_limit")

        return {
            "ram": ram,
            "gtt": _read_int(os.path.join(gpu, "mem_info_gtt_total")) if gpu else 0,
            "vram": _read_int(os.path.join(gpu, "mem_info_vram_total"))
            if gpu and os.path.exists(os.path.join(gpu, "mem_info_vram_total"))
            else 0,
            "active_pages": active or 0,
            "staged_pages": staged or 0,
            # A staged value that differs from the running one is the whole
            # reason this panel needs a "reboot pending" state.
            "pending": bool(staged and staged != active),
            "percent": round(active * PAGE_SIZE * 100 / ram) if active else 0,
            "floor": MIN_OS_BYTES,
            "has_gpu": bool(gpu),
        }

    async def set_percent(self, percent: int):
        """Stage `percent` of RAM as the GTT ceiling. Applied on next boot."""
        if not isinstance(percent, int) or not 10 <= percent <= 90:
            return {"ok": False, "message": "El porcentaje va entre 10 y 90."}

        ram = _ram_bytes()
        target = ram * percent // 100
        clamped = False
        if ram - target < MIN_OS_BYTES:
            target = ram - MIN_OS_BYTES
            clamped = True
        if target <= 0:
            return {"ok": False, "message": "No hay RAM suficiente para reservar nada."}

        pages = target // PAGE_SIZE
        args = ["rpm-ostree", "kargs"]
        # ttm.page_pool_size is the page cache pool; AMD's guidance is to keep
        # it matched to the limit.
        for key in ("ttm.pages_limit", "ttm.page_pool_size"):
            old = await _staged(key)
            if old == pages:
                continue
            # Never a blind --append: it stacks duplicates and the kernel
            # honours the last one on the line, so the panel would stop
            # matching reality without saying so.
            args.append(f"--replace={key}={old}={pages}" if old else f"--append={key}={pages}")

        if len(args) == 2:
            return {"ok": True, "message": "Ya estaba en ese valor.", "pending": False}

        code, out = await _run(*args)
        if code != 0:
            decky.logger.error("rpm-ostree kargs failed: %s", out)
            return {"ok": False, "message": f"rpm-ostree fallo: {out.strip()[:200]}"}

        gib = pages * PAGE_SIZE / (1024 ** 3)
        msg = f"{gib:.1f} GiB preparados. Reinicia para aplicar."
        if clamped:
            msg = f"Recortado a {gib:.1f} GiB para dejar 6 GiB al sistema. Reinicia."
        return {"ok": True, "message": msg, "pending": True}

    async def reset(self):
        """Drop our kargs and go back to the kernel default."""
        args = ["rpm-ostree", "kargs"]
        for key in ("ttm.pages_limit", "ttm.page_pool_size"):
            old = await _staged(key)
            if old:
                args.append(f"--delete={key}={old}")

        if len(args) == 2:
            return {"ok": True, "message": "Ya estaba en el default del kernel.", "pending": False}

        code, out = await _run(*args)
        if code != 0:
            return {"ok": False, "message": f"rpm-ostree fallo: {out.strip()[:200]}"}
        return {"ok": True, "message": "Sacado. Reinicia para volver al default.", "pending": True}
