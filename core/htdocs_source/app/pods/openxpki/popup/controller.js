import Controller from '@ember/controller'
import { tracked } from '@glimmer/tracking'
import { action, set as emSet } from '@ember/object'
import { service } from '@ember/service'
import lite from 'caniuse-lite'
import { detect } from 'detect-browser'

export default class OpenXpkiController extends Controller {
    @service('oxi-content') content

    // Reserved Ember property "queryParams"
    // https://api.emberjs.com/ember/3.17/classes/Route/properties/queryParams?anchor=queryParams
    queryParams = [ 'popupBackButton' ] // binds the query parameter to the object property
    @tracked popupBackButton = null

    @action
    closePopup() {
        /* We have to prevent that the popupBackButton property is being
         * preserved when a popup is closed on a subsequent popup page.
         * Otherwise the Back button might be shown on the first popup page
         * if the same popup is opened again.
         */
        this.popupBackButton = null

        return this.content.closePopup()
    }

    @action
    goBack() {
        history.back()
    }
}