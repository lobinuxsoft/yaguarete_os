import type { Translations } from './types';

const es: Translations = {
  meta: {
    pageTitle:
      'YaguareteOS — Distro KDE basada en Bazzite, orientada al desarrollo y el gaming',
    ogTitle: 'YaguareteOS — KDE para dev y gaming sobre Bazzite',
    description:
      'YaguareteOS es una distribución Linux booteable basada en Bazzite (Universal Blue / Fedora Atomic), orientada al desarrollo y el gaming, con actualizaciones atómicas y firmada en nuestra propia CI.',
  },
  hero: {
    titlePrefix: 'Yaguarete',
    titleSuffix: 'OS',
    subTitle:
      'Distro KDE basada en Bazzite, orientada al desarrollo y el gaming. Image-based con bootc, atualizaciones atómicas, firmada en nuestra propia CI.',
    primaryBtn: 'Leer el README',
    primaryBtnUrl: 'https://github.com/lobinuxsoft/yaguarete_os#readme',
  },
  variants: {
    title: 'Cuatro variantes KDE, un solo pipeline',
    subTitle:
      'Elegí la variante que matchea con tu hardware. Las cuatro se construyen del mismo árbol y se firman con la misma clave cosign.',
    upstreamLabel: 'Base upstream',
    downloadLabel: 'Descargar ISO',
    pendingNote: 'Pre-release — primer ISO stable en preparación',
    cosignNote:
      'Las releases stable se publican firmadas con cosign. Verificá la firma contra cosign.pub antes de instalar — instrucciones en el README.',
    cards: [
      {
        name: 'yaguarete_os',
        tag: 'Desktop AMD / Intel',
        description:
          'Variante por defecto. Stack de gráficos open-source, funciona en la mayoría del hardware no-NVIDIA.',
        upstream: 'bazzite:stable',
        downloadUrl:
          'https://archive.org/download/yaguarete_os-stable-44.20260515/yaguarete_os-testing-44.20260515-live-amd64.iso',
      },
      {
        name: 'yaguarete_os-nvidia',
        tag: 'NVIDIA propietario',
        description:
          'GPU NVIDIA con el driver propietario. Recomendado para gaming en hardware NVIDIA hoy.',
        upstream: 'bazzite-nvidia:stable',
        downloadUrl:
          'https://archive.org/download/yaguarete_os-nvidia-stable-44.20260515/yaguarete_os-nvidia-testing-44.20260515-live-amd64.iso',
      },
      {
        name: 'yaguarete_os-nvidia-open',
        tag: 'Módulo kernel NVIDIA abierto',
        description:
          'GPU NVIDIA con el módulo kernel abierto (Turing+). Orientado a workstations de desarrollo.',
        upstream: 'bazzite-nvidia-open:stable',
        downloadUrl:
          'https://archive.org/download/yaguarete_os-nvidia-open-stable-44.20260515/yaguarete_os-nvidia-open-testing-44.20260515-live-amd64.iso',
      },
      {
        name: 'yaguarete_os-deck',
        tag: 'Handheld (Steam Deck, OneXFly, ROG Ally)',
        description:
          'Bootea directo en game mode. Heredado de Bazzite-deck, todavía en Fedora 43.',
        upstream: 'bazzite-deck:stable',
        downloadUrl:
          'https://archive.org/download/yaguarete_os-deck-stable-43.20260420/yaguarete_os-deck-testing-43.20260420-live-amd64.iso',
      },
    ],
  },
  stack: {
    title: 'Bazzite por debajo, dev y gaming arriba',
    subTitle:
      'Heredamos el stack de gaming de Bazzite — Steam, Proton-GE, GameMode, gamescope, MangoHud, Mesa al día — y le agregamos lo que necesitamos para el dev cotidiano. Image-based con bootc: cada update es atómico, rollback en un comando.',
    features: [
      {
        heading: 'Gaming-ready',
        content:
          'Steam, Proton-GE, GameMode, gamescope y MangoHud preconfigurados. Mesa/AMD recientes. Perfiles para handhelds (Steam Deck, OneXFly, ROG Ally).',
        svg: 'rocket',
      },
      {
        heading: 'Atómico e inmutable',
        content:
          'Image-based sobre Fedora Atomic con bootc. Cada update es una imagen completa firmada. Rollback inmediato si algo falla.',
        svg: 'frame',
      },
      {
        heading: 'Dev-friendly',
        content:
          'Toolbox, distrobox y devcontainer first-class. KDE Plasma como escritorio. Defaults en español, locale es-AR.',
        svg: 'tools',
      },
    ],
  },
  faq: {
    title: 'Preguntas frecuentes',
    subTitle:
      'Qué es YaguareteOS, cómo se instala, y cómo se relaciona con Bazzite y el ecosistema Universal Blue.',
    items: [
      {
        question: '¿YaguareteOS es Bazzite con otro logo?',
        answer:
          'En Phase 0, funcionalmente sí — la imagen es Bazzite stable más nuestro pipeline, clave de firma y registro. El branding argentino (Plymouth, tema, defaults de locale, wallpapers) aterriza incrementalmente en Phase 1. El valor agregado hoy es el pipeline propio: lo construimos nosotros, lo firmamos nosotros, lo publicamos en nuestro registro.',
      },
      {
        question: '¿Qué variante instalo?',
        answer:
          'GPU AMD o Intel en desktop o laptop → yaguarete_os. NVIDIA con driver propietario → yaguarete_os-nvidia. NVIDIA con módulo kernel abierto (Turing+) → yaguarete_os-nvidia-open. Steam Deck, OneXFly o ROG Ally → yaguarete_os-deck (todavía en Fedora 43, lockstep con Bazzite-deck).',
      },
      {
        question: '¿Cómo hago rebase desde otro sistema bootc?',
        answer:
          'Verificá la firma con cosign contra nuestra clave pública, después corré sudo bootc switch ghcr.io/lobinuxsoft/<variante>:stable y reiniciá. El deployment previo queda en disco como target de rollback. Instrucciones paso a paso completas viven en el README.',
      },
      {
        question: '¿Cuándo va a haber ISOs descargables?',
        answer:
          'Apenas se corte el primer release :stable. El pipeline ya está armado (build container → bootc-image-builder → archive.org); falta la promoción manual de unstable → testing → stable. Los botones de descarga de las variantes se activan automáticamente cuando ese release exista.',
      },
      {
        question: '¿Dónde van a vivir las releases stable?',
        answer:
          'Cada promoción a :stable produce un GitHub Release más un item con fecha en archive.org bajo identificador <imagen>-stable-<fedora>.<YYYYMMDD>. El registro de containers sirve los canales :stable, :testing y :unstable para usuarios bootc; los tags con fecha pinean una build específica.',
      },
    ],
  },
};

export default es;
