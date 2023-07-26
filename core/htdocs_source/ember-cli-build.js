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
  const app = new EmberApp(defaults, {
    // Add options here
    ...on_production,

    // store app config in compiled JS file instead of <meta> tag
    'storeConfigInMeta': false,

    /*******************************
      Assets to include
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

    /*******************************
      ES6 support / transpilation
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

    /*******************************
      Modifications
    ********************************/

    // clean-css - minify CSS definitions
    /*
      Currently Ember CLI automatically minifies CSS files using clean-css when
      building for production environment.
      Dependency chain:
      ember-cli
        -> ember-cli-preprocess-registry (3.3.0)
          -> broccoli-clean-css (1.1.0)
            -> clean-css-promise (0.1.1)
              -> clean-css (3.4.28)
      ember-cli-preprocess-registry uses the fallback broccoli-clean-css
      when no other "minify-css" preprocessor was registered in Ember.
      One example of such an alternative preprocessor is ember-cli-clean-css.
    */
    'minifyCSS': {
      // available options: https://github.com/jakubpawlowicz/clean-css/tree/v3.4.28
      options: {
        processImport: true,
        keepBreaks: true,
      }
    },

    // ember-auto-import - create asset bundles from imported modules
    /*
      We adjust the names of the output files. We remove the hash as obviously
      an additional hash is appended by 'broccoli-asset-rev' using the
      'fingerprint' configuration below.
      Also see https://github.com/ef4/ember-auto-import/issues/519
    */
    'autoImport': {
      // JS assets
      webpack: {
        output: {
          // https://webpack.js.org/configuration/output/#template-strings
          filename: 'autoimport-[name].js',
        },
        optimization: {
          realContentHash: true, // default now?!
          moduleIds: 'size'      // prevent changing module IDs in the autoimport-xxx.js bundles
                                 // https://github.com/ef4/ember-auto-import/issues/478#issuecomment-1000515314
        },
      },
      // CSS assets
      miniCssExtractPluginOptions: {
        filename: `autoimport-[name].css`,
      },
      publicAssetURL: 'assets/', // use relative URL (without `{rootURL}/`) so that the old /openxpki/ backend path works
    },

    // broccoli-asset-rev - fingerprint assets in production build
    // (i.e. "openxpki-1312d860591f9801798c1ef46052a7ea.js")
    'fingerprint': {
      enabled: true,
      extensions: ['js', 'css', 'map'], // default also includes 'png', 'jpg', 'gif'
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
