"""Memory introspection and GTT page-limit math.

The GTT (Graphics Translation Table) pool is system RAM the GPU may map as
graphics memory. Its cap is set by the `ttm.pages_limit` kernel argument, where
one page is 4 KiB. The kernel default is ~50% of RAM. On unified-memory APUs the
GTT lives in the same DDR banks as the UMA carveout, so widening it carries no
bandwidth penalty -- only an out-of-memory risk if the OS floor is not respected.
"""

import glob
import os

PAGE_SIZE = 4096  # bytes per page, fixed by ttm
DRM_GLOB = "/sys/class/drm/card*/device"

# Floor of RAM always left to the OS (compositor, shader cache, gamescope).
# A 16 GB device at 75% would leave 4 GB and thrash; keep at least this.
MIN_OS_KB = 6 * 1024 * 1024  # 6 GiB


def _read_int(path: str) -> int:
    with open(path) as f:
        return int(f.read().strip())


def find_amdgpu_device() -> str | None:
    """Return the sysfs `.../device` path of an AMD GPU exposing GTT info.

    Prefers a card whose driver is amdgpu; falls back to any card that reports
    a GTT pool.
    """
    fallback = None
    for dev in sorted(glob.glob(DRM_GLOB)):
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


def read_mem_total_kb() -> int:
    with open("/proc/meminfo") as f:
        for line in f:
            if line.startswith("MemTotal:"):
                return int(line.split()[1])
    raise RuntimeError("MemTotal not found in /proc/meminfo")


def read_gtt_total(device: str) -> int:
    """Effective GTT cap in bytes."""
    return _read_int(os.path.join(device, "mem_info_gtt_total"))


def read_vram_total(device: str) -> int:
    """UMA carveout (BIOS-reserved 'VRAM') in bytes. Immutable at runtime."""
    return _read_int(os.path.join(device, "mem_info_vram_total"))


def pages_for_percent(
    mem_total_kb: int, percent: int, min_os_kb: int = MIN_OS_KB
) -> int:
    """Pages for the requested % of RAM, clamped so the OS floor is preserved."""
    limit_kb = mem_total_kb * percent // 100
    limit_kb = min(limit_kb, mem_total_kb - min_os_kb)
    limit_kb = max(limit_kb, 0)
    return limit_kb * 1024 // PAGE_SIZE


def percent_for_pages(pages: int, mem_total_kb: int) -> int:
    """Inverse of pages_for_percent, rounded to the nearest percent."""
    limit_kb = pages * PAGE_SIZE // 1024
    return round(limit_kb * 100 / mem_total_kb)


def bytes_to_gib(n: int) -> float:
    return n / (1024**3)
