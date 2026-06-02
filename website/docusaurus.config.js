const config = {
  title: 'Настрой',
  tagline: 'Покажи близким, в каком ты сейчас настрое',
  favicon: 'img/logo.png',

  url: 'https://ovsyankinvi.github.io',
  baseUrl: '/nastroi-app/',

  organizationName: 'OvsyankinVI',
  projectName: 'nastroi-app',

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'ru',
    locales: ['ru'],
  },

  markdown: {
    mermaid: true,
  },

  themes: ['@docusaurus/theme-mermaid'],

  presets: [
    [
      'classic',
      {
        docs: {
          path: '../docs',
          routeBasePath: 'docs',
          sidebarPath: require.resolve('./sidebars.js'),
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      },
    ],
  ],

themeConfig: {
  colorMode: {
    defaultMode: 'dark',
    disableSwitch: false,
    respectPrefersColorScheme: false,
  },


navbar: {
  title: 'Настрой',
  logo: {
    alt: 'Настрой',
    src: 'img/logo.png',
  },
	items: [
	  {
	    to: '/',
	    label: 'Главная',
	    position: 'left',
	  },
	  {
	    to: '/docs/user/overview',
	    label: 'Пользовательская документация',
	    position: 'left',
	  },
	  {
	    to: '/docs/technical/architecture',
	    label: 'Техническая документация',
	    position: 'left',
	  },
	],
    },
  },
};

module.exports = config;
