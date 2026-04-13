import Controller from '@ember/controller'
import { action } from '@ember/object'
import { tracked } from '@glimmer/tracking'
import { service } from '@ember/service'

/**
 * Application-level controller: manages theme mode and page-width toggle.
 *
 * The application route is the root of the Ember route hierarchy; all other
 * routes render into its `{{outlet}}`.
 * (https://guides.emberjs.com/release/routing/defining-your-routes/)
 *
 * ## Route hierarchy
 *
 * ```
 * /
 * └── ApplicationRoute          (route-pods/application/)
 *     │   Thin shell: no model, no redirect logic.
 *     │   ApplicationController owns: theme mode, page-width toggle.
 *     │   Renders {{outlet}} for all child routes.
 *     │
 *     ├── IndexRoute            (route-pods/index/)
 *     │       URL: /
 *     │       Immediately redirects to /openxpki/welcome?trigger=nav.
 *     │
 *     ├── OpenxpkiRoute         (route-pods/openxpki/)
 *     │   │   URL: /openxpki/:page
 *     │   │   Query params: startat, limit, force (all refreshModel), trigger.
 *     │   │   beforeModel(): installs Pretender mock server in dev for test pages.
 *     │   │   model(): awaits oxi-config.ready, deduplicates requests (skips
 *     │   │           re-fetch when only the popup URL changes), calls
 *     │   │           content.requestPage({ page, target: TOP, limit, startat }).
 *     │   │           Returns the oxi-content service as the route model.
 *     │   │
 *     │   └── OpenxpkiPopupRoute  (route-pods/openxpki/popup/)
 *     │           URL: /openxpki/:page/popup/:popup_page
 *     │           model(): calls content.requestUpdate({ page, target: POPUP }).
 *     │                    Returns the oxi-content service as the route model.
 *     │
 *     └── TestRoute             (development only, /test)
 * ```
 *
 * @class ApplicationController
 * @extends Controller
 */
export default class ApplicationController extends Controller {
    @service('oxi-content') content
    @service('intl') intl

    @tracked restricted_width = true

    // Theme mode: 'light', 'dark', or 'auto'
    @tracked themeMode = localStorage.getItem('oxi-theme-mode') || 'auto'
    @tracked _osThemeRevision = true
    #systemMode = window.matchMedia('(prefers-color-scheme: dark)') // track OS preference

    #onOsThemeChange = () => {
        this._osThemeRevision = !this._osThemeRevision
        if (this.themeMode === 'auto') { this._applyTheme() }
    }

    /**
     * Returns the resolved theme: `"light"` or `"dark"`.
     * In `"auto"` mode this follows the OS preference.
     * @memberOf ApplicationController
     */
    get effectiveTheme() {
        if (this.themeMode === 'auto') {
            this._osThemeRevision // consume tracked property to trigger re-render of auto-button
            return this.#systemMode.matches ? 'dark' : 'light'
        } else {
            return this.themeMode
        }
    }

    /**
     * Returns the Bootstrap icon class name for the current theme mode button.
     * @memberOf ApplicationController
     */
    get themeIcon() {
        switch (this.themeMode) {
            case 'dark':  return 'bi-moon-fill'
            case 'light': return 'bi-sun-fill'
            case 'auto':  return 'bi-circle-half'
            default:      return 'bi-sun-fill'
        }
    }

    /**
     * Returns the Bootstrap button CSS classes for the current theme mode button.
     * @memberOf ApplicationController
     */
    get themeButtonClass() {
        switch (this.themeMode) {
            case 'dark':  return 'btn-outline-info'
            case 'light': return 'btn-outline-secondary bg-warning-subtle'
            case 'auto':  return this.effectiveTheme === 'dark' ? 'btn-outline-info' : 'btn-outline-secondary bg-warning-subtle'
            default:      return 'btn-outline-secondary bg-warning-subtle'
        }
    }

    constructor() {
        super(...arguments)
        this.intl.setLocale(['en-us']);

        // Listen for OS color scheme changes (relevant when mode is 'auto')
        this.#systemMode.addEventListener('change', this.#onOsThemeChange)
        this._applyTheme()
    }

    // Writes `data-bs-theme` on `<html>` to apply the effective theme.
    _applyTheme() {
        document.documentElement.setAttribute('data-bs-theme', this.effectiveTheme)
    }

    /**
     * Toggles between restricted and full page width.
     * @memberOf ApplicationController
     */
    @action toggleWidth() {
        this.restricted_width = !this.restricted_width
    }

    /**
     * Removes the static loading banner (`#oxi-loading-banner`) from the DOM.
     * Called once after the app has rendered its first page.
     * @memberOf ApplicationController
     */
    @action
    removeLoader() {
        // note: we don't use an Ember loading substate here as this would
        // lead to a disruptive UX on every page (route) switch
        let el = document.querySelector(".oxi-loading-banner")
        if (!el) return
        el.parentNode.removeChild(el)
    }

    /**
     * Cycles the theme mode: `"light"` -> `"dark"` -> `"auto"` -> `"light"`.
     * Persists the choice in `localStorage`.
     * @memberOf ApplicationController
     */
    @action
    cycleThemeMode() {
        // Cycle: light -> dark -> auto -> light
        switch (this.themeMode) {
            case 'light': this.themeMode = 'dark'; break
            case 'dark': this.themeMode = 'auto'; break
            case 'auto': this.themeMode = 'light'; break
            default: this.themeMode = 'auto'
        }
        this._applyTheme()
        localStorage.setItem('oxi-theme-mode', this.themeMode)
    }

    willDestroy() {
        super.willDestroy(...arguments)
        if (this.#systemMode && this.#onOsThemeChange) {
            this.#systemMode.removeEventListener('change', this.#onOsThemeChange)
        }
    }
}
