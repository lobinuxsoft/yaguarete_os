// Yaguarete VRAM -- GTT ceiling control for AMD APUs, in Game Mode.
//
// Hand-written on purpose, with no build step and no node_modules.
//
// A Decky plugin bundle does not embed the UI library: rollup externalises
// `@decky/ui` to the `DFL` global and React to `SP_REACT`, both injected by the
// loader, and `@decky/api` is a thin shim over the loader's own connect() call.
// Verified by reading a shipped plugin's dist/index.js on the device. Writing
// those three lines by hand costs a few lines and buys the whole npm dependency
// tree not existing in this repo -- no lockfile to audit, no postinstall hooks,
// no toolchain in the image build.

const manifest = {
  name: "Yaguarete VRAM",
  author: "lobinuxsoft",
  flags: ["root"],
  api_version: 1,
};

const API_VERSION = 2;

const loader =
  window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
if (!loader) {
  throw new Error("[yaguarete-vram] the Decky loader API was not initialised");
}

let api;
try {
  api = loader.connect(API_VERSION, manifest.name);
} catch {
  // Version 1 of the loader throws on mismatch instead of negotiating.
  api = loader.connect(1, manifest.name);
}

const callable = api.callable;
const toaster = api.toaster;

const React = window.SP_REACT;
const h = React.createElement;
const { useState, useEffect, useCallback, useRef } = React;
const DFL = window.DFL;

const getStatus = callable("get_status");
const applyPercent = callable("set_percent");
const resetKargs = callable("reset");

const GiB = 1024 * 1024 * 1024;
const gib = (bytes) => (bytes / GiB).toFixed(1) + " GiB";

function Row(label, value, accent) {
  return h(
    "div",
    {
      style: {
        display: "flex",
        justifyContent: "space-between",
        fontSize: "13px",
        padding: "2px 0",
        color: accent || undefined,
      },
    },
    h("span", null, label),
    h("span", { style: { fontWeight: "bold" } }, value)
  );
}

function Content() {
  const [status, setStatus] = useState(null);
  const [percent, setPercent] = useState(50);
  const [busy, setBusy] = useState(false);
  // The slider must not fight the user: only seed it from the device on the
  // first load, never on later refreshes.
  const seeded = useRef(false);

  const refresh = useCallback(async () => {
    try {
      const s = await getStatus();
      setStatus(s);
      if (!seeded.current && s && s.percent) {
        setPercent(s.percent);
        seeded.current = true;
      }
    } catch (e) {
      console.error("[yaguarete-vram]", e);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const act = async (fn) => {
    setBusy(true);
    try {
      const r = await fn();
      toaster.toast({ title: "Yaguarete VRAM", body: r.message });
    } catch (e) {
      toaster.toast({ title: "Yaguarete VRAM", body: String(e) });
    } finally {
      setBusy(false);
      refresh();
    }
  };

  if (!status) {
    return h(DFL.PanelSection, { title: "VRAM" }, h(DFL.PanelSectionRow, null, "Leyendo..."));
  }

  if (!status.has_gpu) {
    return h(
      DFL.PanelSection,
      { title: "VRAM" },
      h(DFL.PanelSectionRow, null, "No se encontro una GPU AMD con pool GTT.")
    );
  }

  const target = Math.round((status.ram * percent) / 100);
  const leftover = status.ram - target;
  const clamped = leftover < status.floor;

  const rows = [
    Row("RAM total", gib(status.ram)),
    Row("GTT actual", gib(status.gtt)),
  ];
  if (status.vram) rows.push(Row("VRAM (firmware)", gib(status.vram)));
  if (status.pending) {
    rows.push(
      Row(
        "Pendiente",
        gib(status.staged_pages * 4096) + " tras reiniciar",
        "#ffc107"
      )
    );
  }

  return h(
    DFL.PanelSection,
    { title: "Memoria grafica (GTT)" },
    h(DFL.PanelSectionRow, null, h("div", { style: { width: "100%" } }, rows)),

    h(
      DFL.PanelSectionRow,
      null,
      h(DFL.SliderField, {
        label: "Reservar",
        description: clamped
          ? "Se recorta para dejar 6 GiB al sistema"
          : gib(target) + " para la GPU, " + gib(leftover) + " para el sistema",
        value: percent,
        min: 10,
        max: 90,
        step: 5,
        notchTicksVisible: true,
        showValue: true,
        valueSuffix: "%",
        disabled: busy,
        onChange: setPercent,
      })
    ),

    h(
      DFL.PanelSectionRow,
      null,
      h(
        DFL.ButtonItem,
        {
          layout: "below",
          disabled: busy,
          onClick: () => act(() => applyPercent(percent)),
        },
        busy ? "Aplicando..." : "Aplicar y reiniciar despues"
      )
    ),

    h(
      DFL.PanelSectionRow,
      null,
      h(
        DFL.ButtonItem,
        { layout: "below", disabled: busy, onClick: () => act(() => resetKargs()) },
        "Volver al default del kernel"
      )
    )
  );
}

function Icon() {
  // Inline so the plugin carries no icon dependency either.
  return h(
    "svg",
    { width: "1em", height: "1em", viewBox: "0 0 24 24", fill: "currentColor" },
    h("path", {
      d: "M3 5h18a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1h-2v3h-2v-3H9v3H7v-3H3a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1zm1 2v7h16V7H4zm2 1h3v5H6V8zm5 0h3v5h-3V8z",
    })
  );
}

const definePlugin = (fn) => (...args) => fn(...args);

const index = definePlugin(() => ({
  name: "Yaguarete VRAM",
  title: h("div", { className: DFL.staticClasses && DFL.staticClasses.Title }, "Yaguarete VRAM"),
  content: h(Content, null),
  icon: h(Icon, null),
}));

export { index as default };
