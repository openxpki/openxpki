import Service from '@ember/service';
import ENV from 'openxpki/config/environment';
import { tracked } from '@glimmer/tracking';
import fetch from 'fetch';
import { isNotFoundResponse } from 'ember-fetch/errors';
import yaml from 'js-yaml';

export default class OxiConfigService extends Service {
    localConfig = {};
    ready; // will be set to a Promise that will fulfill if localconfig.js is loaded (or server returned error)
    @tracked localCSS;

    constructor() {
        super(...arguments);

        // load custom YAML config
        this.ready = this._loadRemote('localconfig.yaml')
            .then( yamlStr => {
                try {
                    let doc = yaml.safeLoad(yamlStr);
                    this.localConfig = doc;
                }
                catch (err) {
                    /* eslint-disable-next-line no-console */
                    console.error(`Error parsing localconfig.yaml:\n${err}`);
                }
            } )
            .catch( () => {} ); // ignore errors as they were logged in _loadRemote()

        // load custom CSS
        this._loadRemote('localconfig.css')
        .then( css => this.localCSS = css )
        .catch( () => {} ); // ignore errors as they were logged in _loadRemote()
    }

    // Tries to load the given file below server root URL.
    // Returns a Promise.
    _loadRemote(file) {
        let rootURL = ENV.rootURL.replace(/\/$/, '');
        return fetch(`${rootURL}/${file}`)
        .then(response => {
            if (response.ok) {
                /* eslint-disable-next-line no-console */
                console.log(`Using custom configuration ${file}`);
                return response.text()
            }
            else {
                if (isNotFoundResponse(response)) {
                    /* eslint-disable-next-line no-console */
                    console.info(`No ${file} provided - using defaults`);
                }
                else {
                    /* eslint-disable-next-line no-console */
                    console.error(`Error loading ${file} (server error: ${response.status})`);
                }
                return null;
            }
        })
        .catch(error => {
            /* eslint-disable-next-line no-console */
            console.error(`Error loading ${file} (network error: ${error.name})`);
        });
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
