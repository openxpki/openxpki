import Service from '@ember/service';
import { inject } from '@ember/service';
import { debug } from '@ember/debug';
import moment from "moment-timezone";

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
        moment.locale(locale);
    }

    get locale() {
        return this._locale;
    }
}
