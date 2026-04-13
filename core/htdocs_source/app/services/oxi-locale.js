import Service from '@ember/service';
import { service } from '@ember/service';
import { debug } from '@ember/debug';

/**
 * Manages the active locale and delegates to ember-intl for translation loading.
 *
 * Sets `en-us` as the initial locale on construction. When `locale` is set,
 * the value is normalized (underscores to dashes, lowercased) and passed to
 * `intl.setLocale()` with `en-us` as a fallback.
 *
 * @module service/oxi-locale
 */
export default class OxiLocaleService extends Service {
    @service('intl') intl;

    _locale = null;

    constructor() {
        super(...arguments);

        this.locale = 'en-us';
    }

    /**
     * Sets the active locale. Normalizes the value (underscores to dashes,
     * lowercase) and calls `intl.setLocale()` with `en-us` as fallback.
     * Logs a warning and does nothing if `locale` is empty or undefined.
     *
     * @param {string} locale - Locale string, e.g. `"de_DE"` or `"en-us"`
     */
    set locale(locale) {
        if (!locale) {
            /* eslint-disable-next-line no-console */
            console.warn("oxi-locale - attempt to set locale to empty/undefined value");
            return;
        }
        this._locale = locale.replace('_', '-').toLowerCase();
        debug("oxi-locale - setting locale to " + this._locale);
        this.intl.setLocale([this._locale, 'en-us']); // use "en-us" as fallback in case of missing translations
    }

    /**
     * Returns the current normalized locale string (e.g. `"de-de"`).
     *
     * @returns {string}
     */
    get locale() {
        return this._locale;
    }

    /**
     * Returns the language portion of the locale (e.g. `"de"` from `"de-de"`).
     *
     * @returns {string}
     */
    get shortLocale() {
        return this._locale.split(/[-_]/)[0];
    }
}
