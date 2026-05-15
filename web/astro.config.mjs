import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';
import mdx from '@astrojs/mdx';

// Astro config for the YaguareteOS landing page.
//
// Hosted at https://lobinuxsoft.github.io/yaguarete_os/ — GitHub Pages
// from a project repo, so `base` needs the repo name as a subpath.
// `trailingSlash: 'ignore'` keeps `/foo` and `/foo/` both working.
//
// The upstream ScrewFast template integrated `@astrojs/starlight` for a
// docs site and an English/French i18n setup. We strip both for now —
// landing is Spanish-only and docs live in the repo README + adr/. If
// we later need a hosted docs site, Starlight can be reintroduced as
// a separate route.
export default defineConfig({
  site: 'https://lobinuxsoft.github.io',
  base: '/yaguarete_os',
  // Spanish-first per the project README (es-AR locale defaults, Guaraní
  // naming). English is served as a secondary mirror under /en/.
  i18n: {
    locales: ['es', 'en'],
    defaultLocale: 'es',
    routing: { prefixDefaultLocale: false },
  },
  image: {
    // ScrewFast pulled hero images from unsplash. We use local assets
    // only, so the allowlist is empty. Add domains here if/when we
    // pull from a real CDN.
    domains: [],
  },
  prefetch: true,
  integrations: [sitemap(), mdx()],
  experimental: {
    clientPrerender: true,
  },
  vite: {
    plugins: [tailwindcss()],
  },
});
