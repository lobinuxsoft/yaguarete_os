"""TDP and CPU boost control for AMD APUs, exposed in Game Mode through Decky.

PowerStation is where TDP control belongs, and normally exposes it. On
Strix/Phoenix silicon it cannot: it links RyzenAdj statically, pinned to a
build from before Strix Point support existed, so the one backend that can
*write* a limit refuses to initialise (see ShadowBlip/PowerStation#41). The
slider in Steam's QAM shows a range and moving it does nothing.

This is a stopgap, not a replacement. `steamos-manager` is gaining a proper
extension point for exactly this ("RemoteInterface" -- an external daemon
registers itself in /usr/share/steamos-manager/remotes.d and Steam's own QAM
relays to it), which would put TDP control back where the user actually looks
for it. That mechanism is mid-rollout upstream as of 2026-08-23 -- the
currently installed steamos-manager build still hardcodes a "power_station"
method, the very next build removes it -- so building against it tonight would
mean building against a schema already scheduled to change. This plugin is
what we keep running in the meantime; see the tracking issue for the real fix.

TDP talks to the *system's* libryzenadj.so -- the one Bazzite already keeps
current -- through ctypes.

STAPM (the sustained limit) is set to exactly the requested value. slow/fast
are NOT derived from PowerStation's own formula (boost = live slow - live
stapm, slow = stapm + boost, fast = 1.25x slow) -- that shape was tried first
and, at this device's max_tdp, computed fast=50W: above PPT_LIMIT_APU=45W,
the SMU's own hard ceiling for this rail, measured live on the F1 Pro. Worse,
deriving the margin from a live read on every call means a value that failed
to settle before the next call feeds a bigger number into the one after it --
a feedback loop with no built-in limit, and repeated slider commits are
exactly what would trigger it.

So slow/fast use a fixed offset instead, taken from the same DMI-keyed
database (max_boost), and are only ever raised to the largest of "what is
already configured" and "what the new stapm needs to stay ordered under it" --
never derived by multiplying a value read back from the hardware. The one
external input is the requested watts; everything downstream of that is
arithmetic against constants from our own file, with a fixed ceiling
(max_tdp + max_boost) that cannot move no matter how many times this is
called or what the SMU reports back.

The min/max/boost range is not hardcoded here: it is read from the same
DMI-keyed database PowerStation itself ships
(/usr/share/powerstation/platform/*.toml), matched the same two-level way
PowerStation matches it (DMI product name, then CPU model). One source of
truth for "what TDP does this machine support" -- if that entry gets tuned,
this plugin and the eventual real fix agree without anyone updating two files.

CPU boost is a separate, unrelated knob: the kernel's own
/sys/devices/system/cpu/cpufreq/boost, plain sysfs I/O, no RyzenAdj and no SMU
involved. It works (or does not) independently of the TDP path above, so the
two are reported and set independently -- a machine that fails the TDP
database lookup can still get boost control, and vice versa.

Decky runs this plugin as root, same as YaguareteVram, which is what makes an
FFI call into a privileged library and a write to a root-owned sysfs file
possible without a helper.
"""

import ctypes
import tomllib
from pathlib import Path

import decky

_LIB_PATH = "/usr/lib64/libryzenadj.so"
_PLATFORM_DIR = Path("/usr/share/powerstation/platform")
_PLATFORM_FILES = ("amd_apu_database.toml", "intel_apu_database.toml", "dmi_overrides_apu_database.toml")
_BOOST_PATH = Path("/sys/devices/system/cpu/cpufreq/boost")


def _dmi(attr):
    try:
        return Path(f"/sys/class/dmi/id/{attr}").read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _cpu_model():
    try:
        with open("/proc/cpuinfo", encoding="utf-8") as f:
            for line in f:
                if line.startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return ""


def _hardware_limits():
    """(min_w, max_w, max_boost_w) for this machine, or None.

    Read from PowerStation's own databases. Later files win on a duplicate
    model_name, so dmi_overrides -- listed last -- overrides the generic
    AMD/Intel tables, mirroring PowerStation's own "DMI overrides > Intel >
    AMD" merge order. max_boost defaults to 0.0 when the entry does not carry
    one: no boost is safer than an assumed one on a device nobody tuned it for.
    """
    models = {}
    for name in _PLATFORM_FILES:
        path = _PLATFORM_DIR / name
        try:
            data = tomllib.loads(path.read_text(encoding="utf-8"))
        except (OSError, tomllib.TOMLDecodeError):
            continue
        for model in data.get("models", []):
            model_name = model.get("model_name")
            if model_name:
                models[model_name] = model

    for key in (_dmi("product_name"), _cpu_model()):
        model = models.get(key)
        if model and "min_tdp" in model and "max_tdp" in model:
            return float(model["min_tdp"]), float(model["max_tdp"]), float(model.get("max_boost", 0.0))
    return None


def _boost_state():
    """True/False, or None if this kernel does not expose the knob."""
    try:
        return _BOOST_PATH.read_text(encoding="utf-8").strip() == "1"
    except OSError:
        return None


class _RyzenAdj:
    """Thin ctypes wrapper. Raises on anything unexpected -- callers report it."""

    def __init__(self):
        lib = ctypes.CDLL(_LIB_PATH)

        lib.init_ryzenadj.restype = ctypes.c_void_p
        lib.init_ryzenadj.argtypes = []
        handle = lib.init_ryzenadj()
        if not handle:
            raise RuntimeError("init_ryzenadj devolvió NULL")

        for name in ("init_table", "refresh_table"):
            fn = getattr(lib, name)
            fn.restype = ctypes.c_int
            fn.argtypes = [ctypes.c_void_p]
            rc = fn(handle)
            if rc != 0:
                raise RuntimeError(f"{name} devolvió {rc}")

        for name in ("get_stapm_limit", "get_stapm_value", "get_slow_limit", "get_fast_limit"):
            fn = getattr(lib, name)
            fn.restype = ctypes.c_float
            fn.argtypes = [ctypes.c_void_p]

        for name in ("set_stapm_limit", "set_fast_limit", "set_slow_limit"):
            fn = getattr(lib, name)
            fn.restype = ctypes.c_int
            fn.argtypes = [ctypes.c_void_p, ctypes.c_uint32]

        self._lib, self._handle = lib, handle

    def refresh(self):
        self._lib.refresh_table(self._handle)

    def get(self, name):
        return getattr(self._lib, name)(self._handle)

    def set_watts(self, name, watts):
        rc = getattr(self._lib, name)(self._handle, int(watts * 1000))
        if rc != 0:
            raise RuntimeError(f"{name} devolvió {rc}")


class Plugin:
    def __init__(self):
        self._ry = None
        self._init_error = ""

    def _ryzenadj(self):
        if self._ry is None and not self._init_error:
            try:
                self._ry = _RyzenAdj()
            except (OSError, RuntimeError) as err:
                self._init_error = str(err)
        return self._ry

    async def _main(self):
        decky.logger.info("Yaguarete TDP loaded")

    async def _unload(self):
        pass

    async def get_status(self):
        """TDP and boost are unrelated capabilities -- report each on its own,
        so a machine missing one still gets the other."""
        result = {}

        boost = _boost_state()
        result["boost_supported"] = boost is not None
        if boost is not None:
            result["boost"] = boost

        limits = _hardware_limits()
        ry = self._ryzenadj()
        if not limits:
            result["tdp_supported"] = False
            result["tdp_message"] = "Este equipo no está en la base de datos de TDP."
        elif not ry:
            result["tdp_supported"] = False
            result["tdp_message"] = f"RyzenAdj no inicializó: {self._init_error}"
        else:
            ry.refresh()
            result["tdp_supported"] = True
            result["min_watts"] = limits[0]
            result["max_watts"] = limits[1]
            result["stapm_limit"] = ry.get("get_stapm_limit")
            result["stapm_value"] = ry.get("get_stapm_value")
            result["slow_limit"] = ry.get("get_slow_limit")
            result["fast_limit"] = ry.get("get_fast_limit")

        return result

    async def set_tdp(self, watts: float):
        """STAPM = requested watts, clamped to this device's range. slow/fast
        are only ever raised to keep stapm <= slow <= fast, and never past a
        fixed ceiling (max_tdp + max_boost) taken from our own database --
        never from a value read back off the chip. See the module docstring
        for why: that used to be a live-state feedback loop with no limiter.
        """
        limits = _hardware_limits()
        ry = self._ryzenadj()
        if not limits:
            return {"ok": False, "message": "Este equipo no está en la base de datos de TDP."}
        if not ry:
            return {"ok": False, "message": f"RyzenAdj no inicializó: {self._init_error}"}

        min_w, max_w, max_boost = limits
        watts = max(min_w, min(max_w, watts))
        ceiling = max_w + max_boost
        decky.logger.info("set_tdp(%.1f)", watts)

        try:
            ry.refresh()
            slow = min(max(watts, ry.get("get_slow_limit")), ceiling)
            fast = min(max(slow, ry.get("get_fast_limit")), ceiling)

            ry.set_watts("set_stapm_limit", watts)
            ry.set_watts("set_slow_limit", slow)
            ry.set_watts("set_fast_limit", fast)
        except RuntimeError as err:
            decky.logger.error("set_tdp failed: %s", err)
            return {"ok": False, "message": str(err)}

        return {"ok": True, "message": f"TDP en {watts:.0f} W", "watts": watts}

    async def set_boost(self, enabled: bool):
        if _boost_state() is None:
            return {"ok": False, "message": "Este kernel no expone cpufreq/boost."}

        decky.logger.info("set_boost(%r)", enabled)
        try:
            _BOOST_PATH.write_text("1" if enabled else "0", encoding="utf-8")
        except OSError as err:
            decky.logger.error("set_boost failed: %s", err)
            return {"ok": False, "message": f"No se pudo escribir cpufreq/boost: {err}"}

        return {"ok": True, "message": f"Boost {'activado' if enabled else 'desactivado'}", "enabled": enabled}
