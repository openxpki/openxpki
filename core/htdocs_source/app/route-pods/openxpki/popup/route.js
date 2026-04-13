import Route from '@ember/routing/route'
import { service } from '@ember/service'
import { debug } from '@ember/debug'

/**
 * Route for `/openxpki/:page/popup/:popup_page`. Loads popup content via
 * {@link module:service/oxi-content} and returns the service as the model.
 *
 * @class OpenXpkiPopupRoute
 * @extends Route
 */
export default class OpenXpkiPopupRoute extends Route {
    @service('oxi-content') content

    // Reserved Ember function
    async model(params, transition) {
        let page = params.popup_page
        let target = this.content.TARGET.POPUP
        debug("openxpki/popup/route - popup_page = " + page)

        await this.content.requestUpdate({ page, target }, { verbose: true })
        return this.content
    }
}