import Route from '@ember/routing/route';
import { tracked } from '@glimmer/tracking';
import { inject } from '@ember/service';
import { Promise } from 'rsvp';
import { debug } from '@ember/debug';

/**
 * @module route/openxpki
 */
export default class OpenXpkiRoute extends Route {
    @inject('oxi-config') config;
    @inject('oxi-content') content;

    // Reserved Ember property "queryParams"
    // https://api.emberjs.com/ember/3.17/classes/Route/properties/queryParams?anchor=queryParams
    queryParams = {
        // refreshModel==true causes an "in-place" transition, so the model
        // hooks for this route (and any child routes) will re-fire
        startat:  { refreshModel: true },
        limit:    { refreshModel: true },
        force:    { refreshModel: true },
    };
    needsBootstrap = ["login", "login!logout", "welcome"];

    /*
    Custom handlers for exceptions returned by the server (HTTP status codes):
        [
            {
                status_code: [ 403, ... ], // array or string
                redirect: "https://...",
            },
            { ... }
        ]
    */
    serverExceptions = [];

    // Reserved Ember function
    beforeModel(transition) {
        let queryParams = transition.to.queryParams;
        let modelId = transition.to.params.model_id;
        debug("openxpki/route - beforeModel: model_id = " + modelId);

        // "force" is only evaluated above using "refreshModel: true"
        if (queryParams.force) {
            delete queryParams.force;
        }

        let structureIfNeeded; // chain of ajax calls via Promises

        /*
         * load base page structure first first time or for special pages ("needsBootstrap")
         */
        if (!this.content.navEntries.length || this.needsBootstrap.indexOf(modelId) >= 0) {
            // don't send request yet, only create a lambda via arrow function expression
            structureIfNeeded = () => {
                return this.content.updateRequest({
                    page: "bootstrap!structure",
                    baseurl: window.location.pathname,
                });
            };
        }
        else {
            structureIfNeeded = () => { Promise.resolve() };
        }

        /*
         * load requested page part
         */
        let request = {
            page: modelId
        };
        if (queryParams.limit) { request.limit = queryParams.limit }
        if (queryParams.startat) { request.startat = queryParams.startat }

        // load as top content if 'modelId' is part of navigation or in 'needsBootstrap' list
        let flatList = this.content.navEntries.reduce((p, n) => p.concat(n, n.entries || []), []);
        if (flatList.findBy("key", modelId) || this.needsBootstrap.indexOf(modelId) >= 0) {
            request.target = "top";
        }
        return this.config.ready // localconfig.js might change rootURL, so first thing is to query it
            .then( () => structureIfNeeded() )
            .then( () => this.content.updateRequest(request) );
    }

    // Reserved Ember function
    model(params/*, transition*/) {
        this.content.setPage(params.model_id);
        return this.content;
    }
}