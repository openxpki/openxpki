import EmberRouter from '@ember/routing/router'
import config from 'openxpki/config/environment'

export default class Router extends EmberRouter {
    location = config.locationType
    rootURL = config.rootURL
}

Router.map(function() {
    /* Routes:
     *      /                       app/pods/index/route.js
     *      /openxpki/:page         app/pods/openxpki/route.js
     */
    this.route("openxpki", { path: "/openxpki/:page" }, function() {
         this.route("popup", { path: "/popup/:popup_page" })
    })
    if (config.environment === 'development') this.route("test")
})
