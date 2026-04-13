import Route from '@ember/routing/route'
import { service } from '@ember/service'
import { debug } from '@ember/debug'

/**
 * Index route (`/`). Immediately redirects to `/openxpki/welcome`.
 *
 * @module route/index
 */
export default class IndexRoute extends Route {
    @service router

    redirect(/*model, transition*/) {
        debug('Redirecting from / to /openxpki/welcome')
        return this.router.transitionTo('openxpki', 'welcome', { queryParams: { trigger: 'nav' } })
    }
}
