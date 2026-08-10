import type { Translations } from './types';

const en: Translations = {
  meta: {
    pageTitle:
      'YaguareteOS — Bazzite-based KDE distribution for dev and gaming',
    ogTitle: 'YaguareteOS — KDE for dev and gaming on top of Bazzite',
    description:
      'YaguareteOS is a bootable Linux distribution built on top of Bazzite (Universal Blue / Fedora Atomic), aimed at development and handheld gaming, with a graphics-memory slider for AMD APUs, atomic updates and signed by our own CI.',
  },
  hero: {
    titlePrefix: 'Yaguarete',
    titleSuffix: 'OS',
    subTitle:
      'Handheld-first KDE distribution on top of Bazzite. A graphics-memory slider for AMD APUs with no BIOS trip, a Portal with 176 install actions, our own apps (Yryvu, Tatu) and FSR4 auto-configuration. Image-based with bootc, atomic updates, signed by our own CI.',
    primaryBtn: 'Read the README',
    primaryBtnUrl: 'https://github.com/lobinuxsoft/yaguarete_os#readme',
  },
  variants: {
    title: 'Four KDE variants, one pipeline',
    subTitle:
      'Pick the variant that matches your hardware. All four are built from the same source tree and signed with the same cosign keypair.',
    upstreamLabel: 'Upstream',
    downloadLabel: 'Download ISO',
    pendingNote: 'ISO for this variant in preparation',
    cosignNote:
      'Stable releases are signed with cosign. Verify the signature against cosign.pub before installing — instructions in the README.',
    cards: [
      {
        name: 'yaguarete_os',
        tag: 'AMD / Intel desktop',
        description:
          'Default variant. Open-source graphics stack, works on most non-NVIDIA hardware.',
        upstream: 'bazzite:stable',
        downloadUrl:
          'https://archive.org/download/yaguarete_os-stable-44.20260730/yaguarete_os-stable-44.20260730-live-amd64.iso',
      },
      {
        name: 'yaguarete_os-nvidia',
        tag: 'NVIDIA proprietary',
        description:
          'NVIDIA GPU with the proprietary driver. Recommended for gaming on NVIDIA hardware today.',
        upstream: 'bazzite-nvidia:stable',
        downloadUrl:
          'https://archive.org/download/yaguarete_os-nvidia-stable-44.20260730/yaguarete_os-nvidia-stable-44.20260730-live-amd64.iso',
      },
      {
        name: 'yaguarete_os-nvidia-open',
        tag: 'NVIDIA open kernel module',
        description:
          'NVIDIA GPU with the open kernel module (Turing+). Aimed at dev workstations.',
        upstream: 'bazzite-nvidia-open:stable',
        downloadUrl:
          'https://archive.org/download/yaguarete_os-nvidia-open-stable-44.20260730/yaguarete_os-nvidia-open-stable-44.20260730-live-amd64.iso',
      },
      {
        name: 'yaguarete_os-deck',
        tag: 'Handheld (Steam Deck, OneXFly, ROG Ally)',
        description:
          'Boots into game mode. Inherited from Bazzite-deck, still on Fedora 43.',
        upstream: 'bazzite-deck:stable',
        downloadUrl:
          'https://archive.org/download/yaguarete_os-deck-stable-43.20260730/yaguarete_os-deck-stable-43.20260730-live-amd64.iso',
      },
    ],
  },
  stack: {
    title: 'Bazzite underneath, dev and gaming on top',
    subTitle:
      'We inherit the Bazzite gaming stack — Steam, Proton-GE, GameMode, gamescope, MangoHud, recent Mesa — and layer on what we need for daily dev work and for squeezing a handheld. Image-based with bootc: every update is atomic, rollback is one command.',
    features: [
      {
        heading: 'Gaming-ready',
        content:
          'Steam, Proton-GE, GameMode, gamescope and MangoHud preconfigured. Recent Mesa/AMD. Handheld profiles (Steam Deck, OneXFly, ROG Ally).',
        svg: 'rocket',
      },
      {
        heading: 'Our own handheld tooling',
        content:
          'hhd-vram adds a graphics-memory slider to the Handheld Daemon overlay: assign system RAM as VRAM on AMD APUs without a BIOS trip. Plus ujust yaguarete-setup-decky, which installs Decky Loader verifying everything before deleting anything, and yaguarete-fsr4, which detects the GPU and applies the right upgrade.',
        svg: 'puzzle',
      },
      {
        heading: 'Atomic and immutable',
        content:
          'Image-based on Fedora Atomic with bootc. Every update is a full signed image. Instant rollback if anything breaks.',
        svg: 'frame',
      },
      {
        heading: 'Dev-friendly',
        content:
          'Toolbox, distrobox and devcontainer first-class. KDE Plasma desktop. Spanish-first defaults, es-AR locale.',
        svg: 'tools',
      },
    ],
  },
  faq: {
    title: 'Frequently asked questions',
    subTitle:
      'What YaguareteOS is, how to install it, and how it relates to Bazzite and the Universal Blue ecosystem.',
    items: [
      {
        question: 'Is YaguareteOS just Bazzite with a new logo?',
        answer:
          'No. On top of Bazzite we add: the hhd-vram plugin for splitting RAM into graphics memory on AMD APUs, a yafti Portal with 77 apps and tweaks across 8 sections (182 install/update/uninstall actions, each one logging its output to disk), our own installers for our own apps — Yryvu and Tatu — plus curated recipes for third-party software like Eden, Antigravity, Claude Code or Decky Loader, the ujust yaguarete-fsr4 wrapper that auto-detects the GPU, rescue and per-category install commands (yaguarete-rescue, yaguarete-install-gaming, yaguarete-install-dev), Aurora-style versioning in rpm-ostree status, and our own pipeline signed with cosign.',
      },
      {
        question: 'What is the handheld graphics-memory slider?',
        answer:
          'On an AMD APU the "dedicated VRAM" is carved out by the BIOS and cannot be moved at runtime. The pool that actually matters is the GTT: system RAM the GPU maps as graphics memory through the ttm.pages_limit kernel argument. hhd-vram, which we ship as a plugin for the Handheld Daemon overlay, exposes it as a percentage (25-90%, with a 6 GiB floor always reserved for the OS): move the slider, apply, reboot, and it persists. Useful for texture-heavy games and for running local language models. No other handheld distribution — Bazzite, SteamOS, ChimeraOS — exposes this.',
      },
      {
        question: 'Which variant should I install?',
        answer:
          'AMD or Intel GPU on a desktop or laptop → yaguarete_os. NVIDIA with the proprietary driver → yaguarete_os-nvidia. NVIDIA with the open kernel module (Turing+) → yaguarete_os-nvidia-open. Steam Deck, OneXFly or ROG Ally → yaguarete_os-deck (still on Fedora 43, lockstep with Bazzite-deck).',
      },
      {
        question: 'How do I rebase from another bootc system?',
        answer:
          'Verify the signature with cosign against our public key, then run sudo bootc switch ghcr.io/lobinuxsoft/<variant>:stable and reboot. The previous deployment stays on disk as a rollback target. Full step-by-step instructions live in the README.',
      },
      {
        question: 'When will downloadable ISOs be available?',
        answer:
          'They already are. Each promotion from :testing to :stable produces a GitHub Release plus a permanent archive.org item. The download buttons in the variants section link to the latest published ISO per variant. For bootc users, rebase is direct: sudo bootc switch ghcr.io/lobinuxsoft/<variant>:stable.',
      },
      {
        question: 'Where will stable releases live?',
        answer:
          'Each :stable promotion produces a GitHub Release plus a dated archive.org item under identifier <image>-stable-<fedora>.<YYYYMMDD>. The container registry serves :stable, :testing and :unstable channels for bootc users; the dated tags pin a specific build.',
      },
    ],
  },
};

export default en;
