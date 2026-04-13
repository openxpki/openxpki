import Helper from "@ember/component/helper";

/**
 * Convert given value to lowercase.
 *
 * Example:
 * ```html
 * <span>{{lc this.value}}</span>
 * ```
 * @module helper/lc
 */
export default class Lc extends Helper {
    /**
     * Returns `val` converted to lowercase.
     * @memberOf module:helper/lc
     */
    compute([val]) {
        return (new String(val)).toLowerCase();
    }
}
