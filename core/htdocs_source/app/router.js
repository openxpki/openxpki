import EmberRouter from '@ember/routing/router'
import config from 'openxpki/config/environment'

export default class Router extends EmberRouter {
    location = config.locationType
    rootURL = config.rootURL
}

Router.map(function() {
    this.route("openxpki", { path: "/openxpki/:page" })
    if (config.environment === 'development') this.route("test")
})
