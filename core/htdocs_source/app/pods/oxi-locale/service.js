import Service from '@ember/service';
import { inject } from '@ember/service';
import { debug } from '@ember/debug';

export default class OxiLocaleService extends Service {
    @inject('intl') intl;

    _locale = null;

    constructor() {
        super(...arguments);

        this.locale = 'en-us';
    }

    set locale(locale) {
        this._locale = locale;
        debug("oxi-locale - setting locale to " + locale);
        this.intl.setLocale([locale, 'en-us']); // use "en-us" as fallback in case of missing translations
    }

    get locale() {
        return this._locale;
    }

    get shortLocale() {
        return this._locale.split(/[-_]/)[0];
    }
}
