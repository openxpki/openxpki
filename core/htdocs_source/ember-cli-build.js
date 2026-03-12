'use strict';

const EmberApp = require('ember-cli/lib/broccoli/ember-app');
const Funnel = require('broccoli-funnel');
const { compatBuild } = require("@embroider/compat");

module.exports = async function (defaults) {
  const { setConfig } = await import('@warp-drive/core/build-config');
  const { buildOnce } = await import('@embroider/vite');


  // special behaviour in production mode
  let on_production = {};
  if (process.env.EMBER_ENV === "production") {
    console.log("\n****************************************");
    console.log("Excluding 'test' page");
    on_production = {
      ...on_production,
      // https://github.com/ember-cli/ember-cli/blob/v3.18.0/lib/broccoli/ember-app.js#L319-L327
      'trees': {
        'app': new Funnel('app', { exclude: ['route-pods/test/**'] }),
      },
    };

    // Unminified builds ("make debug")
    if (process.env.OPENXPKI_UI_BUILD_UNMINIFIED == 1) {
      console.log("Building un-minified assets incl. sourcemaps");
      on_production = {
        ...on_production,
        'ember-cli-terser': { enabled: false },
        'sourcemaps': { enabled: true },
      };
    }
    console.log("****************************************\n");
  }


  let app = new EmberApp(defaults, {
    // Add options here
    ...on_production,

    // store app config in compiled JS file instead of <meta> tag
    'storeConfigInMeta': false,

    minifyCSS: {
      options: {
        processImport: true,
      },
    },

    /********************************
     * Assets to include
     ********************************/

    // Bootstrap
    'ember-bootstrap': {
      bootstrapVersion: 5,
      importBootstrapCSS: false,
      insertEmberWormholeElementToDom: false,
      // only include used components into compiled JS
      include: ['bs-button', 'bs-modal', 'bs-dropdown', 'bs-navbar', 'bs-collapse'],
    },

    // fetch() polyfill (does not exist in core-js via ember-cli-babel, so we need to add it)
    'ember-fetch': {
      preferNative: true,
    },

    // flatpickr date picker
    'flatpickr': {
      locales: ['de', 'it', 'ja', 'ru', 'zh'],
    },

    /********************************
     * ES6 support / transpilation
     ********************************/

    // ember-cli-babel - convert ES6 code with Babel to code supported by
    // target browsers as specified in config/targets.js
    'ember-cli-babel': {
      includePolyfill: true,
      includeExternalHelpers: true, // import these helpers from a shared module, reducing app size overall
    },

    // @babel/preset-env (!) configuration used by ember-cli-babel
    // https://cli.emberjs.com/release/advanced-use/asset-compilation/
    // https://babeljs.io/docs/en/babel-preset-env
    'babel': {
      // sourcemaps work without the following, but for some reason it generates smaller files:
      sourceMaps: (process.env.OPENXPKI_UI_BUILD_UNMINIFIED == 1) ? 'inline' : false,
    },
  });

  setConfig(app, __dirname, {
    // this should be the most recent <major>.<minor> version for
    // which all deprecations have been fully resolved
    // and should be updated when that changes
    compatWith: '5.8',
    deprecations: {
      // ... list individual deprecations that have been resolved here
    },
  });

  /********************************
   * Additional libraries whose direct import in a component fails
   ********************************/

  // uPlot
  app.import('node_modules/uplot/dist/uPlot.min.css');

  // Choices.js
  app.import('node_modules/choices.js/public/assets/styles/choices.css');
  app.import('node_modules/choices.js/public/assets/scripts/choices.js', {
    using: [
      { transformation: 'amd', as: 'choices.js' }
    ]
  });

  // Bootstrap
  app.import('node_modules/bootstrap/dist/css/bootstrap.css');

  // Bootstrap Icons
  app.import('node_modules/bootstrap-icons/font/fonts/bootstrap-icons.woff2', {
    destDir: 'assets/fonts'
  });

  // Flatpickr
  app.import('node_modules/flatpickr/dist/flatpickr.css');

  /********************************
   * Compilation
   ********************************/
  return compatBuild(app, buildOnce, {
    staticAddonTestSupportTrees: true,
    staticAddonTrees: true,
    staticInvokables: true,
    /* The setting 'staticEmberSource' will default to true in the next version
       of Embroider and can't be turned off. To prepare for this you should set
       'staticEmberSource: true' in your Embroider config. */
    staticEmberSource: true,
    useAddonConfigModule: false,
    // splitAtRoutes: ['route.name'], // can also be a RegExp

    // packagerOptions: {
    //   webpackConfig: {
    //   },
    //   publicAssetURL: 'assets/', // use relative URL (without `{rootURL}/`) so that the old /openxpki/ backend path works
    // },
  });
};
