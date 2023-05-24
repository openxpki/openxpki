import Route from '@ember/routing/route'
import { service } from '@ember/service'
import { debug } from '@ember/debug'

/**
 * @module route/openxpki
 */
export default class OpenXpkiRoute extends Route {
    @service('oxi-config') config
    @service('oxi-content') content

    // Reserved Ember property "queryParams"
    // https://api.emberjs.com/ember/3.17/classes/Route/properties/queryParams?anchor=queryParams
    queryParams = {
        // refreshModel==true causes an "in-place" transition, so the model
        // hooks for this route (and any child routes) will re-fire
        startat:  { refreshModel: true },
        limit:    { refreshModel: true },
        force:    { refreshModel: true }, // not evaluated, only used to trigger model refresh
        // trigger -- not neccessary as we only evaluate it in model() below
    }
    topTarget = ["login", "login!logout", "welcome"]
    previousParams = []

    // // Reserved Ember function
    // async beforeModel(transition) {
    //     let page = transition.to.parent.params.page // to = openxpki.index
    // }

    // Reserved Ember function
    async model(params, transition) {
        let page = params.page

        let force = transition.to.queryParams.force ?? null
        let trigger = transition.to.queryParams.trigger ?? ''
        // URL-configurable pager variables for <OxiSection::Grid> :
        let limit = transition.to.queryParams.limit ?? null
        let startat = transition.to.queryParams.startat ?? null

        debug(`openxpki/route - model(): page = ${page}, trigger = ${trigger}, force = ${force}`)

        await this.config.ready // localconfig.js might change rootURL, so first thing is to query it

        const equalArrays = (a1, a2) => a1.size === a2.size && a1.every((key, i) => a1.at(i) === a2.at(i))

        /*
         * Load requested top page only if different from previous page:
         * if a popup is opened or the popup content changes then this model()
         * hook is fired again (for this top page in the background) as part
         * of the URL. But the top page does not change so we must prevent
         * repeated background requests for the same content.
         */
        let currentParams = [page, limit, startat, force]
        if (! equalArrays(currentParams, this.previousParams)) {
            this.previousParams = currentParams

            // assemble request
            await this.content.requestPage({
                page,
                target: this.content.TARGET.TOP,
                ...(limit && { limit }),
                ...(startat && { startat }),
            }, {
                trigger,
            })
        }

        return this.content
    }
}