'use strict';

const EmberApp = require('ember-cli/lib/broccoli/ember-app');

module.exports = function(defaults) {
    let app = new EmberApp(defaults, {
        minifyCSS: {
            // for available options see https://github.com/jakubpawlowicz/clean-css/tree/v3.4.28
            options: {
                processImport: true,
                keepBreaks: true,
            }
        },

        'ember-bootstrap': {
            bootstrapVersion: 3,
            importBootstrapCSS: true,
            importBootstrapFont: true,
            // only include used components into compiled JS
            whitelist: ['bs-button', 'bs-modal', 'bs-dropdown', 'bs-tooltip', 'bs-navbar', 'bs-collapse'],
        },

        // disable fingerprinting of assets in production build
        // (i.e. "openxpki.js" instead of "openxpki-1312d860591f9801798c1ef46052a7ea.js")
        fingerprint: {
            enabled: false,
        },

        // store app config in compiled JS file instead of <meta> tag
        storeConfigInMeta: false,
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

    return app.toTree();
};
