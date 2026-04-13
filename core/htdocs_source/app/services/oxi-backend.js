import Service from '@ember/service';
import { service } from '@ember/service';
import ENV from 'openxpki/config/environment';
//import { assert, optional, enums } from 'superstruct';

/**
 * Provides low level functions to send backend requests.
 *
 * @module service/oxi-backend
 */
export default class OxiBackendService extends Service {
    /**
     * Send an HTTP request to the given URL.
     *
     * For `GET` requests, `data` is serialized as URL query parameters.
     * For `POST` requests, `data` is sent as JSON body (default) or with the
     * given `contentType`.
     *
     * Always adds `X-Requested-With` and `X-OPENXPKI-Client` headers. In
     * development mode also adds `X-OpenXPKI-Ember-HTTP-Proxy` so the backend
     * skips the `Secure` cookie flag when running behind the HTTP dev proxy.
     *
     * @param { object } params
     * @param { string } params.url - Request URL
     * @param { string } [params.method] - HTTP method. Default: `'GET'`
     * @param { object } [params.headers] - Additional HTTP headers
     * @param { object } [params.data] - Request payload / query parameters
     * @param { string } [params.contentType] - Content-Type for POST requests. Default: `'application/json'`
     * @returns {Promise<Response>} Fetch `Response` promise; network errors are logged and re-thrown
     */
    request({ url, method = 'GET', headers = {}, data, contentType }) {
        // type validation
        //assert(method, enums(['GET', 'POST']));

        /* In development mode we assume we run the Ember HTTP Proxy (i.e. no TLS):
           this header is a flag that tells the Perl UI to skip "secure" option in cookie
           so it will work with the insecure proxy. */
        let devHeader = ENV.environment == "development" ? { 'X-OpenXPKI-Ember-HTTP-Proxy' : '1' } : {};

        let params = {
            method,
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
                'X-OPENXPKI-Client': '1',
                ...headers,
                ...devHeader,
            },
        };

        if (method == 'POST') {
            // type validation
            //ow(contentType, optional(enums(['application/json'])));

            contentType ||= 'application/json';
            params.headers['Content-Type'] = contentType;

            if (contentType == 'application/json') {
                params.body = JSON.stringify(data);
            }

        }

        if (method == 'GET') {
            if (data) url += '?' + this.#toUrlParams(data);
        }

        return fetch(url, params)
        // Log and rethrow network errors
        .catch(error => {
            console.error('The server connection seems to be lost:', error);
            throw error;
        });
    }

    /*
     * Convert plain (not nested!) key => value hash into URL parameter string.
     * Source: https://github.com/zloirock/core-js/blob/master/packages/core-js/modules/web.url-search-params.js
     *
     * TODO: Replace with...
     *
     *     #toUrlParams(data) {
     *         let params = new URLSearchParams();
     *         Object.keys(data).forEach(k => params.set(k, data[k] ?? ''));
     *         return params.toString();
     *     }
     *
     * ...once https://github.com/babel/ember-cli-babel/issues/395 is fixed and we can
     * set up @babel/preset-env to use core-js version 3.x
     */
    #toUrlParams(entries) {
        let result = [];
        let URLPARAM_FIND = /[!'()~]|%20/g;
        let URLPARAM_REPLACE = { '!': '%21', "'": '%27', '(': '%28', ')': '%29', '~': '%7E', '%20': '+' };
        let serialize = v => encodeURIComponent(v ?? '').replace(URLPARAM_FIND, match => URLPARAM_REPLACE[match]);

        Object.keys(entries).forEach(k => result.push(serialize(k) + '=' + serialize(entries[k])));
        return result.join('&');
    }
}
