import Service from '@ember/service';

export default class OxiConfigService extends Service {
    localConfig = {};

    constructor() {
        super(...arguments);
        try {
            this.localConfig = require('../../localconfig');
        }
        catch (e) {
            if (e.message.match(/Could not find module/)) {
                console.log("No localconfig.js found - using defaults")
            }
            else {
                throw e
            };
        }
    }

    get backendPath() {
        return this.localConfig.backendPath || 'cgi-bin/webui.fcgi'; // Protocol + host are prepended automatically
    }
}
