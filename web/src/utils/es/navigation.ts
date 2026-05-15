// Navegación en español (locale por defecto).
//
// Las rutas internas son anchors single-page del index reescrito. Los links
// externos apuntan al repo canónico lobinuxsoft/yaguarete_os.

const navBarLinks = [
  { name: 'Variantes', url: '/#variants' },
  { name: 'Soberanía', url: '/#sovereign' },
  { name: 'Herencia', url: '/#inheritance' },
  { name: 'Preguntas', url: '/#faq' },
];

const footerLinks = [
  {
    section: 'Proyecto',
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

// FooterSection.astro depende de estas claves; mantenemos la shape estable y
// apuntamos todas las entradas al repo canónico hasta que existan cuentas
// sociales reales.
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
