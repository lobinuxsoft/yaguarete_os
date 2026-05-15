// Navigation data for the landing.
//
// All in-page routes are single-page anchors against the rewritten index.
// External project links point at the canonical YaguareteOS repo on GitHub,
// not the upstream ScrewFast template.

const navBarLinks = [
  { name: 'Variants', url: '#variants' },
  { name: 'Sovereignty', url: '#sovereign' },
  { name: 'Inheritance', url: '#inheritance' },
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

// FooterSection.astro hard-references these keys; keep the shape stable and
// point every entry at the canonical project URL until/unless real social
// accounts exist.
const projectUrl = 'https://github.com/lobinuxsoft/yaguarete_os';
const socialLinks = {
  facebook: projectUrl,
  x: projectUrl,
  github: projectUrl,
  google: projectUrl,
  slack: projectUrl,
};

export default {
  navBarLinks,
  footerLinks,
  socialLinks,
};
