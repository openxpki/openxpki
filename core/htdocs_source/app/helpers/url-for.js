import Helper from "@ember/component/helper";
import { inject as service } from '@ember/service';

/*

Returns the URL for the given Ember route.

Example:

    <a href="{{url-for "openxpki" "login" (hash param1=4)}}">Click</a>

*/
export default class UrlFor extends Helper {
    @service router;

    compute([route, model, params]) {
        return this.router.urlFor(route, model, { queryParams: params });
    }
}
