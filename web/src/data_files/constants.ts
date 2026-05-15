import ogImageSrc from '@images/social.png';

export const SITE = {
  title: 'YaguareteOS',
  tagline: 'Sovereign bootc-based KDE for gaming and dev',
  description:
    'YaguareteOS is a bootable, image-based Linux distribution built on top of Bazzite (Universal Blue / Fedora Atomic). Gaming-ready, atomic, signed in our own CI, with Argentine cultural identity.',
  description_short:
    'Bootc-based KDE distribution built on Bazzite — gaming-ready, atomic, signed in our own CI.',
  url: 'https://lobinuxsoft.github.io/yaguarete_os/',
  author: 'Matías Galarza',
};

export const SEO = {
  title: `${SITE.title} — ${SITE.tagline}`,
  description: SITE.description,
  structuredData: {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    inLanguage: 'en-US',
    '@id': SITE.url,
    url: SITE.url,
    name: SITE.title,
    description: SITE.description,
    isPartOf: {
      '@type': 'WebSite',
      url: SITE.url,
      name: SITE.title,
      description: SITE.description,
    },
  },
};

export const OG = {
  locale: 'en_US',
  type: 'website',
  url: SITE.url,
  title: `${SITE.title} — ${SITE.tagline}`,
  description:
    'A bootable, image-based KDE distribution built on top of Bazzite (Universal Blue / Fedora Atomic). Four variants — base, NVIDIA, NVIDIA-open, handheld. Signed in our own CI, distributed from our own registry, atomic rollback included.',
  image: ogImageSrc,
};
