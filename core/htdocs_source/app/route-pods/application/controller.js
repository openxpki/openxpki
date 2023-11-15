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

    @tracked restricted_width = true

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
}
