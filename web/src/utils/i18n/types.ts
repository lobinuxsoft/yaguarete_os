export interface VariantCard {
  name: string;
  tag: string;
  description: string;
  upstream: string;
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
