import Helper from "@ember/component/helper";
import { inject } from '@ember/service';

/**
 * Returns the URL for the given Ember route.
 *
 * Example:
 * ```html
 * <a href="{{url-for "openxpki" "login" (hash param1=4)}}">Click</a>
 * ```
 * @module helper/url-for
 */
export default class UrlFor extends Helper {
    @inject router;

    compute([ route, model, params = {} ]) {
        return this.router.urlFor(route, model, { queryParams: params });
    }
}
