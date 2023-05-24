import Service from '@ember/service'
import { service } from '@ember/service'
import { tracked } from '@glimmer/tracking'
import { later, next, cancel } from '@ember/runloop'
import { isArray } from '@ember/array'
import { action, set as emSet } from '@ember/object'
import { debug } from '@ember/debug'
import fetch from 'fetch'
import Page from 'openxpki/data/page'

/**
 * Stores the current page contents and state and provides methods to send
 * requests to the backend.
 *
 * @module service/oxi-content
 */
export default class OxiContentService extends Service {
    @service router
    @service('intl') intl
    @service('oxi-config') oxiConfig
    @service('oxi-locale') oxiLocale
    @service('oxi-backend') backend

    @tracked user = null
    @tracked navEntries = []
    @tracked pingTimer = null
    @tracked refreshTimer = null
    @tracked structure = null
    #rtoken = null
    @tracked tenant = null
    @tracked status = null

    @tracked top = null
    @tracked popup = null
    @tracked breadcrumbs = []

    @tracked error = null
    @tracked loadingBanner = null
    last_session_id = null // to track server-side logouts with session id changes
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
    serverExceptions = [] // custom HTTP response code error handling


    TARGET = Object.freeze({
        TOP: Symbol("TOP"),
        POPUP: Symbol("POPUP"),
        BLANK: Symbol("BLANK"),
    })

    get tenantCssClass() {
        if (!this.tenant) return ''
        return 'tenant-'
          + this.tenant
          .toLowerCase()
          .replace(/[_\s]/g, '-')
          .replace(/[^a-z0-9-]/g, '')
          .replace(/-+/g, '-')
    }

    constructor() {
        super(...arguments)
    }

    /**
     * Send AJAX request quietly, i.e. without showing the "loading" banner or
     * dimming the page.
     *
     * @param {hash} request - Request data
     * @param {hash} options - Set `{ verbose: true }` to show loading banner
     * @return {Promise} Promise receiving the JSON document on success or `{}` on error
     */
    async requestUpdate(request, { verbose = false } = {}) {
        return this.requestPage(request, { verbose, partial: true })
    }

    /**
     * Send AJAX request.
     *
     * @param {hash} request - Request data
     * @param {hash} options - Set `{ verbose: true }` to show loading banner. Set `{ partial: true }` to prevent resetting the whole page
     * @return {Promise} Promise receiving the JSON document on success or `{}` on error
     */
    async requestPage(request, { partial = false, verbose = true, ignoreBreadcrumbs = false } = {}) {
        debug(`requestPage({ ..., target = ${typeof request.target == 'symbol' ? request.target.toString() : request.target} }, partial = ${partial ? true : false}, verbose = ${verbose ? true : false})`)
        if (verbose) this.#setLoadingBanner(this.intl.t('site.banner.loading'))

        if (this.refreshTimer) {
            cancel(this.refreshTimer)
            this.refreshTimer = null
        }

        // resolve target
        let realTarget = this.#resolveTarget(request.target)
        delete request.target // may already be a Symbol (our fake enum) which we cannot send to the backend

        try {
            let doc = await this.#request(request)

            // Errors occured and handlers above returned null
            if (!doc) {
                this.#setLoadingBanner(null)
                return {}
            }

            // chain backend calls via Promise
            if (this.#isBootstrapNeeded(doc.session_id)) await this.#bootstrap()

            // last request sets the global status, whether it's a "top" or "popup" target
            this.status = doc.status

            // Popup
            if (realTarget === this.TARGET.POPUP) {
                if (doc.refresh || doc.goto) console.warn("'refresh'/'goto' not supported for popup contents")
            }
            // Page
            else {
                this.popup = null

                // Auto refresh
                if (doc.refresh) {
                    debug("requestPage(): response - \"refresh\" " + doc.refresh.href + ", " + doc.refresh.timeout)
                    this.#autoRefreshOnce(doc.refresh.href, doc.refresh.timeout)
                }

                // Redirect
                if (doc.goto) {
                    debug("requestPage(): response - \"goto\" " + doc.goto)
                    return this.#redirect(doc.goto, realTarget, doc.type, doc.loading_banner)
                }
            }

            // Set page contents
            this.#setPageContent(realTarget, request.page, doc.page, doc.main, doc.right, partial, ignoreBreadcrumbs)

            if (realTarget === this.TARGET.TOP) this.#refreshNavEntries()

            this.#setLoadingBanner(null)
            return doc // the calling code might handle other data
        }
        // Client side error
        catch (error) {
            this.#setLoadingBanner(null)
            console.error('There was an error while processing the data', error)
            this.error = this.intl.t('error_popup.message.client', { reason: error })
            return null
        }
    }

    openPage(name, target, force = false, params = null) {
        debug(`openPage(name = ${name}, target = ${typeof target == 'symbol' ? target.toString() : target}, force = ${force})`)

        if (this.#resolveTarget(target) == this.TARGET.POPUP) {
            debug(`Transitioning to ${this.router.urlFor('openxpki.popup', name)}`)
            return this.router.transitionTo('openxpki.popup', name, {
                queryParams: {
                    ...params,
                    /*
                     * Set popupBackButton=true if there is a previous popup page.
                     * We must alway set the parameter even if it is "false"
                     * and not just omit it because Ember keeps the controller
                     * objects like the popup page. If we would not set it to
                     * "false" on opening a new popup the old state in the
                     * existing popup controller would be reused.
                     */
                    popupBackButton: (this.popup ? true : false),
                },
            })
        }
        else {
            // close popup
            this.popup = null
            // this transition also removes the popup related data from the URL
            debug(`Transitioning to ${this.router.urlFor('openxpki', name)}`)
            return this.router.transitionTo('openxpki', name, {
                queryParams: {
                    ...params,
                    ...(force && { force: (new Date()).valueOf() }),
                }
            })
        }
    }

    openLink(href, target) {
        debug(`openLink(href = ${href}, target = ${typeof target == 'symbol' ? target.toString() : target})`)

        // close popup
        this.popup = null

        // open link
        let realTarget = this.#resolveTarget(target, true)
        window.open(href, realTarget == this.TARGET.TOP ? '_self' : '_blank')
    }

    @action
    closePopup() {
        // close popup
        this.popup = null
        // transition to current route (keeps the current model/page) but without the "popup" part
        return this.router.transitionTo('openxpki')
    }

    @action
    gotoBreadcrumb(bc) {
        let i = this.breadcrumbs.findIndex(el => el === bc)
        debug(`Navigating to breadcrumb #${i}: ${bc.page}`)
        // cut breadcrumbs list back to the one we're navigating to
        this.breadcrumbs = this.breadcrumbs.slice(0, i+1)
        // open breadcrumb's page
        this.openPage(bc.page, this.TARGET.TOP, false, { breadcrumbAction: 1 })
    }

    #resolveTarget(rawTarget = 'self', isLink) {
        let target = (typeof rawTarget == 'symbol') ? rawTarget : null

        // Pseudo-target "self" leads to content being shown in the currently active place.
        if (rawTarget === 'self') target = this.popup ? this.TARGET.POPUP : this.TARGET.TOP
        if (rawTarget === 'top') target = this.TARGET.TOP
        if (rawTarget === 'popup') target = this.TARGET.POPUP
        if (rawTarget === 'modal') target = this.TARGET.POPUP // FIXME remove support for legacy target 'modal'

        /* eslint-disable-next-line no-console */
        if (target === null) console.warn(`Invalid page/action/link target found: "${rawTarget}"`)

        // Links are always opened as "top", i.e. they replace the current URL
        if (isLink && target == this.TARGET.POPUP) target = this.TARGET.TOP

        return target
    }

    #isBootstrapNeeded(session_id) {
        let last_id = this.last_session_id
        if (session_id) this.last_session_id = session_id

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
    async #bootstrap() {
        debug("#bootstrap()")
        let doc = await this.#request({
            page: "bootstrap!structure",
            baseurl: window.location.pathname,
        }, true)


        if (doc.rtoken) this.#rtoken = doc.rtoken // CSRF token
        if (doc.language) this.oxiLocale.locale = doc.language
        this.user = doc.user // this also unsets the user on logout!

        // do not overwrite current tenant on repeated bootstrapping
        if (this.tenant === null && doc.tenant) this.setTenant(doc.tenant)

        // menu
        if (doc.structure) {
            this.navEntries = doc.structure
            this.#refreshNavEntries()
        }

        // keepalive ping
        if (doc.ping) {
            debug("#bootstrap(): setting ping = " + doc.ping)
            this.#ping(doc.ping)
        }

        // custom HTTP error code handling
        if (doc.on_exception) this.serverExceptions = doc.on_exception

        return doc
    }

    async #request(request) {
        debug("#request(" + ['page','action'].map(p=>request[p]?`${p} = ${request[p]}`:null).filter(e=>e!==null).join(", ") + ")")

        let data = {
            ...request,
            '_': new Date().getTime(),
        }
        let url = this.oxiConfig.backendUrl

        // POST
        let method
        if (request.action) {
            method = 'POST'
            data._rtoken = this.#rtoken
        }
        // GET
        else {
            method = 'GET'
        }

        if (this.tenant) data._tenant = this.tenant

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
            this.#handleServerException(response.status)
            return null
        }
    }

    setTenant(tenant) {
        this.tenant = tenant
    }

    // Sets the loading state, i.e. dims the page and shows a banner with the
    // given message.
    // If 'message' is set to null, the banner will be hidden.
    #setLoadingBanner(message) {
        // note that we cannot use the Ember "loading" event as this would only
        // trigger on route changes, but not if we do e.g. background updates via requestUpate()
        if (message) {
            // remove focus from button to prevent user from doing another request e.g. by hitting enter
            document.activeElement.blur()
        }
        this.loadingBanner = message
    }

    #ping(href, timeout) {
        if (this.pingTimer) cancel(this.pingTimer)
        this.pingTimer = later(this, () => {
            fetch(href, {
                headers: {
                    'X-Requested-With': 'XMLHttpRequest',
                    'X-OPENXPKI-Client': '1',
                },
            })
            .catch(error => {
                /* eslint-disable-next-line no-console */
                console.error(`Error loading ${href} (network error: ${error.name})`)
            })
            return this.#ping(href, timeout)
        }, timeout)
    }

    #autoRefreshOnce(page, timeout) {
        this.refreshTimer = later(this, function() {
            this.requestPage({ page })
        }, timeout)
    }

    #redirect(url, target = this.TARGET.TOP, type = 'internal', banner = this.intl.t('site.banner.redirecting')) {
        if (type == 'external' || /^(http|\/)/.test(url)) {
            this.#setLoadingBanner(banner) // never hide banner as browser will open a new page
            window.location.href = url
        }
        else {
            /* Workaround for "TransitionAborted..." error. The error seemingly
             * occurs in Embers rerendering triggered by changes to @tracked
             * properties that we do before #redirect() is called. Ember's
             * update handlers seem to be executed asynchronously and somehow
             * cause the TransitionAborted error.
             * Tested for Ember 4.12.0
             */
            next(this, function() { this.openPage(url, target) })
            //this.openPage(url)
        }
    }

    // Apply custom exception handler for given status code if one was set up
    // (bootstrap parameter 'on_exception').
    #handleServerException(status_code) {
        debug(`Exception - handling server HTTP status code: ${status_code}`)
        // Check custom exception handlers
        for (let handler of this.serverExceptions) {
            let codes = isArray(handler.status_code) ? handler.status_code : [ handler.status_code ]
            if (codes.find(c => c == status_code)) {
                // Show message
                if (handler.message) {
                    this.#setLoadingBanner(null)
                    console.error(handler.message)
                    this.error = handler.message
                }
                // Redirect
                else if (handler.redirect) {
                    // we intentionally do NOT remove the loading banner here
                    debug(`Exception - redirecting to ${handler.redirect}`)
                    this.#redirect(handler.redirect)
                }
                return
            }
        }
        // Unhandled exception
        this.#setLoadingBanner(null)
        console.error(`Server did not return expected data: ${status_code}`)
        this.error = this.intl.t('error_popup.message.server', { code: status_code })
    }

    #setPageContent(target, requestedPageName, page, main, right, partial, ignoreBreadcrumbs) {
        // Mark the first form on screen: only the first one is allowed to focus
        // its first input field.
        for (const section of [...(main||[]), ...(right||[])]) {
            if (section.type === "form") {
                section.content.isFirstForm = true
                break
            }
        }

        let obj
        // Popup
        if (target === this.TARGET.POPUP) {
            if (!this.popup) this.popup = new Page()
            obj = this.popup
        }
        // Main page
        else {
            // If it was a call to an action, requestedPageName == undefined.
            // In this case we do not wipe the page data.
            if (!this.top || (partial == false && requestedPageName)) this.top = new Page()
            obj = this.top

            // breadcrumbs
            let bc = page?.breadcrumb
            if (bc) {
                if (ignoreBreadcrumbs) {
                    debug('Ignoring server-sent breadcrumbs during breadcrumb-initiated navigation')
                }
                else {
                    if (bc.is_root) this.breadcrumbs = []
                    if (this.breadcrumbs.length == 0 || this.breadcrumbs.at(-1).label != bc.label) {
                        this.breadcrumbs.push({
                            label: bc.label || page.label || '',
                            ...(bc.class && { class: bc.class }),
                            ...(requestedPageName && { page: requestedPageName }),
                        })
                        this.breadcrumbs = this.breadcrumbs
                    }
                }
            }
        }
        obj.setFromHash({
            ...(requestedPageName && { name: requestedPageName }),
            ...(page && { page }),
            ...(main && { main }),
            ...(right && { right }),
        })
    }

    #refreshNavEntries() {
        for (const entry of this.navEntries) {
            emSet(entry, "active", (entry.key === this?.top?.name))
            if (entry.entries) {
                entry.entries.forEach(i => emSet(i, "active", false))
                let subEntry = entry.entries.find(i => i.key == this?.top?.name)
                if (subEntry) {
                    emSet(subEntry, "active", true)
                    emSet(entry, "active", true)
                }
            }
        }
        this.navEntries = this.navEntries // eslint-disable-line no-self-assign -- trigger Ember update
    }
}
