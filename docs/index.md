---
layout: default
title: YaguareteOS
description: Linux para gaming, desarrollo y privacidad. Identidad cultural argentina. Construida sobre Bazzite.
image: /assets/img/banner.png
---

<p align="center" class="hero-logo">
  <img src="assets/img/yaguarete-logo.svg" alt="YaguareteOS" width="220" />
</p>

# Linux para gamers, devs y gente que quiere su privacidad

YaguareteOS es una distribución Linux atómica construida sobre **[Bazzite](https://bazzite.gg/)** — gaming-ready out of the box, con Steam, Proton y los drivers que necesitás. Sumamos identidad argentina (naming guaraní, locale es-AR, theme propio) y un set de apps por defecto.

Tu sistema vive como una **imagen firmada**. Eso quiere decir actualizaciones atómicas (todo o nada), rollback con un comando si algo se rompe, y verificación criptográfica del build cada vez que se actualiza.

<p class="cta-row">
  <a class="btn-primary" href="#probala-ya">⬇️ Bajá la ISO</a>
  <a class="btn-secondary" href="#rebase-desde-otra-distro">↻ Rebase desde otra bootc</a>
  <a class="btn-secondary" href="https://github.com/lobinuxsoft/yaguarete_os">📦 Repo en GitHub</a>
</p>

---

## Probala ya

Hay **cuatro versiones** según tu hardware. Elegí la tuya, bajá la ISO, flasheala con [Ventoy](https://www.ventoy.net/) / [Rufus](https://rufus.ie/) / `dd`, y booteá. Live mode te deja probar sin tocar el disco.

<div class="variant-grid" markdown="0">

  <div class="variant-card">
    <div class="variant-icon">🖥️</div>
    <h3>Desktop AMD / Intel</h3>
    <p>Para PCs y laptops con tarjeta gráfica AMD o Intel. La opción por defecto si no sabés cuál elegir y tu GPU no es NVIDIA.</p>
    <a class="btn-download" href="https://github.com/lobinuxsoft/yaguarete_os/releases/download/rolling-unstable/yaguarete_os-rolling-unstable-amd64.iso">Descargar ISO</a>
    <details>
      <summary>Comando para rebase</summary>
      <pre><code>sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os:stable</code></pre>
    </details>
  </div>

  <div class="variant-card">
    <div class="variant-icon">🎮</div>
    <h3>Desktop NVIDIA</h3>
    <p>Tarjetas NVIDIA con driver propietario. La opción más segura si tu GPU es NVIDIA y no te interesa el módulo abierto.</p>
    <a class="btn-download" href="https://github.com/lobinuxsoft/yaguarete_os/releases/download/rolling-unstable/yaguarete_os-nvidia-rolling-unstable-amd64.iso">Descargar ISO</a>
    <details>
      <summary>Comando para rebase</summary>
      <pre><code>sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-nvidia:stable</code></pre>
    </details>
  </div>

  <div class="variant-card">
    <div class="variant-icon">🔓</div>
    <h3>Desktop NVIDIA (open)</h3>
    <p>NVIDIA con el módulo kernel abierto (mantenido por NVIDIA, no es nouveau). Recomendado para RTX 20xx o más nuevo.</p>
    <a class="btn-download" href="https://github.com/lobinuxsoft/yaguarete_os/releases/download/rolling-unstable/yaguarete_os-nvidia-open-rolling-unstable-amd64.iso">Descargar ISO</a>
    <details>
      <summary>Comando para rebase</summary>
      <pre><code>sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-nvidia-open:stable</code></pre>
    </details>
  </div>

  <div class="variant-card">
    <div class="variant-icon">🕹️</div>
    <h3>Handheld</h3>
    <p>Steam Deck, OneXFly, ROG Ally y compañía. Arranca directo en gamescope-session (modo juego), igual que SteamOS.</p>
    <a class="btn-download" href="https://github.com/lobinuxsoft/yaguarete_os/releases/download/rolling-unstable/yaguarete_os-deck-rolling-unstable-amd64.iso">Descargar ISO</a>
    <details>
      <summary>Comando para rebase</summary>
      <pre><code>sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-deck:stable</code></pre>
    </details>
  </div>

</div>

> **¿Qué es esto de "rolling-unstable"?** Las ISOs de arriba se reconstruyen automáticamente cuando hay cambios en el código. Son la versión más fresca, pero puede romperse. Cuando saquemos el primer release `:stable`, va a haber otra sección acá con ese link. Por ahora, asumí que es **versión de desarrollo**.

---

## Cómo se instala

1. **Bajás la ISO** del botón de arriba que corresponda a tu HW.
2. **La flasheás a un USB** con Ventoy (la mejor opción), Rufus o `dd`.
3. **Booteás del USB** (BIOS / UEFI menu, suele ser F12 / F11 / F2).
4. **Probás en live mode** sin instalar — el sistema corre desde la RAM.
5. **Si te gusta**, doble-click en "Instalar YaguareteOS" del escritorio y seguís el wizard.

Después del primer boot, el sistema se va a auto-actualizar cuando haya imagen nueva — vos podés ver el estado con `bootc status` y volver a la versión anterior con `bootc rollback`.

---

## Rebase desde otra distro

Si ya corrés Bazzite, Bluefin, Aurora o cualquier Fedora Atomic con `bootc`, podés cambiarte **sin reinstalar**. Cuatro pasos:

### 1. Verificá la firma cosign primero

```bash
VARIANT=yaguarete_os   # o -nvidia, -nvidia-open, -deck
cosign verify \
  --key https://raw.githubusercontent.com/lobinuxsoft/yaguarete_os/testing/cosign.pub \
  ghcr.io/lobinuxsoft/${VARIANT}:stable
```

Si la verificación falla, **parate**. No avances.

### 2. Switch

```bash
sudo bootc switch ghcr.io/lobinuxsoft/${VARIANT}:stable
```

El sistema actual sigue intacto en disco hasta que reinicies.

### 3. Reiniciá

```bash
sudo systemctl reboot
```

### 4. Confirmá

```bash
sudo bootc status
```

`Booted image` debe mostrar `ghcr.io/lobinuxsoft/${VARIANT}:stable`.

➡️ Detalles completos (rollback, pin-by-date, prerequisitos) en el [README del repo](https://github.com/lobinuxsoft/yaguarete_os/blob/unstable/README.md#rebase-from-an-existing-bootc-system).

---

## Lineage

YaguareteOS no oculta su origen.

```
Fedora Atomic (Kinoite)
   ↓ Universal Blue
   ↓ Bazzite
   ↓ YaguareteOS
```

Heredamos gaming stack, modelo bootc, firma y toolchain de [Universal Blue](https://universal-blue.org/). Sumamos rebranding, locale es-AR, theme negro+naranja, 15 apps default, signing key propio y 4 variants.

Sibling-fork precedent: [Bluefin](https://projectbluefin.io/) y [Aurora](https://getaurora.dev/) — derivan abiertamente. Mismo modelo.

---

## Qué es y qué *no* es

**Es:** una distro libre, KDE-only, optimizada para **dev + gaming + privacidad** con identidad cultural argentina (naming guaraní, español-first, locale es-AR, wallpapers nativos).

**No es:**

- Una plataforma estado-alineada. **No** ship certificados gubernamentales (ONTI), apps tied to state identity (AFIP, ANSES, Mi Argentina), billeteras estatales, mirrors hosted en infra del estado, ni compliance tooling que pida identificarte para usar el sistema.

La privacidad y la libertad están sobre la integración local. Si querés esas integraciones, el fork model existe para eso.

---

## Contribuir y reportar

- 🐛 [Issues](https://github.com/lobinuxsoft/yaguarete_os/issues)
- 💬 [Discusión](https://github.com/lobinuxsoft/yaguarete_os/discussions)
- 📚 [Cómo contribuir](https://github.com/lobinuxsoft/yaguarete_os/blob/unstable/CONTRIBUTING.md)
- 🔐 **Seguridad:** ver [`SECURITY.md`](https://github.com/lobinuxsoft/yaguarete_os/blob/unstable/SECURITY.md) — no abras issues públicos.

---

<sub>Yaguareté = jaguar en guaraní, felino emblema del Litoral argentino. Yryvu (jote) es el cliente Git hermano. Naming guaraní es identidad cultural; el proyecto no integra herramientas estatales.</sub>
