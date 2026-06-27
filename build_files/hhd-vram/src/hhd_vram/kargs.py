"""Read and write the GTT kernel arguments via rpm-ostree.

Backend is `rpm-ostree kargs` (verified: `bootc kargs` does not exist on the
target image). Writes are idempotent and edit in place -- never a blind
`--append`, which would stack duplicate `ttm.pages_limit=` entries every time
the slider is applied.
"""

import logging
import re
import subprocess

logger = logging.getLogger(__name__)

KARG = "ttm.pages_limit"
KARG_POOL = "ttm.page_pool_size"  # page cache pool; AMD recommends matching it

_CMDLINE_PAT = re.compile(rf"\b{re.escape(KARG)}=(\d+)")


def current_pages_limit() -> int | None:
    """Active ttm.pages_limit from /proc/cmdline. None means kernel default."""
    try:
        with open("/proc/cmdline") as f:
            m = _CMDLINE_PAT.search(f.read())
            return int(m.group(1)) if m else None
    except OSError:
        return None


def _read_kargs() -> str:
    return subprocess.check_output(["rpm-ostree", "kargs"], text=True)


def _value_of(kargs: str, key: str) -> str | None:
    m = re.search(rf"\b{re.escape(key)}=(\d+)", kargs)
    return m.group(1) if m else None


def apply_pages_limit(pages: int) -> bool:
    """Set ttm.pages_limit and ttm.page_pool_size to `pages` (staged for reboot).

    Returns True if a karg change was staged, False if already at target.
    Raises RuntimeError if rpm-ostree is unavailable or fails.
    """
    try:
        kargs = _read_kargs()
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        raise RuntimeError(f"cannot read rpm-ostree kargs: {e}") from e

    target = str(pages)
    args = ["rpm-ostree", "kargs"]
    for key in (KARG, KARG_POOL):
        old = _value_of(kargs, key)
        if old == target:
            continue
        if old is not None:
            args.append(f"--replace={key}={old}={target}")
        else:
            args.append(f"--append={key}={target}")

    if len(args) == 2:  # nothing to change
        return False

    logger.info(f"staging kargs: {args[2:]}")
    try:
        subprocess.run(args, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        raise RuntimeError(f"rpm-ostree kargs failed: {e}") from e
    return True
