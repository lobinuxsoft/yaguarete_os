# YaguareteOS — landing source

Astro 6 + Tailwind 4 + GSAP + Lenis. Builds to <https://lobinuxsoft.github.io/yaguarete_os/>.

Forked from [ScrewFast](https://github.com/mearashadowfax/ScrewFast) (MIT). Brand colours, content, assets and copy are YaguareteOS.

## Local dev

Requires Node 20+ and `pnpm` (or `npm` / `yarn`, but the lockfile is pnpm).

```bash
cd web/
pnpm install
pnpm dev
```

Dev server runs at `http://localhost:4321/yaguarete_os/`.

## Build

```bash
pnpm build
```

Output to `web/dist/`. Includes `astro check` + post-process HTML minification.

## CI

`.github/workflows/pages.yml` builds + deploys on every push to `unstable` that touches `web/**`. Pages source is configured to **GitHub Actions** (not branch/folder).

## Migration note

The previous Jekyll/Cayman landing in `docs/` was replaced by this Astro app in #121. ADRs under `docs/adr/` stay where they are (read directly on GitHub).
