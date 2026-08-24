// Yaguarete TDP -- stopgap sustained-power and CPU boost control, in Game Mode.
//
// Why the TDP part exists: PowerStation links RyzenAdj statically, pinned to a
// build from before Strix Point support existed, so its slider in Steam's QAM
// shows a range and writing it does nothing (ShadowBlip/PowerStation#41). This
// talks to the system's own, current libryzenadj.so instead. It goes away the
// day PowerStation ships a RyzenAdj new enough for this hardware -- or the day
// steamos-manager's RemoteInterface mechanism lets us register as Steam's own
// TDP backend instead of a separate panel; see the tracking issue.
//
// CPU boost is unrelated and independently supported/reported: a plain kernel
// sysfs toggle, no RyzenAdj involved.
//
// Hand-written, no build step, no node_modules -- same reasoning as
// YaguareteVram's dist/index.js: @decky/ui is externalised to the DFL global
// and React to SP_REACT by the loader, verified by reading a shipped plugin's
// bundle on the device.

const manifest = {
  name: "Yaguarete TDP",
  author: "lobinuxsoft",
  flags: ["root"],
  api_version: 1,
};

const API_VERSION = 2;

const loader =
  window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
if (!loader) {
  throw new Error("[yaguarete-tdp] the Decky loader API was not initialised");
}

let api;
try {
  api = loader.connect(API_VERSION, manifest.name);
} catch {
  api = loader.connect(1, manifest.name);
}

const callable = api.callable;
const toaster = api.toaster;

const React = window.SP_REACT;
const h = React.createElement;
const { useState, useEffect, useCallback, useRef } = React;
const DFL = window.DFL;

const getStatus = callable("get_status");
const applyTdp = callable("set_tdp");
const applyBoost = callable("set_boost");

// The daemon is a shared resource: a slider firing on every pixel of drag
// would hammer the SMU with writes. Committing only after the pointer settles
// keeps this to one write per intended change.
const COMMIT_DEBOUNCE_MS = 400;

function TdpSection({ status, refresh }) {
  const [pending, setPending] = useState(null); // value shown while debouncing
  const [busy, setBusy] = useState(false);
  const timer = useRef(null);

  useEffect(() => () => clearTimeout(timer.current), []);

  if (!status.tdp_supported) {
    return h(
      DFL.PanelSection,
      { title: "TDP" },
      h(DFL.PanelSectionRow, null, status.tdp_message || "No disponible en este equipo.")
    );
  }

  const onChange = (watts) => {
    setPending(watts);
    clearTimeout(timer.current);
    timer.current = setTimeout(async () => {
      setBusy(true);
      try {
        const r = await applyTdp(watts);
        if (!r.ok) toaster.toast({ title: "Yaguarete TDP", body: r.message });
      } catch (e) {
        toaster.toast({ title: "Yaguarete TDP", body: String(e) });
      } finally {
        setBusy(false);
        setPending(null);
        refresh();
      }
    }, COMMIT_DEBOUNCE_MS);
  };

  const shown = pending !== null ? pending : Math.round(status.stapm_limit);

  return h(
    DFL.PanelSection,
    { title: "TDP" },
    h(
      DFL.PanelSectionRow,
      null,
      h(DFL.SliderField, {
        label: "Sostenido (STAPM)",
        description: busy ? "Aplicando..." : `Real ahora: ${status.stapm_value.toFixed(1)} W`,
        value: shown,
        min: Math.round(status.min_watts),
        max: Math.round(status.max_watts),
        step: 1,
        valueSuffix: " W",
        showValue: true,
        disabled: busy,
        onChange,
      })
    )
  );
}

function CpuSection({ status, refresh }) {
  const [busy, setBusy] = useState(false);

  if (!status.boost_supported) return null;

  const onChange = async (enabled) => {
    setBusy(true);
    try {
      const r = await applyBoost(enabled);
      if (!r.ok) toaster.toast({ title: "Yaguarete TDP", body: r.message });
    } catch (e) {
      toaster.toast({ title: "Yaguarete TDP", body: String(e) });
    } finally {
      setBusy(false);
      refresh();
    }
  };

  return h(
    DFL.PanelSection,
    { title: "CPU" },
    h(
      DFL.PanelSectionRow,
      null,
      h(DFL.ToggleField, {
        label: "Boost",
        description: "Turbo por núcleo (cpufreq/boost). Sube el pico, no el sostenido.",
        checked: status.boost,
        disabled: busy,
        onChange,
      })
    )
  );
}

function Content() {
  const [status, setStatus] = useState(null);

  const refresh = useCallback(async () => {
    try {
      setStatus(await getStatus());
    } catch (e) {
      console.error("[yaguarete-tdp]", e);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  if (!status) {
    return h(DFL.PanelSection, { title: "TDP" }, h(DFL.PanelSectionRow, null, "Leyendo..."));
  }

  return h(
    React.Fragment,
    null,
    h(TdpSection, { status, refresh }),
    h(CpuSection, { status, refresh })
  );
}

function Icon() {
  return h(
    "svg",
    { width: "1em", height: "1em", viewBox: "0 0 24 24", fill: "currentColor" },
    h("path", {
      d: "M13 2 3 14h7l-1 8 11-14h-7z",
    })
  );
}

const definePlugin = (fn) => (...args) => fn(...args);

const index = definePlugin(() => ({
  name: "Yaguarete TDP",
  title: h("div", { className: DFL.staticClasses && DFL.staticClasses.Title }, "Yaguarete TDP"),
  content: h(Content, null),
  icon: h(Icon, null),
}));

export { index as default };
