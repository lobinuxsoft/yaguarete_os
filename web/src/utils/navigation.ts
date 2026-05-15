// English navigation (mirror under /en/).
//
// All in-page links are bare anchors (`#id`) so the browser keeps the current
// path — without the leading slash they would jump to site root and lose the
// /yaguarete_os base prefix.

const navBarLinks = [
  { name: 'Variants', url: '#variants' },
  { name: 'Stack', url: '#stack' },
  { name: 'FAQ', url: '#faq' },
];

const footerLinks = [
  {
    section: 'Project',
    links: [
      {
        name: 'GitHub',
        url: 'https://github.com/lobinuxsoft/yaguarete_os',
      },
      {
        name: 'Releases',
        url: 'https://github.com/lobinuxsoft/yaguarete_os/releases',
      },
      {
        name: 'README',
        url: 'https://github.com/lobinuxsoft/yaguarete_os#readme',
      },
      {
        name: 'ADRs',
        url: 'https://github.com/lobinuxsoft/yaguarete_os/tree/main/docs/adr',
      },
    ],
  },
  {
    section: 'Upstream',
    links: [
      { name: 'Bazzite', url: 'https://bazzite.gg/' },
      { name: 'Universal Blue', url: 'https://universal-blue.org/' },
      {
        name: 'Fedora Atomic',
        url: 'https://fedoraproject.org/atomic-desktops/',
      },
      { name: 'bootc', url: 'https://github.com/containers/bootc' },
    ],
  },
];

// FooterSection.astro hard-references the keys below; placeholder social
// accounts that pointed at the project URL were misleading and have been
// dropped. We keep the shape and set unused channels to null so the footer
// can skip them instead of rendering dead links.
const projectUrl = 'https://github.com/lobinuxsoft/yaguarete_os';
const socialLinks = {
  github: projectUrl,
  facebook: null,
  x: null,
  google: null,
  slack: null,
};

export default {
  navBarLinks,
  footerLinks,
  socialLinks,
};
