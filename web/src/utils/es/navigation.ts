// Navegación en español (locale por defecto).
//
// Los links internos son anchors bare (`#id`) para que el navegador conserve
// el path actual — con el slash inicial saltaríamos a la raíz del sitio y
// perderíamos el prefijo /yaguarete_os.

const navBarLinks = [
  { name: 'Variantes', url: '#variants' },
  { name: 'Stack', url: '#stack' },
  { name: 'Preguntas', url: '#faq' },
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

// FooterSection.astro hard-references las keys de abajo; las cuentas sociales
// placeholder que apuntaban al repo del proyecto eran engañosas y se
// eliminaron. Mantenemos la shape pero los canales no usados son null para
// que el footer los pueda saltar en vez de renderizar links muertos.
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
