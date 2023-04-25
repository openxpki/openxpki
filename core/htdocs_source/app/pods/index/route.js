import Route from '@ember/routing/route'
import { service } from '@ember/service'
import { debug } from '@ember/debug'

export default class IndexRoute extends Route {
    @service router

    redirect(/*model, transition*/) {
        debug("Redirecting from / to /openxpki/welcome")
        return this.router.transitionTo("openxpki", "welcome")
    }
}
