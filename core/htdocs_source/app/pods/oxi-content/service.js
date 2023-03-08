import Service from '@ember/service';
import { service } from '@ember/service';
import { tracked } from '@glimmer/tracking';
import { later, cancel } from '@ember/runloop';
import { isArray } from '@ember/array';
import { set as emSet } from '@ember/object';
import { debug } from '@ember/debug';
import fetch from 'fetch';

/**
 * Stores the current page contents and state and provides methods to send
 * requests to the backend.
 *
 * @module service/oxi-content
 */
export default class OxiContentService extends Service {
    @service router;
    @service('intl') intl;
    @service('oxi-config') oxiConfig;
    @service('oxi-locale') oxiLocale;
    @service('oxi-backend') backend;

    @tracked user = null;
    @tracked page = null;
    @tracked ping = null;
    @tracked refresh = null;
    @tracked structure = null;
    @tracked rtoken = null;
    @tracked tenant = null;
    @tracked status = null;
    @tracked popup = null;
    @tracked tabs = [];
    @tracked navEntries = [];
    @tracked error = null;
    @tracked loadingBanner = null;
    last_session_id = null; // to track server-side logouts with session id changes
    serverExceptions = []; // custom HTTP response code error handling

    get tenantCssClass() {
        if (!this.tenant) return '';
        return 'tenant-'
          + this.tenant
          .toLowerCase()
          .replace(/[_\s]/g, '-')
          .replace(/[^a-z0-9-]/g, '')
          .replace(/-+/g, '-')
    }

    constructor() {
        super(...arguments);
    }

    /**
     * Send AJAX request quietly, i.e. without showing the "loading" banner or
     * dimming the page.
     *
     * @param {hash} request - Request data
     * @return {Promise} Promise receiving the JSON document on success or `{}` on error
     */
    async updateRequestQuiet(request) {
        return this.updateRequest(request, true)
    }

    /**
     * Send AJAX request.
     *
     * @param {hash} request - Request data
     * @param {bool} isQuiet - set to `true` to hide optical hints (loading banner)
     * @return {Promise} Promise receiving the JSON document on success or `{}` on error
     */
    async updateRequest(request, isQuiet = false) {
        if (! isQuiet) this._setLoadingBanner(this.intl.t('site.banner.loading'))

        if (this.refresh) {
            cancel(this.refresh);
            this.refresh = null;
        }

        let realTarget = this._resolveTarget(request.target) // has to be done before "this.popup = null"

        try {
            let doc = await this._request(request, isQuiet)

            // Errors occured and handlers above returned null
            if (!doc) {
                this._setLoadingBanner(null);
                return {};
            }

            // chain backend calls via Promise
            if (this.isBootstrapNeeded(doc.session_id)) await this.bootstrap()

            // Successful request
            this.status = doc.status
            this.popup = null

            // Auto refresh
            if (doc.refresh) {
                debug("updateRequest(): response - \"refresh\" " + doc.refresh.href + ", " + doc.refresh.timeout)
                this._autoRefreshOnce(doc.refresh.href, doc.refresh.timeout)
            }

            // Redirect
            if (doc.goto) {
                debug("updateRequest(): response - \"goto\" " + doc.goto)
                this._redirect(doc.goto, doc.type, doc.loading_banner)
                return doc
            }

            // Set page contents
            if (doc.page || doc.main || doc.right) {
                debug("updateRequest(): response - \"page\" and \"main\"")
                this._setPageContent(realTarget, doc.page, doc.main, doc.right, doc.status)
            }
            // or (e.g. on error) set error code for current tab
            else {
                if (doc.status && this.tabs.length > 0) {
                    let currentTab = this.tabs.findBy("active") // findBy() is an EmberArray method
                    emSet(currentTab, 'status', doc.status)
                }
            }

            this._setLoadingBanner(null)
            return doc // the calling code might handle other data
        }
        // Client side error
        catch (error) {
            this._setLoadingBanner(null)
            console.error('There was an error while processing the data', error)
            this.error = this.intl.t('error_popup.message.client', { reason: error })
            return null
        }
    }

    isBootstrapNeeded(session_id) {
        let last_id = this.last_session_id
        if (session_id) this.last_session_id = session_id;

        // did server-side session change (e.g. user was logged out due to timeout)?
        if (last_id) {
            if (session_id && session_id !== last_id) {
                debug('Bootstrap needed: session ID changed')
                return true
            }
        }
        else {
            debug('Bootstrap needed: first backend call')
            return true
        }
        return false
    }

    // "Bootstrapping" - menu, user info, locale, ...
    async bootstrap() {
        let doc = await this._request({
            page: "bootstrap!structure",
            baseurl: window.location.pathname,
        }, true)

        debug("bootstrap(): response")

        if (doc.rtoken) this.rtoken = doc.rtoken // CSRF token
        if (doc.language) this.oxiLocale.locale = doc.language
        this.user = doc.user // this also unsets the user on logout!

        // do not overwrite current tenant on repeated bootstrapping
        if (this.tenant === null && doc.tenant) this.setTenant(doc.tenant)

        // menu
        if (doc.structure) {
            this.navEntries = doc.structure
            this._refreshNavEntries()
        }

        // keepalive ping
        if (doc.ping) {
            debug("bootstrap(): setting ping = " + doc.ping)
            if (this.ping) cancel(this.ping)
            this._ping(doc.ping)
        }

        // custom HTTP error code handling
        if (doc.on_exception) this.serverExceptions = doc.on_exception

        return doc
    }

    async _request(request, isQuiet = false) {
        debug("_request(" + ['page','action'].map(p=>request[p]?`${p} = ${request[p]}`:null).filter(e=>e!==null).join(", ") + ")")

        let data = {
            ...request,
            '_': new Date().getTime(),
        }
        let url = this.oxiConfig.backendUrl

        // POST
        let method
        if (request.action) {
            method = 'POST'
            data = { ...data, _rtoken: this.rtoken }
        }
        // GET
        else {
            method = 'GET'
        }
        if (this.tenant) {
            data = { ...data, _tenant: this.tenant }
        }

        let response
        try { response = await this.backend.request({ url, method, data }) }
        catch (err) {
            // Network error, thrown by fetch() itself
            this.error = this.intl.t('error_popup.message.network', { reason: err.message })
            return null
        }

        // If OK: unpack JSON data
        if (response?.ok) {
            return response.json()
        }
        // Handle non-2xx HTTP status codes
        else {
            this._handleServerException(response.status)
            return null
        }
    }

    setPage(page) {
        this.page = page;
        this._refreshNavEntries();
    }

    setTenant(tenant) {
        this.tenant = tenant;
    }

    _resolveTarget(requestTarget) {
        let target = requestTarget || 'self';
        // Pseudo-target "self" is transformed so new content will be shown in the
        // currently active place: a modal popup, an active tab or on top (i.e. single hidden tab)
        if (target === 'self') {
            if (this.popup) { target = 'popup' }
            else if (this.tabs.length > 1) { target = 'active' }
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
        // trigger on route changes, but not if we do updateRequest()
        if (message) {
            // remove focus from button to prevent user from doing another
            // submit by hitting enter
            document.activeElement.blur();
        }
        this.loadingBanner = message;
    }

    _ping(href, timeout) {
        this.ping = later(this, () => {
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
        this.refresh = later(this, function() {
            this.updateRequest({ page: href });
        }, timeout);
    }

    _redirect(url, type = 'internal', banner = this.intl.t('site.banner.redirecting')) {
        if (type == 'external' || /^(http|\/)/.test(url)) {
            this._setLoadingBanner(banner); // never hide banner as browser will open a new page
            window.location.href = url;
        }
        else {
            this.router.transitionTo("openxpki", url);
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
                    this.error = handler.message;
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
        this.error = this.intl.t('error_popup.message.server', { code: status_code });
    }

    _setPageContent(target, page, main, right, status) {
        let newTab = {
            active: true,
            page,
            main,
            right,
            status,
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
            this.popup = newTab;
        }
        // New tab
        else if (target === "tab") {
            let tabs = this.tabs;
            tabs.setEach("active", false);
            tabs.pushObject(newTab);
        }
        // Current tab
        else if (target === "active") {
            let tabs = this.tabs;
            let index = tabs.indexOf(tabs.findBy("active")); // findBy() is an EmberArray method
            tabs.replace(index, 1, [newTab]); // top
        }
        // Set as only tab
        else {
            this.tabs = [newTab];
        }
    }

    _refreshNavEntries() {
        let page = this.page;
        for (const entry of this.navEntries) {
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
        this.navEntries = this.navEntries; // eslint-disable-line no-self-assign -- trigger Ember update
    }
}
