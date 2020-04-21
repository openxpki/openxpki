import Controller from '@ember/controller';
import { action } from '@ember/object';

export default class ApplicationController extends Controller {
    @action
    removeLoader() {
        let el = document.getElementById("waiting-for-ember");
        el.parentNode.removeChild(el);
    }
}
