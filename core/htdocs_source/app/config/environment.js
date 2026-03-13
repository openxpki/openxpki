// Pure-Vite build: read environment directly from Vite's import.meta.env
// (replaces @embroider/config-meta-loader which requires classicEmberSupport)
const environment = import.meta.env.MODE || 'development';
const isProduction = environment === 'production';
const isTest = environment === 'test';
const isDevelopment = environment === 'development';

export default {
    modulePrefix: 'openxpki',
    podModulePrefix: 'openxpki/route-pods',
    environment,
    locationType: isTest ? 'none' : 'hash',
    EmberENV: {
        EXTEND_PROTOTYPES: false,
        FEATURES: {},
    },
    APP: {
        ...(isDevelopment ? {
            LOG_TRANSITIONS: true,
            LOG_TRANSITIONS_INTERNAL: true,
            LOG_VIEW_LOOKUPS: true,
        } : {}),
        ...(isTest ? {
            LOG_ACTIVE_GENERATION: false,
            LOG_VIEW_LOOKUPS: false,
            rootElement: '#ember-testing',
            autoboot: false,
        } : {}),
    },
    rootURL: isProduction ? '' : isTest ? '/' : '/webui/democa/',
    buildYear: new Date().getFullYear(),
};
