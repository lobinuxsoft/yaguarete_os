export interface VariantCard {
  name: string;
  tag: string;
  description: string;
  upstream: string;
  rebase: string;
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
  announcement: {
    text: string;
  };
  hero: {
    titlePrefix: string;
    titleSuffix: string;
    subTitle: string;
    primaryBtn: string;
    secondaryBtn: string;
    heroAlt: string;
  };
  variants: {
    title: string;
    subTitle: string;
    upstreamLabel: string;
    rebaseLabel: string;
    cosignNote: string;
    cards: VariantCard[];
  };
  sovereign: {
    title: string;
    subTitle: string;
    features: FeatureCard[];
  };
  inheritance: {
    title: string;
    subTitle: string;
    features: FeatureCard[];
  };
  cta: {
    title: string;
    body: string;
    primaryBtn: string;
    secondaryBtn: string;
  };
  faq: {
    title: string;
    subTitle: string;
    items: FaqItem[];
  };
}
