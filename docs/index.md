---
layout: default
title: YaguareteOS
description: Distribución bootc Linux para gaming, desarrollo y privacidad. Identidad cultural argentina. Construida sobre Bazzite.
image: /assets/img/banner.png
---

<p align="center">
  <img src="assets/img/yaguarete-logo.svg" alt="YaguareteOS" width="180" />
</p>

# YaguareteOS

> Distribución bootc Linux para **gaming, desarrollo y privacidad**.
> Identidad cultural argentina (naming guaraní, locale es-AR).
> Construida sobre [Bazzite](https://bazzite.gg/) — atomic updates, signed images, four KDE variants.

[![Repo](https://img.shields.io/badge/GitHub-yaguarete__os-181717?logo=github)](https://github.com/lobinuxsoft/yaguarete_os)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://github.com/lobinuxsoft/yaguarete_os/blob/unstable/LICENSE)
[![Lineage](https://img.shields.io/badge/Built_on-Bazzite-orange.svg)](https://bazzite.gg/)

---

## ¿Qué variant elijo?

YaguareteOS ships **4 variants KDE**. Cada una hereda una base diferente de Bazzite y está afinada a un perfil de hardware:

| Tu HW | Variant a usar | Comando de rebase |
|---|---|---|
| 🖥️ **Desktop / laptop con AMD o Intel** | `yaguarete_os` | `sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os:stable` |
| 🎮 **Desktop con NVIDIA (driver propietario)** | `yaguarete_os-nvidia` | `sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-nvidia:stable` |
| 🔓 **Desktop con NVIDIA (kernel module abierto, Turing+)** | `yaguarete_os-nvidia-open` | `sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-nvidia-open:stable` |
| 🕹️ **Handheld** (Steam Deck, OneXFly, ROG Ally) | `yaguarete_os-deck` | `sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-deck:stable` |

**Reglas rápidas:**

- Si tu GPU es AMD o Intel → `yaguarete_os`. No hay variant alternativo.
- Si tu GPU es NVIDIA → elegí entre `-nvidia` (driver clásico, mayor compatibilidad) o `-nvidia-open` (kernel module abierto, recomendado en Turing/RTX 20xx o más nuevo). Si dudás, andá con `-nvidia`.
- Si es un handheld (gamescope-session, controles, sensores) → `-deck`. Hereda lockstep con Bazzite-Deck así que su Fedora major puede ir un paso atrás del desktop.
- **GNOME no es un variant**. YaguareteOS es KDE-only por decisión.

---

## Instalación rápida (rebase desde otra bootc system)

Si ya corrés Bazzite, Bluefin, Aurora o cualquier Fedora Atomic con `bootc`, podés cambiarte sin reinstalar. Cuatro pasos:

### 1. Verificá la firma cosign *antes* de switchear

Nunca apliques una imagen que no esté firmada. Reemplazá `<VARIANT>` por el tuyo de la tabla de arriba:

```bash
VARIANT=yaguarete_os
cosign verify \
  --key https://raw.githubusercontent.com/lobinuxsoft/yaguarete_os/testing/cosign.pub \
  ghcr.io/lobinuxsoft/${VARIANT}:stable
```

Si la verificación falla, **parate**. No hagas el switch.

### 2. Switch a YaguareteOS

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

`Booted image` debe mostrar `ghcr.io/lobinuxsoft/${VARIANT}:stable` con el digest verificado en el paso 1.

➡️ Detalles completos (rollback, prerequisitos, tag por fecha) en el [README del repo](https://github.com/lobinuxsoft/yaguarete_os/blob/unstable/README.md#rebase-from-an-existing-bootc-system).

---

## Canales

Cada variant publica tres tags en GHCR:

| Tag | Cuándo usarlo |
|---|---|
| `:stable` | **Recomendado.** Build validado promovido manualmente desde `testing`. Para uso diario. |
| `:testing` | Pre-release rolling. Pre-validation, opcional para early testers. |
| `:unstable` | Rolling tip de integración. Puede romperse — solo contribuidores. |
| `:<channel>-<fedora>.<YYYYMMDD>` | Pin a build específico (ej. `:stable-44.20260514`). |

El cron diario de CI espeja Bazzite stable: cuando upstream cambia, las 4 variants reconstruyen automáticamente.

---

## Lineage

YaguareteOS no oculta su origen. La cadena es:

```
Fedora Atomic (Kinoite)
   ↓ Universal Blue
   ↓ Bazzite
   ↓ YaguareteOS
```

Heredamos el stack gaming, el modelo bootc, las firmas y el toolchain de [Universal Blue](https://universal-blue.org/). Sumamos rebranding, locale es-AR, theme custom, apps default propias y signing key propio.

Sibling-fork precedent: [Bluefin](https://projectbluefin.io/) y [Aurora](https://getaurora.dev/) — atribuyen upstream abiertamente y agregan una capa propia. Mismo modelo.

---

## Scope: qué es y qué *no* es YaguareteOS

**Es:**

- Una distro libre, image-based, **KDE-only**, optimizada para dev + gaming.
- Identidad cultural argentina: naming guaraní (Yaguareté, Yryvu), Spanish-first UI, locale es-AR, wallpapers nativos.
- Defaults pro-privacidad. La variant `yaguarete_os-hardened` (en roadmap, [#25](https://github.com/lobinuxsoft/yaguarete_os/issues/25)) escala esto para usuarios sensibles.

**No es:**

- Una plataforma estado-alineada. **No** ship:
  - Certificados raíz gubernamentales (ONTI, etc.).
  - Apps tied to state identity / fiscal control / social registries (AFIP, ANSES, Mi Argentina, billetera estatal).
  - Mirrors hosted en infraestructura estatal como path canónico.
  - Compliance tooling que requiera identificarte para usar el sistema.

La privacidad y la libertad están sobre la integración local. Si necesitás esas integraciones, el fork model existe exactamente para eso.

---

## Contribuir y reportar

- 🐛 **Bugs:** [Issues](https://github.com/lobinuxsoft/yaguarete_os/issues)
- 💬 **Discusión:** [Discussions](https://github.com/lobinuxsoft/yaguarete_os/discussions)
- 📚 **Cómo contribuir:** [`CONTRIBUTING.md`](https://github.com/lobinuxsoft/yaguarete_os/blob/unstable/CONTRIBUTING.md)
- 🔐 **Vulnerabilidades de seguridad:** ver [`SECURITY.md`](https://github.com/lobinuxsoft/yaguarete_os/blob/unstable/SECURITY.md) — **no abrir issues públicos.**

---

<sub>Yaguareté = jaguar en guaraní. La distro lleva el nombre del felino emblema de la fauna del Litoral argentino. Yryvu (jote, en guaraní) es el cliente Git hermano que acompaña este ecosistema.</sub>
