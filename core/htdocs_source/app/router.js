import EmberRouter from '@embroider/router'
import config from 'openxpki/config/environment'

/**
 * Ember application router. Defines the URL-to-route mapping:
 *
 * - `/` - {@link IndexRoute}
 * - `/openxpki/:page` - {@link OpenXpkiRoute}
 * - `/openxpki/:page/popup/:pp` - {@link OpenXpkiRoute::Popup} child route
 *
 * The `/test` route is only registered in the `development` environment.
 *
 * @class Router
 * @extends EmberRouter
 */
export default class Router extends EmberRouter {
    location = config.locationType
    rootURL = config.rootURL
}

Router.map(function() {
    /* Routes:
     *      /                       app/route-pods/index/route.js
     *      /openxpki/:page         app/route-pods/openxpki/route.js
     */
    this.route("openxpki", { path: "/openxpki/:page" }, function() {
         this.route("popup", { path: "/popup/:popup_page" })
         if (config.environment === 'development') {
             this.route('test', { path: '/test' })
         }
    })
    if (config.environment === 'development') this.route("test")
})
