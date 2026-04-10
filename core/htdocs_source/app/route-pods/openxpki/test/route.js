import Route from '@ember/routing/route'
import { setupPretender, shutdownPretender } from './pretender-setup'

export default class TestRoute extends Route {
    beforeModel() {
        setupPretender()  // no-op if already set up by the initializer
    }

    deactivate() {
        shutdownPretender()
    }
}
