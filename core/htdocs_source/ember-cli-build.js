'use strict';

const EmberApp = require('ember-cli/lib/broccoli/ember-app');
const Funnel = require('broccoli-funnel');

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
  let app = new EmberApp(defaults, {
    ...on_production,

    'minifyCSS': {
      // for available options see https://github.com/jakubpawlowicz/clean-css/tree/v3.4.28
      options: {
        processImport: true,
        keepBreaks: true,
      }
    },

    'ember-bootstrap': {
      bootstrapVersion: 5,
      importBootstrapCSS: true,
      importBootstrapFont: false,
      // only include used components into compiled JS
      whitelist: ['bs-button', 'bs-modal', 'bs-dropdown', 'bs-navbar', 'bs-collapse'],
    },

    // fingerprinting of assets in production build
    // (i.e. "openxpki.js" or "openxpki-1312d860591f9801798c1ef46052a7ea.js")
    'fingerprint': {
      enabled: true,
      extensions: ['js', 'css', 'map'], // default also includes 'png', 'jpg', 'gif'
    },

    // store app config in compiled JS file instead of <meta> tag
    'storeConfigInMeta': false,

    // support e.g. IE11
    'ember-cli-babel': {
      includePolyfill: true,
      includeExternalHelpers: true, // import these helpers from a shared module, reducing app size overall
    },

    // https://cli.emberjs.com/release/advanced-use/asset-compilation/
    // https://babeljs.io/docs/en/babel-preset-env
    'babel': {
      // sourcemaps work without the following, but for some reason it generates smaller files:
      sourceMaps: (process.env.OPENXPKI_UI_BUILD_UNMINIFIED == 1) ? 'inline' : false,
    },

    // options for @babel/preset-env (evaluated by 'ember-cli-babel' and passed on)
    // 'babel': {
    //   useBuiltIns: 'usage', // auto import polyfills without the need to specify them
    //   // options for core-js, see https://babeljs.io/docs/en/babel-preset-env#corejs
    //   corejs: {
    //     version: '3.9.1',
    //   },
    // },

    // fetch() polyfill does not exist in core-js (via ember-cli-babel), so we need to add it:
    'ember-fetch': {
      preferNative: true,
    },

    // flatpickr date picker
    'flatpickr': {
      locales: ['de', 'it', 'ja', 'ru', 'zh'],
    },
  });

  // Use `app.import` to add additional libraries to the generated
  // output files.
  //
  // If you need to use different assets in different
  // environments, specify an object as the first parameter. That
  // object's keys should be the environment name and the values
  // should be the asset to use in that environment.
  //
  // If the library that you are including contains AMD or ES6
  // modules that you would like to import into your application
  // please specify an object with the list of modules as keys
  // along with the exports of each module as its value.
  app.import('node_modules/uplot/dist/uPlot.min.css');

  return app.toTree();
};
