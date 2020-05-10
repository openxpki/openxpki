import Service from '@ember/service';
import ENV from 'openxpki/config/environment';

export default class OxiConfigService extends Service {
    localConfig = {};

    constructor() {
        super(...arguments);
        /* eslint-disable-next-line no-undef */
        if (typeof OXI_LOCALCONFIG !== 'undefined') {
            /* eslint-disable-next-line no-undef */
            this.localConfig = OXI_LOCALCONFIG;
            /* eslint-disable-next-line no-console */
            console.log("Using custom configuration in localconfig.js");
        }
        else {
            /* eslint-disable-next-line no-console */
            console.log("No localconfig.js found - using defaults");
        }
    }

    get backendPath() {
        return this.localConfig.backendPath || '/cgi-bin/webui.fcgi'; // Protocol + host/port are prepended automatically
    }

    get copyrightYear() {
        return this.localConfig.copyrightYear || ENV.buildYear;
    }

    get header() {
        return this.localConfig.header;
    }

    get footer() {
        return this.localConfig.footer;
    }
}
