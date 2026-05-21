export interface VariantCard {
  name: string;
  tag: string;
  description: string;
  upstream: string;
  // Direct .iso URL on archive.org. Absent on variants whose stable
  // ISO is not yet published (e.g. deck blocked by #112) — the landing
  // falls back to the disabled button + pendingNote.
  downloadUrl?: string;
}

export interface FeatureCard {
  heading: string;
  content: string;
  svg: string;
}

export interface FaqItem {
  question: string;
  answer: string;
}

export interface AppCard {
  // Recipe id used by ujust + the URL scheme handler. Translated copy
  // never touches this — it stays stable across locales.
  id: string;
  // Human-friendly product name. Localised.
  name: string;
  // One-line category tag (e.g. "Switch emulator", "AI coding IDE").
  tag: string;
  // Marketing blurb shown inside the card body. Localised.
  description: string;
  // Source / upstream identity (e.g. "git.eden-emu.dev", "antigravity.google").
  upstream: string;
  // Optional permalink to the upstream project page (logo target, etc).
  upstreamUrl?: string;
}

export interface Translations {
  meta: {
    pageTitle: string;
    ogTitle: string;
    description: string;
  };
  hero: {
    titlePrefix: string;
    titleSuffix: string;
    subTitle: string;
    primaryBtn: string;
    primaryBtnUrl: string;
  };
  variants: {
    title: string;
    subTitle: string;
    upstreamLabel: string;
    downloadLabel: string;
    pendingNote: string;
    cosignNote: string;
    cards: VariantCard[];
  };
  tools: {
    pageTitle: string;
    pageMeta: string;
    heading: string;
    intro: string;
    upstreamLabel: string;
    installLabel: string;
    copyLabel: string;
    copiedLabel: string;
    commandNote: string;
    cards: AppCard[];
  };
  stack: {
    title: string;
    subTitle: string;
    features: FeatureCard[];
  };
  faq: {
    title: string;
    subTitle: string;
    items: FaqItem[];
  };
}
