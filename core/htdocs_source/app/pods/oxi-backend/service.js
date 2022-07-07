import Service from '@ember/service';
import { inject } from '@ember/service';
import { debug } from '@ember/debug';
import fetch from 'fetch';
import { assert, optional, enums } from 'superstruct';

/**
 * Provides low level functions to send backend requests.
 *
 * @module service/oxi-backend
 */
export default class OxiBackendService extends Service {
    @inject('intl') intl;

    request({ url, method = 'GET', headers = {}, data, contentType }) {
        // type validation
        assert(method, enums(['GET', 'POST']));

        let params = {
            method,
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
                'X-OPENXPKI-Client': '1',
                ...headers,
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
            if (data) url += '?' + this._toUrlParams(data);
        }

        return fetch(url, params)
        // Network error, thrown by fetch() itself
        .catch(error => {
            this.error = this.intl.t('error_popup.message.network', { reason: error.message });
            console.error('The server connection seems to be lost', error);
            throw error;
        });
    }

    /*
     * Convert plain (not nested!) key => value hash into URL parameter string.
     * Source: https://github.com/zloirock/core-js/blob/master/packages/core-js/modules/web.url-search-params.js
     *
     * TODO: Replace with...
     *
     *     _toUrlParams(data) {
     *         let params = new URLSearchParams();
     *         Object.keys(data).forEach(k => params.set(k, data[k] ?? ''));
     *         return params.toString();
     *     }
     *
     * ...once https://github.com/babel/ember-cli-babel/issues/395 is fixed and we can
     * set up @babel/preset-env to use core-js version 3.x
     */
    _toUrlParams(entries) {
        let result = [];
        let URLPARAM_FIND = /[!'()~]|%20/g;
        let URLPARAM_REPLACE = { '!': '%21', "'": '%27', '(': '%28', ')': '%29', '~': '%7E', '%20': '+' };
        let serialize = v => encodeURIComponent(v ?? '').replace(URLPARAM_FIND, match => URLPARAM_REPLACE[match]);

        Object.keys(entries).forEach(k => result.push(serialize(k) + '=' + serialize(entries[k])));
        return result.join('&');
    }
}
