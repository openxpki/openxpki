import Controller from '@ember/controller'
import { action } from '@ember/object'
import { tracked } from '@glimmer/tracking'
import { service } from '@ember/service'

/*
 * The application route is entered when the app first boots up.
 * Like other routes, it will load a template with the same name by default.
 * [..] All other routes will render their templates into the application.hbs
 * template's {{outlet}}.
 *
 * This route is part of every application, so you don't need to specify it in
 * your app/router.js.
 *
 * (https://guides.emberjs.com/release/routing/defining-your-routes/)
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

    get effectiveTheme() {
        if (this.themeMode === 'auto') {
            this._osThemeRevision // consume tracked property to trigger re-render of auto-button
            return this.#systemMode.matches ? 'dark' : 'light'
        } else {
            return this.themeMode
        }
    }

    get themeIcon() {
        switch (this.themeMode) {
            case 'dark':  return 'bi-moon-fill'
            case 'light': return 'bi-sun-fill'
            case 'auto':  return 'bi-circle-half'
            default:      return 'bi-sun-fill'
        }
    }

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

    _applyTheme() {
        document.documentElement.setAttribute('data-bs-theme', this.effectiveTheme)
    }

    @action toggleWidth() {
        this.restricted_width = !this.restricted_width
    }

    @action
    removeLoader() {
        // note: we don't use an Ember loading substate here as this would
        // lead to a disruptive UX on every page (route) switch
        let el = document.querySelector(".oxi-loading-banner")
        if (!el) return
        el.parentNode.removeChild(el)
    }

    @action
    cycleThemeMode() {
        // Cycle: light → dark → auto → light
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
