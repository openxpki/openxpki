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
        // breadcrumbAction -- not neccessary as we only evaluate it in model() below
    }
    topTarget = ["login", "login!logout", "welcome"]

    // Reserved Ember function
    async model(params, transition) {
        await this.config.ready // localconfig.js might change rootURL, so first thing is to query it

        let page = params.page
        debug("openxpki/route - model: page = " + page)

        /*
         * Load requested page if different from current page.
         * If the popup content changes then this top page is requested again
         * but does not change as it stays in the background.
         */
        if (!this.content.top || page != this.content.top.name) {
            // URL-configurable pager variables for <OxiSection::Grid>
            let limit = transition.to.queryParams.limit ?? null
            let startat = transition.to.queryParams.startat ?? null
            let breadcrumbAction = transition.to.queryParams.breadcrumbAction ?? false

            // assemble request
            await this.content.requestPage({
                page,
                target: this.content.TARGET.TOP,
                ...(limit && { limit }),
                ...(startat && { startat }),
            }, {
                ignoreBreadcrumbs: breadcrumbAction ? true : false,
            })
        }

        return this.content
    }
}