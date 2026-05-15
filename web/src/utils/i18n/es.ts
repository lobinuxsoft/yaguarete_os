import type { Translations } from './types';

const es: Translations = {
  meta: {
    pageTitle: 'YaguareteOS — Distribución KDE soberana basada en bootc para gaming y desarrollo',
    ogTitle: 'YaguareteOS — Distribución KDE soberana basada en bootc',
    description:
      'YaguareteOS es una distribución Linux booteable, basada en imágenes, construida sobre Bazzite (Universal Blue / Fedora Atomic). Lista para gaming, atómica, firmada en nuestra propia CI, con identidad cultural argentina.',
  },
  announcement: {
    text: 'Aviso Phase 0 — El branding argentino aterriza en Phase 1',
  },
  hero: {
    titlePrefix: 'Yaguarete',
    titleSuffix: 'OS',
    subTitle:
      'Una distribución KDE booteable, basada en imágenes, construida sobre Bazzite (Universal Blue / Fedora Atomic). Lista para gaming, con actualizaciones atómicas, firmada en nuestra propia CI.',
    primaryBtn: 'Última release',
    secondaryBtn: 'Leer el README',
    heroAlt:
      'Selva oscura — la jungla argentina que da identidad visual a YaguareteOS',
  },
  variants: {
    title: 'Cuatro variantes KDE, un solo pipeline',
    subTitle:
      'Elegí la variante que matchea con tu hardware. Las cuatro se construyen del mismo árbol y se firman con la misma clave cosign. No hay variantes GNOME — esto es un proyecto KDE-only.',
    upstreamLabel: 'Base upstream',
    rebaseLabel: 'Rebase',
    cosignNote:
      'Verificá la firma de la imagen con cosign verify contra cosign.pub antes de correr bootc switch. Instrucciones completas en el README.',
    cards: [
      {
        name: 'yaguarete_os',
        tag: 'Desktop AMD / Intel',
        description:
          'Variante por defecto. Usa el stack de gráficos open-source y funciona en la mayoría del hardware no-NVIDIA.',
        upstream: 'bazzite:stable',
        rebase: 'sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os:stable',
      },
      {
        name: 'yaguarete_os-nvidia',
        tag: 'NVIDIA propietario',
        description:
          'GPU NVIDIA con el driver propietario. Recomendado para gaming en hardware NVIDIA hoy.',
        upstream: 'bazzite-nvidia:stable',
        rebase:
          'sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-nvidia:stable',
      },
      {
        name: 'yaguarete_os-nvidia-open',
        tag: 'Módulo kernel NVIDIA abierto',
        description:
          'GPU NVIDIA con el módulo kernel abierto (Turing+). Orientado a servidores / workstations de desarrollo.',
        upstream: 'bazzite-nvidia-open:stable',
        rebase:
          'sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-nvidia-open:stable',
      },
      {
        name: 'yaguarete_os-deck',
        tag: 'Handheld (Steam Deck, OneXFly, ROG Ally)',
        description:
          'Bootea directo en game mode. La build de ISO todavía está bloqueada por el issue #112; el rebase desde Bazzite-deck funciona hoy.',
        upstream: 'bazzite-deck:stable',
        rebase:
          'sudo bootc switch ghcr.io/lobinuxsoft/yaguarete_os-deck:stable',
      },
    ],
  },
  sovereign: {
    title: 'Lo que es soberano',
    subTitle:
      'Soberanía digital acá significa controlar el pipeline — claves de firma, infraestructura de build, registro de distribución, gobernanza del proyecto, branding — no esconder la herencia técnica.',
    features: [
      {
        heading: 'Nuestro pipeline de build',
        content:
          'Runners de CI, políticas de build y workflow de release viven en este repo. Sin builders de terceros, sin pasos opacos de promoción.',
        svg: 'tools',
      },
      {
        heading: 'Nuestro par de claves de firma',
        content:
          'Par cosign bajo nuestro control. Clave pública embebida en el repo; clave privada offline. Cada imagen publicada está firmada y es verificable.',
        svg: 'verified',
      },
      {
        heading: 'Nuestro registro de distribución',
        content:
          'Imágenes publicadas en ghcr.io/lobinuxsoft/yaguarete_os. Las releases stable se espejan como identificadores con fecha en archive.org para preservación de largo plazo.',
        svg: 'rocket',
      },
      {
        heading: 'Nuestro branding y locale',
        content:
          'Nombres guaraníes, defaults en español, locale es-AR, wallpapers nativos. Cultural, no gubernamental — no se incluyen herramientas de identidad estatal.',
        svg: 'sparks',
      },
    ],
  },
  inheritance: {
    title: 'Lo que se hereda (acreditado abiertamente)',
    subTitle:
      'YaguareteOS no esconde su linaje. Derivadas hermanas de Universal Blue como Bluefin y Aurora también acreditan upstream abiertamente; seguimos el mismo principio. La honestidad sobre lo que heredamos es lo que permite a los usuarios auditar y confiar en lo que agregamos.',
    features: [
      {
        heading: 'Imagen base — Bazzite',
        content:
          'KDE desktop, Steam, Proton-GE, GameMode, gamescope, MangoHud y los drivers más recientes de Mesa/AMD se heredan directo de bazzite:stable.',
        svg: 'community',
      },
      {
        heading: 'Sistema de build — Universal Blue',
        content:
          'Containerfile + overlay system_files + recipes just siguen el layout image-template de Universal Blue. Las recipes se mantienen compatibles upstream.',
        svg: 'puzzle',
      },
      {
        heading: 'Updates atómicas — bootc',
        content:
          'OS basado en imágenes con updates transaccionales y rollback atómico vía bootc sobre Fedora Atomic. Roll forward, roll back, reboot.',
        svg: 'frame',
      },
      {
        heading: 'Stack de gaming — Valve + comunidad',
        content:
          'Steam, Proton-GE, MangoHud, gamescope y el resto del stack handheld-friendly se tiran del upstream — acreditado, no rebrandeado.',
        svg: 'guides',
      },
    ],
  },
  cta: {
    title:
      'Construilo vos, rebaseá desde un host bootc, o agarrá una release firmada.',
    body: 'Containerfile + recipes just son reproducibles en cualquier host Bazzite, Bluefin, Aurora o Fedora Atomic con podman 5.8+. Las releases stable se shippean como tags OCI firmados y como artefactos ISO/qcow2 con fecha en archive.org.',
    primaryBtn: 'Última release',
    secondaryBtn: 'Repo en GitHub',
  },
  faq: {
    title: 'Preguntas frecuentes',
    subTitle:
      'Preguntas comunes sobre qué es YaguareteOS, cómo instalarlo, y cómo se relaciona con Bazzite y el ecosistema Universal Blue.',
    items: [
      {
        question: '¿YaguareteOS es Bazzite con otro logo?',
        answer:
          'En Phase 0, funcionalmente sí — la imagen es Bazzite stable más nuestro pipeline, clave de firma y registro. El branding argentino (Plymouth, tema, defaults de locale, wallpapers) aterriza incrementalmente en Phase 1. El punto del proyecto es el supply chain soberano, no pretender que la herencia no existe.',
      },
      {
        question: '¿Qué variante instalo?',
        answer:
          'GPU AMD o Intel en desktop o laptop → yaguarete_os. NVIDIA con driver propietario → yaguarete_os-nvidia. NVIDIA con módulo kernel abierto (Turing+) → yaguarete_os-nvidia-open. Steam Deck, OneXFly o ROG Ally → yaguarete_os-deck (sólo por rebase por ahora; la build de ISO para deck está trackeada en el issue #112).',
      },
      {
        question: '¿Cómo hago rebase desde otro sistema bootc?',
        answer:
          'Verificá la firma con cosign contra nuestra clave pública, después corré sudo bootc switch ghcr.io/lobinuxsoft/<variante>:stable y reiniciá. El deployment previo queda en disco como target de rollback. Instrucciones paso a paso completas viven en el README.',
      },
      {
        question:
          '¿Por qué no hay integraciones gubernamentales (AFIP, ANSES, Mi Argentina)?',
        answer:
          'YaguareteOS es argentino porque el maintainer es argentino, no porque traiga herramientas de identidad estatal. Privacidad y libertad tienen precedencia sobre compliance de locale. Una variante hardened trackeada en el issue #25 es la escalación natural para usuarios security-conscious; las integraciones estatales están explícitamente fuera del scope.',
      },
      {
        question: '¿Dónde viven las releases stable?',
        answer:
          'Cada promoción a :stable produce un GitHub Release más un item dated en archive.org bajo identificador <imagen>-stable-<fedora>.<YYYYMMDD>. El registro de containers sirve los canales :stable, :testing y :unstable para usuarios bootc; los tags con fecha pinean una build específica.',
      },
    ],
  },
};

export default es;
