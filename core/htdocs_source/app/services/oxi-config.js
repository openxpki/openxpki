import Service from '@ember/service'
import { tracked } from '@glimmer/tracking'
import ENV from 'openxpki/config/environment'
import fetch from 'fetch'
import yaml from 'js-yaml'

/**
 * Loads the YAML configuration from the backend and makes it available to
 * the other components.
 *
 * @module service/oxi-config
 */
export default class OxiConfigService extends Service {
    @tracked localConfig = {}
    ready // will be set to a Promise that will fulfill if localconfig.yaml is loaded (or server returned error)

    constructor() {
        super(...arguments)

        // load custom YAML config
        let url = this.#rel2absUrl('localconfig.yaml')
        this.ready = this.#loadRemote(url)
            .then( yamlStr => {
                console.debug(`Custom config (YAML):\n${yamlStr}`)
                if (! yamlStr) return
                try {
                    let doc = yaml.load(yamlStr) // might be null if YAML is empty string
                    if (doc) this.localConfig = doc
                    console.debug('Custom config (decoded):', this.localConfig)
                }
                catch (err) {
                    /* eslint-disable-next-line no-console */
                    console.error(`Error parsing localconfig.yaml:\n${err}`)
                }
            } )
            .catch( () => {} ) // ignore errors as they were logged in #loadRemote()
    }

    // Tries to load the given url.
    // Returns a Promise.
    #loadRemote(url) {
        return fetch(url)
        .then(response => {
            if (response.ok) {
                /* eslint-disable-next-line no-console */
                console.log(`Using custom configuration: ${url}`)
                return response.text()
            }
            else {
                if (response.status === 404) {
                    /* eslint-disable-next-line no-console */
                    console.info(`No ${url} provided - using defaults`)
                }
                else {
                    /* eslint-disable-next-line no-console */
                    console.error(`Error loading ${url} (server error: ${response.status})`)
                }
                return null
            }
        })
        .catch(error => {
            /* eslint-disable-next-line no-console */
            console.error(`Error loading ${url} (network error: ${error.name})`)
        })
    }

    // Takes the given absolute or relative path and returns a URL
    #rel2absUrl(path) {
        let baseUrl = window.location.protocol + '//' + window.location.host

        // add current path if given path is relative
        if (! path.match(/^\//)) baseUrl += window.location.pathname
        return baseUrl.replace(/(tests)?\/?$/, '') + '/' + path.replace(/^\//, '')
    }

    get backendUrl() {
        // default to relative path to support URL-based realms
        let path = this.localConfig.backendPath || 'cgi-bin/webui.fcgi'
        return this.#rel2absUrl(path)
    }

    get customCSSUrl() {
        let url = this.localConfig.customCSSPath ?? this.localConfig.customCssPath
        if (!url) return null
        let absUrl = this.#rel2absUrl(url)
        /* eslint-disable-next-line no-console */
        console.log(`Loading custom CSS file: ${absUrl}`)
        return absUrl
    }

    get customCSS() {
        let css = this.localConfig.customCSS
        if (! css) return null
        console.log(`Injecting custom CSS:`, css)
        return css
    }

    get copyrightYear() {
        return this.localConfig.copyrightYear || ENV.buildYear
    }

    get header() {
        let header = this.localConfig.header
        // if YAML parameter 'header' is an object
        if ( typeof header === 'object' && !Array.isArray(header) && header !== null) {
            return this.localConfig.header
        }
        return null
    }

    get oldHeader() {
        // if YAML parameter 'header' is a string (or undefined)
        if (!this.header && this.localConfig.header) {
            /* eslint-disable-next-line no-console */
            console.warn("Deprecation warning: Parameter 'header' in localconfig.yaml is now expected to be a hash structure. Please consult the latest localconfig.yaml.template")
            return this.localConfig.header
        }
        return null
    }

    get footer() {
        return this.localConfig.footer
    }

    get pageTitle() {
        return this.localConfig.pageTitle || 'OpenXPKI - Open Source Trustcenter'
    }

    get tooltipDelay() {
        let rawDelay = this.localConfig.accessibility?.tooltipDelay
        let delay = Number.parseInt(rawDelay)
        if (!Number.isInteger(delay)) {
            if (rawDelay !== undefined) {
                console.warn("Configuration item 'accessibility.tooltipDelay' in localconfig.yaml is not a number: ", rawDelay)
            }
            return 500
        }
        return delay
    }
}
