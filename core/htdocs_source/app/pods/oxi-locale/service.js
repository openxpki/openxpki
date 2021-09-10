import Service from '@ember/service';
import { inject } from '@ember/service';
import { debug } from '@ember/debug';

export default class OxiLocaleService extends Service {
    @inject('intl') intl;

    _locale = null;

    constructor() {
        super(...arguments);

        this.locale = 'en-US';
    }

    set locale(locale) {
        this._locale = locale;
        debug("oxi-locale - setting locale to " + locale);
        this.intl.setLocale([locale]);
    }

    get locale() {
        return this._locale;
    }

    get shortLocale() {
        return this._locale.split(/-/)[0];
    }
}
