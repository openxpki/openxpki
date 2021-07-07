import Route from '@ember/routing/route';
import { tracked } from '@glimmer/tracking';
import { later, cancel } from '@ember/runloop';
import { Promise } from 'rsvp';
import { set as emSet } from '@ember/object';
import { inject as service } from '@ember/service';
import { isArray } from '@ember/array';
import { debug } from '@ember/debug';
import fetch from 'fetch';

class Content {
    @tracked user = null;
    @tracked page = null;
    @tracked ping = null;
    @tracked refresh = null;
    @tracked structure = null;
    @tracked rtoken = null;
    @tracked status = null;
    @tracked popup = null;
    @tracked tabs = [];
    @tracked navEntries = [];
    @tracked error = null;
    @tracked loadingBanner = null;
}

/**
 * @module
 */
export default class OpenXpkiRoute extends Route {
    @service('oxi-config') oxiConfig;
    @service('oxi-locale') oxiLocale;
    @service('intl') intl;

    // Reserved Ember property "queryParams"
    // https://api.emberjs.com/ember/3.17/classes/Route/properties/queryParams?anchor=queryParams
    queryParams = {
        // refreshModel==true causes an "in-place" transition, so the model
        // hooks for this route (and any child routes) will re-fire
        startat:  { refreshModel: true },
        limit:    { refreshModel: true },
        force:    { refreshModel: true },
    };
    needReboot = ["login", "logout", "login!logout", "welcome"];

    content = new Content();
    /*
    Custom handlers for exceptions returned by the server (HTTP status codes):
        [
            {
                status_code: [ 403, ... ], // array or string
                redirect: "https://...",
            },
            { ... }
        ]
    */
    serverExceptions = [];

    // Reserved Ember function
    beforeModel(transition) {
        let queryParams = transition.to.queryParams;
        let modelId = transition.to.params.model_id;
        debug("openxpki/route - beforeModel: model_id = " + modelId);

        // "force" is only evaluated above using "refreshModel: true"
        if (queryParams.force) {
            delete queryParams.force;
        }

        let structureIfNeeded; // chain of ajax calls via Promises

        /*
         * load base page structure first first time or for special pages ("needReboot")
         */
        if (!this.content.navEntries.length || this.needReboot.indexOf(modelId) >= 0) {
            // don't send request yet, only create a lambda via arrow function expression
            structureIfNeeded = () => {
                return this.sendAjax({
                    page: "bootstrap!structure",
                    baseurl: window.location.pathname,
                });
            };
        }
        else {
            structureIfNeeded = () => { Promise.resolve() };
        }

        /*
         * load requested page part
         */
        let request = {
            page: modelId
        };
        if (queryParams.limit) { request.limit = queryParams.limit }
        if (queryParams.startat) { request.startat = queryParams.startat }

        // load as top content if 'modelId' is part of navigation or in 'needReboot' list
        let flatList = this.content.navEntries.reduce((p, n) => p.concat(n, n.entries || []), []);
        if (flatList.findBy("key", modelId) || this.needReboot.indexOf(modelId) >= 0) {
            request.target = "top";
        }
        return this.oxiConfig.ready // localconfig.js might change rootURL, so first thing is to query it
            .then( () => structureIfNeeded() )
            .then( () => this.sendAjax(request) );
    }

    // Reserved Ember function
    model(params/*, transition*/) {
        this.content.page = params.model_id; this._updateNavEntryActiveState(this.content);
        return this.content;
    }

    /**
     * Send AJAX request quietly, i.e. without showing the "loading" banner or
     * dimming the page.
     *
     * @param {hash} request - Request data
     * @return {Promise} Promise receiving the JSON document on success or `{}` on error
     */
    sendAjaxQuiet(request) {
        return this.sendAjax(request, true);
    }

    /**
     * Send AJAX request.
     *
     * @param {hash} request - Request data
     * @param {bool} isQuiet - set to `true` to hide optical hints (loading banner)
     * @return {Promise} Promise receiving the JSON document on success or `{}` on error
     */
    sendAjax(request, isQuiet = false) {
        if (! isQuiet) this._setLoadingBanner(this.intl.t('site.banner.loading'));
        debug("openxpki/route - sendAjax: " + ['page','action'].map(p=>request[p]?`${p} = ${request[p]}`:null).filter(e=>e!==null).join(", "));

        if (this.content.refresh) {
            cancel(this.content.refresh);
            this.content.refresh = null;
        }

        let realTarget = this._resolveTarget(request.target); // has to be done before "this.content.popup = null"

        let data = {
            ...request,
            '_': new Date().getTime(),
        }
        let url = this.oxiConfig.backendUrl;
        let fetchParams = {
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
                'X-OPENXPKI-Client': '1',
            },
        };

        // POST
        if (request.action) {
            fetchParams.method = "POST";
            fetchParams.headers['Content-Type'] = 'application/json';
            fetchParams.body = JSON.stringify({
                ...data,
                _rtoken: this.content.rtoken,
            });
        }
        // GET
        else {
            fetchParams.method = "GET";
            fetchParams.headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8';
            url += '?' + this._toUrlParams(data);
        }

        return fetch(url, fetchParams)
        .then(response => {
            // If OK: unpack JSON data
            if (response.ok) {
                return response.json();
            }
            // Handle non-2xx HTTP status codes
            else {
                this._handleServerException(response.status);
                return null;
            }
        })
        // Network error, thrown by fetch() itself
        .catch(error => {
            this._setLoadingBanner(null);
            console.error('The server connection seems to be lost', error);
            this.content.error = this.intl.t('error_popup.message.network', { reason: error.message });
            return null;
        })
        .then(doc => {
            // Errors occured and handlers above returned null
            if (!doc) return {};

            // Successful request
            this.content.status = doc.status;
            this.content.popup = null;

            // Ping
            if (doc.ping) {
                debug("openxpki/route - sendAjax response: \"ping\" " + doc.ping);
                if (this.content.ping) { cancel(this.content.ping) }
                this._ping(doc.ping);
            }

            // Auto refresh
            if (doc.refresh) {
                debug("openxpki/route - sendAjax response: \"refresh\" " + doc.refresh.href + ", " + doc.refresh.timeout);
                this._autoRefreshOnce(doc.refresh.href, doc.refresh.timeout);
            }

            // Redirect
            if (doc.goto) {
                debug("openxpki/route - sendAjax response: \"goto\" " + doc.goto);
                this._redirect(doc.goto, doc.type, doc.loading_banner);
                return doc;
            }

            // "Bootstrapping" - menu, user info, locale
            if (doc.structure) {
                debug("openxpki/route - sendAjax response: \"structure\"");
                this.content.navEntries = doc.structure; this._updateNavEntryActiveState();
                this.content.user = doc.user;
                this.content.rtoken = doc.rtoken;

                // set locale
                if (doc.language) this.oxiLocale.locale = doc.language;

                // set custom exception handling
                if (doc.on_exception) this.serverExceptions = doc.on_exception;
            }
            // Page contents
            else {
                if (doc.page && doc.main) {
                    debug("openxpki/route - sendAjax response: \"page\" and \"main\"");
                    this._setPageContent(realTarget, doc.page, doc.main, doc.right);
                }
            }

            this._setLoadingBanner(null);
            return doc; // calling code might handle other data
        })
        // Client side error
        .catch(error => {
            this._setLoadingBanner(null);
            console.error('There was an error while processing the data', error);
            this.content.error = this.intl.t('error_popup.message.client', { reason: error });
            return null;
        })
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

    _resolveTarget(requestTarget) {
        let target = requestTarget || 'self';
        // Pseudo-target "self" is transformed so new content will be shown in the
        // currently active place: a modal popup, an active tab or on top (i.e. single hidden tab)
        if (target === 'self') {
            if (this.content.popup) { target = 'popup' }
            else if (this.content.tabs.length > 1) { target = 'active' }
            else { target = 'top' }
        }
        if (target === 'modal') target = 'popup'; // FIXME remove support for legacy target 'modal'
        return target;
    }

    // Sets the loading state, i.e. dims the page and shows a banner with the
    // given message.
    // If 'message' is set to null, the banner will be hidden.
    _setLoadingBanner(message) {
        // note that we cannot use the Ember "loading" event as this would only
        // trigger on route changes, but not if we do sendAjax()
        if (message) {
            // remove focus from button to prevent user from doing another
            // submit by hitting enter
            document.activeElement.blur();
        }
        this.content.loadingBanner = message;
    }

    _ping(href, timeout) {
        this.content.ping = later(this, () => {
            fetch(href, {
                headers: {
                    'X-Requested-With': 'XMLHttpRequest',
                    'X-OPENXPKI-Client': '1',
                },
            })
            .catch(error => {
                /* eslint-disable-next-line no-console */
                console.error(`Error loading ${href} (network error: ${error.name})`);
            });
            return this._ping(href, timeout);
        }, timeout);
    }

    _autoRefreshOnce(href, timeout) {
        this.content.refresh = later(this, function() {
            this.sendAjax({ page: href });
        }, timeout);
    }

    _redirect(url, type = 'internal', banner = this.intl.t('site.banner.redirecting')) {
        if (type == 'external' || /^(http|\/)/.test(url)) {
            this._setLoadingBanner(banner); // never hide banner as browser will open a new page
            window.location.href = url;
        }
        else {
            this.transitionTo("openxpki", url);
        }
    }

    // Apply custom exception handler for given status code if one was set up
    // (bootstrap parameter 'on_exception').
    _handleServerException(status_code) {
        debug(`Exception - handling server HTTP status code: ${status_code}`);
        // Check custom exception handlers
        for (let handler of this.serverExceptions) {
            let codes = isArray(handler.status_code) ? handler.status_code : [ handler.status_code ];
            if (codes.find(c => c == status_code)) {
                // Show message
                if (handler.message) {
                    this._setLoadingBanner(null);
                    console.error(handler.message);
                    this.content.error = handler.message;
                }
                // Redirect
                else if (handler.redirect) {
                    // we intentionally do NOT remove the loading banner here
                    debug(`Exception - redirecting to ${handler.redirect}`);
                    this._redirect(handler.redirect);
                }
                return;
            }
        }
        // Unhandled exception
        this._setLoadingBanner(null);
        console.error(`Server did not return expected data: ${status_code}`);
        this.content.error = this.intl.t('error_popup.message.server', { code: status_code });
    }

    _setPageContent(target, page, main, right) {
        let newTab = {
            active: true,
            page: page,
            main: main,
            right: right
        };

        // Mark the first form on screen: only the first one is allowed to focus
        // its first input field.
        let isFirst = true;
        for (const section of [...(newTab.main||[]), ...(newTab.right||[])]) {
            if (section.type === "form") {
                section.content.isFirstForm = isFirst;
                if (isFirst) isFirst = false;
            }
        }

        // Popup
        if (target === "popup") {
            this.content.popup = newTab;
        }
        // New tab
        else if (target === "tab") {
            let tabs = this.content.tabs;
            tabs.setEach("active", false);
            tabs.pushObject(newTab);
        }
        // Current tab
        else if (target === "active") {
            let tabs = this.content.tabs;
            let index = tabs.indexOf(tabs.findBy("active"));
            tabs.replace(index, 1, [newTab]); // top
        }
        // Set as only tab
        else {
            this.content.tabs = [newTab];
        }
    }

    _updateNavEntryActiveState() {
        let page = this.content.page;
        for (const entry of this.content.navEntries) {
            emSet(entry, "active", (entry.key === page));
            if (entry.entries) {
                entry.entries.setEach("active", false);
                let subEntry = entry.entries.findBy("key", page);
                if (subEntry) {
                    emSet(subEntry, "active", true);
                    emSet(entry, "active", true);
                }
            }
        }
        this.content.navEntries = this.content.navEntries; // trigger updates
    }
}