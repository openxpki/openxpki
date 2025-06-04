import Service from '@ember/service'
import { service } from '@ember/service'
import { tracked } from '@glimmer/tracking'
import { later, next, cancel } from '@ember/runloop'
import { isArray } from '@ember/array'
import { action, set as emSet } from '@ember/object'
import { debug, warn } from '@ember/debug'
import { guidFor } from '@ember/object/internals'
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
    @tracked realm = null
    @tracked status = null
    @tracked popupStatus = null

    @tracked top = null
    @tracked popup = null
    @tracked breadcrumbs = []

    @tracked error = null
    @tracked loadingBanner = null
    last_session_id = null // to track server-side logouts with session id changes
    #loginTimestamp = null // to track logouts in another browser window via Cookie comparison

    @tracked refreshTimers = new Map()

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
    serverExceptions = []

    #focusFavourite = null // hash containing element + rank for the current focus favourite
    #willSetFocusOnNextRunLoop = false

    #id = guidFor(this)

    TARGET = Object.freeze({
        TOP: Symbol("TOP"),
        POPUP: Symbol("POPUP"),
        BLANK: Symbol("BLANK"),
    })

    LOGIN_PAGES = ['login', 'login!logout', 'logout']

    get realmCssClass() {
        if (!this.realm) return ''
        return 'oxi-realm-' + this.safeCssLabel(this.realm)
    }

    get tenantCssClass() {
        if (!this.tenant) return ''
        return 'tenant-' + this.safeCssLabel(this.tenant)
    }

    safeCssLabel(label) {
        return label
          .toLowerCase()
          .replace(/[_\s]/g, '-')
          .replace(/[^a-z0-9-]/g, '')
          .replace(/-+/g, '-')
    }

    get isAutoRefresh() {
        return this.refreshTimers.has(`${this.#id}/page_refresh`)
    }

    /**
     * Open the given OpenXPKI page via Ember route transition, i.e. change the
     * URL.
     *
     * @param {object} page - Page specification
     * @param {string} page.name - OpenXPKI page to open
     * @param {string|symbol} page.target - Target: `'self'` (same target as the caller), `'top'`, `'popup'` or `this.TARGET.SELF`, `this.TARGET.TOP`, `this.TARGET.POPUP`
     * @param {boolean} [page.force=false] - Forces a transition even if the new page equals the current one
     * @param {hash} [page.params] - Additional `queryParams` for Ember Router's `transitionTo()`
     * @return {Promise} Promise that resolves when the route transition finished
     */
    openPage({ name, target, force = false, params = null }) {
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

    /**
     * Open the given (external) browser URL via `window.open()`.
     *
     * @param {string} href - URL
     * @param {string} target - Browser target
     */
    openLink(href, target) {
        debug(`openLink(href = ${href}, target = ${typeof target == 'symbol' ? target.toString() : target})`)

        // close popup
        this.popup = null

        // open link
        let realTarget = this.#resolveTarget(target, true)
        window.open(href, realTarget == this.TARGET.TOP ? '_self' : '_blank')
    }

    /**
     * Ember action to close the popup.
     */
    @action
    closePopup() {
        // close popup
        this.popup = null
        // transition to current route (keeps the current model/page) but without the "popup" part
        return this.router.transitionTo('openxpki')
    }

    /**
     * Ember action to go back to the given breadcrumb via `this.openPage()`.
     * Also truncates the breadcrumbs list.
     *
     * @param {hash} bc - Breadcrumb definition
     * @return {Promise} Promise that resolves when the route transition finished
     */
    @action
    gotoBreadcrumb(bc) {
        let i = this.breadcrumbs.findIndex(el => el === bc)
        debug(`Navigating to breadcrumb #${i}: ${bc.page}`)
        // cut breadcrumbs list back to the one we're navigating to
        this.breadcrumbs = this.breadcrumbs.slice(0, i+1)
        // open breadcrumb's page
        this.openPage({ name: bc.page, target: this.TARGET.TOP, force: true, params: { trigger: 'breadcrumb' } })
    }

    /**
     * Send AJAX request.
     *
     * @param {hash} request - Request data
     * @param {hash} options
     * @param {boolean} [options.partial=false] - set to `true` to prevent resetting the whole page (data)
     * @param {boolean} [options.verbose=true] - set to `false` to suppress "loading" banner
     * @param {string} [options.trigger] - trigger that caused the request: might be `nav` or `breadcrumb`
     * @return {Promise} Promise receiving the JSON document on success or `{}` on error
     */
    async requestPage(request, { partial = false, verbose = true, trigger = '' } = {}) {
        debug(
            'requestPage(' +
                '{ ' +
                    (request.page ? 'page = '+request.page : 'action = '+request.action) + ', ' +
                    'target = ' + (typeof request.target == 'symbol' ? request.target.toString() : request.target) + ' ' +
                '}, ' +
                `partial = ${partial ? true : false}, ` +
                `verbose = ${verbose ? true : false}, ` +
                `trigger = ${trigger??'<none>'}, ` +
            ')'
        )

        if (verbose) this.#setLoadingBanner(this.intl.t('site.banner.loading'))

        if (partial) {
            this.cancelTimer(`${this.#id}/page_refresh`)
        }
        else {
            // Remove all refresh timers to prevent that an OpenXPKI page refresh
            // (!= browser reload) leads to multiple parallel request timers.
            // Or that the requests continue if another OpenXPKI page is opened.
            this.cancelAllTimers()
        }

        // resolve target
        let realTarget = this.#resolveTarget(request.target)
        delete request.target // may already be a Symbol (our fake enum) which we cannot send to the backend

        try {
            let doc = await this.#request(request)

            // Errors occured and #request() returned null
            if (!doc) {
                this.#setLoadingBanner(null)
                return {}
            }

            if (doc?.status?.level == 'error') {
                debug('Stopping all timers / refreshes because of page status level "error"')
                this.cancelAllTimers()
            }

            // chain backend calls via Promise
            if (this.#isBootstrapNeeded(doc.session_id)) await this.#bootstrap()

            // "goto" in a popup will refresh the top page instead
            if (realTarget === this.TARGET.POPUP && doc.goto) realTarget = this.TARGET.TOP

            // last request sets the status
            if (realTarget === this.TARGET.POPUP) {
                this.popupStatus = doc.status
            } else {
                this.status = doc.status
            }

            // Set page contents (must be done before setting breadcrumbs)
            if (!doc.goto) this.#setPageContent(realTarget, request.page, doc.page, doc.main, partial, trigger)

            // Popup
            if (realTarget === this.TARGET.POPUP) {
                if (doc.refresh) console.warn("'refresh' not supported for popup contents")
            }
            // Page
            if (realTarget !== this.TARGET.POPUP) {
                this.popup = null

                this.#setBreadcrumbs(request.page, trigger, doc.page)

                // Auto refresh
                if (doc.refresh) {
                    debug("requestPage(): response - \"refresh\" " + doc.refresh.href + ", " + doc.refresh.timeout)
                    this.addTimer(this, `${this.#id}/page_refresh`, function() { this.requestPage({ page: doc.refresh.href }) }, doc.refresh.timeout)
                }

                // Redirect
                if (doc.goto) {
                    debug("requestPage(): response - \"goto\" " + doc.goto)
                    return this.#redirect(doc.goto, realTarget, doc.type, doc.loading_banner)
                }
            }

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
            // We send the URL to the backend because the Ember web UI (index.html)
            // may have a different URL than the asynchronously called backend.
            // This is equivalent to the "Referer" HTTP header which may be disabled.
            baseurl: window.location.pathname,
        })

        // Errors occured and #request() returned null
        if (!doc) {
            this.#setLoadingBanner(null)
            return {}
        }

        if (doc.rtoken) this.#rtoken = doc.rtoken // CSRF token
        this.#loginTimestamp = this.#getLoginTimestampCookie()

        if (doc.language) this.oxiLocale.locale = doc.language
        if (doc.pki_realm) this.realm = doc.pki_realm
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
            /* Check the known login timestamp against the current timestamp in
             * the cookie. A re-login in another browser windows may have
             * updated the cookie (= new session/rtoken).
             * In this case we interrupt the POST request and silently try to
             * fetch the new rtoken by calling the bootstrap page.
             * Upon success a message is shown.
             */
            let timestampCookie = this.#getLoginTimestampCookie()
            if (this.#loginTimestamp !== null) {
                if (this.#loginTimestamp != timestampCookie) {
                    // Login
                    if (this.#loginTimestamp == 0) {
                        debug('Cookie "oxi-login-timestamp" changed - Login')
                    }
                    // Logout (somewhere else)
                    else if (timestampCookie == 0) {
                        // the server will send a redirect to the login page in this case
                        debug('Cookie "oxi-login-timestamp" changed - Logout')
                    }
                    // Old session/rtoken in our window, new rtoken should be available
                    else {
                        console.error('Cookie "oxi-login-timestamp" changed - Session was renewed in other window', this.#loginTimestamp, timestampCookie)
                        // intermediate request just to get the new rtoken
                        let doc = await this.#request({ page: "bootstrap!structure" })
                        if (doc.rtoken) {
                            this.#rtoken = doc.rtoken // CSRF token
                            this.#loginTimestamp = this.#getLoginTimestampCookie()
                            this.status = {
                                message: this.intl.t('site.session_renewed'),
                                level: "warn",
                            }
                            return null // cancel current request
                        }
                        // if no rtoken was returned something went wrong and
                        // we just render the contents from the server.
                    }
                }
            }

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

    /**
     * Calculates a "rank" for the given DOM element and registers it as the
     * "favourite" one to receive the focus if its rank is lower than the best
     * one seen so far.
     *
     * The rank is better if the element is inside a popup, if it's a form field,
     * the lower the section number is and the lower the field number within a
     * section is (if any).
     *
     * @param {bool} isPopup - whether the element resides in a popup
     * @param {bool} isFormField - whether the element is a form field
     * @param {object} element - the DOM element
     * @param {number} sectionNo - section no. (or null)
     * @param {number} fieldNo - field no. within a form (or null)
     */
    @action
    registerFocusElement(isPopup=false, isFormField=false, element, sectionNo=-1, fieldNo=-1) {
        let rank =
              ((isPopup     ? 0 : 1) << 17)
            + ((isFormField ? 0 : 1) << 16)
            + ((sectionNo+1)         <<  8)
            + (fieldNo+1)

        // remove current favourite if it's gone or invisible
        if (this.#focusFavourite && !this.#focusFavourite.element) this.#focusFavourite = null
        if (this.#focusFavourite && !this.isElementVisible(this.#focusFavourite.element)) this.#focusFavourite = null

        if (!this.#focusFavourite || rank < this.#focusFavourite.rank) {
            this.#focusFavourite = { rank, element }
            debug(`New favourite to receive focus is (isPopup=${isPopup}, isFormField=${isFormField}, sectionNo=${sectionNo}, fieldNo=${fieldNo}, ${element}) -> rank=${rank}`)

            // set focus on favourite field in next cycle
            // (this allows for all form fields to settle / register)
            if (!this.#willSetFocusOnNextRunLoop) {
                this.#willSetFocusOnNextRunLoop = true
                next(() => this.setFocus())
            }
        }
    }

    isElementVisible(el) {
        let rect = el.getBoundingClientRect()
        return (
            rect.top >= 0 &&
            rect.left >= 0 &&
            rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
            rect.right <= (window.innerWidth || document.documentElement.clientWidth) &&
            rect.width > 0 &&
            rect.height > 0
        )
    }

    /**
     * Sets the focus to the current favourite DOM element.
     */
    @action
    setFocus() {
        this.#willSetFocusOnNextRunLoop = false
        if (!this.#focusFavourite) return

        if (!this.#focusFavourite.element) {
            warn('NOT setting focus as favourite element does not exist (anymore?)', { id: 'oxi.services.oxi-content' })
            this.#focusFavourite = null
            return
        }
        if (!this.isElementVisible(this.#focusFavourite.element)) {
            /*
              This is a workaround for cases where the originally created
              element [1] gets replaced (hidden) e.g. by a Javascript module.
              By sending our own "oxi-focus" event we allow the original elemen
              to redirect the focus even if it is invisible itself.

              [1]: the one that receives {{on-init @setFocusInfo true}} from
              OxiSection::Form::Field::xxx via "...attributes" and thus fires
              setFocusInfo(element, true) with itself as the first argument
            */
            warn('Trying to set focus via custom event "oxi-focus" as favourite element is not visible', { id: 'oxi.services.oxi-content' })
            this.#focusFavourite.element.dispatchEvent(new Event("oxi-focus"))
            return
        }

        debug('Setting focus to current favourite element')
        this.#focusFavourite.element.focus()
    }

    /**
     * Register a new timer.
     *
     * @param {object} ctx - context (`this` will be set to this context when `cb` is executed)
     * @param {string} id - timer ID
     * @param {function} cb - callback function to be executed
     * @param {number} timeoutSec - timeout in seconds until `cb` will be executed
     */
    addTimer(ctx, id, cb, timeoutSec) {
        this.cancelTimer(id)
        debug(`Register timer "${id}"`)
        this.refreshTimers.set(id, later(ctx, cb, timeoutSec * 1000))
        this.refreshTimers = this.refreshTimers // trigger Ember refresh
    }

    /**
     * Cancel and deregister a timer.
     *
     * Does nothing if the timer with the given ID does not exist.
     *
     * @param {string} id - timer ID
     */
    cancelTimer(id) {
        let oldTimer = this.refreshTimers.get(id)
        if (!oldTimer) return

        debug(`Cancel timer "${id}"`)
        cancel(oldTimer)
        this.refreshTimers.delete(id)
        this.refreshTimers = this.refreshTimers // trigger Ember refresh
    }

    /**
     * Cancel and deregister all timers.
     */
    cancelAllTimers() {
        debug('Cancel all timers')
        for (const timer of this.refreshTimers.values()) cancel(timer)
        this.refreshTimers.clear()
        this.refreshTimers = this.refreshTimers // trigger Ember refresh
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
        this.cancelTimer(`${this.#id}/ping`)
        this.addTimer(this, `${this.#id}/ping`, function() {
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
            this.#ping(href, timeout)
        }, timeout)
    }

    #redirect(url, target = this.TARGET.TOP, type = 'internal', banner = this.intl.t('site.banner.redirecting')) {
        debug(`#redirect() - redirecting to ${url}`)

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
            next(this, function() { this.openPage({ name: url, target: target }) })
            //this.openPage({ name: url, target: target })
        }
    }

    // Apply custom exception handler for given status code if one was set up
    // (bootstrap parameter 'on_exception').
    #handleServerException(status_code) {
        warn(`Exception - handling server HTTP status code: ${status_code}`, { id: 'oxi.services.oxi-content' })
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

    #setPageContent(target, requestedPageName, page, main, partial, trigger) {
        let obj
        // Popup
        if (target === this.TARGET.POPUP) {
            if (!this.popup) this.popup = new Page()
            obj = this.popup
        }
        // Main page
        else {
            // If it was a call to an action, requestedPageName == undefined.
            // In this case we leave the page data untouched.
            if (!this.top || (partial == false && requestedPageName)) this.top = new Page()
            obj = this.top
        }
        obj.setFromHash({
            ...(requestedPageName && { name: requestedPageName }),
            ...(page && { page }),
            ...(main && { main }),
        })
    }

    #setBreadcrumbs(requestedPageName, trigger, page = {}) {
        let bc = page?.breadcrumb || {}
        let ignoreBreadcrumbs = trigger === 'breadcrumb'
        let navAction = trigger === 'nav'
        let pageName = requestedPageName ?? this.top.name ?? ''
        let breadcrumb

        if (ignoreBreadcrumbs) {
            warn('#setBreadcrumbs(): ignoring server-sent breadcrumbs during breadcrumb-initiated navigation', { id: 'oxi.services.oxi-content' })
            return
        }

        debug(`#setBreadcrumbs(): page = ${requestedPageName??'<none>'}, trigger = ${trigger??'<none>'}, breadcrumb = ${page?.breadcrumb?.label??'<none>'}`)

        // Reset breadcrumbs for nav menu clicks
        if (navAction) {
            debug(`#setBreadcrumbs(): navigation item detected, resetting breadcrumbs`)
            this.breadcrumbs = []
        }

        // login or logout pages
        if (this.LOGIN_PAGES.findIndex(p => pageName.startsWith(p)) != -1) {
            debug(`#setBreadcrumbs(): login/logout page detected, suppressing breadcrumbs`)
            this.breadcrumbs = []
            return
        }

        // Breadcrumb may be suppressed by setting empty workflow label.
        // See OpenXPKI::Client::Service::WebUI::Page::Workflow->__get_breadcrumb()
        let suppressBreadcrumb = (Object.keys(page).length == 0) || (bc.suppress??0 == 1)
        if (suppressBreadcrumb) debug('#setBreadcrumbs(): server sent empty hash - suppressing new breadcrumb')

        if (! suppressBreadcrumb) {
            if (bc.is_root) this.breadcrumbs = []

            // Set defaults from server
            breadcrumb = {
                ...(bc.label && { label: bc.label }),
                ...(bc.class && { class: bc.class }),
                page: pageName,
            }

            // Default to page label
            if (!breadcrumb.label) breadcrumb.label = page.label

            // Special handling for nav menu clicks
            if (navAction) {
                // always use nav menu label if available
                let flatList = this.navEntries.reduce((p, n) => p.concat(n, n.entries || []), []);
                const navItem = flatList.find(i => i.key == requestedPageName)
                if (navItem) {
                    debug('#setBreadcrumbs(): using navigation item label for breadcrumb')
                    breadcrumb.label = navItem.label
                }
            }

            // Remove trailing items if current page equals previous one in the breadcrumbs
            let alreadySeenAt = this.breadcrumbs.findIndex(
                el => (el.page == (breadcrumb.page) || (el.label??'-') == (breadcrumb.label??'--'))
            )
            if (alreadySeenAt != -1) {
                debug('#setBreadcrumbs(): breadcrumb already in list - replacing it (to get new label)')
                this.breadcrumbs = this.breadcrumbs.slice(0, alreadySeenAt)
            }
        }

        // stop if there is nothing to add
        if (suppressBreadcrumb || !(breadcrumb && breadcrumb.label)) return

        // add new breadcrumb
        this.breadcrumbs.push(breadcrumb)
        this.breadcrumbs = this.breadcrumbs // trigger Ember refresh
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

    #getLoginTimestampCookie() {
        return new Map(
            // create an array of arrays [name,value] to feed the Map constructor
            document.cookie.split(/;\s*/).map(c => c.match(/^([^=]*)=?(.*)/).slice(1,3))
        ).get('oxi-login-timestamp')
    }
}
