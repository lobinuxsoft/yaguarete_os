import type { Translations } from './types';

const es: Translations = {
  meta: {
    pageTitle:
      'YaguareteOS — Distro KDE basada en Bazzite, orientada al desarrollo y el gaming',
    ogTitle: 'YaguareteOS — KDE para dev y gaming sobre Bazzite',
    description:
      'YaguareteOS es una distribución Linux booteable basada en Bazzite (Universal Blue / Fedora Atomic), orientada al desarrollo y el gaming en handhelds, con slider de memoria gráfica para APUs AMD, actualizaciones atómicas y firmada en nuestra propia CI.',
  },
  hero: {
    titlePrefix: 'Yaguarete',
    titleSuffix: 'OS',
    subTitle:
      'Distro KDE handheld-first sobre Bazzite. Slider de memoria gráfica para APUs AMD sin pasar por el BIOS, Portal con 182 acciones de instalación, apps propias (Yryvu, Tatu) y autoconfiguración de FSR4. Image-based con bootc, actualizaciones atómicas, firmada en nuestra propia CI.',
    primaryBtn: 'Leer el README',
    primaryBtnUrl: 'https://github.com/lobinuxsoft/yaguarete_os#readme',
  },
  variants: {
    title: 'Cuatro variantes KDE, un solo pipeline',
    subTitle:
      'Elegí la variante que matchea con tu hardware. Las cuatro se construyen del mismo árbol y se firman con la misma clave cosign.',
    upstreamLabel: 'Base upstream',
    downloadLabel: 'Descargar ISO',
    pendingNote: 'ISO en preparación para esta variante',
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
          'https://archive.org/download/yaguarete_os-stable-44.20260730/yaguarete_os-stable-44.20260730-live-amd64.iso',
      },
      {
        name: 'yaguarete_os-nvidia',
        tag: 'NVIDIA propietario',
        description:
          'GPU NVIDIA con el driver propietario. Recomendado para gaming en hardware NVIDIA hoy.',
        upstream: 'bazzite-nvidia:stable',
        downloadUrl:
          'https://archive.org/download/yaguarete_os-nvidia-stable-44.20260730/yaguarete_os-nvidia-stable-44.20260730-live-amd64.iso',
      },
      {
        name: 'yaguarete_os-nvidia-open',
        tag: 'Módulo kernel NVIDIA abierto',
        description:
          'GPU NVIDIA con el módulo kernel abierto (Turing+). Orientado a workstations de desarrollo.',
        upstream: 'bazzite-nvidia-open:stable',
        downloadUrl:
          'https://archive.org/download/yaguarete_os-nvidia-open-stable-44.20260730/yaguarete_os-nvidia-open-stable-44.20260730-live-amd64.iso',
      },
      {
        name: 'yaguarete_os-deck',
        tag: 'Handheld (Steam Deck, OneXFly, ROG Ally)',
        description:
          'Bootea directo en game mode. Heredado de Bazzite-deck, todavía en Fedora 43.',
        upstream: 'bazzite-deck:stable',
        downloadUrl:
          'https://archive.org/download/yaguarete_os-deck-stable-43.20260730/yaguarete_os-deck-stable-43.20260730-live-amd64.iso',
      },
    ],
  },
  stack: {
    title: 'Bazzite por debajo, dev y gaming arriba',
    subTitle:
      'Heredamos el stack de gaming de Bazzite — Steam, Proton-GE, GameMode, gamescope, MangoHud, Mesa al día — y le agregamos lo que necesitamos para el dev cotidiano y para exprimir un handheld. Image-based con bootc: cada update es atómico, rollback en un comando.',
    features: [
      {
        heading: 'Gaming-ready',
        content:
          'Steam, Proton-GE, GameMode, gamescope y MangoHud preconfigurados. Mesa/AMD recientes. Perfiles para handhelds (Steam Deck, OneXFly, ROG Ally).',
        svg: 'rocket',
      },
      {
        heading: 'Herramientas propias para handheld',
        content:
          'hhd-vram agrega un slider de memoria gráfica al overlay de Handheld Daemon: asignás RAM como VRAM en APUs AMD sin tocar el BIOS. Más ujust yaguarete-setup-decky, que instala Decky Loader verificando antes de borrar nada, y yaguarete-fsr4, que detecta la GPU y aplica el upgrade correcto.',
        svg: 'puzzle',
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
          'Terminal lista de fábrica: kitty con zsh, prompt Powerlevel10k y FiraCode Nerd Font con ligatures, en un comando. Claude Code y Antigravity a un clic desde el Portal. Toolbox, distrobox y devcontainer first-class. KDE Plasma como escritorio. Defaults en español, locale es-AR.',
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
          'No. Sumamos sobre Bazzite: el plugin hhd-vram para repartir RAM como memoria gráfica en APUs AMD, un Portal yafti con 78 apps y ajustes en 8 secciones (185 acciones install/update/uninstall, con la salida de cada una registrada en disco), instaladores propios para nuestras apps —Yryvu y Tatu— y recetas curadas para software de terceros como Eden, Antigravity, Claude Code o Decky Loader, el wrapper ujust yaguarete-fsr4 que autodetecta la GPU, comandos de rescate y de instalación por categoría (yaguarete-rescue, yaguarete-install-gaming, yaguarete-install-dev), versionado Aurora-style en rpm-ostree status y pipeline propio firmado con cosign.',
      },
      {
        question: '¿Qué es el slider de memoria gráfica para handhelds?',
        answer:
          'En una APU AMD la "VRAM dedicada" la reserva el BIOS y no se mueve en caliente. El pool que sí importa es el GTT: RAM del sistema que la GPU mapea como memoria gráfica a través del argumento de kernel ttm.pages_limit. hhd-vram, que shippeamos como plugin del overlay de Handheld Daemon, lo expone como un porcentaje (25-90%, con un piso de 6 GiB siempre reservado para el sistema): movés el slider, aplicás, reinicia y queda persistido. Sirve para juegos con texturas pesadas y para correr modelos de lenguaje locales. Ninguna otra distro handheld —Bazzite, SteamOS, ChimeraOS— lo expone de esta forma.',
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
          'Ya están disponibles. Cada promoción de :testing a :stable genera un GitHub Release más un item permanente en archive.org. Los botones de descarga en la sección de variantes apuntan a la última ISO publicada por variant. Para usuarios bootc, el rebase es directo: sudo bootc switch ghcr.io/lobinuxsoft/<variante>:stable.',
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
