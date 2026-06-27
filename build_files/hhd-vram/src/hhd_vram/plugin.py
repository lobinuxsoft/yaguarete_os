"""The VRAM/GTT allocation plugin: a slider that maps a % of RAM as GPU memory."""

import logging
import subprocess

from hhd.plugins import Context, HHDPlugin, HHDSettings, load_relative_yaml
from hhd.plugins.conf import Config

from .kargs import apply_pages_limit, current_pages_limit
from .mem import (
    PAGE_SIZE,
    bytes_to_gib,
    pages_for_percent,
    percent_for_pages,
    read_gtt_total,
    read_mem_total_kb,
    read_vram_total,
)

logger = logging.getLogger(__name__)

# UI config paths (section.container.field). Co-located in the TDP tab next to
# the other GPU controls; merges with adjustor's "tdp" section when present.
ROOT = "tdp.vram"


class VramPlugin(HHDPlugin):
    def __init__(self, device: str) -> None:
        self.name = "hhd_vram"
        self.priority = 60
        self.log = "vram"
        self.device = device
        self.mem_total_kb = read_mem_total_kb()
        self.emit = None

    def open(self, emit, context: Context) -> None:
        self.emit = emit

    def settings(self) -> HHDSettings:
        sets = load_relative_yaml("settings.yml")
        # Seed the slider from the effective state so it opens on the live value.
        pages = current_pages_limit()
        if pages is None:  # no karg -> kernel default; derive from live GTT
            pages = read_gtt_total(self.device) // PAGE_SIZE
        sets["children"]["percent"]["default"] = percent_for_pages(
            pages, self.mem_total_kb
        )
        return {"tdp": {"vram": sets}}

    def update(self, conf: Config) -> None:
        total_gib = self.mem_total_kb * 1024 / (1024**3)
        conf[f"{ROOT}.info"] = (
            f"GTT {bytes_to_gib(read_gtt_total(self.device)):.1f} GiB"
            f" · UMA {bytes_to_gib(read_vram_total(self.device)):.1f} GiB"
            f" · RAM {total_gib:.1f} GiB"
        )

        percent = conf.get(f"{ROOT}.percent", None)
        if percent is None:
            return

        pages = pages_for_percent(self.mem_total_kb, int(percent))
        conf[f"{ROOT}.preview"] = (
            f"{bytes_to_gib(pages * PAGE_SIZE):.1f} GiB of {total_gib:.1f} GiB"
        )

        if not conf.get_action(f"{ROOT}.apply"):
            return

        try:
            changed = apply_pages_limit(pages)
        except Exception as e:
            logger.error(f"failed to apply GTT kargs: {e}")
            conf[f"{ROOT}.status"] = f"Error: {e}"
            return

        if not changed:
            conf[f"{ROOT}.status"] = "Already set."
            return

        logger.info(f"GTT kargs staged ({pages} pages); rebooting")
        conf[f"{ROOT}.status"] = "Applied. Rebooting..."
        subprocess.run(["reboot"])
