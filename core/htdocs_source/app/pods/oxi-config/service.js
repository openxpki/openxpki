import Service from '@ember/service';
import ENV from 'openxpki/config/environment';

export default class OxiConfigService extends Service {
    localConfig = {};

    constructor() {
        super(...arguments);
        if (typeof OXI_LOCALCONFIG !== 'undefined') {
            this.localConfig = OXI_LOCALCONFIG;
            console.log("Using custom configuration in localconfig.js");
        }
        else {
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
