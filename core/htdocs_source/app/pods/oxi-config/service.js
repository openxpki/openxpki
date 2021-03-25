import Service from '@ember/service';
import ENV from 'openxpki/config/environment';
import fetch from 'fetch';
import yaml from 'js-yaml';

export default class OxiConfigService extends Service {
    localConfig = {};
    ready; // will be set to a Promise that will fulfill if localconfig.js is loaded (or server returned error)

    constructor() {
        super(...arguments);

        // load custom YAML config
        let url = ENV.rootURL.replace(/\/$/, '') + '/localconfig.yaml';
        this.ready = this._loadRemote(url)
            .then( yamlStr => {
                if (! yamlStr) return;
                try {
                    let doc = yaml.safeLoad(yamlStr); // might be null if YAML is empty string
                    if (doc) this.localConfig = doc;
                }
                catch (err) {
                    /* eslint-disable-next-line no-console */
                    console.error(`Error parsing localconfig.yaml:\n${err}`);
                }
            } )
            .catch( () => {} ); // ignore errors as they were logged in _loadRemote()
    }

    // Tries to load the given url.
    // Returns a Promise.
    _loadRemote(url) {
        return fetch(url)
        .then(response => {
            if (response.ok) {
                /* eslint-disable-next-line no-console */
                console.log(`Using custom configuration: ${url}`);
                return response.text()
            }
            else {
                if (response.status === 404) {
                    /* eslint-disable-next-line no-console */
                    console.info(`No ${url} provided - using defaults`);
                }
                else {
                    /* eslint-disable-next-line no-console */
                    console.error(`Error loading ${url} (server error: ${response.status})`);
                }
                return null;
            }
        })
        .catch(error => {
            /* eslint-disable-next-line no-console */
            console.error(`Error loading ${url} (network error: ${error.name})`);
        });
    }

    _rel2absUrl(relativeUrl) {
        let baseUrl = window.location.protocol + '//' + window.location.host;
        // if relativeUrl contains leading slash, treat it as absolute path
        if (! relativeUrl.match(/^\//)) baseUrl += window.location.pathname;
        return baseUrl.replace(/\/$/, '') + '/' + relativeUrl.replace(/^\//, '');

    }

    get backendUrl() {
        let path = this.localConfig.backendPath || '/cgi-bin/webui.fcgi';
        return this._rel2absUrl(path);
    }

    get customCssUrl() {
        if (! this.localConfig.customCssPath) return null;
        let absUrl = this._rel2absUrl(this.localConfig.customCssPath);
        /* eslint-disable-next-line no-console */
        console.log(`Custom CSS file configured: ${absUrl}`);
        return absUrl;
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
