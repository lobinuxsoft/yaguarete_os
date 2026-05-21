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
  tools: {
    pageTitle: 'YaguareteOS — Herramientas y emuladores',
    pageMeta:
      'Instalá emuladores, IDEs y herramientas en YaguareteOS con un solo click. Cada botón ejecuta un recipe ujust que descarga, configura e integra la app en tu sistema bootc.',
    heading: 'Herramientas',
    intro:
      'Cada tarjeta ejecuta un recipe ujust que descarga la app oficial, configura el firmware / claves / paths necesarios e integra con Steam Game Mode cuando aplica. Si preferís correrlo a mano, copiá el comando — el resultado es el mismo.',
    upstreamLabel: 'Origen',
    installLabel: 'Instalar',
    copyLabel: 'Copiar comando',
    copiedLabel: 'Copiado ✓',
    commandNote:
      'El botón Instalar abre un handler yaguarete:// que confirma antes de ejecutar. Si tu navegador no tiene el handler registrado, copiá el comando y pegalo en una terminal — el resultado es idéntico.',
    cards: [
      {
        id: 'eden',
        name: 'Eden',
        tag: 'Emulador de Nintendo Switch',
        description:
          'Fork community de Yuzu / Sudachi, mantenido activamente. Incluye descarga automática de firmware (THZoria) + claves (ProdKeys.net) + parser de Steam ROM Manager para que tus ROMs aparezcan en Game Mode sin tocar config.',
        upstream: 'eden-emu.dev',
        upstreamUrl: 'https://git.eden-emu.dev/eden-emu/eden',
      },
      {
        id: 'antigravity-ide',
        name: 'Antigravity IDE',
        tag: 'IDE de Google con agentes de IA',
        description:
          'IDE oficial de Google con agentes de IA integrados. Se instala desde la tarball Linux oficial de antigravity.google, queda en /opt/antigravity y registra el launcher del menú KDE.',
        upstream: 'antigravity.google',
        upstreamUrl: 'https://antigravity.google',
      },
      {
        id: 'antigravity-cli',
        name: 'Antigravity CLI',
        tag: 'Agente de terminal (agy)',
        description:
          'CLI complementario al IDE: trabajar con agentes de IA desde la terminal. Binario en ~/.local/bin/agy + completions para bash / fish / zsh. Comparte autenticación con el IDE vía keyring del sistema.',
        upstream: 'antigravity.google',
        upstreamUrl: 'https://antigravity.google',
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
