import Controller from '@ember/controller'
import { tracked } from '@glimmer/tracking'
import { action } from '@ember/object'
import { service } from '@ember/service'

export default class OpenXpkiController extends Controller {
    @service('oxi-content') content

    /*
     * Reserved Ember property "queryParams" - binds the given query parameter
     * to the object properties of the same name.
     * (https://guides.emberjs.com/v4.12.0/routing/query-params/)
     *
     * BEWARE that if we manually set such an object property the URL parameter
     * would also be set, which in return fires the model() hook in the Route
     * class and would result in a second backend request.
     */
    queryParams = [ 'popupBackButton' ]
    @tracked popupBackButton = false

    @action
    goBack() {
        history.back()
    }
}