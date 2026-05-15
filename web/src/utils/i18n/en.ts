import type { Translations } from './types';

const en: Translations = {
  meta: {
    pageTitle: 'YaguareteOS — Sovereign bootc-based KDE for gaming and dev',
    ogTitle: 'YaguareteOS — Sovereign bootc-based KDE',
    description:
      'YaguareteOS is a bootable, image-based Linux distribution built on top of Bazzite (Universal Blue / Fedora Atomic). Gaming-ready, atomic, signed in our own CI, with Argentine cultural identity.',
  },
  announcement: {
    text: 'Phase 0 caveat — Argentine branding lands in Phase 1',
  },
  hero: {
    titlePrefix: 'Yaguarete',
    titleSuffix: 'OS',
    subTitle:
      'A bootable, image-based KDE distribution built on top of Bazzite (Universal Blue / Fedora Atomic). Gaming-ready, atomically updated, signed in our own CI.',
    primaryBtn: 'Get the latest release',
    secondaryBtn: 'Read the README',
    heroAlt:
      'Selva oscura — the dark Argentine jungle that gives YaguareteOS its visual identity',
  },
  variants: {
    title: 'Four KDE variants, one pipeline',
    subTitle:
      'Pick the variant that matches your hardware. All four are built from the same source tree and signed with the same cosign keypair. GNOME variants are intentionally not offered — this is a KDE-only project.',
    upstreamLabel: 'Upstream',
    rebaseLabel: 'Rebase',
    cosignNote:
      'Verify the image signature with cosign verify against cosign.pub before running bootc switch. Full instructions in the README.',
    cards: [
      {
        name: 'yaguarete_os',
        tag: 'AMD / Intel desktop',
        description:
          'Default variant. Picks the open-source graphics stack and works on most non-NVIDIA hardware.',
        upstream: 'bazzite:stable',
        rebase: 'sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os:stable',
      },
      {
        name: 'yaguarete_os-nvidia',
        tag: 'NVIDIA proprietary',
        description:
          'NVIDIA GPU with the proprietary driver. Recommended for gaming on NVIDIA hardware today.',
        upstream: 'bazzite-nvidia:stable',
        rebase:
          'sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-nvidia:stable',
      },
      {
        name: 'yaguarete_os-nvidia-open',
        tag: 'NVIDIA open kernel module',
        description:
          'NVIDIA GPU with the open kernel module (Turing+). Server / dev workstation oriented.',
        upstream: 'bazzite-nvidia-open:stable',
        rebase:
          'sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-nvidia-open:stable',
      },
      {
        name: 'yaguarete_os-deck',
        tag: 'Handheld (Steam Deck, OneXFly, ROG Ally)',
        description:
          'Boots into game mode by default. ISO build is still gated by issue #112; rebase from Bazzite-deck works today.',
        upstream: 'bazzite-deck:stable',
        rebase:
          'sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-deck:stable',
      },
    ],
  },
  sovereign: {
    title: 'What is sovereign',
    subTitle:
      'Digital sovereignty here means controlling the pipeline — signing keys, build infrastructure, distribution registry, project governance, branding — not hiding technical inheritance.',
    features: [
      {
        heading: 'Our build pipeline',
        content:
          'CI runners, build policies and release workflow live in this repo. No third-party builders, no opaque promotion steps.',
        svg: 'tools',
      },
      {
        heading: 'Our signing keypair',
        content:
          'cosign keypair under our control. Public key shipped in-tree; private key offline. Every published image is signed and verifiable.',
        svg: 'verified',
      },
      {
        heading: 'Our distribution registry',
        content:
          'Images published to ghcr.io/lobinuxsoft/yaguarete_os. Stable releases are mirrored as dated identifiers on archive.org for long-term preservation.',
        svg: 'rocket',
      },
      {
        heading: 'Our branding and locale',
        content:
          'Guaraní project naming, Spanish-first defaults, es-AR locale, native wallpapers. Cultural, not governmental — no state-identity tooling bundled.',
        svg: 'sparks',
      },
    ],
  },
  inheritance: {
    title: 'What is inherited (openly credited)',
    subTitle:
      'YaguareteOS does not hide its lineage. Sibling Universal Blue derivatives such as Bluefin and Aurora attribute upstream openly; we follow the same principle. Honesty about what we inherit is what allows users to audit and trust what we add.',
    features: [
      {
        heading: 'Base image — Bazzite',
        content:
          'KDE desktop, Steam, Proton-GE, GameMode, gamescope, MangoHud and the latest Mesa/AMD drivers inherit straight from bazzite:stable.',
        svg: 'community',
      },
      {
        heading: 'Build system — Universal Blue',
        content:
          'Containerfile + system_files overlay + just recipes follow the Universal Blue image-template layout. Recipes are kept compatible upstream.',
        svg: 'puzzle',
      },
      {
        heading: 'Atomic updates — bootc',
        content:
          'Image-based OS with transactional updates and atomic rollback via bootc on top of Fedora Atomic. Roll forward, roll back, reboot.',
        svg: 'frame',
      },
      {
        heading: 'Gaming stack — Valve + community',
        content:
          'Steam, Proton-GE, MangoHud, gamescope and the rest of the handheld-friendly stack are pulled from upstream — credited, not rebadged.',
        svg: 'guides',
      },
    ],
  },
  cta: {
    title:
      'Build it yourself, rebase from a bootc host, or grab a signed release.',
    body: 'Containerfile + just recipes are reproducible on any Bazzite, Bluefin, Aurora or Fedora Atomic host with podman 5.8+. Stable releases ship as signed OCI tags and as dated ISO/qcow2 artefacts on archive.org.',
    primaryBtn: 'Latest release',
    secondaryBtn: 'GitHub repo',
  },
  faq: {
    title: 'Frequently asked questions',
    subTitle:
      'Common questions about what YaguareteOS is, how to install it, and how it relates to Bazzite and the Universal Blue ecosystem.',
    items: [
      {
        question: 'Is YaguareteOS just Bazzite with a new logo?',
        answer:
          'In Phase 0, functionally yes — the image is Bazzite stable plus our pipeline, signing key and registry. Argentine branding (Plymouth, theme, locale defaults, wallpapers) lands incrementally in Phase 1. The point of the project is the sovereign supply chain, not pretending the lineage does not exist.',
      },
      {
        question: 'Which variant should I install?',
        answer:
          'AMD or Intel GPU on a desktop or laptop → yaguarete_os. NVIDIA with the proprietary driver → yaguarete_os-nvidia. NVIDIA with the open kernel module (Turing+) → yaguarete_os-nvidia-open. Steam Deck, OneXFly or ROG Ally → yaguarete_os-deck (rebase only for now; the deck ISO build is tracked in issue #112).',
      },
      {
        question: 'How do I rebase from another bootc system?',
        answer:
          'Verify the signature with cosign against our public key, then run sudo bootc switch ghcr.io/lobinuxsoft/<variant>:stable and reboot. The previous deployment stays on disk as a rollback target. Full step-by-step instructions live in the README.',
      },
      {
        question: 'Why no government integrations (AFIP, ANSES, Mi Argentina)?',
        answer:
          'YaguareteOS is Argentine because the maintainer is Argentine, not because it ships state-identity tooling. Privacy and freedom take precedence over locale compliance. A hardened variant tracked in issue #25 is the natural escalation for security-conscious users; state integrations are explicitly out of scope.',
      },
      {
        question: 'Where do stable releases live?',
        answer:
          'Each :stable promotion produces a GitHub Release plus a dated archive.org item under identifier <image>-stable-<fedora>.<YYYYMMDD>. The container registry serves :stable, :testing and :unstable channels for bootc users; the dated tags pin a specific build.',
      },
    ],
  },
};

export default en;
