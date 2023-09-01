'use strict';

const EmberApp = require('ember-cli/lib/broccoli/ember-app');
const Funnel = require('broccoli-funnel');
const { Webpack } = require('@embroider/webpack');

module.exports = function(defaults) {
  // special behaviour in production mode
  let on_production = {};
  if (process.env.EMBER_ENV === "production") {
    console.log("\n****************************************");
    console.log("Excluding 'test' page");
    on_production = {
      ...on_production,
      // https://github.com/ember-cli/ember-cli/blob/v3.18.0/lib/broccoli/ember-app.js#L319-L327
      'trees': {
        'app': new Funnel('app', { exclude: ['pods/test/**'] }),
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

  // app configuration
  const app = new EmberApp(defaults, {
    // Add options here
    ...on_production,

    // store app config in compiled JS file instead of <meta> tag
    'storeConfigInMeta': false,

    /********************************
     * Assets to include
     ********************************/

    // Bootstrap
    'ember-bootstrap': {
      bootstrapVersion: 5,
      importBootstrapCSS: true,
      importBootstrapFont: false,
      // only include used components into compiled JS
      whitelist: ['bs-button', 'bs-modal', 'bs-dropdown', 'bs-navbar', 'bs-collapse'],
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

  /********************************
   * Additional libraries whose direct import in a component fails
   ********************************/

  // uPlot
  app.import('node_modules/uplot/dist/uPlot.min.css');

  // slim-select
  app.import('node_modules/slim-select/dist/slimselect.css');
  app.import('node_modules/slim-select/dist/slimselect.js', {
    using: [
      { transformation: 'amd', as: 'slimselect' }
    ]
  });

  /********************************
   * Compilation
   ********************************/
  return require('@embroider/compat').compatBuild(app, Webpack, {
    staticAddonTestSupportTrees: true,
    staticAddonTrees: true,
    // staticHelpers: true,
    // staticModifiers: true,
    // staticComponents: true,
    // splitAtRoutes: ['route.name'], // can also be a RegExp

    // packagerOptions: {
    //   webpackConfig: {
    //   },
    //   publicAssetURL: 'assets/', // use relative URL (without `{rootURL}/`) so that the old /openxpki/ backend path works
    // },
  });
};
