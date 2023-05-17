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
    popupBackButton = null

    @action
    closePopup() {
        return this.content.closePopup()
    }

    @action
    goBack() {
        history.back()
    }
}