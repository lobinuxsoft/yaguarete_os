---
layout: default
title: YaguareteOS
description: Linux argentino para jugar, crear y trabajar tranquilo. Bajá la ISO y probala en tu PC, laptop o handheld.
image: /assets/img/banner.png
---

<p align="center" class="hero-logo">
  <img src="assets/img/yaguarete-logo.svg" alt="YaguareteOS" width="220" />
</p>

# YaguareteOS

> **Linux argentino para jugar, crear y trabajar tranquilo.**
> Bajá la ISO, pasala a un USB, booteala. Funciona en PC, laptop o handheld.

<p class="cta-row">
  <a class="btn-primary" href="#descargar">⬇️ Bajá la ISO</a>
  <a class="btn-secondary" href="#como-se-instala">📀 Cómo se instala</a>
</p>

---

## Descargar

Elegí tu versión según tu computadora. Si dudás, **arrancá con la primera**.

<blockquote class="status-callout">

📅 **Hoy:** Los botones llevan a la **última versión estable** publicada en GitHub Releases. Cada release oficial se preserva en [archive.org](https://archive.org/details/@matias_galarza_lobinuxsoft_) con su propia URL permanente — historial intacto, podés volver a versiones viejas cuando quieras.

</blockquote>

<div class="variant-grid" markdown="0">

  <div class="variant-card">
    <div class="variant-icon">🖥️</div>
    <h3>PC o laptop común</h3>
    <p>Si tu computadora tiene placa de video AMD o Intel — la mayoría de las PCs y notebooks de los últimos 10 años. Si no sabés cuál tenés, esta es la indicada.</p>
    <a class="btn-download" href="https://github.com/lobinuxsoft/yaguarete_os/releases/latest">Ver última versión</a>
    <details>
      <summary>¿Ya corrés Bazzite u otra distro bootc?</summary>
      <pre><code>sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os:stable</code></pre>
    </details>
  </div>

  <div class="variant-card">
    <div class="variant-icon">🎮</div>
    <h3>PC con placa NVIDIA</h3>
    <p>Si tu computadora tiene una placa NVIDIA (cualquier modelo de los últimos 15 años) — usa los drivers oficiales de NVIDIA.</p>
    <a class="btn-download" href="https://github.com/lobinuxsoft/yaguarete_os/releases/latest">Ver última versión</a>
    <details>
      <summary>¿Ya corrés Bazzite u otra distro bootc?</summary>
      <pre><code>sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-nvidia:stable</code></pre>
    </details>
  </div>

  <div class="variant-card">
    <div class="variant-icon">🔓</div>
    <h3>PC con NVIDIA moderna</h3>
    <p>Si tu placa NVIDIA es RTX 20xx o más nueva (Turing en adelante). Usa el driver abierto de NVIDIA — un poquito más nuevo, mismo rendimiento.</p>
    <a class="btn-download" href="https://github.com/lobinuxsoft/yaguarete_os/releases/latest">Ver última versión</a>
    <details>
      <summary>¿Ya corrés Bazzite u otra distro bootc?</summary>
      <pre><code>sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-nvidia-open:stable</code></pre>
    </details>
  </div>

  <div class="variant-card">
    <div class="variant-icon">🕹️</div>
    <h3>Consola portátil</h3>
    <p>Para Steam Deck, OneXFly, ROG Ally y similares. Arranca directo en modo juego, igual que SteamOS, pero con todas las apps de escritorio disponibles cuando las necesites.</p>
    <a class="btn-download" href="https://github.com/lobinuxsoft/yaguarete_os/releases/latest">Ver última versión</a>
    <details>
      <summary>¿Ya corrés Bazzite u otra distro bootc?</summary>
      <pre><code>sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-deck:stable</code></pre>
    </details>
  </div>

</div>

> 💡 **Sin estables aún:** El primer release oficial está saliendo del horno. Si llegás antes que aparezca, los botones de arriba te van a llevar a una página "No releases yet" — y en ese caso, los comandos del bloque colapsado en cada card te permiten rebasear al canal `:stable` (también listo cuando se prenda). Para los más impacientes: hay [builds rolling unstable en Actions](https://github.com/lobinuxsoft/yaguarete_os/actions/workflows/build-iso.yml?query=branch%3Aunstable+is%3Asuccess) (requiere login GitHub, retención 7 días).

---

## Cómo se instala

Cuatro pasos. No hace falta conocimiento técnico previo.

### 1. Bajá la ISO

Apretá el botón **Descargar ISO** de la versión que te corresponda. Vas a recibir un archivo `.iso` de unos 3 GB.

### 2. Pasala a un USB

Necesitás un pendrive de **mínimo 8 GB** (lo que tenga adentro se borra). La forma más fácil:

- **[Ventoy](https://www.ventoy.net/)** — instalalo al USB una vez, después copiás cualquier `.iso` ahí como si fuera un archivo común. Funciona en Windows, Mac y Linux. **Recomendado para principiantes.**
- **[Rufus](https://rufus.ie/)** (Windows) o **[balenaEtcher](https://etcher.balena.io/)** (cualquier sistema) son alternativas simples si no querés usar Ventoy.

### 3. Booteá del USB

Reiniciá la computadora con el USB conectado. Al prender, apretá la tecla del menú de booteo — suele ser **F12, F11, F10, F2 o Esc** según la marca. Elegí el USB de la lista.

### 4. Probá y/o instalá

Vas a entrar en **modo live** — el sistema corre desde el USB sin tocar tu disco. Podés navegar, abrir programas, ver si te gusta.

Cuando estés listo, hacé doble click en **"Instalar YaguareteOS"** en el escritorio y seguí el asistente.

> 🔁 **Antes de instalar:** verificá que tu información importante está respaldada. El instalador te va a pedir borrar el disco — eso es definitivo.

---

## ¿Qué viene incluido?

Sin instalar nada extra, tu sistema arranca listo para:

- 🎮 **Jugar** — Steam con Proton (corre la mayoría de los juegos de Windows), Lutris, Heroic Launcher, gamescope, MangoHud.
- 🎨 **Crear** — GIMP (imágenes), Inkscape (vectorial), Krita, Blender (3D), OBS Studio (grabar/streamear).
- 💬 **Comunicarte** — Signal, Discord, Telegram preinstalados.
- 💼 **Trabajar** — OnlyOffice (compatible con MS Office), VSCodium (programar sin telemetría), Git con interfaz gráfica.
- 🌎 **Navegar** — Firefox, todo en español argentino por default.

Y se actualiza solo en segundo plano (con `bootc rollback` para volver atrás si algo se rompe).

---

## ¿Qué es YaguareteOS exactamente?

Es una distribución de **Linux argentina**, basada en [Bazzite](https://bazzite.gg/) (proyecto open source orientado a gaming). Le agregamos:

- Nombre en guaraní (Yaguareté = jaguar), idioma español argentino, locale `es-AR`, wallpapers con fauna local.
- Set de programas curado para uso real, no genérico.
- Tema visual propio (negro + naranja).

**Es libre y gratis.** Código abierto bajo licencia Apache 2.0. **No tiene telemetría, no espía, no requiere identificarte.**

**No es** una plataforma del estado argentino — el proyecto es independiente, sin integraciones con AFIP, ANSES, ONTI ni similares. Si querés esas integraciones, podés agregarlas vos mismo o hacer un fork.

---

## ¿Hay problemas? ¿Querés ayudar?

- 🐛 [Reportar un bug](https://github.com/lobinuxsoft/yaguarete_os/issues/new)
- 💬 [Discusión y dudas](https://github.com/lobinuxsoft/yaguarete_os/discussions)
- 📦 [Código fuente en GitHub](https://github.com/lobinuxsoft/yaguarete_os)
- 📚 [Guía para contribuir](https://github.com/lobinuxsoft/yaguarete_os/blob/unstable/CONTRIBUTING.md)

---

<sub>Yaguareté = jaguar en guaraní, felino emblema del Litoral argentino. Yryvu (jote, en guaraní) es el cliente Git hermano del ecosistema.</sub>
