import Controller from '@ember/controller'
import { action } from '@ember/object'
import { tracked } from '@glimmer/tracking'

export default class ApplicationController extends Controller {
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
