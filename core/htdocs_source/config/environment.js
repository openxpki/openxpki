'use strict';

module.exports = function (environment) {
  const ENV = {
    modulePrefix: 'openxpki',
    podModulePrefix: 'openxpki/route-pods', // where resolver will look for resource files (we only use /route-pods/ for routes)
    environment,
    locationType: 'hash',   // https://guides.emberjs.com/release/configuring-ember/specifying-url-type/
    EmberENV: {
      EXTEND_PROTOTYPES: false,
      FEATURES: {
        // Here you can enable experimental features on an ember canary build
        // e.g. EMBER_NATIVE_DECORATOR_SUPPORT: true
      },
    },

    APP: {
      // Here you can pass flags/options to your application instance
      // when it is created
    },
  };

  /*
   * Custom global constants
   */
  ENV.buildYear = new Date().getFullYear();

  /*
   * Mode specific
   */
  if ('development' === environment) {
    /*
     * /webui/democa/ is required in development as "ember serve" will
     * redirect asset requests to the backend otherwise (no hot reload etc.).
     */
    ENV.rootURL = '/webui/democa/'  // https://guides.emberjs.com/release/configuring-ember/embedding-applications/#toc_specifying-a-root-url
    /*
     * Set up logging
     * https://guides.emberjs.com/release/configuring-ember/debugging/
     */
    //ENV.APP.LOG_RESOLVER = true;
    //ENV.APP.LOG_ACTIVE_GENERATION = true; // this will log Ember-internal component names, e.g. "template:components/oxi-base/formatted"
    ENV.APP.LOG_TRANSITIONS = true;       // Basic logging, e.g. "Transitioned into 'post'"
    ENV.APP.LOG_TRANSITIONS_INTERNAL = true;  // Detailed logging incl. internal steps made while transitioning into a route
    ENV.APP.LOG_VIEW_LOOKUPS = true;
  }

  // Embroider also seems to run with env "test" when doing "ember serve"
  if ('test' === environment) {
    ENV.rootURL = '/webui/democa/'

    // Testem prefers this...
    ENV.locationType = 'none';

    // keep test console output quieter
    ENV.APP.LOG_ACTIVE_GENERATION = false;
    ENV.APP.LOG_VIEW_LOOKUPS = false;

    ENV.APP.rootElement = '#ember-testing';
    ENV.APP.autoboot = false;
  }

  if ('production' === environment) {
    /*
     * An empty rootURL results in relative asset URLs instead of absolute
     * ones in index.html. This allows the application to run on any server
     * path like /webui/REALM/ or /openxpki/ or others.
     */
    ENV.rootURL = ''
  }

  return ENV;
};
