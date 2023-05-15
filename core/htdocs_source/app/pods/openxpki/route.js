import Route from '@ember/routing/route';
import { service } from '@ember/service';
import { debug } from '@ember/debug';

/**
 * @module route/openxpki
 */
export default class OpenXpkiRoute extends Route {
    @service('oxi-config') config;
    @service('oxi-content') content;

    // Reserved Ember property "queryParams"
    // https://api.emberjs.com/ember/3.17/classes/Route/properties/queryParams?anchor=queryParams
    queryParams = {
        // refreshModel==true causes an "in-place" transition, so the model
        // hooks for this route (and any child routes) will re-fire
        startat:  { refreshModel: true },
        limit:    { refreshModel: true },
        force:    { refreshModel: true },
    };
    topTarget = ["login", "login!logout", "welcome"];

    // Reserved Ember function
    async model(params, transition) {
        await this.config.ready; // localconfig.js might change rootURL, so first thing is to query it

        let page = params.page;
        debug("openxpki/route - model: page = " + page);

        /*
         * load requested page part
         */

        // URL-configurable pager variables for <OxiSection::Grid>
        let limit = transition.to.queryParams.limit
        let startat = transition.to.queryParams.startat

        // assemble request
        let request = {
            page,
            target: 'top',
            ...(limit ? { limit } : {}),
            ...(startat ? { startat } : {}),
        };

        // // load as top content if 'page' is part of navigation or in 'topTarget' list
        // let flatList = this.content.navEntries.reduce((p, n) => p.concat(n, n.entries || []), []);
        // if (flatList.find(i => i.key == page) || this.topTarget.indexOf(page) >= 0) {
        //     request.target = "top";
        // }

        await this.content.requestPage(request);
        return this.content;
    }
}