"""hhd-vram: allocate system RAM as GPU graphics memory (GTT) on AMD APUs.

External Handheld Daemon plugin. Registered via the `hhd.plugins` entry point;
no fork of HHD required.
"""

import logging
import os
from typing import Sequence

from hhd.plugins import HHDPlugin

from .mem import find_amdgpu_device

logger = logging.getLogger(__name__)


def autodetect(existing: Sequence[HHDPlugin]) -> Sequence[HHDPlugin]:
    """Entry point. Activate only on AMD GPUs that expose a GTT pool."""
    if os.environ.get("HHD_VRAM_DISABLE"):
        return []
    if existing:
        return existing

    device = find_amdgpu_device()
    if not device:
        logger.info("No AMD GPU with GTT info found; hhd-vram disabled.")
        return []

    from .plugin import VramPlugin

    logger.info(f"hhd-vram active for device: {device}")
    return [VramPlugin(device)]
