import Controller from '@ember/controller';
import { action } from '@ember/object';

export default class ApplicationController extends Controller {
    @action
    removeLoader() {
        // note: we don't use an Ember loading substate here as this would
        // lead to a disruptive UX on every page (route) switch
        let el = document.querySelector(".oxi-loading-banner");
        if (!el) return;
        el.parentNode.removeChild(el);
    }
}
