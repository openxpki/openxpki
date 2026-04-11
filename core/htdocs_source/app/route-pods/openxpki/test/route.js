import Route from '@ember/routing/route'

export default class TestRoute extends Route {
    async beforeModel() {
        const { setupPretender } = await import('./pretender-setup')
        await setupPretender()  // no-op if already set up by the parent route's beforeModel
    }

    async deactivate() {
        const { shutdownPretender } = await import('./pretender-setup')
        shutdownPretender()
    }
}
