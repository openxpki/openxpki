/**
 * Loads YAML translation files from translations/ into ember-intl.
 *
 * In the classic ember-cli build, ember-intl's build plugin handled this
 * automatically via config/ember-intl.js. In the pure-Vite build there is no
 * such plugin, so we load the files ourselves using Vite's import.meta.glob
 * with ?raw and parse them with js-yaml.
 */
import yaml from 'js-yaml';

// Eagerly import all translation YAML files as raw strings.
// The path is relative to the Vite project root (core/htdocs_source/).
const rawTranslations = import.meta.glob('/translations/*.yaml', { eager: true, query: '?raw', import: 'default' });

export function initialize(appInstance) {
    const intl = appInstance.lookup('service:intl');

    for (const [path, raw] of Object.entries(rawTranslations)) {
        const locale = path.replace('/translations/', '').replace('.yaml', '');
        try {
            const translations = yaml.load(raw);
            if (translations) intl.addTranslations(locale, translations);
        } catch (err) {
            console.error(`ember-intl: failed to parse ${path}:`, err); // eslint-disable-line no-console
        }
    }
}

export default { initialize };
