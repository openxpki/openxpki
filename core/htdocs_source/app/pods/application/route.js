import Route from '@ember/routing/route';
import { action } from '@ember/object';
/*
import { on } from '@ember/object/evented';
import { debug } from '@ember/debug';
*/

export default class ApplicationRoute extends Route {
    // fired when attempting to transition into a route and any of the hooks
    // returns a promise that rejects
    @action
    error(error /*, transition*/) {
        /* eslint-disable-next-line no-console */
        console.error(error);
    }
/*
    // triggered when the router enters the route
    @on('activate', function() {
        debug("Application route - event 'activate'");
    })

    // triggered when the router completely exits this route
    @on('deactivate', function() {
        debug("Application route - event 'deactivate'");
    })

    // fired at the beginning of any attempted transition
    @action
    willTransition(transition) {
        debug("Application route - event 'willTransition'");
    }

    // fired after a transition has successfully been completed
    @action
    didTransition(transition) {
        debug("Application route - event 'didTransition'");
        return true; // bubble the didTransition event
    }
*/
}
