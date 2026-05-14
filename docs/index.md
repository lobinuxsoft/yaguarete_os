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
  <a class="btn-primary" href="#probala-ya">↻ Rebase desde otra bootc</a>
  <a class="btn-secondary" href="https://github.com/lobinuxsoft/yaguarete_os">📦 Repo en GitHub</a>
  <a class="btn-secondary" href="https://github.com/lobinuxsoft/yaguarete_os/discussions">💬 Discusiones</a>
</p>

<blockquote class="status-callout">

📦 **Hoy:** YaguareteOS se instala vía `bootc switch` desde otro sistema bootc (Bazzite, Bluefin, Aurora, Fedora Atomic).
📀 **Pronto:** ISO instalable offline para cuando promovamos el primer `:stable` — la subimos a Internet Archive y aparece linkeada acá.

</blockquote>

---

## Probala ya

Si ya corrés un sistema bootc, podés cambiarte a YaguareteOS sin reinstalar. Elegí tu variant según el hardware y ejecutá el comando — el sistema actual queda intacto en disco hasta que reinicies.

<div class="variant-grid" markdown="0">

  <div class="variant-card">
    <div class="variant-icon">🖥️</div>
    <h3>Desktop AMD / Intel</h3>
    <p>Para PCs y laptops con tarjeta gráfica AMD o Intel. La opción por defecto si no sabés cuál elegir y tu GPU no es NVIDIA.</p>
    <pre><code>sudo bootc switch \
  ghcr.io/lobinuxsoft/yaguarete_os:unstable</code></pre>
  </div>

  <div class="variant-card">
    <div class="variant-icon">🎮</div>
    <h3>Desktop NVIDIA</h3>
    <p>Tarjetas NVIDIA con driver propietario. La opción más segura si tu GPU es NVIDIA y no te interesa el módulo abierto.</p>
    <pre><code>sudo bootc switch \
  ghcr.io/lobinuxsoft/yaguarete_os-nvidia:unstable</code></pre>
  </div>

  <div class="variant-card">
    <div class="variant-icon">🔓</div>
    <h3>Desktop NVIDIA (open)</h3>
    <p>NVIDIA con el módulo kernel abierto (mantenido por NVIDIA, no es nouveau). Recomendado para RTX 20xx o más nuevo.</p>
    <pre><code>sudo bootc switch \
  ghcr.io/lobinuxsoft/yaguarete_os-nvidia-open:unstable</code></pre>
  </div>

  <div class="variant-card">
    <div class="variant-icon">🕹️</div>
    <h3>Handheld</h3>
    <p>Steam Deck, OneXFly, ROG Ally y compañía. Arranca directo en gamescope-session (modo juego), igual que SteamOS.</p>
    <pre><code>sudo bootc switch \
  ghcr.io/lobinuxsoft/yaguarete_os-deck:unstable</code></pre>
  </div>

</div>

> Estás rebaseando a **`:unstable`** — la versión rolling de desarrollo. Cuando saquemos el primer `:stable` validado, los comandos van a apuntar a `:stable` por default. Mientras tanto, `bootc rollback` te lleva al sistema anterior con un comando si algo rompe.

---

## ¿No corro bootc todavía?

Si arrancás de cero (Windows / otra distro tradicional), necesitás **primero instalar un sistema bootc** y después rebasear a YaguareteOS. Las opciones recomendadas:

- **[Bazzite](https://bazzite.gg/)** — el upstream directo nuestro. Mismo stack gaming. Bajá su ISO, instalala, después rebaseá a YaguareteOS con uno de los comandos de arriba.
- **[Bluefin](https://projectbluefin.io/)** o **[Aurora](https://getaurora.dev/)** — sibling forks de Universal Blue (Bluefin = workstation dev, Aurora = KDE general).
- **Fedora Atomic Kinoite** directo — la base mínima.

Después del rebase: `bootc status` confirma la imagen activa, `bootc rollback` vuelve a la versión anterior, y `rpm-ostree upgrade` aplica las actualizaciones que llegan via cron diario del CI.

> 📀 **Cuando promovamos el primer `:stable`**, vamos a publicar una ISO instalable offline (sin necesidad de Bazzite previo) en Internet Archive. El link va a aparecer en esta página + en el Release de GitHub correspondiente. Hasta entonces, la ruta es bootc-encima-de-bootc.

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
