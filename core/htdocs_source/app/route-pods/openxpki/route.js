import Route from '@ember/routing/route'
import { service } from '@ember/service'
import { debug } from '@ember/debug'
import config from 'openxpki/config/environment'

/**
 * @module route/openxpki
 */
export default class OpenXpkiRoute extends Route {
    @service('oxi-config') oxiConfig
    @service('oxi-content') content

    // Reserved Ember property "queryParams"
    // https://api.emberjs.com/ember/3.17/classes/Route/properties/queryParams?anchor=queryParams
    queryParams = {
        // refreshModel==true causes an "in-place" transition, so the model
        // hooks for this route (and any child routes) will re-fire
        startat:  { refreshModel: true },
        limit:    { refreshModel: true },
        force:    { refreshModel: true }, // not evaluated, only used to trigger model refresh
        trigger:  { refreshModel: false }, // must be declared for ember-source >= 6.11 even though we only read it from transition.to.queryParams
    }
    previousParams = []

    // Reserved Ember function
    async beforeModel(transition) {
        // Install Pretender mock server before model() does first HTTP request.
        // This cannot be done in the "test" child route's beforeModel() because
        // the parent model() hook runs first.
        if (config.environment === 'development') {
            const page = transition.to.params?.page ?? transition.to.parent?.params?.page
            if (page === 'test' || page?.startsWith('openxpki.test.')) {
                // dynamic import to keep test code out of production bundles
                const { setupPretender } = await import('./test/pretender-setup')
                await setupPretender()
            }
        }
    }

    // Reserved Ember function
    async model(params, transition) {
        let page = params.page

        let force = transition.to.queryParams.force ?? null
        let trigger = transition.to.queryParams.trigger ?? ''
        // URL-configurable pager variables for <OxiSection::Grid> :
        let limit = transition.to.queryParams.limit ?? null
        let startat = transition.to.queryParams.startat ?? null

        debug(`openxpki/route - model(): page = ${page}, trigger = ${trigger}, force = ${force}`)

        await this.oxiConfig.ready // localconfig.js might change rootURL, so first thing is to query it

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
