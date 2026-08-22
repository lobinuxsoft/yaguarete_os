// Yaguarete VRAM -- firmware VRAM control for AMD APUs, in Game Mode.
//
// One knob: the carveout the firmware hands the iGPU. The GTT pool is reported
// but not moved -- inflating it was the workaround for a carveout nobody could
// reach, and it competes for the same DDR once the carveout itself moves.
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
const { useState, useEffect, useCallback } = React;
const DFL = window.DFL;

const getStatus = callable("get_status");
const applyCarveout = callable("set_carveout");

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
  const [busy, setBusy] = useState(false);

  const refresh = useCallback(async () => {
    try {
      setStatus(await getStatus());
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
      h(DFL.PanelSectionRow, null, "No se encontro una GPU AMD.")
    );
  }

  const rows = [
    Row("RAM total", gib(status.ram)),
    Row("VRAM (firmware)", gib(status.vram)),
    Row("GTT (pool del kernel)", gib(status.gtt)),
  ];
  if (status.pending) {
    rows.push(Row("Pendiente", status.pending_label + " tras reiniciar", "#ffc107"));
  }

  // Steam's Dropdown is uncontrolled unless told otherwise: it seeds its value
  // in the constructor and then ignores the prop. Its menu is a context menu,
  // and opening one can take the Quick Access panel down with it, so anything
  // parked in React state between picking a size and confirming it is gone by
  // the time the panel comes back.
  //
  // Nothing is parked. `controlled` makes the widget a mirror of what the
  // device reports, and picking a size writes it -- the kernel is already the
  // thing holding the change until the next boot.
  const umaOptions = status.uma_options || [];
  const carveout = umaOptions.length
    ? h(
        DFL.PanelSection,
        { title: "VRAM de firmware" },
        h(
          DFL.PanelSectionRow,
          null,
          h(DFL.DropdownItem, {
            label: "Reservar",
            description: "Se aplica al reiniciar",
            menuLabel: "VRAM de firmware",
            rgOptions: umaOptions.map((o) => ({ data: o.index, label: o.label })),
            selectedOption: status.uma_current,
            controlled: true,
            disabled: busy,
            onChange: (o) => act(() => applyCarveout(o.data)),
          })
        )
      )
    : null;

  const info = h(
    DFL.PanelSection,
    { title: "Memoria" },
    h(DFL.PanelSectionRow, null, h("div", { style: { width: "100%" } }, rows))
  );

  return h(React.Fragment, null, carveout, info);
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
